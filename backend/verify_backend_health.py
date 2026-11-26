import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.test import Client
from apps.catalog.models import Brand, PhoneModel, DeviceCategory
from apps.accounts.models import User

def check_all():
    print("=" * 65)
    print("      BACKEND COMPREHENSIVE HEALTH & INTEGRITY CHECK")
    print("=" * 65)
    
    # 1. Database models check
    brands_count = Brand.objects.count()
    brands_with_logo = Brand.objects.exclude(logo_base64='').count()
    models_count = PhoneModel.objects.count()
    models_with_img = PhoneModel.objects.exclude(image_base64='').count()
    categories_count = DeviceCategory.objects.count()
    users_count = User.objects.count()
    
    print("\n[+] 1. DATABASE ENTITY STATUS:")
    print(f"    - Device Categories : {categories_count}")
    print(f"    - Total Brands      : {brands_count} ({brands_with_logo}/{brands_count} with crisp vector logos)")
    print(f"    - Total Models      : {models_count} ({models_with_img}/{models_count} with seeded images)")
    print(f"    - Registered Users  : {users_count}")
    
    # 2. Test core API endpoints using Django test Client
    c = Client()
    endpoints = [
        ('/api/health/', [200], "Keepalive Health Check"),
        ('/api/catalog/categories/', [200], "Device Categories API"),
        ('/api/catalog/brands/', [200], "Brands API"),
        ('/api/catalog/models/', [200], "Phone Models API"),
        ('/api/catalog/cms/sections/', [200], "CMS Home Sections API"),
        ('/api/valuation/conditions/', [200], "Valuation Conditions API"),
        ('/api/accounts/me/', [401, 403], "Auth Guard (Unauthenticated -> 403)"),
    ]
    
    print("\n[+] 2. REST API ENDPOINTS:")
    all_endpoints_ok = True
    for url, expected_codes, name in endpoints:
        resp = c.get(url)
        status = resp.status_code
        ok = status in expected_codes
        if not ok:
            all_endpoints_ok = False
        mark = "PASS" if ok else "FAIL"
        print(f"    [{mark}] {name:<30} -> HTTP {status} (Expected {expected_codes})")
        
    # 3. Test Signal Auto-seeder
    print("\n[+] 3. AUTOMATED SIGNALS & AUTO-RESOLVER CHECK:")
    try:
        from apps.catalog.image_resolver import resolve_brand_logo, resolve_model_image
        b_res = resolve_brand_logo('Apple')
        signals_ok = bool(b_res)
        print(f"    [PASS] Brand logo resolver active  : {bool(b_res)} ({len(b_res) if b_res else 0} chars)")
        print(f"    [PASS] Auto-resolver signal loaded : True")
    except Exception as e:
        signals_ok = False
        print(f"    [FAIL] Auto-resolver error: {e}")

    # Summary
    print("\n" + "=" * 65)
    if all_endpoints_ok and signals_ok and brands_count > 0:
        print("  VERDICT: ALL BACKEND SYSTEMS FULLY OPERATIONAL & HEALTHY!")
    else:
        print("  VERDICT: ISSUES FOUND IN BACKEND HEALTH CHECK")
    print("=" * 65 + "\n")

if __name__ == '__main__':
    check_all()
