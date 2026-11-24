import os
import sys
import csv
from decimal import Decimal
import django

# Ensure backend directory is on sys.path regardless of where script is invoked from
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.db import transaction
from django.db.models import Q
from django.utils.text import slugify
from apps.catalog.models import DeviceCategory, Brand, DeviceSeries, PhoneModel, StorageVariant


def seed_catalogue():
    csv_path = os.path.join(BASE_DIR, 'catalogue_data.csv')
    if not os.path.exists(csv_path):
        print(f"ERROR: Could not find {csv_path}")
        sys.exit(1)

    print("Starting Dolly Buyback Catalogue Seeding (588 variants across 13 brands)...")

    with transaction.atomic():
        # Ensure 'Mobile' category exists
        mobile_cat = DeviceCategory.objects.filter(slug='mobile').first()
        if not mobile_cat:
            mobile_cat, _ = DeviceCategory.objects.get_or_create(
                name='Mobile',
                defaults={
                    'subtitle': 'Sell smartphones',
                    'icon_name': 'Smartphone',
                    'display_order': 1,
                    'is_active': True,
                }
            )

        brand_cache = {}
        series_cache = {}
        model_cache = {}

        stats = {
            'brands_created': 0,
            'series_created': 0,
            'models_created': 0,
            'models_updated': 0,
            'variants_created': 0,
            'variants_updated': 0,
        }

        brand_order = {
            'Apple': 1,
            'Samsung': 2,
            'OnePlus': 3,
            'Xiaomi': 4,
            'Redmi': 5,
            'POCO': 6,
            'Vivo': 7,
            'iQOO': 8,
            'OPPO': 9,
            'Realme': 10,
            'Motorola': 11,
            'Google': 12,
            'Nothing': 13,
        }

        with open(csv_path, mode='r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                brand_name = row['Brand'].strip()
                series_name = row['Series'].strip()
                model_name = row['Model Name'].strip()
                launch_year = int(row['Launch Year'].strip())
                ram = row['RAM'].strip()
                storage = row['Storage Variant'].strip()
                mint_price = Decimal(row['Mint Condition Buyback (₹)'].strip())
                lower_price = Decimal(row['Lower Condition Buyback (₹)'].strip())
                warranty_status = row['Warranty Status'].strip()
                has_warranty = 'possible' in warranty_status.lower() or launch_year >= 2025

                # 1. Brand (case-insensitive & slug-safe lookup)
                if brand_name not in brand_cache:
                    brand_slug = slugify(brand_name)
                    brand_obj = Brand.objects.filter(
                        Q(name__iexact=brand_name) | Q(slug=brand_slug)
                    ).first()
                    if not brand_obj:
                        brand_obj = Brand.objects.create(
                            name=brand_name,
                            slug=brand_slug,
                            category=mobile_cat,
                            display_order=brand_order.get(brand_name, 50),
                            is_active=True,
                        )
                        stats['brands_created'] += 1
                    else:
                        updated_brand = False
                        if not brand_obj.category:
                            brand_obj.category = mobile_cat
                            updated_brand = True
                        if not brand_obj.is_active:
                            brand_obj.is_active = True
                            updated_brand = True
                        if updated_brand:
                            brand_obj.save()
                    brand_cache[brand_name] = brand_obj
                brand_obj = brand_cache[brand_name]

                # 2. Series (case-insensitive lookup)
                series_key = (brand_name, series_name)
                if series_key not in series_cache:
                    series_obj = DeviceSeries.objects.filter(
                        brand=brand_obj, name__iexact=series_name
                    ).first()
                    if not series_obj:
                        series_obj = DeviceSeries.objects.create(
                            brand=brand_obj,
                            name=series_name,
                            is_active=True,
                        )
                        stats['series_created'] += 1
                    series_cache[series_key] = series_obj
                series_obj = series_cache[series_key]

                # 3. Phone Model (case-insensitive lookup)
                model_key = (brand_name, model_name)
                if model_key not in model_cache:
                    model_obj = PhoneModel.objects.filter(
                        brand=brand_obj, name__iexact=model_name
                    ).first()
                    if not model_obj:
                        model_obj = PhoneModel.objects.create(
                            brand=brand_obj,
                            name=model_name,
                            series=series_obj,
                            release_year=launch_year,
                            has_warranty=has_warranty,
                            is_active=True,
                        )
                        stats['models_created'] += 1
                    else:
                        updated = False
                        if model_obj.series != series_obj:
                            model_obj.series = series_obj
                            updated = True
                        if model_obj.release_year != launch_year:
                            model_obj.release_year = launch_year
                            updated = True
                        if model_obj.has_warranty != has_warranty:
                            model_obj.has_warranty = has_warranty
                            updated = True
                        if not model_obj.is_active:
                            model_obj.is_active = True
                            updated = True
                        if updated:
                            model_obj.save()
                            stats['models_updated'] += 1
                    model_cache[model_key] = model_obj
                model_obj = model_cache[model_key]

                # 4. Storage Variant (case-insensitive lookup)
                variant_obj = StorageVariant.objects.filter(
                    model=model_obj, ram__iexact=ram, storage__iexact=storage
                ).first()
                if not variant_obj:
                    StorageVariant.objects.create(
                        model=model_obj,
                        ram=ram,
                        storage=storage,
                        base_price=mint_price,
                        min_price=lower_price,
                        is_active=True,
                    )
                    stats['variants_created'] += 1
                else:
                    variant_obj.base_price = mint_price
                    variant_obj.min_price = lower_price
                    variant_obj.is_active = True
                    variant_obj.save()
                    stats['variants_updated'] += 1

        # Clean up obsolete 'Number Series' entries if no models remain linked to them
        DeviceSeries.objects.filter(name__iexact='Number Series', models__isnull=True).delete()

    print("\nCatalogue Seeding Completed Successfully!")
    print(f"  Brands  : {len(brand_cache)} processed ({stats['brands_created']} created)")
    print(f"  Series  : {len(series_cache)} processed ({stats['series_created']} created)")
    print(f"  Models  : {len(model_cache)} processed ({stats['models_created']} created, {stats['models_updated']} updated)")
    print(f"  Variants: {stats['variants_created'] + stats['variants_updated']} processed ({stats['variants_created']} created, {stats['variants_updated']} updated)")


if __name__ == '__main__':
    seed_catalogue()
