import os
import sys
import json
import django
from decimal import Decimal

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
django.setup()

from rest_framework.test import APIClient
from apps.accounts.models import User
from apps.catalog.models import Brand, PhoneModel, StorageVariant
from apps.valuation.models import ConditionCategory, ConditionOption, PriceHistory

def run_tests():
    print("🧪 Running Comprehensive Tests for Catalogue & Valuation Engine...")
    client = APIClient()

    # 1. Admin Login
    admin_user = User.objects.filter(role='ADMIN').first()
    assert admin_user, "Admin user must exist"
    client.force_authenticate(user=admin_user)
    print("✅ 1. Authenticated as Admin:", admin_user.email)

    # 2. Test Brand Management (GET, POST, PUT, DELETE)
    # Create brand
    res = client.post('/api/v1/catalog/brands/', {
        'name': 'TestBrand_X',
        'logo_base64': 'data:image/svg+xml;utf8,<svg></svg>',
        'display_order': 99,
        'is_active': True
    }, format='json')
    assert res.status_code == 201, f"Failed create brand: {res.status_code} {res.data}"
    brand_id = res.data['id']
    print(f"✅ 2. Created Brand '{res.data['name']}' (ID: {brand_id})")

    # Update brand
    res = client.put(f'/api/v1/catalog/brands/{brand_id}/', {'name': 'TestBrand_Updated'}, format='json')
    assert res.status_code == 200 and res.data['name'] == 'TestBrand_Updated'
    print("✅ 3. Updated Brand name to 'TestBrand_Updated'")

    # 3. Test PhoneModel Management
    res = client.post('/api/v1/catalog/models/', {
        'brand': brand_id,
        'name': 'TestModel_1',
        'release_year': 2024,
        'is_active': True
    }, format='json')
    assert res.status_code == 201, f"Failed create model: {res.data}"
    model_id = res.data['id']
    print(f"✅ 4. Created Model 'TestModel_1' (ID: {model_id})")

    # 4. Test StorageVariant & Base Price Management with Audit Log
    res = client.post('/api/v1/catalog/variants/', {
        'model': model_id,
        'ram': '8GB',
        'storage': '256GB',
        'base_price': '30000.00',
        'min_price': '1000.00',
        'is_active': True
    }, format='json')
    assert res.status_code == 201, f"Failed create variant: {res.data}"
    variant_id = res.data['id']
    print(f"✅ 5. Created Storage Variant: 8GB / 256GB with Base Price ₹30,000")

    # Update base price with reason and verify PriceHistory audit
    res = client.put(f'/api/v1/catalog/variants/{variant_id}/', {
        'base_price': '28000.00',
        'change_reason': 'Market festival price update'
    }, format='json')
    assert res.status_code == 200, f"Failed update variant price: {res.data}"
    print("✅ 6. Updated Base Price to ₹28,000")

    # Check PriceHistory
    res = client.get(f'/api/v1/valuation/pricing/history/?variant={variant_id}')
    assert res.status_code == 200 and len(res.data) > 0, "Price history entry must exist"
    entry = res.data[0]
    assert float(entry['old_base_price']) == 30000.0 and float(entry['new_base_price']) == 28000.0
    print(f"✅ 7. Verified Price History Audit: ₹{entry['old_base_price']} ➔ ₹{entry['new_base_price']} ({entry['reason']})")

    # 5. Test Condition Category & Option with Exclusive Group and Rejection
    res = client.post('/api/v1/valuation/conditions/', {
        'name': 'Test Screen Cat',
        'description': 'Screen test',
        'icon_name': 'Smartphone',
        'display_order': 1
    }, format='json')
    assert res.status_code == 201
    cat_id = res.data['id']
    print(f"✅ 8. Created Condition Category (ID: {cat_id})")

    # Option A: Minor Scratches (Flat ₹500, exclusive_group: 'test_glass')
    res_a = client.post('/api/v1/valuation/options/', {
        'category': cat_id,
        'code': 'TEST_GLASS_SCRATCH',
        'title': 'Minor glass scratches',
        'deduction_type': 'FLAT',
        'default_deduction_value': '500.00',
        'exclusive_group': 'test_glass',
        'is_defect': True
    }, format='json')
    assert res_a.status_code == 201

    # Option B: Cracked Glass (Flat ₹3,000, exclusive_group: 'test_glass')
    res_b = client.post('/api/v1/valuation/options/', {
        'category': cat_id,
        'code': 'TEST_GLASS_CRACK',
        'title': 'Cracked glass',
        'deduction_type': 'FLAT',
        'default_deduction_value': '3000.00',
        'exclusive_group': 'test_glass',
        'is_defect': True
    }, format='json')
    assert res_b.status_code == 201

    # Option C: Battery Service (Percentage 10% of base)
    res_c = client.post('/api/v1/valuation/options/', {
        'category': cat_id,
        'code': 'TEST_BATTERY_10PCT',
        'title': 'Battery Service Required',
        'deduction_type': 'PERCENTAGE',
        'default_deduction_value': '10.00',
        'is_defect': True
    }, format='json')
    assert res_c.status_code == 201

    # Option D: Safety Rejection (Swollen battery)
    res_d = client.post('/api/v1/valuation/options/', {
        'category': cat_id,
        'code': 'TEST_SWOLLEN_BATTERY',
        'title': 'Battery Swollen / Exploding Hazard',
        'deduction_type': 'FLAT',
        'default_deduction_value': '5000.00',
        'is_rejection': True,
        'is_defect': True
    }, format='json')
    assert res_d.status_code == 201
    print("✅ 9. Created Condition Options (Flat, Percentage, Exclusive Group, Rejection)")

    # 6. Test Valuation Calculation Engine: Mutually Exclusive Rule
    # When BOTH minor scratches (-500) and cracked glass (-3000) are ticked:
    # It must take ONLY the max deduction (-3000), not double stack (-3500)!
    res = client.post('/api/v1/valuation/estimate/', {
        'variant_id': variant_id,
        'selected_option_codes': ['TEST_GLASS_SCRATCH', 'TEST_GLASS_CRACK', 'TEST_BATTERY_10PCT']
    }, format='json')
    assert res.status_code == 200, f"Estimate failed: {res.data}"
    
    # Base: 28,000
    # Glass max: 3,000
    # Battery 10%: 2,800
    # Total deduction: 5,800
    # Expected estimated price: 28,000 - 5,800 = 22,200
    assert float(res.data['total_deduction']) == 5800.0, f"Expected 5800 deduction, got {res.data['total_deduction']}"
    assert float(res.data['estimated_price']) == 22200.0, f"Expected 22200 estimate, got {res.data['estimated_price']}"
    print("✅ 10. Valuation Engine Exclusive Group Resolution Verified: ₹28,000 - ₹5,800 = ₹22,200")

    # 7. Test Valuation Engine: Safety Rejection Rule
    res_rej = client.post('/api/v1/valuation/estimate/', {
        'variant_id': variant_id,
        'selected_option_codes': ['TEST_SWOLLEN_BATTERY']
    }, format='json')
    assert res_rej.status_code == 200
    assert res_rej.data['is_rejected'] == True, "Must flag rejection"
    assert res_rej.data['estimated_price'] == 0.0, "Rejection price must be 0"
    print("✅ 11. Safety Rejection Rule Verified: Device Rejected with ₹0 payout")

    # Cleanup test artifacts
    client.delete(f'/api/v1/catalog/brands/{brand_id}/')
    client.delete(f'/api/v1/valuation/conditions/{cat_id}/')
    print("✅ 12. Cleaned up temporary test entities")

    print("\n🎉 ALL 12 CATALOGUE, PRICING & VALUATION ENGINE TESTS PASSED 100%!")

if __name__ == '__main__':
    run_tests()
