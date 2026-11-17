import os
import django
from decimal import Decimal

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from apps.accounts.models import User
from apps.catalog.models import DeviceCategory, Brand, DeviceSeries, PhoneModel, StorageVariant, CMSHomeSection
from apps.valuation.models import ConditionCategory, ConditionOption, PriceHistory
from apps.sales.models import PhoneSale, PhoneSaleConditionAnswer
from apps.inspections.models import DeviceInspection, InspectionPhoto
from apps.payments.models import Payment

def seed_database():
    print("🚀 Starting 1103 RECELL Full-Stack Buyback Platform database seed...")

    # ================= 1. USERS & ROLES =================
    admin_user, _ = User.objects.get_or_create(
        email='admin@buyback.in',
        defaults={
            'username': 'admin',
            'full_name': 'Super Admin',
            'phone': '9876543210',
            'role': 'ADMIN',
            'is_staff': True,
            'is_superuser': True,
        }
    )
    admin_user.set_password('admin123')
    admin_user.role = 'ADMIN'
    admin_user.save()

    agent_user, _ = User.objects.get_or_create(
        email='agent@buyback.in',
        defaults={
            'username': 'agent',
            'full_name': 'Ramesh Kumar (Pickup Specialist)',
            'phone': '9876543211',
            'role': 'COLLECTION_AGENT',
        }
    )
    agent_user.set_password('agent123')
    agent_user.role = 'COLLECTION_AGENT'
    agent_user.save()

    customer_user, _ = User.objects.get_or_create(
        email='customer@example.com',
        defaults={
            'username': 'customer',
            'full_name': 'Mohamed K.',
            'phone': '9876543212',
            'role': 'CUSTOMER',
        }
    )
    customer_user.set_password('customer123')
    customer_user.role = 'CUSTOMER'
    customer_user.save()

    print("✅ Users seeded (Super Admin, Pickup Agent, Customer)")

    # ================= 2. DEVICE CATEGORIES =================
    cat_mobile, _ = DeviceCategory.objects.get_or_create(
        slug='mobile',
        defaults={
            'name': 'Mobile',
            'subtitle': 'Sell smartphones',
            'icon_name': 'Smartphone',
            'display_order': 1,
            'is_active': True
        }
    )
    cat_tablet, _ = DeviceCategory.objects.get_or_create(
        slug='tablet',
        defaults={
            'name': 'Tablet',
            'subtitle': 'Sell tablets',
            'icon_name': 'Tablet',
            'display_order': 2,
            'is_active': True
        }
    )
    cat_laptop, _ = DeviceCategory.objects.get_or_create(
        slug='laptop',
        defaults={
            'name': 'Laptop',
            'subtitle': 'Sell laptops',
            'icon_name': 'Laptop',
            'display_order': 3,
            'is_active': True
        }
    )
    cat_smartwatch, _ = DeviceCategory.objects.get_or_create(
        slug='smartwatch',
        defaults={
            'name': 'Smartwatch',
            'subtitle': 'Sell smartwatches',
            'icon_name': 'Watch',
            'display_order': 4,
            'is_active': True
        }
    )
    cat_dead_phone, _ = DeviceCategory.objects.get_or_create(
        slug='dead-phone',
        defaults={
            'name': 'Dead Phone',
            'subtitle': 'Not working device',
            'icon_name': 'AlertOctagon',
            'display_order': 5,
            'is_active': True
        }
    )
    cat_other, _ = DeviceCategory.objects.get_or_create(
        slug='other',
        defaults={
            'name': 'Other',
            'subtitle': 'More devices',
            'icon_name': 'Layers',
            'display_order': 6,
            'is_active': True
        }
    )

    print("✅ Device Categories seeded (Mobile, Tablet, Laptop, Smartwatch, Dead Phone, Other)")

    # ================= 3. BRANDS & LOGOS =================
    apple_logo = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 170 170' width='100' height='100'><path fill='%23111827' d='M150.37 130.25c-2.45 5.66-5.35 10.87-8.71 15.66-4.58 6.53-8.33 11.05-11.22 13.56-4.48 4.12-9.28 6.23-14.42 6.35-3.69 0-8.14-1.05-13.32-3.18-5.19-2.12-9.97-3.17-14.34-3.17-4.58 0-9.49 1.05-14.74 3.17-5.26 2.13-9.5 3.24-12.74 3.35-4.35.13-9.16-1.9-14.42-6.08-3.7-3.08-7.71-7.96-12.04-14.64-5.41-8.38-9.74-17.65-13.01-27.81-3.26-10.16-4.9-20.08-4.9-29.77 0-13.62 3.65-25.04 10.95-34.25 7.3-9.21 16.48-13.92 27.54-14.13 4.88 0 10.45 1.34 16.7 4.02 6.25 2.68 10.15 4.08 11.71 4.2 1.62-.12 5.76-1.58 12.42-4.39 6.66-2.81 12.47-4.14 17.43-3.99 12.75.75 22.86 5.43 30.34 14.04-11.07 6.69-16.51 16-16.32 27.93.19 9.87 3.96 17.97 11.31 24.31 7.35 6.34 16.14 9.9 26.37 10.68-2.3 6.96-5.08 14.14-8.33 21.55zM119.22 31.9c0-6.73 2.45-13.02 7.35-18.87 4.9-5.85 11.04-9.7 18.42-11.55.19 1.05.28 1.95.28 2.7 0 6.61-2.6 12.91-7.8 18.91-5.2 6-11.23 9.77-18.09 11.31-.06-.83-.16-1.66-.16-2.5z'/></svg>"
    samsung_logo = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 60' width='140' height='42'><text x='10' y='42' font-family='Arial, sans-serif' font-weight='bold' font-size='32' fill='%231428A0' letter-spacing='2'>SAMSUNG</text></svg>"
    xiaomi_logo = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 160 60' width='120' height='42'><rect x='5' y='10' width='40' height='40' fill='%23FF6900' rx='8'/><text x='12' y='38' font-family='Arial, sans-serif' font-weight='bold' font-size='22' fill='white'>mi</text><text x='55' y='38' font-family='Arial, sans-serif' font-weight='bold' font-size='24' fill='%23111827'>Xiaomi</text></svg>"
    google_logo = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 160 60' width='120' height='42'><text x='10' y='40' font-family='Arial, sans-serif' font-weight='bold' font-size='26' fill='%234285F4'>G<tspan fill='%23EA4335'>o</tspan><tspan fill='%23FBBC05'>o</tspan><tspan fill='%234285F4'>g</tspan><tspan fill='%2334A853'>l</tspan><tspan fill='%23EA4335'>e</tspan></text></svg>"
    oneplus_logo = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 180 60' width='130' height='42'><rect x='5' y='10' width='40' height='40' fill='%23F50514' rx='4'/><text x='18' y='38' font-family='Arial, sans-serif' font-weight='bold' font-size='26' fill='white'>1</text><text x='55' y='40' font-family='Arial, sans-serif' font-weight='bold' font-size='26' fill='%23111827'>ONEPLUS</text></svg>"
    vivo_logo = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 160 60' width='120' height='42'><text x='10' y='40' font-family='Arial, sans-serif' font-weight='bold' font-size='30' fill='%230066FF'>vivo</text></svg>"
    oppo_logo = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 160 60' width='120' height='42'><text x='10' y='40' font-family='Arial, sans-serif' font-weight='bold' font-size='28' fill='%23008040'>oppo</text></svg>"
    realme_logo = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 160 60' width='120' height='42'><text x='10' y='40' font-family='Arial, sans-serif' font-weight='bold' font-size='28' fill='%23FFC400'>realme</text></svg>"
    nothing_logo = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 180 60' width='130' height='42'><text x='10' y='40' font-family='monospace' font-weight='bold' font-size='26' fill='%23111827'>NOTHING</text></svg>"
    nokia_logo = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 160 60' width='120' height='42'><text x='10' y='40' font-family='Arial, sans-serif' font-weight='bold' font-size='28' fill='%23124191'>NOKIA</text></svg>"
    motorola_logo = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 180 60' width='130' height='42'><circle cx='30' cy='30' r='20' fill='%2300142E'/><text x='20' y='38' font-family='Arial' font-weight='bold' font-size='22' fill='white'>M</text><text x='60' y='38' font-family='Arial' font-weight='bold' font-size='20' fill='%2300142E'>motorola</text></svg>"
    honor_logo = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 160 60' width='120' height='42'><text x='10' y='40' font-family='Arial, sans-serif' font-weight='bold' font-size='28' fill='%2300A5DF'>HONOR</text></svg>"

    brands_data = [
        ('Apple', apple_logo, 1),
        ('Samsung', samsung_logo, 2),
        ('Xiaomi', xiaomi_logo, 3),
        ('Google', google_logo, 4),
        ('OnePlus', oneplus_logo, 5),
        ('Vivo', vivo_logo, 6),
        ('Oppo', oppo_logo, 7),
        ('Realme', realme_logo, 8),
        ('NOTHING', nothing_logo, 9),
        ('Nokia', nokia_logo, 10),
        ('Motorola', motorola_logo, 11),
        ('HONOR', honor_logo, 12),
    ]

    brand_objs = {}
    for name, logo, order in brands_data:
        b, _ = Brand.objects.update_or_create(
            name=name,
            defaults={
                'category': cat_mobile,
                'logo_base64': logo,
                'display_order': order,
                'is_active': True
            }
        )
        brand_objs[name] = b

    print(f"✅ Brands seeded ({len(brand_objs)} Brands: Apple, Samsung, Xiaomi, Google, OnePlus...)")

    # ================= 4. SERIES & MODELS =================
    b_apple = brand_objs['Apple']
    s_ip11, _ = DeviceSeries.objects.get_or_create(brand=b_apple, name='iPhone 11 Series', defaults={'display_order': 1})
    s_ip12, _ = DeviceSeries.objects.get_or_create(brand=b_apple, name='iPhone 12 Series', defaults={'display_order': 2})
    s_ip13, _ = DeviceSeries.objects.get_or_create(brand=b_apple, name='iPhone 13 Series', defaults={'display_order': 3})

    b_samsung = brand_objs['Samsung']
    s_galaxy_s, _ = DeviceSeries.objects.get_or_create(brand=b_samsung, name='Galaxy S Series', defaults={'display_order': 1})

    phone_graphic_svg = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 120 200' width='120' height='200'><rect x='5' y='5' width='110' height='190' rx='20' fill='%231e293b' stroke='%23475569' stroke-width='3'/><rect x='10' y='18' width='100' height='164' rx='12' fill='%230f172a'/><circle cx='60' cy='12' r='3' fill='%2364748b'/><rect x='42' y='28' width='36' height='12' rx='6' fill='%23020617'/></svg>"

    models_list = [
        # Apple iPhone 11 Series
        (b_apple, s_ip11, 'iPhone 11', 2019, [('4GB', '64GB', Decimal('12500.00')), ('4GB', '128GB', Decimal('16000.00')), ('4GB', '256GB', Decimal('19000.00'))]),
        (b_apple, s_ip11, 'iPhone 11 Pro', 2019, [('4GB', '64GB', Decimal('16500.00')), ('4GB', '256GB', Decimal('21000.00')), ('4GB', '512GB', Decimal('24500.00'))]),
        (b_apple, s_ip11, 'iPhone 11 Pro Max', 2019, [('4GB', '64GB', Decimal('19500.00')), ('4GB', '256GB', Decimal('24000.00')), ('4GB', '512GB', Decimal('28000.00'))]),

        # Apple iPhone 12 Series
        (b_apple, s_ip12, 'iPhone 12 Mini', 2020, [('4GB', '64GB', Decimal('15000.00')), ('4GB', '128GB', Decimal('18000.00'))]),
        (b_apple, s_ip12, 'iPhone 12', 2020, [('4GB', '64GB', Decimal('18000.00')), ('4GB', '128GB', Decimal('21000.00')), ('4GB', '256GB', Decimal('24000.00'))]),
        (b_apple, s_ip12, 'iPhone 12 Pro', 2020, [('6GB', '128GB', Decimal('26000.00')), ('6GB', '256GB', Decimal('30000.00'))]),

        # Apple iPhone 13 Series
        (b_apple, s_ip13, 'iPhone 13', 2021, [('4GB', '128GB', Decimal('26000.00')), ('4GB', '256GB', Decimal('30000.00')), ('4GB', '512GB', Decimal('35000.00'))]),

        # Samsung
        (b_samsung, s_galaxy_s, 'Galaxy S21', 2021, [('8GB', '128GB', Decimal('14500.00')), ('8GB', '256GB', Decimal('17000.00'))]),
        (b_samsung, s_galaxy_s, 'Galaxy S24 Ultra', 2024, [('12GB', '256GB', Decimal('68000.00')), ('12GB', '512GB', Decimal('76000.00'))]),
    ]

    for brand, series, m_name, year, variants in models_list:
        pm, _ = PhoneModel.objects.update_or_create(
            brand=brand,
            name=m_name,
            defaults={
                'series': series,
                'release_year': year,
                'image_base64': phone_graphic_svg,
                'is_active': True
            }
        )
        for ram, storage, price in variants:
            StorageVariant.objects.update_or_create(
                model=pm,
                ram=ram,
                storage=storage,
                defaults={'base_price': price, 'min_price': Decimal('500.00'), 'is_active': True}
            )

    print("✅ Models, Series and Storage Variants seeded")

    # ================= 5. DYNAMIC 11-STEP QUESTIONNAIRE =================
    # High-contrast SVGs
    img_screen_clean = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 200' width='200' height='200'><rect width='200' height='200' rx='24' fill='%23F0FDF4'/><rect x='45' y='20' width='110' height='160' rx='16' fill='%231E293B' stroke='%2316A34A' stroke-width='3'/><rect x='52' y='32' width='96' height='136' rx='8' fill='%230F172A'/><circle cx='100' cy='100' r='20' fill='%2316A34A'/><path d='M92 100 L98 106 L108 94' stroke='white' stroke-width='3' fill='none'/><text x='100' y='18' text-anchor='middle' font-family='Arial' font-weight='bold' font-size='11' fill='%2316A34A'>NO DEFECT</text></svg>"
    img_screen_scratch = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 200' width='200' height='200'><rect width='200' height='200' rx='24' fill='%23FFFBEB'/><rect x='45' y='20' width='110' height='160' rx='16' fill='%231E293B' stroke='%23F59E0B' stroke-width='3'/><rect x='52' y='32' width='96' height='136' rx='8' fill='%230F172A'/><path d='M65 50 L115 75 M75 110 L130 135 M60 140 L100 155' stroke='%23F59E0B' stroke-width='2' stroke-linecap='round' stroke-dasharray='4,4'/><text x='100' y='18' text-anchor='middle' font-family='Arial' font-weight='bold' font-size='11' fill='%23D97706'>SCRATCHES</text></svg>"
    img_screen_crack = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 200' width='200' height='200'><rect width='200' height='200' rx='24' fill='%23FEF2F2'/><rect x='45' y='20' width='110' height='160' rx='16' fill='%231E293B' stroke='%23DC2626' stroke-width='3'/><rect x='52' y='32' width='96' height='136' rx='8' fill='%230F172A'/><path d='M100 80 L65 40 M100 80 L140 50 M100 80 L80 120 M80 120 L55 145 M80 120 L125 155 M100 80 L135 115 M135 115 L145 140' stroke='%23EF4444' stroke-width='3' stroke-linecap='round'/><text x='100' y='18' text-anchor='middle' font-family='Arial' font-weight='black' font-size='11' fill='%23DC2626'>BROKEN / CRACKED</text></svg>"
    
    # 11 Steps
    steps_data = [
        # Step 2: Device Details
        (2, 'Device Details', 'Verify calling and screen replacement status', 'MULTIPLE', 'Smartphone', 'Ensure device powers on without looping', [
            ('CALLING_OK', 'Calling Functional', 'Phone can make and receive cellular calls', img_screen_clean, False, 'FLAT', Decimal('0.00'), False, False),
            ('DISPLAY_REPLACED', 'Replaced / Duplicate Display', 'Screen was replaced by non-official shop', img_screen_scratch, True, 'FLAT', Decimal('1500.00'), False, False),
        ]),

        # Step 3: Display Glass Condition
        (3, 'Display Glass Condition', 'Choose the display glass condition of your device', 'SINGLE', 'Smartphone', 'Check your screen under bright light and from different angles', [
            ('DISP_NO_DEFECT', 'No Defect', 'Pristine screen without scratches or cracks', img_screen_clean, False, 'FLAT', Decimal('0.00'), False, False),
            ('DISP_SCRATCHES', 'Scratches', 'Hairline micro-scratches on glass surface', img_screen_scratch, True, 'FLAT', Decimal('500.00'), False, False),
            ('DISP_BROKEN', 'Broken / Cracked', 'Spiderweb cracks or physical glass breaks', img_screen_crack, True, 'FLAT', Decimal('2500.00'), False, False),
        ]),

        # Step 4: Display Defects
        (4, 'Display Defects', 'Check for internal OLED / LCD panel issues', 'MULTIPLE', 'Layers', 'Look for vertical colored lines or black spots', [
            ('DEAD_SPOTS', 'Dead Spots / Black Ink', 'Ink bleeding or black dots on display', img_screen_crack, True, 'FLAT', Decimal('1500.00'), False, False),
            ('GREEN_LINES', 'Display Lines / Discoloration', 'Green, pink or white lines on screen', img_screen_crack, True, 'PERCENTAGE', Decimal('15.00'), False, False),
        ]),

        # Step 5: Body Defects
        (5, 'Body Defects', 'Check the metal or aluminum frame of your phone', 'MULTIPLE', 'Shield', 'Inspect corners and sides for drop dents', [
            ('BODY_MINOR_SCRATCH', 'Minor Scratches', 'Light daily usage scuffs on frame', img_screen_scratch, True, 'FLAT', Decimal('500.00'), False, False),
            ('BODY_DENT', 'Body Dent / Chipped', 'Corner dents or chipped aluminum', img_screen_crack, True, 'FLAT', Decimal('500.00'), False, False),
            ('BODY_BENT', 'Body Bend', 'Device is visibly bent or curved', img_screen_crack, True, 'FLAT', Decimal('2000.00'), False, False),
        ]),

        # Step 6: Panel / Back Glass
        (6, 'Panel Defects', 'Check back cover or rear glass condition', 'SINGLE', 'Layers', 'Look for cracks around camera module', [
            ('PANEL_CLEAN', 'Clean Back Panel', 'No cracks on rear glass', img_screen_clean, False, 'FLAT', Decimal('0.00'), False, False),
            ('PANEL_CRACKED', 'Back Glass Broken', 'Cracked or shattered rear glass panel', img_screen_crack, True, 'FLAT', Decimal('2000.00'), False, False),
            ('PANEL_LOOSE', 'Loose / Missing Back Cover', 'Back cover popping open or loose', img_screen_scratch, True, 'FLAT', Decimal('1000.00'), False, False),
        ]),

        # Step 7: SIM & Network
        (7, 'SIM & Network', 'SIM tray and wireless network connectivity', 'MULTIPLE', 'Wifi', 'Ensure SIM tray ejects smoothly', [
            ('SIM_TRAY_FAIL', 'SIM Tray Missing or Damaged', 'Tray broken or missing', img_screen_scratch, True, 'FLAT', Decimal('300.00'), False, False),
            ('SIM_CARD_FAIL', 'SIM Card Not Detecting', 'No service or invalid SIM error', img_screen_crack, True, 'FLAT', Decimal('1200.00'), False, False),
        ]),

        # Step 8: Camera Faults
        (8, 'Camera Faults', 'Select multiple options if device has more than one fault', 'MULTIPLE', 'Camera', 'Open camera app and test zoom, front & rear lenses', [
            ('FRONT_CAM_FAULT', 'Front Camera Faulty', 'Front camera blank or not opening', img_screen_crack, True, 'FLAT', Decimal('1500.00'), False, False),
            ('FRONT_CAM_GLASS', 'Front Camera Glass Scratch / Broken', 'Cracked glass over selfie camera', img_screen_scratch, True, 'FLAT', Decimal('800.00'), False, False),
            ('BACK_CAM_FAULT', 'Back Camera Faulty', 'Blur, jitter, blank or not opening', img_screen_crack, True, 'FLAT', Decimal('2000.00'), False, False),
            ('BACK_CAM_GLASS', 'Back Camera Glass Scratch / Broken', 'Lens glass broken or cracked', img_screen_crack, True, 'FLAT', Decimal('800.00'), False, False),
        ]),

        # Step 9: Functional Faults
        (9, 'Functional Faults', 'Select all applicable functional faults', 'MULTIPLE', 'Settings', 'Test biometric Face ID, audio speakers and mic', [
            ('PROXIMITY_FAIL', 'Proximity Sensor', 'Screen does not turn off during calls', img_screen_scratch, True, 'FLAT', Decimal('600.00'), False, False),
            ('EARPIECE_FAIL', 'Headset / Earpiece Speaker', 'No sound or low distorted sound', img_screen_scratch, True, 'FLAT', Decimal('600.00'), False, False),
            ('LOUDSPEAKER_FAIL', 'Loud Speaker', 'Ring tones or media audio not playing', img_screen_crack, True, 'FLAT', Decimal('800.00'), False, False),
            ('MIC_FAIL', 'Microphone', 'Callers cannot hear your voice', img_screen_crack, True, 'FLAT', Decimal('800.00'), False, False),
            ('WIFI_FAIL', 'WiFi / Bluetooth', 'Cannot connect to wireless networks', img_screen_crack, True, 'FLAT', Decimal('1200.00'), False, False),
            ('BATTERY_LOW', 'Battery Health (Below 80%)', 'Requires frequent charging / Service notice', img_screen_scratch, True, 'PERCENTAGE', Decimal('15.00'), False, False),
            ('BATTERY_SWOLLEN', 'Swollen Battery (Safety Risk)', 'Bulging back cover / fire risk', img_screen_crack, True, 'FLAT', Decimal('0.00'), True, False),
            ('ICLOUD_LOCKED', 'Apple iCloud / Google FRP Account Lock', 'Ownership lock active on phone', img_screen_crack, True, 'FLAT', Decimal('0.00'), True, False),
        ]),

        # Step 10: Accessories & Warranty
        (10, 'Accessories & Warranty', 'Select multiple options if available', 'MULTIPLE', 'Gift', 'Including original accessories increases buyback value', [
            ('ACC_BOX', 'Original Box', 'Original device packaging box with matching IMEI', img_screen_clean, False, 'FLAT', Decimal('0.00'), False, True),
            ('ACC_CHARGER', 'Original Charger', 'Official wall adapter', img_screen_clean, False, 'FLAT', Decimal('0.00'), False, True),
            ('ACC_CABLE', 'Charger Cable', 'Original charging wire', img_screen_clean, False, 'FLAT', Decimal('0.00'), False, True),
            ('ACC_BILL', 'Invoice Bill', 'Valid retail tax purchase invoice', img_screen_clean, False, 'FLAT', Decimal('0.00'), False, True),
            ('WARRANTY_3M', 'Warranty Below 3 Months', 'Device in official manufacturer warranty', img_screen_clean, False, 'FLAT', Decimal('0.00'), False, False),
            ('WARRANTY_NONE', 'No Warranty', 'Device out of warranty', img_screen_clean, False, 'FLAT', Decimal('0.00'), False, False),
        ]),
    ]

    for step_num, title, subtitle, sel_type, icon, tip, opts in steps_data:
        cat_obj, _ = ConditionCategory.objects.update_or_create(
            step_number=step_num,
            defaults={
                'device_category': cat_mobile,
                'name': title,
                'subtitle': subtitle,
                'selection_type': sel_type,
                'icon_name': icon,
                'pro_tip': tip,
                'display_order': step_num,
                'is_active': True
            }
        )
        for code, o_title, o_desc, o_img, is_defect, d_type, d_val, is_rej, is_acc in opts:
            ConditionOption.objects.update_or_create(
                code=code,
                defaults={
                    'category': cat_obj,
                    'title': o_title,
                    'description': o_desc,
                    'image_base64': o_img,
                    'is_defect': is_defect,
                    'deduction_type': d_type,
                    'default_deduction_value': d_val,
                    'is_rejection': is_rej,
                    'is_accessory_bonus': is_acc,
                    'display_order': 1,
                    'is_active': True
                }
            )

    print("✅ Dynamic 11-Step Questionnaire & Options seeded")

    # ================= 6. DYNAMIC CMS HOMEPAGE SECTIONS =================
    cms_sections = [
        ('HERO_CAROUSEL', 'Welcome Back! Sell Your Device', 'Get the best value for your old device.', 1, {
            'slides': [
                {
                    'badge': 'The Device Buyback Company',
                    'title': 'Sell Your Old Device',
                    'subtitle': 'Get the best value for your phone, tablet, laptop & more.',
                    'button_text': 'Start Selling Now →',
                    'button_link': '/sell',
                    'bg_gradient': 'from-[#0BAA4B] to-[#087C38]'
                },
                {
                    'badge': 'Instant Payout Guarantee',
                    'title': 'Doorstep Cash in 60 Seconds',
                    'subtitle': 'Verified agent inspects device and transfers UPI to your GPay / PhonePe.',
                    'button_text': 'Check Phone Value →',
                    'button_link': '/sell',
                    'bg_gradient': 'from-[#087C38] to-[#0D4722]'
                }
            ]
        }),
        ('QUICK_SERVICES', 'Quick Services', 'Fast access to your buyback operations', 2, {
            'services': [
                {'icon': 'Smartphone', 'title': 'Sell Device', 'desc': 'Get instant cash', 'action': 'sell'},
                {'icon': 'Truck', 'title': 'Track Pickup', 'desc': 'Live agent status', 'action': 'track'},
                {'icon': 'Package', 'title': 'My Orders', 'desc': 'View past sales', 'action': 'orders'},
                {'icon': 'Headphones', 'title': 'Support', 'desc': 'Help & WhatsApp', 'action': 'support'},
            ]
        }),
        ('TOP_BRANDS', 'Top Brands', 'Select your device manufacturer', 3, {
            'brands': ['Apple', 'Samsung', 'Xiaomi', 'Google', 'OnePlus', 'Vivo', 'Oppo', 'Realme']
        }),
        ('SECURITY_BANNER', 'Your Data is Safe', 'We value your privacy and security. 100% Certified Data Wipe.', 4, {
            'icon': 'ShieldCheck',
            'title': 'Your Data is Safe',
            'subtitle': 'We perform military-grade certified factory wipe before your phone is processed.'
        }),
    ]

    for s_type, s_title, s_sub, s_order, s_data in cms_sections:
        CMSHomeSection.objects.update_or_create(
            section_type=s_type,
            defaults={
                'title': s_title,
                'subtitle': s_sub,
                'display_order': s_order,
                'data_json': s_data,
                'is_active': True
            }
        )

    print("✅ Dynamic CMS Home Sections seeded")

    # ================= 7. LIVE SAMPLE ORDERS (Matching Reference Image) =================
    sample_sale, _ = PhoneSale.objects.update_or_create(
        sale_code='XP2610008753',
        defaults={
            'customer': customer_user,
            'customer_name': 'Mohamed K.',
            'customer_phone': '9876543212',
            'customer_email': 'mohamed@example.com',
            'variant': StorageVariant.objects.filter(model__name='iPhone 11', storage='128GB').first() or StorageVariant.objects.first(),
            'base_price': Decimal('16000.00'),
            'estimated_price': Decimal('14500.00'),
            'final_price': Decimal('14500.00'),
            'status': 'PICKUP_SCHEDULED',
            'assigned_agent': agent_user,
            'pickup_address': 'No. 42, Green Avenue, Anna Nagar',
            'pickup_city': 'Tirupur',
            'pickup_pincode': '641602',
            'pickup_slot': 'Afternoon (1:00 PM - 5:00 PM)',
            'beneficiary_type': 'UPI',
            'beneficiary_name': 'Mohamed K.',
            'beneficiary_upi_id': 'mohamed@okaxis',
        }
    )

    print(f"✅ Sample Order {sample_sale.sale_code} seeded (XP2610008753)")
    print("🎉 MASTER 1103 RECELL SEED COMPLETED 100% SUCCESSFULLY!")

if __name__ == '__main__':
    seed_database()
