import os
import io
import json
import time
import base64
import requests
import django
from PIL import Image

try:
    import fitz
except ImportError:
    fitz = None

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from apps.catalog.models import Brand

BRAND_URLS = {
    'Apple': 'https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/apple.svg',
    'Samsung': 'https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/samsung.svg',
    'OnePlus': 'https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/oneplus.svg',
    'Xiaomi': 'https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/xiaomi.svg',
    'Redmi': 'https://upload.wikimedia.org/wikipedia/commons/a/ae/Redmi_10A_Logo.svg',
    'POCO': 'https://upload.wikimedia.org/wikipedia/commons/0/0d/Poco_Logo_Transparent.png',
    'Vivo': 'https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/vivo.svg',
    'iQOO': 'https://upload.wikimedia.org/wikipedia/commons/2/27/IQOO_Neo10_logo.png',
    'OPPO': 'https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/oppo.svg',
    'Realme': 'https://upload.wikimedia.org/wikipedia/commons/1/1d/Realme-realme-_logo_box-RGB-01.svg',
    'Motorola': 'https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/motorola.svg',
    'Google': 'https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/google.svg',
    'Nothing': 'https://upload.wikimedia.org/wikipedia/commons/4/4e/Nothing_Phone_1_wordmark.svg',
    'ASUS': 'https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/asus.svg',
    'CMF by Nothing': 'https://upload.wikimedia.org/wikipedia/commons/4/4e/Nothing_Phone_1_wordmark.svg',
    'HONOR': 'https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/honor.svg',
    'Huawei': 'https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/huawei.svg',
    'Infinix': 'https://upload.wikimedia.org/wikipedia/commons/8/85/Infinix_logo.jpg',
    'Lava': 'https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/lava.svg',
    'REDMAGIC': 'https://upload.wikimedia.org/wikipedia/commons/7/77/Nubia_Technology_logo.svg',
    'Sony': 'https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/sony.svg',
    'TECNO': 'https://thumb.wikimedia.org/wikipedia/commons/thumb/e/ec/Tecno_Mobile_logo.svg/320px-Tecno_Mobile_logo.svg.png',
    'ZTE': 'https://thumb.wikimedia.org/wikipedia/commons/thumb/2/20/ZTE-logo.svg/330px-ZTE-logo.svg.png',
    'itel': 'https://upload.wikimedia.org/wikipedia/commons/d/d9/Itel-mobile-logo-vector.svg',
    'nubia': 'https://upload.wikimedia.org/wikipedia/commons/7/77/Nubia_Technology_logo.svg',
}

headers = {'User-Agent': 'DollyBuybackCatalog/1.0 (contact@dollyresell.com)'}

def fetch_and_convert_to_png_base64(url):
    r = requests.get(url, headers=headers, timeout=12)
    if r.status_code != 200:
        raise Exception(f"HTTP {r.status_code}")
    
    raw_data = r.content
    content_type = r.headers.get('Content-Type', '').lower()
    is_svg = url.lower().endswith('.svg') or 'svg' in content_type or b'<svg' in raw_data[:200]
    
    if is_svg:
        if not fitz:
            raise Exception("PyMuPDF (fitz) required for SVG rendering")
        doc = fitz.open(stream=raw_data, filetype="svg")
        pix = doc[0].get_pixmap(dpi=200)
        png_bytes = pix.tobytes("png")
        img = Image.open(io.BytesIO(png_bytes))
    else:
        img = Image.open(io.BytesIO(raw_data))

    # Convert to RGBA
    if img.mode != 'RGBA':
        img = img.convert('RGBA')

    # Resize while maintaining aspect ratio (max 200x200)
    img.thumbnail((200, 200), Image.Resampling.LANCZOS)
    
    buf = io.BytesIO()
    img.save(buf, format='PNG', optimize=True)
    b64_str = base64.b64encode(buf.getvalue()).decode('utf-8')
    return f"data:image/png;base64,{b64_str}"

def run():
    print("=== SEEDING ALL 25 BRAND LOGOS ===")
    
    # 1. Fast path: load pre-converted high quality PNG logos if JSON exists
    json_path = os.path.join(os.path.dirname(__file__), 'brand_logos.json')
    if os.path.exists(json_path):
        try:
            with open(json_path, 'r', encoding='utf-8') as f:
                cached_logos = json.load(f)
            print(f"[*] Found pre-converted brand_logos.json with {len(cached_logos)} logos.")
            updated = 0
            for brand_name, b64_str in cached_logos.items():
                brand = Brand.objects.filter(name__iexact=brand_name).first()
                if brand:
                    brand.logo_base64 = b64_str
                    brand.save(update_fields=['logo_base64'])
                    print(f"  [✓] Updated logo for '{brand.name}'")
                    updated += 1
            print(f"\n[+] Successfully seeded {updated}/25 brand logos instantly!\n")
            return
        except Exception as e:
            print(f"[-] Could not load cached JSON: {e}. Falling back to web fetch...")

    # 2. Web fallback path
    success_count = 0
    for brand_name, url in BRAND_URLS.items():
        try:
            brand = Brand.objects.filter(name__iexact=brand_name).first()
            if not brand:
                print(f"[-] Brand '{brand_name}' not found in database. Skipping.")
                continue

            print(f"[*] Fetching logo for '{brand_name}' from {url}...")
            b64_str = fetch_and_convert_to_png_base64(url)
            brand.logo_base64 = b64_str
            brand.save(update_fields=['logo_base64'])
            print(f"  [+] Saved logo for '{brand_name}' ({len(b64_str)} chars)")
            success_count += 1
            time.sleep(0.2)
        except Exception as e:
            print(f"  [!] Failed for '{brand_name}': {e}")

    print(f"\nFinished seeding: {success_count}/{len(BRAND_URLS)} logos updated successfully.")

if __name__ == '__main__':
    run()
