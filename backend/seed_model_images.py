"""
seed_model_images.py
Automated Phone Model Image Seeder for Dolly Buyback Platform.
Fetches high-res device renders, compresses to lightweight base64 thumbnails,
and updates PhoneModel.image_base64.

Usage:
    python seed_model_images.py                   # Seeds all models without images
    python seed_model_images.py --brand Apple      # Seeds Apple models only
    python seed_model_images.py --brand Samsung    # Seeds Samsung models only
    python seed_model_images.py --limit 50         # Seeds first 50 models
"""

import os
import io
import re
import sys
import time
import base64
import argparse
import requests
import django
from PIL import Image, ImageDraw, ImageFont

# Initialize Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from apps.catalog.models import Brand, PhoneModel

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
}

WIKI_HEADERS = {
    'User-Agent': 'DollyBuybackCatalog/1.0 (contact@dollyresell.com)'
}

def generate_slug_variants(brand_name, model_name):
    """Generate smart CDN slug variants for a phone model."""
    b = brand_name.lower().strip()
    m = model_name.lower().strip()
    
    # Strip leading brand name if repeated
    m_clean = re.sub(r'^' + re.escape(b) + r'\s*', '', m)
    
    # Base slug
    base = f"{b}-{m_clean}"
    base = re.sub(r'[^a-z0-9]+', '-', base).strip('-')
    
    variants = [
        f"{base}.jpg",
        f"{base}-5g.jpg",
        f"{base.replace('-5g', '')}.jpg",
    ]
    
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
            r = requests.get(url, headers=HEADERS, timeout=4)
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
        r = requests.get(api, params=params, headers=WIKI_HEADERS, timeout=6)
        if r.status_code == 200:
            pages = r.json().get('query', {}).get('pages', {})
            for pid, p in pages.items():
                infos = p.get('imageinfo', [])
                if infos:
                    url = infos[0].get('url')
                    mime = infos[0].get('mime', '')
                    if any(x in mime for x in ['jpeg', 'png', 'webp', 'jpg']):
                        img_res = requests.get(url, headers=WIKI_HEADERS, timeout=8)
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
    
    # Outer phone frame
    phone_x0, phone_y0 = 60, 20
    phone_x1, phone_y1 = 180, 220
    corner_radius = 24
    
    # Phone body
    draw.rounded_rectangle([phone_x0, phone_y0, phone_x1, phone_y1], radius=corner_radius, fill=(245, 247, 250), outline=(203, 213, 225), width=3)
    # Screen area
    draw.rounded_rectangle([phone_x0 + 6, phone_y0 + 10, phone_x1 - 6, phone_y1 - 10], radius=16, fill=(15, 23, 42))
    # Camera pill at top
    draw.rounded_rectangle([105, 30, 135, 36], radius=3, fill=(51, 65, 85))
    
    # Brand initials/name on screen
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
    """Resize, clean and compress image into a lightweight WebP/PNG base64 string."""
    img = Image.open(io.BytesIO(raw_bytes))
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
        
    # Resize to max 260x260 with high-quality resampling
    img.thumbnail((260, 260), Image.Resampling.LANCZOS)
    
    buf = io.BytesIO()
    # Save as compressed WebP or PNG
    img.save(buf, format='WEBP', quality=85, method=6)
    b64 = base64.b64encode(buf.getvalue()).decode('utf-8')
    return f"data:image/webp;base64,{b64}"

def seed_models(brand_filter=None, limit=None, force=False):
    qs = PhoneModel.objects.select_related('brand').all()
    if brand_filter:
        qs = qs.filter(brand__name__iexact=brand_filter)
    if not force:
        qs = qs.filter(image_base64='')
        
    total = qs.count()
    if limit:
        qs = qs[:limit]
        total = min(total, limit)
        
    print(f"\n=======================================================")
    print(f"  SEEDING PHONE MODEL IMAGES ({total} models queued)")
    print(f"=======================================================\n")
    
    success = 0
    fallback_used = 0
    
    for idx, model in enumerate(qs, 1):
        brand_name = model.brand.name if model.brand else 'Device'
        model_name = model.name
        print(f"[{idx}/{total}] Fetching image for: {brand_name} {model_name}...", end=" ", flush=True)
        
        # 1. Try GSMArena CDN
        img_bytes, source_url = fetch_from_gsm_cdn(brand_name, model_name)
        source_name = "GSM-CDN"
        
        # 2. Try Wikimedia Commons
        if not img_bytes:
            img_bytes, source_url = fetch_from_wikimedia(brand_name, model_name)
            source_name = "Wikimedia"
            
        # 3. Fallback to clean branded silhouette if not found
        if not img_bytes:
            img_bytes = generate_fallback_phone_render(brand_name, model_name)
            source_name = "BrandedRender"
            fallback_used += 1
            
        try:
            b64_str = process_and_compress_image(img_bytes)
            model.image_base64 = b64_str
            model.save(update_fields=['image_base64'])
            print(f"✓ ({source_name})")
            success += 1
        except Exception as e:
            print(f"✗ Failed to save: {e}")
            
        time.sleep(0.15)
        
    print(f"\n=======================================================")
    print(f"  COMPLETED: {success}/{total} model images seeded!")
    print(f"  (Real Online Photos: {success - fallback_used}, Silhouette Fallbacks: {fallback_used})")
    print(f"=======================================================\n")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Seed phone model images")
    parser.add_argument('--brand', type=str, help="Specific brand to seed (e.g. Apple)")
    parser.add_argument('--limit', type=int, help="Limit number of models to process")
    parser.add_argument('--force', action='store_true', help="Overwrite existing model images")
    args = parser.parse_args()
    
    seed_models(brand_filter=args.brand, limit=args.limit, force=args.force)
