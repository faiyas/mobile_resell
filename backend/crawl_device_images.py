"""
crawl_device_images.py
High-Performance Automated Phone Image Crawler for Dolly Buyback Platform.

Finds and downloads official device renders from GSMArena CDN & Wikimedia Commons,
compresses them into ultra-lightweight WebP base64 (~12KB), and updates the database.

Usage:
    python crawl_device_images.py                   # Updates all missing & unknown device images
    python crawl_device_images.py --brand Apple     # Updates Apple models only
    python crawl_device_images.py --brand Samsung   # Updates Samsung models only
    python crawl_device_images.py --limit 100       # Process first 100 devices
    python crawl_device_images.py --concurrency 8   # Multi-threaded parallel crawling
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
from PIL import Image

# Initialize Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.db import connection
from apps.catalog.models import PhoneModel, Brand

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Referer': 'https://www.gsmarena.com/',
    'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
}

WIKI_HEADERS = {
    'User-Agent': 'DollyBuybackCrawler/1.0 (support@dollybuyback.com)'
}

print_lock = threading.Lock()

def safe_print(*args, **kwargs):
    with print_lock:
        print(*args, **kwargs)

def generate_smart_slug_matrix(brand_name, model_name):
    """Generates all standard official slug variations used by smartphone CDNs."""
    b = brand_name.lower().strip()
    n = model_name.lower().strip()
    
    n_clean = re.sub(r'\((\d+)\)', r'\1', n)
    m_clean = re.sub(r'^' + re.escape(b) + r'\s*', '', n_clean).strip()
    m_slug = re.sub(r'[^a-z0-9]+', '-', m_clean).strip('-')
    
    bases = [f"{b}-{m_slug}"]
    if b == 'samsung' and not m_slug.startswith('galaxy'):
        bases.append(f"samsung-galaxy-{m_slug}")
    elif b == 'motorola' and not m_slug.startswith('moto'):
        bases.append(f"motorola-moto-{m_slug}")
    elif b in ['redmi', 'poco']:
        bases.append(f"xiaomi-{b}-{m_slug}")
    elif b == 'nothing':
        bases.append(f"nothing-{m_slug.replace('-', '')}")
        bases.append(f"nothing-{m_slug}")
        
    candidates = []
    for base in bases:
        candidates.extend([
            f"vv/bigpic/{base}.jpg",
            f"vv/bigpic/{base}-1.jpg",
            f"vv/bigpic/{base}-2.jpg",
            f"vv/bigpic/{base}-new.jpg",
            f"vv/bigpic/{base}-gl.jpg",
            f"vv/bigpic/{base}-in.jpg",
            f"vv/pics/{b}/{base}-1.jpg",
            f"vv/pics/{b}/{base}-2.jpg",
        ])
        if not base.endswith('-5g'):
            candidates.extend([
                f"vv/bigpic/{base}-5g.jpg",
                f"vv/bigpic/{base}-5g-1.jpg",
                f"vv/bigpic/{base}-5g-2.jpg",
            ])
        else:
            base_no_5g = base[:-3]
            candidates.extend([
                f"vv/bigpic/{base_no_5g}.jpg",
                f"vv/bigpic/{base_no_5g}-1.jpg",
                f"vv/bigpic/{base_no_5g}-2.jpg",
            ])
        if base.endswith('-4g'):
            candidates.append(f"vv/bigpic/{base[:-3]}.jpg")
            candidates.append(f"vv/bigpic/{base[:-3]}-2.jpg")
            
    return list(dict.fromkeys(candidates))

def fetch_from_cdn(brand_name, model_name):
    """Checks official GSMArena static image CDN for matching high-res product renders."""
    candidates = generate_smart_slug_matrix(brand_name, model_name)
    for c in candidates:
        url = f"https://fdn2.gsmarena.com/{c}"
        try:
            r = requests.get(url, headers=HEADERS, timeout=3.0)
            if r.status_code == 200 and len(r.content) > 1500:
                return r.content, url
        except Exception:
            pass
    return None, None

def fetch_from_wikimedia(brand_name, model_name):
    """Fallback: Queries Wikimedia Commons for official device renders."""
    url = "https://commons.wikimedia.org/w/api.php"
    params = {
        "action": "query",
        "generator": "search",
        "gsrsearch": f"{brand_name} {model_name} phone",
        "gsrnamespace": 6,
        "gsrlimit": 3,
        "prop": "imageinfo",
        "iiprop": "url|mime",
        "iiurlwidth": 400,
        "format": "json"
    }
    try:
        r = requests.get(url, params=params, headers=WIKI_HEADERS, timeout=4.0)
        if r.status_code == 200:
            pages = r.json().get("query", {}).get("pages", {})
            for pid, p in pages.items():
                title = p.get("title", "").lower()
                if any(bad in title for bad in ['box', 'teardown', 'case', 'charger', 'logo', 'store']):
                    continue
                info = p.get("imageinfo", [{}])[0]
                thumb = info.get("thumburl") or info.get("url")
                if thumb:
                    img_res = requests.get(thumb, headers=WIKI_HEADERS, timeout=5.0)
                    if img_res.status_code == 200 and len(img_res.content) > 2000:
                        return img_res.content, thumb
    except Exception:
        pass
    return None, None

def compress_to_webp_base64(raw_bytes):
    """Resizes to 360x360 and converts to high-quality lightweight WebP base64."""
    img = Image.open(io.BytesIO(raw_bytes))
    if img.mode not in ('RGB', 'RGBA'):
        img = img.convert('RGB')
    img.thumbnail((360, 360), Image.Resampling.LANCZOS)
    
    buffer = io.BytesIO()
    img.save(buffer, format='WEBP', quality=85, method=6)
    compressed = buffer.getvalue()
    b64 = base64.b64encode(compressed).decode('utf-8')
    return f"data:image/webp;base64,{b64}", len(compressed)

def process_model(model_id, brand_name, model_name, index, total):
    try:
        connection.close()  # Refresh thread connection
        
        # 1. Try GSMArena CDN
        img_bytes, source_url = fetch_from_cdn(brand_name, model_name)
        source = "GSM-CDN"
        
        # 2. Try Wikimedia Commons
        if not img_bytes:
            img_bytes, source_url = fetch_from_wikimedia(brand_name, model_name)
            source = "Wikimedia"
            
        if img_bytes:
            b64_str, size_bytes = compress_to_webp_base64(img_bytes)
            PhoneModel.objects.filter(id=model_id).update(image_base64=b64_str)
            safe_print(f"[{index}/{total}] ✓ [{brand_name}] {model_name} -> {source} ({size_bytes / 1024:.1f} KB)")
            return True
        else:
            safe_print(f"[{index}/{total}] ✗ [{brand_name}] {model_name} -> No official image found")
            return False
    except Exception as e:
        safe_print(f"[{index}/{total}] ! [{brand_name}] {model_name} -> Error: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description="Official phone image crawler")
    parser.add_argument("--brand", type=str, help="Process specific brand (e.g. Apple, Samsung, OnePlus)")
    parser.add_argument("--limit", type=int, help="Limit number of models")
    parser.add_argument("--force", action="store_true", help="Overwrite existing images")
    parser.add_argument("--concurrency", type=int, default=8, help="Parallel worker threads")
    args = parser.parse_args()

    qs = PhoneModel.objects.select_related('brand').order_by('id')
    if args.brand:
        qs = qs.filter(brand__name__icontains=args.brand)
        
    # Target missing images or low-res placeholders (length < 2500)
    if not args.force:
        qs = [m for m in qs if not m.image_base64 or len(m.image_base64) < 2500]
    else:
        qs = list(qs)
        
    if args.limit:
        qs = qs[:args.limit]
        
    total = len(qs)
    print("=" * 60)
    print(f"DOLLY OFFICIAL DEVICE IMAGE CRAWLER")
    print(f"Targeting {total} phone models with {args.concurrency} parallel threads...")
    print("=" * 60)
    
    if total == 0:
        print("All models already have official images!")
        return

    success_count = 0
    t0 = time.time()
    
    with ThreadPoolExecutor(max_workers=args.concurrency) as executor:
        futures = {
            executor.submit(process_model, m.id, m.brand.name, m.name, i + 1, total): m
            for i, m in enumerate(qs)
        }
        for f in as_completed(futures):
            if f.result():
                success_count += 1

    elapsed = time.time() - t0
    print("=" * 60)
    print(f"CRAWLER FINISHED in {elapsed:.1f}s")
    print(f"Successfully updated: {success_count}/{total} models with official WebP images")
    print("=" * 60)

if __name__ == '__main__':
    main()
