import os
import sys
import django

# Set up Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.db import transaction
from apps.accounts.models import User
from apps.catalog.models import Brand, DeviceSeries, PhoneModel, StorageVariant
from apps.valuation.models import ConditionCategory, ConditionOption, ModelPricingOverride, PriceHistory
from apps.sales.models import PhoneSale, PhoneSaleConditionAnswer
from apps.inspections.models import DeviceInspection, InspectionPhoto
from apps.payments.models import Payment

def reset_to_production():
    with transaction.atomic():
        print("=== 1103 RECELL PRODUCTION DATABASE INITIALIZATION ===")

        # 1. Preserve condition categories by detaching foreign key to Brand
        cats_count = ConditionCategory.objects.count()
        opts_count = ConditionOption.objects.count()
        ConditionCategory.objects.all().update(brand=None)
        print(f"Preserved {cats_count} Condition Categories and {opts_count} Condition Options (detached brand constraints).")

        # 2. Purge transactional demo data
        payments_deleted = Payment.objects.all().delete()[0]
        photos_deleted = InspectionPhoto.objects.all().delete()[0]
        inspections_deleted = DeviceInspection.objects.all().delete()[0]
        answers_deleted = PhoneSaleConditionAnswer.objects.all().delete()[0]
        sales_deleted = PhoneSale.objects.all().delete()[0]
        overrides_deleted = ModelPricingOverride.objects.all().delete()[0]
        history_deleted = PriceHistory.objects.all().delete()[0]
        print(f"Purged demo transactions: {sales_deleted} sales, {inspections_deleted} inspections, {payments_deleted} payments.")

        # 3. Purge demo brands and phone models
        variants_deleted = StorageVariant.objects.all().delete()[0]
        models_deleted = PhoneModel.objects.all().delete()[0]
        series_deleted = DeviceSeries.objects.all().delete()[0]
        brands_deleted = Brand.objects.all().delete()[0]
        print(f"Purged demo catalog: {brands_deleted} brands, {series_deleted} series, {models_deleted} models, {variants_deleted} storage variants.")

        # 4. Remove all previous demo users
        users_deleted = User.objects.all().delete()[0]
        print(f"Purged {users_deleted} old demo user accounts.")

        # 5. Create Main Super Admin
        admin1 = User.objects.create_superuser(
            email='admin@1103recell.com',
            password='Rashidha@1103',
            phone='9025232453',
            full_name='Main Super Admin',
            role='ADMIN',
            is_staff=True,
            is_superuser=True,
        )
        print(f"Successfully created Main Admin: Mobile={admin1.phone}, Email={admin1.email}")

        # 6. Create Secondary Admin
        admin2 = User.objects.create_superuser(
            email='secondary@1103recell.com',
            password='Gaming@mobiles',
            phone='6383445014',
            full_name='Secondary Admin',
            role='ADMIN',
            is_staff=True,
            is_superuser=True,
        )
        print(f"Successfully created Secondary Admin: Mobile={admin2.phone}, Email={admin2.email}")

        print("\n=== FINAL VERIFICATION ===")
        print(f"Total Brands: {Brand.objects.count()} (Ready for manual addition)")
        print(f"Total Phone Models: {PhoneModel.objects.count()} (Ready for manual addition)")
        print(f"Total Storage Variants: {StorageVariant.objects.count()}")
        print(f"Total Orders: {PhoneSale.objects.count()}")
        print(f"Total Condition Categories: {ConditionCategory.objects.count()} (All rules intact)")
        print(f"Total Condition Options: {ConditionOption.objects.count()} (All deduction options intact)")
        print(f"Total Users: {User.objects.count()} (Main Admin & Secondary Admin only)")

if __name__ == '__main__':
    reset_to_production()
