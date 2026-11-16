import os
import sys
import django
from decimal import Decimal

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
django.setup()

from rest_framework.test import APIClient
from apps.accounts.models import User
from apps.sales.models import PhoneSale
from apps.catalog.models import StorageVariant

def run_tests():
    print("🚀 Testing Agent Assignment & Fast Execution Flow...")
    client = APIClient()

    # 1. Fetch Admin and Agent Users
    admin_user = User.objects.filter(role='ADMIN').first()
    agent_user = User.objects.filter(role='COLLECTION_AGENT').first()
    assert admin_user, "Admin must exist"
    assert agent_user, "Agent must exist"

    # 2. Find or create an unassigned SUBMITTED sale
    variant = StorageVariant.objects.first()
    assert variant, "At least one variant must exist"

    sale = PhoneSale.objects.create(
        customer_name="Test Assignee",
        customer_phone="9988776655",
        variant=variant,
        base_price=variant.base_price,
        estimated_price=variant.base_price,
        status='SUBMITTED',
        pickup_address='123 Tech Park',
        pickup_city='Bengaluru',
        pickup_pincode='560001',
        beneficiary_type='UPI',
        beneficiary_name='Test Assignee',
        beneficiary_upi_id='test@okaxis'
    )
    print(f"✅ 1. Created Test Sale: {sale.sale_code} (Status: {sale.status}, Assigned: None)")

    # 3. Admin assigns agent
    client.force_authenticate(user=admin_user)
    assign_res = client.post(f'/api/v1/sales/{sale.id}/schedule-pickup/', {
        'agent_id': agent_user.id,
        'pickup_date': '2026-11-17',
        'pickup_slot': 'Morning (10:00 AM - 1:00 PM)'
    }, format='json')
    assert assign_res.status_code == 200, f"Failed assign: {assign_res.data}"
    
    sale.refresh_from_db()
    assert sale.status == 'PICKUP_SCHEDULED', f"Expected PICKUP_SCHEDULED, got {sale.status}"
    assert sale.assigned_agent == agent_user, "Agent was not assigned"
    print(f"✅ 2. Admin Assigned Pickup to '{agent_user.full_name}' ➔ Status: {sale.status}")

    # 4. Agent logs in and fetches assigned sales
    client.force_authenticate(user=agent_user)
    agent_sales_res = client.get('/api/v1/sales/')
    assert agent_sales_res.status_code == 200
    assigned_codes = [s['sale_code'] for s in agent_sales_res.data]
    assert sale.sale_code in assigned_codes, f"Sale {sale.sale_code} must appear in agent queue! Found: {assigned_codes}"
    print(f"✅ 3. Agent Logged in ➔ Sale {sale.sale_code} appeared immediately in Agent Queue (Count: {len(assigned_codes)})")

    # 5. Agent conducts physical inspection
    inspect_res = client.post('/api/v1/inspections/', {
        'sale_id': str(sale.id),
        'switches_on': True,
        'screen_working': True,
        'screen_glass_broken': False,
        'touch_working': True,
        'camera_working': True,
        'battery_healthy': True,
        'body_condition': 'GOOD',
        'cloud_locks_removed': True,
        'imei_verified': True,
        'verified_imei': '358941092837411',
        'customer_id_verified': True,
        'suggested_final_price': str(sale.estimated_price),
        'inspector_notes': 'Device flawless, verified physically at doorstep.',
        'photos': []
    }, format='json')
    assert inspect_res.status_code == 201, f"Inspection failed: {inspect_res.data}"
    
    sale.refresh_from_db()
    assert sale.status == 'OWNERSHIP_TRANSFERRED', f"Expected OWNERSHIP_TRANSFERRED, got {sale.status}"
    print(f"✅ 4. Agent Submitted Inspection ➔ Verified IMEI '{sale.imei_number}' ➔ Status: {sale.status}")

    # Cleanup
    sale.delete()
    print("✅ 5. Cleanup test sale completed")
    print("\n🎉 AGENT ASSIGNMENT & FAST WORKFLOW VERIFIED 100% WORKING!")

if __name__ == '__main__':
    run_tests()
