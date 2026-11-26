"""
seed_model_images.py
High-Performance Automated Phone Model Image Seeder & Crawler for Dolly Platform.
Multi-threaded parallel fetching, smart slug matching, and automatic compression to WebP base64.

Usage:
    python seed_model_images.py                     # Crawls & seeds ALL models in parallel (8 threads)
    python seed_model_images.py --concurrency 10     # Faster crawling with 10 parallel threads
    python seed_model_images.py --brand Samsung     # Seeds Samsung models only
    python seed_model_images.py --brand Vivo        # Seeds Vivo models only
    python seed_model_images.py --limit 100         # Seeds first 100 unseeded models
    python seed_model_images.py --force             # Re-crawl even if model already has image
"""

import os
import io
import re
import sys
import time
import base64
import argparse
import requests
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
import django
from PIL import Image, ImageDraw, ImageFont

# Initialize Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.db import connection
from apps.catalog.models import Brand, PhoneModel

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
}

WIKI_HEADERS = {
    'User-Agent': 'DollyBuybackCatalog/1.0 (contact@dollyresell.com)'
}

print_lock = threading.Lock()

def safe_print(*args, **kwargs):
    with print_lock:
        print(*args, **kwargs)

def generate_slug_variants(brand_name, model_name):
    """Generate smart CDN slug variants for any phone model across all brands."""
    b = brand_name.lower().strip()
    m = model_name.lower().strip()
    
    # Strip leading brand name if repeated
    m_clean = re.sub(r'^' + re.escape(b) + r'\s*', '', m).strip()
    
    # Base slug
    base = f"{b}-{m_clean}"
    base = re.sub(r'[^a-z0-9]+', '-', base).strip('-')
    
    variants = [
        f"{base}.jpg",
        f"{base}-5g.jpg",
        f"{base}-4g.jpg",
        f"{base.replace('-5g', '')}.jpg",
    ]
    
    # Brand specific adjustments
    if b == 'samsung':
        if not m_clean.startswith('galaxy-'):
            variants.append(f"samsung-galaxy-{m_clean}.jpg")
            variants.append(f"samsung-galaxy-{m_clean}-5g.jpg")
    elif b in ['redmi', 'poco']:
        # Often indexed under xiaomi-redmi or xiaomi-poco
        variants.append(f"xiaomi-{b}-{m_clean}.jpg")
        variants.append(f"xiaomi-{b}-{m_clean}-5g.jpg")
    elif b == 'motorola':
        if not m_clean.startswith('moto-'):
            variants.append(f"motorola-moto-{m_clean}.jpg")
            variants.append(f"motorola-moto-{m_clean}-5g.jpg")
            
    # Number suffixes (e.g. reno11 vs reno-11)
    no_dashes = re.sub(r'-(\d+)', r'\1', base)
    if no_dashes != base:
        variants.append(f"{no_dashes}.jpg")
        variants.append(f"{no_dashes}-5g.jpg")

    if 'plus' in m_clean:
        variants.append(f"{base.replace('plus', 's')}.jpg")
    if '+' in m_clean:
        variants.append(f"{base.replace('+', '-plus')}.jpg")
        variants.append(f"{base.replace('+', '-plus-5g')}.jpg")
        variants.append(f"{base.replace('+', 'plus')}.jpg")
    if 'pro-max' in base:
        variants.append(f"{base.replace('pro-max', 'promax')}.jpg")
    if 'ultra' in base and '-5g' not in base:
        variants.append(f"{base}-5g.jpg")

    return list(dict.fromkeys(variants))

def fetch_from_gsm_cdn(brand_name, model_name):
    """Check GSMArena static image CDN for matching render."""
    variants = generate_slug_variants(brand_name, model_name)
    for v in variants:
        url = f"https://fdn2.gsmarena.com/vv/bigpic/{v}"
        try:
            r = requests.get(url, headers=HEADERS, timeout=3.5)
            if r.status_code == 200 and len(r.content) > 1000:
                return r.content, url
        except Exception:
            pass
    return None, None

def fetch_from_wikimedia(brand_name, model_name):
    """Search Wikimedia Commons for authentic device render/photo."""
    query = f"{brand_name} {model_name}"
    api = "https://commons.wikimedia.org/w/api.php"
    params = {
        'action': 'query',
        'generator': 'search',
        'gsrsearch': query,
        'gsrnamespace': 6,
        'gsrlimit': 2,
        'prop': 'imageinfo',
        'iiprop': 'url|mime',
        'format': 'json'
    }
    try:
        r = requests.get(api, params=params, headers=WIKI_HEADERS, timeout=5)
        if r.status_code == 200:
            pages = r.json().get('query', {}).get('pages', {})
            for _, p in pages.items():
                infos = p.get('imageinfo', [])
                if infos:
                    url = infos[0].get('url', '')
                    mime = infos[0].get('mime', '').lower()
                    if any(x in mime for x in ['jpeg', 'png', 'webp', 'jpg']):
                        img_res = requests.get(url, headers=WIKI_HEADERS, timeout=6)
                        if img_res.status_code == 200 and len(img_res.content) > 2000:
                            return img_res.content, url
    except Exception:
        pass
    return None, None

