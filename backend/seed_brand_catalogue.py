import os
import sys
import csv
import glob
import argparse
import zipfile
import xml.etree.ElementTree as ET
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


BRAND_ORDER = {
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


def read_xlsx_rows_stdlib(xlsx_path):
    """Lightweight pure-stdlib XLSX reader for the first worksheet (no openpyxl required)."""
    ns = {'main': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
    with zipfile.ZipFile(xlsx_path, 'r') as z:
        shared_strings = []
        if 'xl/sharedStrings.xml' in z.namelist():
            root = ET.fromstring(z.read('xl/sharedStrings.xml'))
            for si in root.findall('main:si', ns):
                texts = [t.text or '' for t in si.iter('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t')]
                shared_strings.append(''.join(texts))

        sheet_root = ET.fromstring(z.read('xl/worksheets/sheet1.xml'))
        rows = []
        for row_el in sheet_root.findall('.//main:sheetData/main:row', ns):
            row_vals = {}
            max_col = 0
            for c_el in row_el.findall('main:c', ns):
                ref = c_el.attrib.get('r', '')
                col_letters = ''.join(ch for ch in ref if ch.isalpha())
                col_idx = 0
                for ch in col_letters:
                    col_idx = col_idx * 26 + (ord(ch.upper()) - ord('A') + 1)
                col_idx = max(col_idx - 1, 0)
                max_col = max(max_col, col_idx)

                cell_type = c_el.attrib.get('t', '')
                v_el = c_el.find('main:v', ns)
                if v_el is None or v_el.text is None:
                    is_el = c_el.find('main:is/main:t', ns)
                    val = is_el.text if is_el is not None else ''
                elif cell_type == 's':
                    val = shared_strings[int(v_el.text)]
                else:
                    val = v_el.text
                row_vals[col_idx] = val

            if row_vals:
                row_list = [row_vals.get(i, '') for i in range(max_col + 1)]
                if any(str(x).strip() for x in row_list):
                    rows.append(row_list)

        if not rows:
            return []
        headers = [str(h).strip() for h in rows[0]]
        return [dict(zip(headers, r + [''] * (len(headers) - len(r)))) for r in rows[1:]]


def load_catalogue_rows(file_path):
    ext = os.path.splitext(file_path)[1].lower()
    if ext == '.csv':
        with open(file_path, mode='r', encoding='utf-8-sig') as f:
            return list(csv.DictReader(f))
    elif ext in ('.xlsx', '.xlsm'):
        try:
            import openpyxl
            wb = openpyxl.load_workbook(file_path, data_only=True)
            ws = wb[wb.sheetnames[0]]
            all_rows = [list(r) for r in ws.iter_rows(values_only=True) if any(c is not None for c in r)]
            if not all_rows:
                return []
            headers = [str(h).strip() for h in all_rows[0]]
            return [dict(zip(headers, r)) for r in all_rows[1:]]
        except ImportError:
            return read_xlsx_rows_stdlib(file_path)
    else:
        raise ValueError(f"Unsupported file type: {ext}. Please provide .csv or .xlsx")


def get_col(row, *candidates, default=''):
    for key in candidates:
        if key in row and row[key] is not None and str(row[key]).strip() != '':
            return str(row[key]).strip()
    return default


def seed_file(file_path):
    if not os.path.exists(file_path):
        print(f"ERROR: File not found: {file_path}")
        sys.exit(1)

    rows = load_catalogue_rows(file_path)
    if not rows:
        print(f"WARNING: No rows found in {file_path}")
        return

    print(f"\nSeeding catalogue from: {file_path} ({len(rows)} rows)...")

    with transaction.atomic():
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

        for row in rows:
            brand_name = get_col(row, 'Brand')
            series_name = get_col(row, 'Series')
            model_name = get_col(row, 'Model Name', 'Model')
            if not brand_name or not model_name:
                continue

            launch_year_raw = get_col(row, 'Launch Year', 'Year', default='0')
            launch_year = int(float(launch_year_raw)) if launch_year_raw else None
            ram = get_col(row, 'RAM', default='')
            storage = get_col(row, 'Storage Variant', 'Storage')

            mint_raw = get_col(row, 'Mint Condition Buyback (₹)', 'Mint Condition Buyback', 'Base Price', default='0')
            lower_raw = get_col(row, 'Lower Condition Buyback (₹)', 'Lower Condition Buyback', 'Min Price', default='0')
            mint_price = max(Decimal('0'), Decimal(mint_raw))
            lower_price = max(Decimal('0'), Decimal(lower_raw))

            warranty_status = get_col(row, 'Warranty Status', default='')
            w_lower = warranty_status.lower()
            has_warranty = (
                'non-warranty' not in w_lower
                and ('possible' in w_lower or 'active warranty' in w_lower or (launch_year is not None and launch_year >= 2025))
            )

            # 1. Brand (case-insensitive & slug-safe lookup)
            if brand_name not in brand_cache:
                brand_slug = slugify(brand_name)
                brand_obj = Brand.objects.filter(Q(name__iexact=brand_name) | Q(slug=brand_slug)).first()
                if not brand_obj:
                    brand_obj = Brand.objects.create(
                        name=brand_name,
                        slug=brand_slug,
                        category=mobile_cat,
                        display_order=BRAND_ORDER.get(brand_name, 50),
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
            series_obj = None
            if series_name:
                series_key = (brand_name, series_name)
                if series_key not in series_cache:
                    series_obj = DeviceSeries.objects.filter(brand=brand_obj, name__iexact=series_name).first()
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
                model_obj = PhoneModel.objects.filter(brand=brand_obj, name__iexact=model_name).first()
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
                    if series_obj and model_obj.series != series_obj:
                        model_obj.series = series_obj
                        updated = True
                    if launch_year and model_obj.release_year != launch_year:
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

            # 4. Storage Variant (avoids duplicate storage rows when RAM is omitted)
            if ram:
                variant_obj = StorageVariant.objects.filter(
                    model=model_obj, ram__iexact=ram, storage__iexact=storage
                ).first()
            else:
                variant_obj = StorageVariant.objects.filter(
                    model=model_obj, storage__iexact=storage
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

    print(f"Completed: {os.path.basename(file_path)}")
    print(f"  Brands  : {len(brand_cache)} processed ({stats['brands_created']} created)")
    print(f"  Series  : {len(series_cache)} processed ({stats['series_created']} created)")
    print(f"  Models  : {len(model_cache)} processed ({stats['models_created']} created, {stats['models_updated']} updated)")
    print(f"  Variants: {stats['variants_created'] + stats['variants_updated']} processed ({stats['variants_created']} created, {stats['variants_updated']} updated)")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Seed brand catalogue (.csv or .xlsx) into Dolly database.')
    parser.add_argument('file', nargs='?', help='Path to a .csv or .xlsx catalogue file. Defaults to all CSVs in backend/data/.')
    args = parser.parse_args()

    if args.file:
        target = args.file if os.path.isabs(args.file) else os.path.abspath(args.file)
        if not os.path.exists(target):
            target = os.path.join(BASE_DIR, args.file)
        seed_file(target)
    else:
        data_files = sorted(glob.glob(os.path.join(BASE_DIR, 'data', '*.csv')))
        if not data_files:
            print("No CSV files found in backend/data/. Pass a file path explicitly.")
            sys.exit(1)
        for fp in data_files:
            seed_file(fp)
