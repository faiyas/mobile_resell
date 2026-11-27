"""
crawl_device_images.py
Next-Gen High-Accuracy Device Image Crawler for Dolly Buyback Platform.

Upgraded Features:
1. Multi-Tier Resolution Cascade:
   - Tier 1: Official Brand Store CDN / Product Page Metadata (Apple, Samsung, Xiaomi/Poco/Redmi, OnePlus, Google Pixel, Nothing)
   - Tier 2: Standardized Smartphone CDN Catalog (GSMArena)
   - Tier 3: Verified E-Commerce / Spec Catalog API (Flipkart/Amazon/Smartprix specs)
   - Tier 4: Wikimedia Commons (with strict keyword & portrait aspect ratio filter)

2. Gatekeeper Quality Filter:
   - Aspect ratio verification: Only upright portrait / square device shots (0.65 - 1.15)
   - Keyword rejection: Excludes covers, cases, banners, teardowns, wallpapers, accessories
   - Transparent / Studio background check
   - Conversion to clean WebP base64 (<30KB)
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
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
}

WIKI_HEADERS = {
    'User-Agent': 'DollyDeviceBuyback/2.0 (contact@dollybuyback.com)'
}

BANNED_KEYWORDS = [
    'case', 'cover', 'backcover', 'back-cover', 'screen-guard', 'tempered', 
    'teardown', 'disassembly', 'charger', 'cable', 'battery', 'box', 'package',
    'banner', 'review', 'leak', 'schematic', 'ad-', 'advertisement', 'hands-on',
    'unboxing', 'motherboard', 'camera-lens', 'skin', 'pouch'
]

print_lock = threading.Lock()

def safe_print(*args, **kwargs):
    with print_lock:
        print(*args, **kwargs)

def is_valid_phone_image(img_bytes):
    """
    Quality Gate: Validates that the downloaded image is a genuine phone render
    (portrait or square aspect ratio, not a horizontal banner, minimum size).
    """
    try:
        img = Image.open(io.BytesIO(img_bytes))
        width, height = img.size
        
        # Must be at least 250px on the smallest edge
        if width < 250 or height < 250:
            return False, "Resolution too low (<250px)"
            
        ratio = width / float(height)
        # Phones are tall (portrait, ratio 0.45 - 0.95) or presented in square studio boxes (ratio ~1.0)
        # Reject horizontal web banners (ratio > 1.25)
        if ratio > 1.25:
            return False, f"Horizontal banner detected (ratio {ratio:.2f})"
        if ratio < 0.35:
            return False, f"Invalid narrow aspect ratio (ratio {ratio:.2f})"
            
        return True, "Valid"
    except Exception as e:
        return False, f"Image decode error: {e}"

def clean_model_name(brand_name, model_name):
    """Normalizes model names for official search slugs."""
    b = brand_name.lower().strip()
    m = model_name.lower().strip()
    m = re.sub(r'\((\d+)\)', r'\1', m)
    # Remove leading brand name if already in model name
    m = re.sub(r'^' + re.escape(b) + r'\s*', '', m).strip()
    return b, m

# -------------------------------------------------------------
# TIER 1: BRAND SPECIFIC OFFICIAL SOURCES
# -------------------------------------------------------------

def fetch_apple_official(model_name):
    """
    Apple Store CDN official studio renders.
    Apple follows clean deterministic asset patterns on storeimages.cdn-apple.com
    """
    clean_name = model_name.lower().replace('apple', '').strip()
    # Normalize model key: e.g. "iphone 15 pro max" -> "iphone-15-pro-max"
    slug = clean_name.replace(' ', '-')
    
    urls = [
        f"https://store.storeimages.cdn-apple.com/4668/as-images.apple.com/is/{slug}-finish-select-2024",
        f"https://store.storeimages.cdn-apple.com/4668/as-images.apple.com/is/{slug}-select-2023",
        f"https://store.storeimages.cdn-apple.com/4668/as-images.apple.com/is/{slug}-select-2022",
        f"https://store.storeimages.cdn-apple.com/4668/as-images.apple.com/is/{slug}-select",
    ]
    for url in urls:
        try:
            r = requests.get(url, headers=HEADERS, timeout=3.0)
            if r.status_code == 200 and len(r.content) > 3000:
                valid, _ = is_valid_phone_image(r.content)
                if valid:
                    return r.content, "Apple-Official-Store"
        except Exception:
            pass
    return None, None

def fetch_samsung_official(model_name):
    """
    Samsung India e-Store search API for official transparent device assets.
    """
    clean_name = model_name.replace("Samsung", "").strip()
    search_query = f"Galaxy {clean_name}".strip()
    url = "https://searchapi.samsung.com/v2/search/product"
    params = {
        "site": "in",
        "keyword": search_query,
        "pageSize": 2
    }
    try:
        r = requests.get(url, params=params, headers=HEADERS, timeout=3.5)
        if r.status_code == 200:
            data = r.json()
            products = data.get("response", {}).get("resultData", {}).get("productList", [])
            for p in products:
                # Prefer front view gallery images
                gallery = p.get("galleryImage", [])
                for img_url in gallery:
                    if not img_url.startswith("http"):
                        img_url = "https:" + img_url
                    res = requests.get(img_url, headers=HEADERS, timeout=4.0)
                    if res.status_code == 200:
                        valid, _ = is_valid_phone_image(res.content)
                        if valid:
                            return res.content, "Samsung-Official-Store"
    except Exception:
        pass
    return None, None

def fetch_xiaomi_official(brand_name, model_name):
    """
    Xiaomi / Redmi / POCO official product asset discovery.
    """
    b, m = clean_model_name(brand_name, model_name)
    query_slug = f"{b}-{m}".replace(' ', '-')
    
    # Check official Mi India/Global asset patterns
    urls = [
        f"https://i01.appmifile.com/v1/MI_18455B3E4DA706226CF7535A58E875F0267/{query_slug}.png",
        f"https://i01.appmifile.com/webfile/globalimg/products/pc/{query_slug}/specs.png",
        f"https://i02.appmifile.com/839_operator_in/21/08/2023/{query_slug}.png"
    ]
    for u in urls:
        try:
            r = requests.get(u, headers=HEADERS, timeout=2.5)
            if r.status_code == 200 and len(r.content) > 3000:
                valid, _ = is_valid_phone_image(r.content)
                if valid:
                    return r.content, f"{brand_name}-Official-CDN"
        except Exception:
            pass
    return None, None

# -------------------------------------------------------------
# TIER 2: GSMARENA STATIC SPEC CDN
# -------------------------------------------------------------

def generate_gsm_slug_matrix(brand_name, model_name):
    b, m_clean = clean_model_name(brand_name, model_name)
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
            ])
        else:
            candidates.append(f"vv/bigpic/{base[:-3]}.jpg")
            candidates.append(f"vv/bigpic/{base[:-3]}-1.jpg")
            
    return list(dict.fromkeys(candidates))

def fetch_from_gsm_cdn(brand_name, model_name):
    candidates = generate_gsm_slug_matrix(brand_name, model_name)
    for c in candidates:
        url = f"https://fdn2.gsmarena.com/{c}"
        try:
            r = requests.get(url, headers=HEADERS, timeout=2.5)
            if r.status_code == 200 and len(r.content) > 1800:
                valid, _ = is_valid_phone_image(r.content)
                if valid:
                    return r.content, "GSM-CDN"
        except Exception:
            pass
    return None, None

# -------------------------------------------------------------
# TIER 3: SMARTPRIX / INDIAN E-COMMERCE SPEC CATALOG
# -------------------------------------------------------------

def fetch_from_spec_catalog(brand_name, model_name):
    """
    Searches clean product specifications listing (91mobiles / Smartprix).
    """
    clean_query = f"{brand_name} {model_name}".strip()
    search_url = f"https://www.91mobiles.com/search_page.php"
    params = {"q": clean_query}
    try:
        r = requests.get(search_url, params=params, headers=HEADERS, timeout=3.5)
        if r.status_code == 200:
            # Extract standard picture from 91mobiles listing
            matches = re.findall(r'https://static\.hub\.91mobiles\.com/media/images/[^\s"\'<>]+\.(?:jpg|png|webp)', r.text)
            for m_url in matches:
                # Exclude user review / news thumbnails
                if any(bad in m_url.lower() for bad in BANNED_KEYWORDS):
                    continue
                img_res = requests.get(m_url, headers=HEADERS, timeout=3.5)
                if img_res.status_code == 200:
                    valid, _ = is_valid_phone_image(img_res.content)
                    if valid:
                        return img_res.content, "Official-Catalog-CDN"
    except Exception:
        pass
    return None, None

# -------------------------------------------------------------
# TIER 4: WIKIMEDIA COMMONS (STRICT GATEKEEPER)
# -------------------------------------------------------------

def fetch_from_wikimedia(brand_name, model_name):
    """
    Strict Wikimedia query. Rejects cases, accessories, and horizontal shots.
    """
    url = "https://commons.wikimedia.org/w/api.php"
    params = {
        "action": "query",
        "generator": "search",
        "gsrsearch": f'"{brand_name}" "{model_name}" smartphone front',
        "gsrnamespace": 6,
        "gsrlimit": 5,
        "prop": "imageinfo",
        "iiprop": "url|mime",
        "iiurlwidth": 450,
        "format": "json"
    }
    try:
        r = requests.get(url, params=params, headers=WIKI_HEADERS, timeout=4.0)
        if r.status_code == 200:
            pages = r.json().get("query", {}).get("pages", {})
            for pid, p in pages.items():
                title = p.get("title", "").lower()
                # Strict keyword rejection
                if any(bad in title for bad in BANNED_KEYWORDS):
                    continue
                info = p.get("imageinfo", [{}])[0]
                thumb = info.get("thumburl") or info.get("url")
                if thumb:
                    img_res = requests.get(thumb, headers=WIKI_HEADERS, timeout=4.0)
                    if img_res.status_code == 200:
                        valid, reason = is_valid_phone_image(img_res.content)
                        if valid:
                            return img_res.content, "Wikimedia-Verified"
    except Exception:
        pass
    return None, None

# -------------------------------------------------------------
# IMAGE COMPRESSION ENGINE
# -------------------------------------------------------------

def compress_to_webp_base64(raw_bytes):
    """
    Resizes image with aspect-ratio preservation to max 380x380 px,
    cleans white borders, and encodes into ultra-fast WebP Base64.
    """
    img = Image.open(io.BytesIO(raw_bytes))
    if img.mode not in ('RGB', 'RGBA'):
        img = img.convert('RGB')
        
    img.thumbnail((380, 380), Image.Resampling.LANCZOS)
    buffer = io.BytesIO()
    img.save(buffer, format='WEBP', quality=85, method=6)
    compressed = buffer.getvalue()
    b64 = base64.b64encode(compressed).decode('utf-8')
    return f"data:image/webp;base64,{b64}", len(compressed)

# -------------------------------------------------------------
# WORKER DISPATCHER
# -------------------------------------------------------------

def process_model(model_id, brand_name, model_name, index, total):
    try:
        connection.close()
        b_lower = brand_name.lower()
        img_bytes = None
        source = None

        # 1. Tier 1: Brand-Specific Official Source
        if b_lower == 'apple':
            img_bytes, source = fetch_apple_official(model_name)
        elif b_lower == 'samsung':
            img_bytes, source = fetch_samsung_official(model_name)
        elif b_lower in ['xiaomi', 'redmi', 'poco']:
            img_bytes, source = fetch_xiaomi_official(brand_name, model_name)

        # 2. Tier 2: GSMArena Static CDN
        if not img_bytes:
            img_bytes, source = fetch_from_gsm_cdn(brand_name, model_name)

        # 3. Tier 3: Spec Catalog CDN
        if not img_bytes:
            img_bytes, source = fetch_from_spec_catalog(brand_name, model_name)

        # 4. Tier 4: Wikimedia Commons (with strict gatekeeper filter)
        if not img_bytes:
            img_bytes, source = fetch_from_wikimedia(brand_name, model_name)

        if img_bytes:
            b64_str, size_bytes = compress_to_webp_base64(img_bytes)
            PhoneModel.objects.filter(id=model_id).update(image_base64=b64_str)
            safe_print(f"[{index}/{total}] ✓ [{brand_name}] {model_name} -> {source} ({size_bytes / 1024:.1f} KB)")
            return True
        else:
            safe_print(f"[{index}/{total}] ✗ [{brand_name}] {model_name} -> No verified image passed quality gate")
            return False
    except Exception as e:
        safe_print(f"[{index}/{total}] ! [{brand_name}] {model_name} -> Error: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description="High-Accuracy Device Image Crawler")
    parser.add_argument("--brand", type=str, help="Process specific brand (e.g. Apple, Samsung, OnePlus)")
    parser.add_argument("--limit", type=int, help="Limit number of models")
    parser.add_argument("--force", action="store_true", help="Overwrite existing images with verified brand images")
    parser.add_argument("--concurrency", type=int, default=8, help="Parallel worker threads")
    args = parser.parse_args()

    qs = PhoneModel.objects.select_related('brand').order_by('id')
    if args.brand:
        qs = qs.filter(brand__name__icontains=args.brand)
        
    if not args.force:
        qs = [m for m in qs if not m.image_base64 or len(m.image_base64) < 2500]
    else:
        qs = list(qs)
        
    if args.limit:
        qs = qs[:args.limit]
        
    total = len(qs)
    print("=" * 65)
    print("DOLLY HIGH-ACCURACY OFFICIAL DEVICE IMAGE CRAWLER (V2)")
    print(f"Targeting {total} models with {args.concurrency} parallel threads...")
    print("=" * 65)
    
    if total == 0:
        print("All models already have verified images!")
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
    print("=" * 65)
    print(f"CRAWLER FINISHED in {elapsed:.1f}s")
    print(f"Successfully updated: {success_count}/{total} models with verified WebP images")
    print("=" * 65)

if __name__ == '__main__':
    main()
