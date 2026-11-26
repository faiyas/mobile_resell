"""
apps.catalog.image_resolver
Automated image and logo resolution service for Brand and PhoneModel.
Searches high-res renders, Wikimedia, CDN sources, and applies lightweight compression.
"""

import os
import io
import re
import json
import base64
import logging
from PIL import Image, ImageDraw, ImageFont

logger = logging.getLogger(__name__)

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
}

WIKI_HEADERS = {
    'User-Agent': 'DollyBuybackCatalog/1.0 (contact@dollyresell.com)'
}

# -------------------------------------------------------------
# Brand Logo Resolution
# -------------------------------------------------------------

def generate_fallback_brand_badge(brand_name):
    """Generates a modern clean branded icon badge when no logo is found."""
    width, height = 200, 200
    img = Image.new('RGBA', (width, height), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)
    
    # Modern rounded container with subtle border
    draw.rounded_rectangle([10, 10, 190, 190], radius=40, fill=(245, 248, 250), outline=(226, 232, 240), width=3)
    
    # Brand initials / name
    name_clean = brand_name.strip()
    initials = ''.join([w[0] for w in name_clean.split()[:2]]).upper()
    if not initials:
        initials = name_clean[:2].upper()
        
    try:
        # Central brand initial badge
        draw.rounded_rectangle([50, 50, 150, 150], radius=24, fill=(11, 170, 75))
        draw.text((100, 98), initials, fill=(255, 255, 255), anchor="mm")
    except Exception:
        pass
        
    buf = io.BytesIO()
    img.save(buf, format='PNG', optimize=True)
    b64 = base64.b64encode(buf.getvalue()).decode('utf-8')
    return f"data:image/png;base64,{b64}"

def resolve_brand_logo(brand_name):
    """
    Resolves official transparent PNG logo for a brand.
    1. Checks local pre-bundled brand_logos.json (exact and partial word match)
    2. Falls back to online SVG/PNG repos (SimpleIcons / Wikimedia)
    3. Generates modern branded badge fallback
    """
    b_name = brand_name.strip()
    
    # 1. Check local pre-rendered database
    json_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), 'brand_logos.json')
    if os.path.exists(json_path):
        try:
            with open(json_path, 'r', encoding='utf-8') as f:
                cached = json.load(f)
            # 1a. Exact case-insensitive match
            for k, val in cached.items():
                if k.lower() == b_name.lower():
                    return val
            # 1b. Word token match (e.g. "Google Pixel" -> "Google", "Samsung Mobile" -> "Samsung")
            b_words = set(re.findall(r'[a-z0-9]+', b_name.lower()))
            for k, val in cached.items():
                k_words = set(re.findall(r'[a-z0-9]+', k.lower()))
                if k_words and k_words.issubset(b_words):
                    return val
        except Exception as e:
            logger.warning(f"Failed to read brand_logos.json: {e}")

    # 2. Try SimpleIcons SVG repository
    slug = re.sub(r'[^a-z0-9]', '', b_name.lower())
    simple_url = f"https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/{slug}.svg"
    try:
        import requests
        r = requests.get(simple_url, headers=HEADERS, timeout=5)
        if r.status_code == 200 and len(r.content) > 50:
            converted = _convert_svg_or_raster_to_png_base64(r.content, is_svg=True)
            if converted:
                return converted
    except Exception:
        pass

    # 3. Try Wikimedia Commons search
    try:
        import requests
        api = "https://commons.wikimedia.org/w/api.php"
        params = {
            'action': 'query',
            'generator': 'search',
            'gsrsearch': f"{b_name} logo",
            'gsrnamespace': 6,
            'gsrlimit': 3,
            'prop': 'imageinfo',
            'iiprop': 'url|mime',
            'format': 'json'
        }
        r = requests.get(api, params=params, headers=WIKI_HEADERS, timeout=6)
        if r.status_code == 200:
            pages = r.json().get('query', {}).get('pages', {})
            for _, p in pages.items():
                infos = p.get('imageinfo', [])
                if infos:
                    url = infos[0].get('url', '')
                    mime = infos[0].get('mime', '').lower()
                    img_res = requests.get(url, headers=WIKI_HEADERS, timeout=6)
                    if img_res.status_code == 200 and len(img_res.content) > 500:
                        is_svg = 'svg' in mime or url.lower().endswith('.svg')
                        converted = _convert_svg_or_raster_to_png_base64(img_res.content, is_svg=is_svg)
                        if converted:
                            return converted
    except Exception as e:
        logger.warning(f"Wikimedia logo search failed for {b_name}: {e}")

    # 4. Fallback badge
    return generate_fallback_brand_badge(brand_name)

def _convert_svg_or_raster_to_png_base64(raw_bytes, is_svg=False):
    """Renders SVG or raster image to clean RGBA PNG base64."""
    if is_svg:
        try:
            import fitz  # PyMuPDF
            doc = fitz.open(stream=raw_bytes, filetype="svg")
            pix = doc[0].get_pixmap(dpi=200)
            png_bytes = pix.tobytes("png")
            img = Image.open(io.BytesIO(png_bytes))
        except Exception:
            return None
    else:
        try:
            img = Image.open(io.BytesIO(raw_bytes))
        except Exception:
            return None

    if img.mode != 'RGBA':
        img = img.convert('RGBA')

    img.thumbnail((200, 200), Image.Resampling.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format='PNG', optimize=True)
    b64 = base64.b64encode(buf.getvalue()).decode('utf-8')
    return f"data:image/png;base64,{b64}"

# -------------------------------------------------------------
# Phone Model Image Resolution
# -------------------------------------------------------------

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
    try:
        import requests
        variants = generate_slug_variants(brand_name, model_name)
        for v in variants:
            url = f"https://fdn2.gsmarena.com/vv/bigpic/{v}"
            try:
                r = requests.get(url, headers=HEADERS, timeout=3)
                if r.status_code == 200 and len(r.content) > 1000:
                    return r.content
            except Exception:
                pass
    except Exception:
        pass
    return None

def fetch_from_wikimedia(brand_name, model_name):
    """Search Wikimedia Commons for authentic device render/photo."""
    try:
        import requests
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
                            return img_res.content
    except Exception:
        pass
    return None

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

def compress_phone_image_to_webp_base64(raw_bytes):
    """Resize, clean and compress image into a lightweight WebP base64 string."""
    img = Image.open(io.BytesIO(raw_bytes))
    if img.mode != 'RGBA':
        img = img.convert('RGBA')
        
    img.thumbnail((260, 260), Image.Resampling.LANCZOS)
    
    buf = io.BytesIO()
    img.save(buf, format='WEBP', quality=85, method=6)
    b64 = base64.b64encode(buf.getvalue()).decode('utf-8')
    return f"data:image/webp;base64,{b64}"

def resolve_model_image(brand_name, model_name):
    """
    Resolves a high-quality phone image base64 for a given brand and model.
    1. GSMArena static CDN
    2. Wikimedia Commons
    3. Branded silhouette fallback
    """
    # 1. GSMArena static CDN
    img_bytes = fetch_from_gsm_cdn(brand_name, model_name)
    
    # 2. Wikimedia Commons
    if not img_bytes:
        img_bytes = fetch_from_wikimedia(brand_name, model_name)
        
    # 3. Clean fallback
    if not img_bytes:
        img_bytes = generate_fallback_phone_render(brand_name, model_name)
        
    try:
        return compress_phone_image_to_webp_base64(img_bytes)
    except Exception as e:
        logger.error(f"Failed to compress phone image for {brand_name} {model_name}: {e}")
        return None
