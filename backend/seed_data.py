import os
import sys
import django
from decimal import Decimal

# Setup django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
django.setup()

from apps.accounts.models import User
from apps.catalog.models import Brand, PhoneModel, StorageVariant
from apps.valuation.models import ConditionCategory, ConditionOption, ModelPricingOverride, PriceHistory
from apps.sales.models import PhoneSale, PhoneSaleConditionAnswer
from apps.inspections.models import DeviceInspection, InspectionPhoto
from apps.payments.models import Payment

def run():
    print("🚀 Starting Mobile Buyback Platform database seed...")

    # 1. Create Users
    admin_user, _ = User.objects.get_or_create(
        email='admin@buyback.in',
        defaults={
            'full_name': 'Super Admin',
            'phone': '9876543210',
            'role': 'ADMIN',
            'is_staff': True,
            'is_superuser': True,
        }
    )
    admin_user.set_password('admin123')
    admin_user.save()

    agent_user, _ = User.objects.get_or_create(
        email='agent@buyback.in',
        defaults={
            'full_name': 'Ramesh Kumar (Pickup Specialist)',
            'phone': '9876543211',
            'role': 'COLLECTION_AGENT',
        }
    )
    agent_user.set_password('agent123')
    agent_user.save()

    customer_user, _ = User.objects.get_or_create(
        email='customer@example.com',
        defaults={
            'full_name': 'Pooja Verma',
            'phone': '9876543212',
            'role': 'CUSTOMER',
        }
    )
    customer_user.set_password('customer123')
    customer_user.save()

    print("✅ Users seeded (Admin, Agent, Customer)")

    # 2. Condition Categories & Valuation Rules
    cat_display, _ = ConditionCategory.objects.get_or_create(
        name='Screen & Touchscreen',
        defaults={'description': 'Physical glass, display lines and touch responsiveness', 'icon_name': 'Smartphone', 'display_order': 1}
    )
    cat_body, _ = ConditionCategory.objects.get_or_create(
        name='Body & Physical Glass',
        defaults={'description': 'Back glass, aluminum frame scuffs and dents', 'icon_name': 'Shield', 'display_order': 2}
    )
    cat_camera, _ = ConditionCategory.objects.get_or_create(
        name='Camera & Sensors',
        defaults={'description': 'Front/Rear camera, Face ID / In-display Fingerprint', 'icon_name': 'Camera', 'display_order': 3}
    )
    cat_battery, _ = ConditionCategory.objects.get_or_create(
        name='Battery & Charging',
        defaults={'description': 'Battery health percentage and charging port', 'icon_name': 'BatteryCharging', 'display_order': 4}
    )
    cat_hardware, _ = ConditionCategory.objects.get_or_create(
        name='Functional & Wireless',
        defaults={'description': 'Speakers, Mic, Wi-Fi, Bluetooth, Cellular call quality', 'icon_name': 'Wifi', 'display_order': 5}
    )

    # High-contrast Visual SVGs for Condition Options
    img_screen_scratch = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 200' width='200' height='200'><rect width='200' height='200' rx='24' fill='%23F8FAFC'/><rect x='45' y='20' width='110' height='160' rx='16' fill='%231E293B' stroke='%23475569' stroke-width='3'/><rect x='52' y='32' width='96' height='136' rx='8' fill='%230F172A'/><path d='M65 50 L115 75 M75 110 L130 135 M60 140 L100 155' stroke='%23F59E0B' stroke-width='2' stroke-linecap='round' stroke-dasharray='4,4'/><circle cx='100' cy='178' r='4' fill='%2364748B'/><text x='100' y='18' text-anchor='middle' font-family='Arial' font-weight='bold' font-size='11' fill='%23D97706'>HAIRLINE SCRATCHES</text></svg>"
    img_screen_crack = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 200' width='200' height='200'><rect width='200' height='200' rx='24' fill='%23FEF2F2'/><rect x='45' y='20' width='110' height='160' rx='16' fill='%231E293B' stroke='%23DC2626' stroke-width='3'/><rect x='52' y='32' width='96' height='136' rx='8' fill='%230F172A'/><path d='M100 80 L65 40 M100 80 L140 50 M100 80 L80 120 M80 120 L55 145 M80 120 L125 155 M100 80 L135 115 M135 115 L145 140' stroke='%23EF4444' stroke-width='3' stroke-linecap='round'/><path d='M85 70 L95 55 M115 90 L130 85 M70 130 L60 125' stroke='%23FCA5A5' stroke-width='1.5'/><text x='100' y='18' text-anchor='middle' font-family='Arial' font-weight='black' font-size='11' fill='%23DC2626'>CRACKED SCREEN</text></svg>"
    img_display_lines = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 200' width='200' height='200'><rect width='200' height='200' rx='24' fill='%23FDF2F8'/><rect x='45' y='20' width='110' height='160' rx='16' fill='%231E293B' stroke='%23DB2777' stroke-width='3'/><rect x='52' y='32' width='96' height='136' rx='8' fill='%230F172A'/><line x1='75' y1='32' x2='75' y2='168' stroke='%2322C55E' stroke-width='4'/><line x1='110' y1='32' x2='110' y2='168' stroke='%23EC4899' stroke-width='3'/><circle cx='125' cy='70' r='14' fill='%23000000' stroke='%23475569' stroke-width='2'/><text x='100' y='18' text-anchor='middle' font-family='Arial' font-weight='bold' font-size='11' fill='%23BE185D'>LINES / BLACK SPOT</text></svg>"
    img_touch_fail = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 200' width='200' height='200'><rect width='200' height='200' rx='24' fill='%23FFFBEB'/><rect x='45' y='20' width='110' height='160' rx='16' fill='%231E293B' stroke='%23D97706' stroke-width='3'/><rect x='52' y='32' width='96' height='136' rx='8' fill='%230F172A'/><circle cx='100' cy='95' r='24' fill='%23F59E0B' fill-opacity='0.2' stroke='%23F59E0B' stroke-width='2'/><path d='M90 85 L110 105 M110 85 L90 105' stroke='%23DC2626' stroke-width='4' stroke-linecap='round'/><path d='M95 140 L105 115 L120 125 Z' fill='%23FFFFFF'/><text x='100' y='18' text-anchor='middle' font-family='Arial' font-weight='bold' font-size='11' fill='%23B45309'>UNRESPONSIVE TOUCH</text></svg>"
    img_body_scratches = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 200' width='200' height='200'><rect width='200' height='200' rx='24' fill='%23F8FAFC'/><rect x='45' y='20' width='110' height='160' rx='16' fill='%23334155' stroke='%2364748B' stroke-width='3'/><rect x='52' y='30' width='35' height='40' rx='6' fill='%231E293B'/><circle cx='62' cy='42' r='6' fill='%230F172A'/><circle cx='62' cy='58' r='6' fill='%230F172A'/><path d='M100 80 L135 110 M110 130 L145 155 M60 110 L85 130' stroke='%23F59E0B' stroke-width='2.5' stroke-linecap='round'/><text x='100' y='18' text-anchor='middle' font-family='Arial' font-weight='bold' font-size='11' fill='%2364748B'>BODY SCUFFS</text></svg>"
    img_body_dents = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 200' width='200' height='200'><rect width='200' height='200' rx='24' fill='%23FEF2F2'/><path d='M45 40 Q45 20 65 20 L135 20 Q155 20 155 40 L155 140 L145 150 L155 160 Q155 180 135 180 L65 180 Q45 180 45 160 Z' fill='%23334155' stroke='%23DC2626' stroke-width='3'/><circle cx='150' cy='150' r='12' fill='%23EF4444' fill-opacity='0.3'/><polygon points='145,145 155,150 145,155' fill='%23DC2626'/><text x='100' y='18' text-anchor='middle' font-family='Arial' font-weight='bold' font-size='11' fill='%23DC2626'>DENTED CORNER</text></svg>"
    img_back_glass_broken = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 200' width='200' height='200'><rect width='200' height='200' rx='24' fill='%23FEF2F2'/><rect x='45' y='20' width='110' height='160' rx='16' fill='%23475569' stroke='%23DC2626' stroke-width='3'/><rect x='52' y='28' width='38' height='42' rx='8' fill='%231E293B'/><path d='M100 60 L75 90 M100 60 L135 75 M100 60 L115 110 M115 110 L80 145 M115 110 L140 150' stroke='%23EF4444' stroke-width='3' stroke-linecap='round'/><text x='100' y='18' text-anchor='middle' font-family='Arial' font-weight='black' font-size='11' fill='%23DC2626'>CRACKED BACK GLASS</text></svg>"
    img_camera_fail = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 200' width='200' height='200'><rect width='200' height='200' rx='24' fill='%23FEF2F2'/><circle cx='100' cy='95' r='45' fill='%231E293B' stroke='%23DC2626' stroke-width='4'/><circle cx='100' cy='95' r='30' fill='%230F172A'/><circle cx='92' cy='88' r='8' fill='%2338BDF8'/><path d='M80 75 L120 115 M100 95 L115 80 M100 95 L85 110' stroke='%23EF4444' stroke-width='3' stroke-linecap='round'/><text x='100' y='18' text-anchor='middle' font-family='Arial' font-weight='bold' font-size='11' fill='%23DC2626'>CAMERA DAMAGED</text></svg>"
    img_faceid_fail = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 200' width='200' height='200'><rect width='200' height='200' rx='24' fill='%23FEF2F2'/><path d='M70 70 L60 70 L60 80 M130 70 L140 70 L140 80 M60 120 L60 130 L70 130 M140 120 L140 130 L130 130' stroke='%23DC2626' stroke-width='4' fill='none'/><circle cx='85' cy='90' r='4' fill='%23DC2626'/><circle cx='115' cy='90' r='4' fill='%23DC2626'/><path d='M85 115 Q100 105 115 115' stroke='%23DC2626' stroke-width='3' fill='none'/><text x='100' y='18' text-anchor='middle' font-family='Arial' font-weight='bold' font-size='11' fill='%23DC2626'>FACE ID / SENSOR FAIL</text></svg>"
    img_battery_degraded = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 200' width='200' height='200'><rect width='200' height='200' rx='24' fill='%23FFFBEB'/><rect x='50' y='70' width='90' height='55' rx='10' fill='none' stroke='%23D97706' stroke-width='5'/><rect x='142' y='87' width='8' height='20' rx='4' fill='%23D97706'/><rect x='58' y='78' width='35' height='39' rx='4' fill='%23F59E0B'/><text x='100' y='103' text-anchor='middle' font-family='Arial' font-weight='black' font-size='16' fill='%2392400E'>&lt;80%</text><text x='100' y='18' text-anchor='middle' font-family='Arial' font-weight='bold' font-size='11' fill='%23B45309'>BATTERY HEALTH LOW</text></svg>"
    img_battery_swollen = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 200' width='200' height='200'><rect width='200' height='200' rx='24' fill='%23FEF2F2'/><path d='M60 40 Q40 100 60 160 L140 160 Q160 100 140 40 Z' fill='%23B91C1C' stroke='%23EF4444' stroke-width='4'/><path d='M100 70 L100 110 M100 125 L100 130' stroke='white' stroke-width='6' stroke-linecap='round'/><text x='100' y='18' text-anchor='middle' font-family='Arial' font-weight='black' font-size='11' fill='%23DC2626'>SWOLLEN BATTERY (DANGER)</text></svg>"
    img_speaker_fail = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 200' width='200' height='200'><rect width='200' height='200' rx='24' fill='%23FEF2F2'/><path d='M65 85 L85 85 L110 65 L110 135 L85 115 L65 115 Z' fill='%2364748B'/><line x1='125' y1='75' x2='155' y2='125' stroke='%23DC2626' stroke-width='5' stroke-linecap='round'/><line x1='155' y1='75' x2='125' y2='125' stroke='%23DC2626' stroke-width='5' stroke-linecap='round'/><text x='100' y='18' text-anchor='middle' font-family='Arial' font-weight='bold' font-size='11' fill='%23DC2626'>SPEAKER / MIC FAULTY</text></svg>"
    img_icloud_locked = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 200' width='200' height='200'><rect width='200' height='200' rx='24' fill='%23FEF2F2'/><rect x='55' y='30' width='90' height='140' rx='14' fill='%231E293B' stroke='%23DC2626' stroke-width='3'/><rect x='70' y='90' width='60' height='45' rx='8' fill='%23EF4444'/><path d='M80 90 L80 75 Q80 60 100 60 Q120 60 120 75 L120 90' fill='none' stroke='%23FCA5A5' stroke-width='5'/><circle cx='100' cy='110' r='4' fill='white'/><text x='100' y='18' text-anchor='middle' font-family='Arial' font-weight='black' font-size='11' fill='%23DC2626'>ACTIVATION / FRP LOCKED</text></svg>"

    # Question Options & Deductions (With Exclusive Groups, Rejections, and Visual Images)
    options_data = [
        # Screen
        (cat_display, 'SCREEN_MINOR_SCRATCH', 'Minor hairline screen scratches', 'Light surface micro-scratches', img_screen_scratch, True, 'FLAT', Decimal('500.00'), 'screen_glass', False, 1),
        (cat_display, 'SCREEN_CRACKED', 'Screen glass is cracked or broken', 'Visible cracks, spiderweb cracks on glass', img_screen_crack, True, 'FLAT', Decimal('3500.00'), 'screen_glass', False, 2),
        (cat_display, 'DISPLAY_LINES', 'Display has colored lines, bleeding or black spots', 'OLED/LCD damage or green lines', img_display_lines, True, 'PERCENTAGE', Decimal('15.00'), '', False, 3),
        (cat_display, 'TOUCH_ISSUE', 'Touch is erratic or not responding in some areas', 'Dead touch zones', img_touch_fail, True, 'FLAT', Decimal('2500.00'), '', False, 4),
        
        # Body
        (cat_body, 'BODY_MINOR_SCRATCHES', 'Minor scratches on body / frame', 'Light signs of normal daily use', img_body_scratches, True, 'FLAT', Decimal('500.00'), 'body_damage', False, 1),
        (cat_body, 'BODY_DENTS', 'Dents or chipped corners on frame', 'Impact drops or bent frame', img_body_dents, True, 'FLAT', Decimal('1500.00'), 'body_damage', False, 2),
        (cat_body, 'BACK_GLASS_BROKEN', 'Back glass is cracked or broken', 'Cracks on rear glass panel', img_back_glass_broken, True, 'FLAT', Decimal('2500.00'), '', False, 3),

        # Camera
        (cat_camera, 'REAR_CAMERA_FAIL', 'Rear camera blurry, jittery or not working', 'Camera lens cracked or sensor dead', img_camera_fail, True, 'FLAT', Decimal('2000.00'), '', False, 1),
        (cat_camera, 'FACEID_FAIL', 'Face ID or Fingerprint scanner not working', 'Biometric sensor failure', img_faceid_fail, True, 'FLAT', Decimal('1500.00'), '', False, 2),

        # Battery
        (cat_battery, 'BATTERY_DEGRADED', 'Battery health below 80% / Service Recommended', 'Frequent charging required', img_battery_degraded, True, 'PERCENTAGE', Decimal('8.00'), '', False, 1),
        (cat_battery, 'BATTERY_SWOLLEN', 'Battery is swollen / back cover bulging', 'Safety hazard: fire/explosion risk', img_battery_swollen, True, 'FLAT', Decimal('0.00'), '', True, 2),

        # Hardware & Security Rejection
        (cat_hardware, 'SPEAKER_MIC_FAIL', 'Earpiece speaker or microphone issue', 'Call audio is distorted or silent', img_speaker_fail, True, 'FLAT', Decimal('800.00'), '', False, 1),
        (cat_hardware, 'ICLOUD_LOCKED', 'Apple iCloud / Google FRP Account Lock Active', 'Ownership lock active on device', img_icloud_locked, True, 'FLAT', Decimal('0.00'), '', True, 2),
    ]

    for cat, code, title, desc, img, is_defect, d_type, val, grp, is_rej, order in options_data:
        ConditionOption.objects.update_or_create(
            code=code,
            defaults={
                'category': cat,
                'title': title,
                'description': desc,
                'image_base64': img,
                'is_defect': is_defect,
                'deduction_type': d_type,
                'default_deduction_value': val,
                'exclusive_group': grp,
                'is_rejection': is_rej,
                'display_order': order
            }
        )

    print("✅ Valuation rules & condition deductions seeded")

    # 3. Brands, Models, and Storage Variants
    # Sample clean SVG icons encoded in Base64
    apple_logo = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 170 170' width='100' height='100'><path fill='%23111827' d='M150.37 130.25c-2.45 5.66-5.35 10.87-8.71 15.66-4.58 6.53-8.33 11.05-11.22 13.56-4.48 4.12-9.28 6.23-14.42 6.35-3.69 0-8.14-1.05-13.32-3.18-5.19-2.12-9.97-3.17-14.34-3.17-4.58 0-9.49 1.05-14.74 3.17-5.26 2.13-9.5 3.24-12.74 3.35-4.35.13-9.16-1.9-14.42-6.08-3.7-3.08-7.71-7.96-12.04-14.64-5.41-8.38-9.74-17.65-13.01-27.81-3.26-10.16-4.9-20.08-4.9-29.77 0-13.62 3.65-25.04 10.95-34.25 7.3-9.21 16.48-13.92 27.54-14.13 4.88 0 10.45 1.34 16.7 4.02 6.25 2.68 10.15 4.08 11.71 4.2 1.62-.12 5.76-1.58 12.42-4.39 6.66-2.81 12.47-4.14 17.43-3.99 12.75.75 22.86 5.43 30.34 14.04-11.07 6.69-16.51 16-16.32 27.93.19 9.87 3.96 17.97 11.31 24.31 7.35 6.34 16.14 9.9 26.37 10.68-2.3 6.96-5.08 14.14-8.33 21.55zM119.22 31.9c0-6.73 2.45-13.02 7.35-18.87 4.9-5.85 11.04-9.7 18.42-11.55.19 1.05.28 1.95.28 2.7 0 6.61-2.6 12.91-7.8 18.91-5.2 6-11.23 9.77-18.09 11.31-.06-.83-.16-1.66-.16-2.5z'/></svg>"
    samsung_logo = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 60' width='140' height='42'><text x='10' y='42' font-family='Arial, sans-serif' font-weight='bold' font-size='32' fill='%231428A0' letter-spacing='2'>SAMSUNG</text></svg>"
    oneplus_logo = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 180 60' width='130' height='42'><rect x='5' y='10' width='40' height='40' fill='%23F50514' rx='4'/><text x='18' y='38' font-family='Arial, sans-serif' font-weight='bold' font-size='26' fill='white'>1</text><text x='55' y='40' font-family='Arial, sans-serif' font-weight='bold' font-size='26' fill='%23111827'>ONEPLUS</text></svg>"
    xiaomi_logo = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 160 60' width='120' height='42'><rect x='5' y='10' width='40' height='40' fill='%23FF6900' rx='8'/><text x='12' y='38' font-family='Arial, sans-serif' font-weight='bold' font-size='22' fill='white'>mi</text><text x='55' y='38' font-family='Arial, sans-serif' font-weight='bold' font-size='24' fill='%23111827'>Xiaomi</text></svg>"
    google_logo = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 160 60' width='120' height='42'><text x='10' y='40' font-family='Arial, sans-serif' font-weight='bold' font-size='26' fill='%234285F4'>G<tspan fill='%23EA4335'>o</tspan><tspan fill='%23FBBC05'>o</tspan><tspan fill='%234285F4'>g</tspan><tspan fill='%2334A853'>l</tspan><tspan fill='%23EA4335'>e</tspan></text></svg>"

    b_apple, _ = Brand.objects.get_or_create(name='Apple', defaults={'logo_base64': apple_logo, 'display_order': 1})
    b_samsung, _ = Brand.objects.get_or_create(name='Samsung', defaults={'logo_base64': samsung_logo, 'display_order': 2})
    b_oneplus, _ = Brand.objects.get_or_create(name='OnePlus', defaults={'logo_base64': oneplus_logo, 'display_order': 3})
    b_xiaomi, _ = Brand.objects.get_or_create(name='Xiaomi', defaults={'logo_base64': xiaomi_logo, 'display_order': 4})
    b_google, _ = Brand.objects.get_or_create(name='Google', defaults={'logo_base64': google_logo, 'display_order': 5})

    # Device mock graphic SVG in Base64
    phone_graphic_svg = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 120 200' width='120' height='200'><rect x='5' y='5' width='110' height='190' rx='20' fill='%231e293b' stroke='%23475569' stroke-width='3'/><rect x='10' y='18' width='100' height='164' rx='12' fill='%230f172a'/><circle cx='60' cy='12' r='3' fill='%2364748b'/><rect x='42' y='28' width='36' height='12' rx='6' fill='%23020617'/></svg>"

    models_data = [
        # Apple
        (b_apple, 'iPhone 15 Pro Max', 2023, [('8GB', '256GB', Decimal('72000.00')), ('8GB', '512GB', Decimal('82000.00'))]),
        (b_apple, 'iPhone 15', 2023, [('6GB', '128GB', Decimal('44000.00')), ('6GB', '256GB', Decimal('51000.00'))]),
        (b_apple, 'iPhone 14', 2022, [('6GB', '128GB', Decimal('34000.00')), ('6GB', '256GB', Decimal('39000.00'))]),
        (b_apple, 'iPhone 13', 2021, [('4GB', '128GB', Decimal('26000.00')), ('4GB', '256GB', Decimal('30000.00'))]),
        (b_apple, 'iPhone 12', 2020, [('4GB', '64GB', Decimal('18000.00')), ('4GB', '128GB', Decimal('21000.00'))]),

        # Samsung
        (b_samsung, 'Galaxy S24 Ultra', 2024, [('12GB', '256GB', Decimal('68000.00')), ('12GB', '512GB', Decimal('76000.00'))]),
        (b_samsung, 'Galaxy S23', 2023, [('8GB', '128GB', Decimal('31000.00')), ('8GB', '256GB', Decimal('35000.00'))]),
        (b_samsung, 'Galaxy A54 5G', 2023, [('8GB', '128GB', Decimal('14500.00')), ('8GB', '256GB', Decimal('16500.00'))]),

        # OnePlus
        (b_oneplus, 'OnePlus 12', 2024, [('12GB', '256GB', Decimal('39000.00')), ('16GB', '512GB', Decimal('45000.00'))]),
        (b_oneplus, 'OnePlus 11R', 2023, [('8GB', '128GB', Decimal('22000.00')), ('16GB', '256GB', Decimal('25000.00'))]),

        # Xiaomi
        (b_xiaomi, 'Redmi Note 13 Pro+ 5G', 2024, [('8GB', '256GB', Decimal('16000.00')), ('12GB', '512GB', Decimal('18500.00'))]),

        # Google
        (b_google, 'Pixel 8 Pro', 2023, [('12GB', '128GB', Decimal('42000.00')), ('12GB', '256GB', Decimal('48000.00'))]),
        (b_google, 'Pixel 7a', 2023, [('8GB', '128GB', Decimal('21000.00'))]),
    ]

    for brand_obj, m_name, yr, variants in models_data:
        m_obj, _ = PhoneModel.objects.get_or_create(
            brand=brand_obj,
            name=m_name,
            defaults={'release_year': yr, 'image_base64': phone_graphic_svg}
        )
        for ram_val, storage_val, price in variants:
            StorageVariant.objects.get_or_create(
                model=m_obj,
                ram=ram_val,
                storage=storage_val,
                defaults={'base_price': price, 'min_price': Decimal('1500.00')}
            )

    print("✅ Catalog seeded with Brands, Models, and Storage Variants")

    # 4. Seed Live Test Orders in different states to demonstrate the full workflow
    v_ip13 = StorageVariant.objects.filter(model__name='iPhone 13', storage='128GB').first()
    v_s23 = StorageVariant.objects.filter(model__name='Galaxy S23', storage='128GB').first()
    v_op12 = StorageVariant.objects.filter(model__name='OnePlus 12', storage='256GB').first()
    v_pix8 = StorageVariant.objects.filter(model__name='Pixel 8 Pro', storage='128GB').first()

    # SVG payment receipt preview
    sample_receipt_svg = "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 350 450' width='350' height='450'><rect width='100%25' height='100%25' fill='%230f172a'/><circle cx='175' cy='70' r='36' fill='%2310b981'/><path d='M160 70 L170 80 L190 60' stroke='white' stroke-width='6' fill='none' stroke-linecap='round'/><text x='175' y='135' font-family='Arial' font-size='22' font-weight='bold' fill='white' text-anchor='middle'>Paid Successfully</text><text x='175' y='175' font-family='Arial' font-size='32' font-weight='bold' fill='%2338bdf8' text-anchor='middle'>%E2%82%B9 24,000</text><rect x='30' y='210' width='290' height='180' rx='8' fill='%231e293b'/><text x='45' y='240' font-family='Arial' font-size='14' fill='%2394a3b8'>Paid to:</text><text x='45' y='265' font-family='Arial' font-size='16' font-weight='bold' fill='white'>Vikram Mehra</text><text x='45' y='285' font-family='Arial' font-size='14' fill='%23cbd5e1'>vikram@icici</text><text x='45' y='320' font-family='Arial' font-size='14' fill='%2394a3b8'>UPI Ref / UTR:</text><text x='45' y='345' font-family='Arial' font-size='15' font-weight='bold' fill='%2310b981'>432109876543</text><text x='45' y='370' font-family='Arial' font-size='12' fill='%2394a3b8'>State Bank of India %E2%80%A2 15-Nov-2026</text></svg>"

    if v_ip13:
        # Order 1: Ready for Admin Payout (Status: OWNERSHIP_TRANSFERRED)
        PhoneSale.objects.update_or_create(
            sale_code='PHN-2026-001',
            defaults={
                'customer': customer_user,
                'customer_name': 'Pooja Verma',
                'customer_phone': '9876543212',
                'customer_email': 'customer@example.com',
                'variant': v_ip13,
                'base_price': v_ip13.base_price,
                'estimated_price': Decimal('22500.00'),
                'final_price': Decimal('21000.00'),
                'status': 'OWNERSHIP_TRANSFERRED',
                'assigned_agent': agent_user,
                'pickup_address': 'Flat 402, Green Glen Layout, Bellandur',
                'pickup_city': 'Bengaluru',
                'pickup_pincode': '560103',
                'beneficiary_type': 'UPI',
                'beneficiary_name': 'Pooja Verma',
                'beneficiary_upi_id': 'pooja@okhdfcbank',
                'imei_number': '354892109845123',
                'customer_handover_signed': True,
                'admin_notes': 'Doorstep inspection completed. Ready for UPI payout transfer.',
            }
        )

        # Order 2: Already Paid with Base64 screenshot proof and UTR!
        sale_paid, _ = PhoneSale.objects.update_or_create(
            sale_code='PHN-2026-PAID-01',
            defaults={
                'customer': customer_user,
                'customer_name': 'Vikram Mehra',
                'customer_phone': '9870099887',
                'customer_email': 'vikram@example.com',
                'variant': v_ip13,
                'base_price': v_ip13.base_price,
                'estimated_price': Decimal('24000.00'),
                'final_price': Decimal('24000.00'),
                'status': 'PAYMENT_COMPLETED',
                'assigned_agent': agent_user,
                'pickup_address': 'Plot 12, Koramangala 4th Block',
                'pickup_city': 'Bengaluru',
                'pickup_pincode': '560034',
                'beneficiary_type': 'UPI',
                'beneficiary_name': 'Vikram Mehra',
                'beneficiary_upi_id': 'vikram@icici',
                'imei_number': '358941092837465',
                'customer_handover_signed': True,
                'admin_notes': 'Payment transferred via Google Pay.',
            }
        )

        Payment.objects.update_or_create(
            sale=sale_paid,
            defaults={
                'amount': Decimal('24000.00'),
                'payment_method': 'GPAY',
                'beneficiary_name': 'Vikram Mehra',
                'beneficiary_upi_id': 'vikram@icici',
                'utr_number': '432109876543',
                'payment_proof_base64': sample_receipt_svg,
                'admin_notes': 'Paid via Google Pay business UPI. Transfer confirmed.',
                'paid_by': admin_user,
                'is_verified': True,
            }
        )

    # Order 3: Assigned to Collection Agent (Status: PICKUP_SCHEDULED)
    if v_s23:
        PhoneSale.objects.update_or_create(
            sale_code='PHN-2026-002',
            defaults={
                'customer': customer_user,
                'customer_name': 'Pooja Verma',
                'customer_phone': '9876543212',
                'customer_email': 'customer@example.com',
                'variant': v_s23,
                'base_price': v_s23.base_price,
                'estimated_price': Decimal('31000.00'),
                'final_price': Decimal('31000.00'),
                'status': 'PICKUP_SCHEDULED',
                'assigned_agent': agent_user,
                'pickup_address': '14th Cross, Indiranagar',
                'pickup_city': 'Bengaluru',
                'pickup_pincode': '560038',
                'pickup_slot': 'Morning (10:00 AM - 1:00 PM)',
                'beneficiary_type': 'UPI',
                'beneficiary_name': 'Pooja Verma',
                'beneficiary_upi_id': 'pooja@okhdfcbank',
                'customer_handover_signed': False,
                'admin_notes': 'Agent Ramesh assigned for morning doorstep pickup.',
            }
        )

    # Order 4: Revised Offer Sent - Waiting Customer Acceptance (Status: FINAL_OFFER_SENT)
    if v_op12:
        sale_revised, _ = PhoneSale.objects.update_or_create(
            sale_code='PHN-2026-003',
            defaults={
                'customer': customer_user,
                'customer_name': 'Arun Karthik',
                'customer_phone': '9840192837',
                'customer_email': 'arun@example.com',
                'variant': v_op12,
                'base_price': v_op12.base_price,
                'estimated_price': Decimal('39000.00'),
                'final_price': Decimal('36500.00'),
                'status': 'FINAL_OFFER_SENT',
                'assigned_agent': agent_user,
                'pickup_address': 'Prestige Falcon City, Kanakapura Road',
                'pickup_city': 'Bengaluru',
                'pickup_pincode': '560062',
                'beneficiary_type': 'BANK',
                'beneficiary_name': 'Arun Karthik',
                'beneficiary_account_no': '9182736450123',
                'beneficiary_ifsc': 'HDFC0000128',
                'imei_number': '867123049581726',
                'customer_handover_signed': False,
                'admin_notes': 'Minor hairline scratches on back glass during inspection. Reduced by ₹2,500.',
            }
        )

    # Order 5: Brand New Request Submitted (Status: SUBMITTED - Awaiting Admin Assignment)
    if v_pix8:
        PhoneSale.objects.update_or_create(
            sale_code='PHN-2026-004',
            defaults={
                'customer_name': 'Siddharth Rao',
                'customer_phone': '9900112233',
                'customer_email': 'sid@example.com',
                'variant': v_pix8,
                'base_price': v_pix8.base_price,
                'estimated_price': Decimal('42000.00'),
                'status': 'SUBMITTED',
                'pickup_address': 'Sobha City, Thanisandra Main Road',
                'pickup_city': 'Bengaluru',
                'pickup_pincode': '560077',
                'pickup_slot': 'Afternoon (1:00 PM - 4:00 PM)',
                'beneficiary_type': 'UPI',
                'beneficiary_name': 'Siddharth Rao',
                'beneficiary_upi_id': 'sidrao@axisbank',
                'customer_handover_signed': False,
            }
        )

    # 5. Price History Audit Sample
    if v_ip13:
        PriceHistory.objects.get_or_create(
            variant=v_ip13,
            old_base_price=Decimal('28000.00'),
            new_base_price=Decimal('26000.00'),
            defaults={
                'changed_by': admin_user,
                'reason': 'Market markdown post festive season',
            }
        )
    if v_s23:
        PriceHistory.objects.get_or_create(
            variant=v_s23,
            old_base_price=Decimal('33000.00'),
            new_base_price=Decimal('31000.00'),
            defaults={
                'changed_by': admin_user,
                'reason': 'Flagship depreciation adjustment',
            }
        )

    print("✅ Sample live orders seeded with Base64 payment proof")
    print("✅ Price history audit entries seeded")
    print("🎉 SEED COMPLETED SUCCESSFULLY!")

if __name__ == '__main__':
    run()
