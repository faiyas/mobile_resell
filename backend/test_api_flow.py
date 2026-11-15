import os
import sys
import django
from decimal import Decimal

# Setup django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
django.setup()

from rest_framework.test import APIClient
from apps.accounts.models import User
from apps.catalog.models import Brand, PhoneModel, StorageVariant
from apps.valuation.models import ConditionOption
from apps.sales.models import PhoneSale
from apps.payments.models import Payment

def test_full_platform_flow():
    client = APIClient()
    print("🧪 Testing Mobile Buyback End-to-End API Flow...")

    # 1. Test Auth: Login as Super Admin
    login_res = client.post('/api/v1/auth/login/', {'email': 'admin@buyback.in', 'password': 'admin123'})
    assert login_res.status_code == 200, f"Login failed: {login_res.data}"
    admin_token = login_res.data['token']
    client.credentials(HTTP_AUTHORIZATION=f'Bearer {admin_token}')
    print("✅ 1. Admin JWT Authentication verified")

    # 2. Test Catalog API
    brands_res = client.get('/api/v1/catalog/brands/')
    assert brands_res.status_code == 200, f"Brands fetch failed: {brands_res.data}"
    assert len(brands_res.data) >= 4, "Expected at least 4 brands"
    print(f"✅ 2. Catalog Brands verified ({len(brands_res.data)} brands found)")

    # 3. Test Dynamic Valuation Engine API
    variant = StorageVariant.objects.filter(model__name='iPhone 13', storage='128GB').first()
    assert variant is not None, "Variant iPhone 13 128GB not found"
    
    val_res = client.post('/api/v1/valuation/estimate/', {
        'variant_id': variant.id,
        'selected_option_codes': ['SCREEN_CRACKED', 'BODY_MINOR_SCRATCHES']
    })
    assert val_res.status_code == 200, f"Valuation failed: {val_res.data}"
    val_data = val_res.data
    expected_est = variant.base_price - Decimal('3500.00') - Decimal('500.00')
    assert Decimal(str(val_data['estimated_price'])) == expected_est, f"Price mismatch: {val_data['estimated_price']} vs {expected_est}"
    print(f"✅ 3. Valuation Engine verified (Base: ₹{val_data['base_price']} -> Deductions: -₹{val_data['total_deduction']} -> Net: ₹{val_data['estimated_price']})")

    # 4. Test Customer Submitting Phone Sale
    sale_payload = {
        'variant_id': variant.id,
        'selected_option_codes': ['SCREEN_CRACKED', 'BODY_MINOR_SCRATCHES'],
        'customer_name': 'Ananya Sen',
        'customer_phone': '9812345678',
        'customer_email': 'ananya@example.com',
        'pickup_address': 'Flat 101, Indiranagar 100ft Road',
        'pickup_city': 'Bengaluru',
        'pickup_pincode': '560038',
        'pickup_slot': 'Morning (10:00 AM - 1:00 PM)',
        'beneficiary_type': 'UPI',
        'beneficiary_name': 'Ananya Sen',
        'beneficiary_upi_id': 'ananya@oksbi',
    }
    sale_res = client.post('/api/v1/sales/', sale_payload)
    assert sale_res.status_code == 201, f"Sale submission failed: {sale_res.data}"
    sale_id = sale_res.data['id']
    sale_code = sale_res.data['sale_code']
    print(f"✅ 4. Customer Sale Created successfully: {sale_code} (Status: {sale_res.data['status']})")

    # 5. Test Field Agent Inspection with revised offer (e.g. ₹19,500 due to deeper dent)
    inspection_payload = {
        'sale_id': sale_id,
        'switches_on': True,
        'screen_working': True,
        'screen_glass_broken': True,
        'touch_working': True,
        'camera_working': True,
        'battery_healthy': True,
        'body_condition': 'FAIR',
        'cloud_locks_removed': True,
        'imei_verified': True,
        'verified_imei': '359871029384756',
        'customer_id_verified': True,
        'suggested_final_price': '19500.00', # Revised offer lower than estimate
        'inspector_notes': 'Verified screen crack + deep corner dent observed. Revised offer to ₹19,500.',
        'photos': [
            {'label': 'Front Screen', 'image_base64': 'data:image/jpeg;base64,samplebase64frontphoto12345'},
            {'label': 'Corner Dent', 'image_base64': 'data:image/jpeg;base64,samplebase64dentphoto12345'}
        ]
    }
    insp_res = client.post('/api/v1/inspections/', inspection_payload)
    assert insp_res.status_code == 201, f"Inspection failed: {insp_res.data}"
    assert insp_res.data['sale_status'] == 'FINAL_OFFER_SENT', f"Expected FINAL_OFFER_SENT, got {insp_res.data['sale_status']}"
    print(f"✅ 5. Inspection recorded & Revised Offer Sent (Status: FINAL_OFFER_SENT, Price: ₹{insp_res.data['inspection']['suggested_final_price']})")

    # 6. Test Customer Acceptance of Revised Offer
    accept_res = client.post(f'/api/v1/sales/{sale_id}/accept-offer/')
    assert accept_res.status_code == 200, f"Customer accept failed: {accept_res.data}"
    assert accept_res.data['status'] == 'CUSTOMER_ACCEPTED'
    print(f"✅ 6. Customer Accepted Revised Offer (Status: {accept_res.data['status']})")

    # 7. Test Admin Payment Proof & UTR Upload Workflow (Base64)
    # Generate dynamic UPI QR string
    qr_res = client.get(f'/api/v1/payments/qr/{sale_id}/')
    assert qr_res.status_code == 200, f"QR generation failed: {qr_res.data}"
    assert 'upi://pay?' in qr_res.data['upi_uri'], "UPI URI missing"
    print(f"✅ 7a. Dynamic UPI QR URI generated: {qr_res.data['upi_uri']}")

    # Admin transfers ₹19,500 on GPay and uploads screenshot proof + UTR
    import time
    test_utr = f"UTR{int(time.time())}"
    payout_payload = {
        'sale_id': sale_id,
        'amount': '19500.00',
        'payment_method': 'GPAY',
        'utr_number': test_utr,
        'payment_proof_base64': 'data:image/jpeg;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
        'admin_notes': 'Transferred ₹19,500 via Google Pay Business UPI.'
    }
    payout_res = client.post('/api/v1/payments/record-payout/', payout_payload)
    assert payout_res.status_code == 201, f"Payout recording failed: {payout_res.data}"
    assert payout_res.data['sale_status'] == 'PAYMENT_COMPLETED', "Expected status PAYMENT_COMPLETED"
    print(f"✅ 7b. Payment recorded & Status changed to PAID (UTR: {payout_res.data['payment']['utr_number']})")

    # 8. Test Duplicate UTR Protection
    dup_payout = client.post('/api/v1/payments/record-payout/', payout_payload)
    assert dup_payout.status_code == 400, "Duplicate UTR was not blocked!"
    print("✅ 8. Duplicate UTR Protection verified (Double-spend attempt rejected)")

    # 9. Test Public / Customer Official Receipt & Bill of Sale
    receipt_res = client.get(f'/api/v1/payments/receipt/{sale_code}/')
    assert receipt_res.status_code == 200, f"Receipt retrieval failed: {receipt_res.data}"
    receipt = receipt_res.data
    assert receipt['status'] == 'PAID'
    assert receipt['payout_amount'] == 19500.0
    assert receipt['utr_number'] == test_utr
    print(f"✅ 9. Official Receipt & Bill of Sale verified (Receipt: {receipt['receipt_number']} · Amount: ₹{receipt['payout_amount']})")

    print("\n🎉 ALL 9 TEST SUITES PASSED FLAWLESSLY!")

if __name__ == '__main__':
    test_full_platform_flow()