def generate_fallback_phone_render(brand_name, model_name):
    """Generates a clean modern phone device silhouette with brand label."""
    width, height = 240, 240
    img = Image.new('RGBA', (width, height), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)
    
    phone_x0, phone_y0 = 60, 20
    phone_x1, phone_y1 = 180, 220
    corner_radius = 24
    
    draw.rounded_rectangle([phone_x0, phone_y0, phone_x1, phone_y1], radius=corner_radius, fill=(245, 247, 250), outline=(203, 213, 225), width=3)
    draw.rounded_rectangle([phone_x0 + 6, phone_y0 + 10, phone_x1 - 6, phone_y1 - 10], radius=16, fill=(15, 23, 42))
    draw.rounded_rectangle([105, 30, 135, 36], radius=3, fill=(51, 65, 85))
    
    short_brand = (brand_name[:8]).upper()
    try:
        draw.text((120, 110), short_brand, fill=(11, 170, 75), anchor="mm")
        draw.text((120, 130), "DOLLY", fill=(148, 163, 184), anchor="mm")
    except Exception:
        pass
        
    buf = io.BytesIO()
    img.save(buf, format='PNG', optimize=True)
    return buf.getvalue()

def process_and_compress_image(raw_bytes):
    """Resize, clean and compress image into a lightweight WebP base64 string."""
    img = Image.open(io.BytesIO(raw_bytes))
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
        
    img.thumbnail((260, 260), Image.Resampling.LANCZOS)
    
    buf = io.BytesIO()
    img.save(buf, format='WEBP', quality=85, method=6)
    b64 = base64.b64encode(buf.getvalue()).decode('utf-8')
    return f"data:image/webp;base64,{b64}"

def process_single_model(model_id, brand_name, model_name, counter, total):
    """Worker function to process one phone model in a thread-safe manner."""
    try:
        connection.close()  # Refresh thread-specific DB connection
        
        # 1. Try GSMArena CDN
        img_bytes, source_url = fetch_from_gsm_cdn(brand_name, model_name)
        source_name = "GSM-CDN"
        
        # 2. Try Wikimedia Commons
        if not img_bytes:
            img_bytes, source_url = fetch_from_wikimedia(brand_name, model_name)
            source_name = "Wikimedia"
            
        # 3. Fallback to clean branded silhouette if not found
        fallback = False
        if not img_bytes:
            img_bytes = generate_fallback_phone_render(brand_name, model_name)
            source_name = "BrandedRender"
            fallback = True
            
        b64_str = process_and_compress_image(img_bytes)
        
        PhoneModel.objects.filter(id=model_id).update(image_base64=b64_str)
        safe_print(f"[{counter}/{total}] ✓ {brand_name} {model_name} ({source_name})")
        return True, fallback
    except Exception as e:
        safe_print(f"[{counter}/{total}] ✗ {brand_name} {model_name} failed: {e}")
        return False, False
    finally:
        connection.close()

def seed_models(brand_filter=None, limit=None, force=False, concurrency=8):
    qs = PhoneModel.objects.select_related('brand').all()
    if brand_filter:
        qs = qs.filter(brand__name__iexact=brand_filter)
    if not force:
        qs = qs.filter(image_base64='')
        
    total = qs.count()
    if limit:
        qs = qs[:limit]
        total = min(total, limit)
        
    print(f"\n" + "=" * 65)
    print(f"  DOLLY CATALOG PARALLEL IMAGE SEEDER")
    print(f"  Queued: {total} models | Concurrency: {concurrency} threads")
    if brand_filter:
        print(f"  Brand Filter: {brand_filter}")
    print("=" * 65 + "\n")
    
    if total == 0:
        print("[+] All models already have images! Nothing to seed.\n")
        return

    # Extract model metadata to avoid holding querysets across threads
    model_items = [(m.id, m.brand.name if m.brand else 'Device', m.name) for m in qs]
    
    success_count = 0
    fallback_count = 0
    start_time = time.time()
    
    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = {
            executor.submit(process_single_model, m_id, b_name, m_name, idx, total): (m_id, b_name, m_name)
            for idx, (m_id, b_name, m_name) in enumerate(model_items, 1)
        }
        
        for future in as_completed(futures):
            ok, is_fallback = future.result()
            if ok:
                success_count += 1
                if is_fallback:
                    fallback_count += 1
                    
    elapsed = round(time.time() - start_time, 1)
    real_photos = success_count - fallback_count
    print(f"\n" + "=" * 65)
    print(f"  COMPLETED: {success_count}/{total} model images updated in {elapsed}s!")
    print(f"  - Authentic Online Renders/Photos: {real_photos}")
    print(f"  - Branded Silhouette Fallbacks   : {fallback_count}")
    print("=" * 65 + "\n")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Parallel phone model image crawler and seeder")
    parser.add_argument('--brand', type=str, help="Specific brand to seed (e.g. Samsung, Vivo, Realme)")
    parser.add_argument('--limit', type=int, help="Limit number of models to process")
    parser.add_argument('--concurrency', type=int, default=8, help="Number of parallel worker threads (default: 8)")
    parser.add_argument('--force', action='store_true', help="Overwrite existing model images")
    args = parser.parse_args()
    
    seed_models(
        brand_filter=args.brand,
        limit=args.limit,
        force=args.force,
        concurrency=args.concurrency
    )
