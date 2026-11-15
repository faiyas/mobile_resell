import urllib.request
import json
import time

LIVE_API = "https://8010-agq5qlr2uletnjyzudtddvxrdq.instabox.tech/api/v1"

def request(method, path, data=None, token=None):
    url = f"{LIVE_API}{path}"
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = f"Bearer {token}"
    
    body = json.dumps(data).encode('utf-8') if data else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    
    try:
        with urllib.request.urlopen(req, timeout=15) as res:
            res_body = res.read().decode('utf-8')
            return res.status, json.loads(res_body) if res_body else {}
    except urllib.error.HTTPError as e:
        err_body = e.read().decode('utf-8')
        return e.code, json.loads(err_body) if err_body else {}
    except Exception as e:
        return 0, {'error': str(e)}

def test_live_system():
    print(f"🚀 Running Complete End-to-End Test on LIVE Backend:\n{LIVE_API}\n" + "="*60)
    
    # 1. Catalog Brands
    status, brands = request('GET', '/catalog/brands/')
    assert status == 200 and len(brands) >= 4, f"Brands failed: {status} {brands}"
    print(f"✅ 1. Catalog Brands: Verified ({len(brands)} brands: {[b['name'] for b in brands]})")

    # 2. Models for Apple (brand_id=1)
    status, models = request('GET', '/catalog/models/?brand=1')
    assert status == 200 and len(models) >= 1, f"Models failed: {status} {models}"
    print(f"✅ 2. Phone Models: Verified ({len(models)} models for Apple: {[m['name'] for m in models[:3]]}...)")
    
    # Grab iPhone 13 variant
    ip13 = next((m for m in models if '13' in m['name']), models[0])
    variant = ip13['variants'][0]
    variant_id = variant['id']
    base_price = float(variant['base_price'])
    print(f"   Using variant: {ip13['name']} ({variant['storage']}) Base Price: ₹{base_price}")

    # 3. Valuation Conditions
    status, conditions = request('GET', '/valuation/conditions/')
    assert status == 200 and len(conditions) >= 4, f"Conditions failed: {status} {conditions}"
    print(f"✅ 3. Valuation Categories: Verified ({len(conditions)} categories found)")

    # 4. Dynamic Price Calculation
    status, est = request('POST', '/valuation/estimate/', {
        'variant_id': variant_id,
        'selected_option_codes': ['SCREEN_CRACKED', 'BODY_MINOR_SCRATCHES']
    })
    assert status == 200 and est['estimated_price'] < base_price, f"Valuation failed: {status} {est}"
    print(f"✅ 4. Dynamic Valuation Engine: Base ₹{est['base_price']} - Deductions ₹{est['total_deduction']} = Final Est ₹{est['estimated_price']}")

    # 5. Authentication: Super Admin Login
    status, auth = request('POST', '/auth/login/', {'email': 'admin@buyback.in', 'password': 'admin123'})
    assert status == 200 and 'token' in auth, f"Admin login failed: {status} {auth}"
    admin_token = auth['token']
    print(f"✅ 5. Admin Authentication: Logged in as {auth['user']['full_name']} (Role: {auth['user']['role']})")

    # 6. Customer Submits Phone Sale
    sale_payload = {
        'variant_id': variant_id,
        'selected_option_codes': ['SCREEN_CRACKED', 'BODY_MINOR_SCRATCHES'],
        'customer_name': 'Deepak Sundaram',
        'customer_phone': '9840123456',
        'customer_email': 'deepak@example.com',
        'pickup_address': 'Flat 204, Sea Breeze Apts, ECR Road',
        'pickup_city': 'Puducherry',
        'pickup_pincode': '605001',
        'pickup_slot': 'Morning (10:00 AM - 1:00 PM)',
        'beneficiary_type': 'UPI',
        'beneficiary_name': 'Deepak Sundaram',
        'beneficiary_upi_id': 'deepak@okaxis',
    }
    status, sale = request('POST', '/sales/', sale_payload)
    assert status == 201 and 'id' in sale, f"Sale submission failed: {status} {sale}"
    sale_id = sale['id']
    sale_code = sale['sale_code']
    print(f"✅ 6. Customer Sale Request Created: {sale_code} (Initial Status: {sale['status']})")

    # 7. Admin Schedules Pickup & Assigns Field Agent
    status, agents = request('GET', '/auth/agents/', token=admin_token)
    agent_id = agents[0]['id'] if agents else None
    
    status, sched = request('POST', f'/sales/{sale_id}/schedule-pickup/', {
        'agent_id': agent_id,
        'pickup_date': '2026-11-20',
        'pickup_slot': 'Morning (10:00 AM - 1:00 PM)'
    }, token=admin_token)
    assert status == 200 and sched['sale']['status'] == 'PICKUP_SCHEDULED', f"Schedule failed: {status} {sched}"
    print(f"✅ 7. Pickup Scheduled: Assigned to Agent (Status: {sched['sale']['status']})")

    # 8. Field Agent Performs Inspection, verifies IMEI, and uploads Base64 device photos
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
        'verified_imei': '358941029384751',
        'customer_id_verified': True,
        'suggested_final_price': '18500.00',
        'inspector_notes': 'Screen crack verified + light bezel scuffs. Revised price ₹18,500.',
        'photos': [
            {'label': 'Screen Condition', 'image_base64': 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><rect width="100" height="100" fill="gray"/><text x="10" y="50" fill="white">Crack</text></svg>'},
            {'label': 'Back Glass', 'image_base64': 'data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><rect width="100" height="100" fill="silver"/><text x="10" y="50" fill="black">Back</text></svg>'}
        ]
    }
    status, insp = request('POST', '/inspections/', inspection_payload, token=admin_token)
    assert status == 201, f"Inspection failed: {status} {insp}"
    print(f"✅ 8. Field Inspection Recorded: 2 Base64 Photos + IMEI (Revised Offer: ₹{insp['inspection']['suggested_final_price']})")

    # 9. Customer Reviews & Accepts Revised Final Offer
    status, accepted = request('POST', f'/sales/{sale_id}/accept-offer/')
    assert status == 200 and accepted['status'] == 'CUSTOMER_ACCEPTED', f"Offer accept failed: {status} {accepted}"
    print(f"✅ 9. Customer Accepted Revised Offer: (Status: {accepted['status']})")

    # 10. Dynamic Scan-to-Pay UPI QR Code Generated
    status, qr = request('GET', f'/payments/qr/{sale_id}/', token=admin_token)
    assert status == 200 and 'upi://pay?' in qr['upi_uri'], f"QR failed: {status} {qr}"
    print(f"✅ 10. Dynamic UPI QR Generated: {qr['upi_uri']}")

    # 11. Admin Transfers Money via GPay/PhonePe & Uploads Screenshot Proof (Base64) + 12-digit UTR
    test_utr = f"UTR{int(time.time())}"
    sample_proof_base64 = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='200' height='200'><rect width='200' height='200' fill='green'/><text x='20' y='100' fill='white'>PAID 18500</text></svg>"
    
    payout_payload = {
        'sale_id': sale_id,
        'amount': '18500.00',
        'payment_method': 'GPAY',
        'utr_number': test_utr,
        'payment_proof_base64': sample_proof_base64,
        'admin_notes': 'Paid via Google Pay Business account. UTR verified.'
    }
    status, payout = request('POST', '/payments/record-payout/', payout_payload, token=admin_token)
    assert status == 201 and payout['sale_status'] == 'PAYMENT_COMPLETED', f"Payout failed: {status} {payout}"
    print(f"✅ 11. Payout Recorded & Marked as PAID: UTR: {test_utr} (Status: {payout['sale_status']})")

    # 12. Duplicate UTR Protection Check
    status, dup_err = request('POST', '/payments/record-payout/', payout_payload, token=admin_token)
    assert status == 400, "Duplicate UTR was NOT blocked!"
    print(f"✅ 12. Duplicate UTR Protection: Successfully blocked double-payment attempt")

    # 13. Public Official Handover Receipt & Payment Voucher
    status, receipt = request('GET', f'/payments/receipt/{sale_code}/')
    assert status == 200 and receipt['status'] == 'PAID' and receipt['payout_amount'] == 18500.0, f"Receipt failed: {status} {receipt}"
    print(f"✅ 13. Official Printable Bill of Sale: Verified ({receipt['receipt_number']} · Device: {receipt['device']} · Amount: ₹{receipt['payout_amount']} · Verified IMEI: {receipt['imei']})")

    print("\n" + "="*60)
    print("🎉 ALL 13 CORE FUNCTIONS TESTED AND PASSING 100% ON LIVE MARIADB BACKEND!")
    print("="*60)

if __name__ == '__main__':
    test_live_system()
