import os
import sys
import django
import base64

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from apps.catalog.models import DeviceCategory, Brand
from apps.valuation.models import ConditionCategory, ConditionOption

def svg_to_b64(svg_str):
    return "data:image/svg+xml;base64," + base64.b64encode(svg_str.strip().encode('utf-8')).decode('utf-8')

# High quality SVG line-art icons
SVG_BATTERY_GREEN = svg_to_b64('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 60" width="100" height="60">
  <rect x="5" y="10" width="75" height="40" rx="8" fill="none" stroke="#0BAA4B" stroke-width="4"/>
  <rect x="80" y="22" width="6" height="16" rx="3" fill="#0BAA4B"/>
  <rect x="12" y="17" width="61" height="26" rx="4" fill="#0BAA4B"/>
  <text x="42" y="35" font-family="Arial, sans-serif" font-weight="900" font-size="14" fill="#FFFFFF" text-anchor="middle">85%+</text>
</svg>
''')

SVG_BATTERY_YELLOW = svg_to_b64('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 60" width="100" height="60">
  <rect x="5" y="10" width="75" height="40" rx="8" fill="none" stroke="#D97706" stroke-width="4"/>
  <rect x="80" y="22" width="6" height="16" rx="3" fill="#D97706"/>
  <rect x="12" y="17" width="45" height="26" rx="4" fill="#F59E0B"/>
  <text x="35" y="35" font-family="Arial, sans-serif" font-weight="900" font-size="12" fill="#FFFFFF" text-anchor="middle">81-85%</text>
</svg>
''')

SVG_BATTERY_RED = svg_to_b64('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 60" width="100" height="60">
  <rect x="5" y="10" width="75" height="40" rx="8" fill="none" stroke="#DC2626" stroke-width="4"/>
  <rect x="80" y="22" width="6" height="16" rx="3" fill="#DC2626"/>
  <rect x="12" y="17" width="22" height="26" rx="4" fill="#EF4444"/>
  <text x="23" y="35" font-family="Arial, sans-serif" font-weight="900" font-size="12" fill="#FFFFFF" text-anchor="middle">≤80%</text>
</svg>
''')

SVG_ICLOUD_LOCK = svg_to_b64('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 80 80" width="80" height="80">
  <rect x="22" y="12" width="36" height="56" rx="8" fill="#F8FAFC" stroke="#0BAA4B" stroke-width="3"/>
  <circle cx="40" cy="62" r="3" fill="#0BAA4B"/>
  <path d="M40 24 C34 24 30 28 30 33 C26 33 24 36 24 40 C24 44 27 47 31 47 L49 47 C53 47 56 44 56 40 C56 36 53 33 49 33 C49 28 45 24 40 24 Z" fill="#3B82F6" opacity="0.9"/>
  <rect x="35" y="36" width="10" height="8" rx="2" fill="#F59E0B"/>
  <path d="M37 36 L37 33 C37 31.5 38.5 30 40 30 C41.5 30 43 31.5 43 33 L43 36" fill="none" stroke="#F59E0B" stroke-width="2"/>
</svg>
''')

SVG_PHONE_BOX = svg_to_b64('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 80 80" width="80" height="80">
  <polygon points="40,10 70,24 40,38 10,24" fill="#F1F5F9" stroke="#0BAA4B" stroke-width="2.5"/>
  <polygon points="10,24 40,38 40,68 10,54" fill="#E2E8F0" stroke="#0BAA4B" stroke-width="2.5"/>
  <polygon points="40,38 70,24 70,54 40,68" fill="#CBD5E1" stroke="#0BAA4B" stroke-width="2.5"/>
</svg>
''')

SVG_CHARGER = svg_to_b64('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 80 80" width="80" height="80">
  <rect x="18" y="28" width="44" height="34" rx="6" fill="#F8FAFC" stroke="#0BAA4B" stroke-width="2.5"/>
  <rect x="28" y="16" width="6" height="12" rx="2" fill="#94A3B8"/>
  <rect x="46" y="16" width="6" height="12" rx="2" fill="#94A3B8"/>
  <line x1="40" y1="40" x2="40" y2="52" stroke="#0BAA4B" stroke-width="3" stroke-linecap="round"/>
  <line x1="34" y1="46" x2="46" y2="46" stroke="#0BAA4B" stroke-width="3" stroke-linecap="round"/>
</svg>
''')

SVG_CABLE = svg_to_b64('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 80 80" width="80" height="80">
  <circle cx="40" cy="40" r="24" fill="none" stroke="#0BAA4B" stroke-width="3.5" stroke-dasharray="140" stroke-dashoffset="30"/>
  <rect x="52" y="18" width="16" height="8" rx="2" transform="rotate(45 52 18)" fill="#0BAA4B"/>
  <rect x="12" y="54" width="16" height="8" rx="2" transform="rotate(-45 12 54)" fill="#0BAA4B"/>
</svg>
''')

SVG_INVOICE_BILL = svg_to_b64('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 80 80" width="80" height="80">
  <rect x="20" y="12" width="40" height="56" rx="4" fill="#FFFFFF" stroke="#0BAA4B" stroke-width="2.5"/>
  <line x1="28" y1="24" x2="52" y2="24" stroke="#0BAA4B" stroke-width="3" stroke-linecap="round"/>
  <line x1="28" y1="34" x2="52" y2="34" stroke="#94A3B8" stroke-width="2" stroke-linecap="round"/>
  <line x1="28" y1="42" x2="44" y2="42" stroke="#94A3B8" stroke-width="2" stroke-linecap="round"/>
  <rect x="28" y="52" width="24" height="8" rx="2" fill="#E8F8EE"/>
</svg>
''')

SVG_FLAWLESS = svg_to_b64('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 80 80" width="80" height="80">
  <rect x="24" y="14" width="32" height="52" rx="6" fill="#F8FAFC" stroke="#0BAA4B" stroke-width="2.5"/>
  <path d="M40 22 L42 27 L47 28 L43 32 L44 37 L40 34 L36 37 L37 32 L33 28 L38 27 Z" fill="#F59E0B"/>
  <circle cx="40" cy="58" r="2.5" fill="#0BAA4B"/>
</svg>
''')

SVG_CRACKED = svg_to_b64('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 80 80" width="80" height="80">
  <rect x="24" y="14" width="32" height="52" rx="6" fill="#FEF2F2" stroke="#EF4444" stroke-width="2.5"/>
  <path d="M28 20 L40 34 L34 42 L52 50 L42 58" fill="none" stroke="#EF4444" stroke-width="2" stroke-linecap="round"/>
</svg>
''')

def seed_categories():
    print("Configuring default categories...")
    # Mobile
    mob, _ = DeviceCategory.objects.get_or_create(name='Mobile', defaults={'slug': 'mobile', 'subtitle': 'Sell Smartphones'})
    mob.is_active = True
    mob.display_order = 1
    mob.save()

    # Tablet
    tab, _ = DeviceCategory.objects.get_or_create(name='Tablet', defaults={'slug': 'tablet', 'subtitle': 'Sell Tablets & iPads'})
    tab.is_active = True
    tab.display_order = 2
    tab.save()

    # Gaming Console
    console, _ = DeviceCategory.objects.get_or_create(name='Gaming Console', defaults={'slug': 'gaming-console', 'subtitle': 'PlayStation, Xbox & Nintendo'})
    console.is_active = True
    console.display_order = 3
    console.save()

    # Deactivate others unless admin turns them on
    for other_name in ['Laptop', 'Smartwatch', 'Dead Phone', 'Other']:
        cat = DeviceCategory.objects.filter(name=other_name).first()
        if cat:
            cat.is_active = False
            cat.save()
            print(f"Deactivated category {other_name} (can be enabled by Admin).")

def seed_conditions():
    print("Seeding Brand-Specific and Universal Condition Steps...")
    apple = Brand.objects.filter(name__iexact='Apple').first()
    samsung = Brand.objects.filter(name__iexact='Samsung').first()

    # 1. Step 1: Core 3 Diagnostic (Universal)
    c1, _ = ConditionCategory.objects.update_or_create(
        name='Core 3 Diagnostic Checks',
        brand=None,
        defaults={
            'step_number': 1,
            'subtitle': 'Primary power, call connectivity and touchscreen verification',
            'selection_type': 'MULTIPLE',
            'pro_tip': 'Make sure phone switches on and SIM is detected properly.',
            'icon_name': 'CheckSquare',
            'is_mandatory': True,
            'display_order': 1,
            'is_active': True,
        }
    )
    ConditionOption.objects.update_or_create(
        code='CORE_SWITCH_ON',
        defaults={
            'category': c1,
            'title': 'Device Switches On Normally',
            'description': 'Phone powers up to the lock screen without bootlooping.',
            'default_deduction_value': 0,
            'is_defect': False,
            'display_order': 1,
            'image_base64': SVG_FLAWLESS,
        }
    )
    ConditionOption.objects.update_or_create(
        code='CORE_CALLS_WORKING',
        defaults={
            'category': c1,
            'title': 'Calls Can Be Made & Received',
            'description': 'Cellular baseband and network antenas function without dropouts.',
            'default_deduction_value': 0,
            'is_defect': False,
            'display_order': 2,
            'image_base64': SVG_FLAWLESS,
        }
    )
    ConditionOption.objects.update_or_create(
        code='CORE_TOUCH_SMOOTH',
        defaults={
            'category': c1,
            'title': 'Touchscreen Responsive Across Edges',
            'description': 'Smooth touch response without dead zones or phantom taps.',
            'default_deduction_value': 0,
            'is_defect': False,
            'display_order': 3,
            'image_base64': SVG_FLAWLESS,
        }
    )

    # 2. Step 2: Physical Body & Display Condition (Universal)
    c2, _ = ConditionCategory.objects.update_or_create(
        name='Display & Body Condition',
        brand=None,
        defaults={
            'step_number': 2,
            'subtitle': 'Select physical glass and housing appearance',
            'selection_type': 'SINGLE',
            'pro_tip': 'Inspect the back panel and side frame under bright light.',
            'icon_name': 'Smartphone',
            'is_mandatory': True,
            'display_order': 2,
            'is_active': True,
        }
    )
    ConditionOption.objects.update_or_create(
        code='BODY_FLAWLESS',
        defaults={
            'category': c2,
            'title': 'Flawless / Like New',
            'description': 'Zero scratches, no dents, looks brand new.',
            'default_deduction_value': 0,
            'is_defect': False,
            'display_order': 1,
            'image_base64': SVG_FLAWLESS,
        }
    )
    ConditionOption.objects.update_or_create(
        code='BODY_MINOR_SCRATCHES',
        defaults={
            'category': c2,
            'title': 'Minor Scratches',
            'description': 'Light hairline marks on screen or housing from daily use.',
            'default_deduction_value': 500,
            'is_defect': True,
            'display_order': 2,
            'image_base64': SVG_FLAWLESS,
        }
    )
    ConditionOption.objects.update_or_create(
        code='BODY_DENTS_HEAVY',
        defaults={
            'category': c2,
            'title': 'Dents / Heavy Usage',
            'description': 'Visible frame dent, chipped corners or deep scuffs.',
            'default_deduction_value': 1200,
            'is_defect': True,
            'display_order': 3,
            'image_base64': SVG_CRACKED,
        }
    )
    ConditionOption.objects.update_or_create(
        code='BODY_CRACKED_GLASS',
        defaults={
            'category': c2,
            'title': 'Cracked / Shattered Glass',
            'description': 'Broken front glass or cracked back panel.',
            'default_deduction_value': 2500,
            'is_defect': True,
            'display_order': 4,
            'image_base64': SVG_CRACKED,
        }
    )

    # 3. Step 3: Apple Exclusive Diagnostics (Brand = Apple)
    if apple:
        c_apple_battery, _ = ConditionCategory.objects.update_or_create(
            name='Battery Health (Apple iOS)',
            brand=apple,
            defaults={
                'step_number': 3,
                'subtitle': 'Check Settings > Battery > Battery Health & Charging',
                'selection_type': 'SINGLE',
                'pro_tip': 'Original battery health percentage determines deduction.',
                'icon_name': 'BatteryCharging',
                'is_mandatory': True,
                'display_order': 1,
                'is_active': True,
            }
        )
        ConditionOption.objects.update_or_create(
            code='APPLE_BATT_85_ABOVE',
            defaults={
                'category': c_apple_battery,
                'title': 'Battery Health 85% Above',
                'description': 'Peak performance capability, maximum battery endurance.',
                'default_deduction_value': 0,
                'is_defect': False,
                'display_order': 1,
                'image_base64': SVG_BATTERY_GREEN,
            }
        )
        ConditionOption.objects.update_or_create(
            code='APPLE_BATT_81_85',
            defaults={
                'category': c_apple_battery,
                'title': 'Battery Health 81% to 85%',
                'description': 'Normal battery degradation over 1-2 years of usage.',
                'default_deduction_value': 600,
                'is_defect': True,
                'display_order': 2,
                'image_base64': SVG_BATTERY_YELLOW,
            }
        )
        ConditionOption.objects.update_or_create(
            code='APPLE_BATT_80_BELOW',
            defaults={
                'category': c_apple_battery,
                'title': 'Battery Health 80% or Below',
                'description': 'Service recommended alert; replacement required.',
                'default_deduction_value': 1500,
                'is_defect': True,
                'display_order': 3,
                'image_base64': SVG_BATTERY_RED,
            }
        )

        c_apple_icloud, _ = ConditionCategory.objects.update_or_create(
            name='iCloud & Security Lock (Apple iOS)',
            brand=apple,
            defaults={
                'step_number': 4,
                'subtitle': 'Find My iPhone & Apple ID Activation status',
                'selection_type': 'SINGLE',
                'pro_tip': 'All devices must be signed out before handing over to agent.',
                'icon_name': 'Shield',
                'is_mandatory': True,
                'display_order': 2,
                'is_active': True,
            }
        )
        ConditionOption.objects.update_or_create(
            code='APPLE_ICLOUD_UNLOCKED',
            defaults={
                'category': c_apple_icloud,
                'title': 'iCloud Unlocked & Ready for Sign-Out',
                'description': 'You know the password and can sign out upon doorstep pickup.',
                'default_deduction_value': 0,
                'is_defect': False,
                'display_order': 1,
                'image_base64': SVG_ICLOUD_LOCK,
            }
        )
        ConditionOption.objects.update_or_create(
            code='APPLE_ICLOUD_LOCKED',
            defaults={
                'category': c_apple_icloud,
                'title': 'iCloud Locked / Password Forgotten',
                'description': 'Device cannot be unlocked or signed out.',
                'default_deduction_value': 0,
                'is_defect': True,
                'is_rejection': True,
                'display_order': 2,
                'image_base64': SVG_ICLOUD_LOCK,
            }
        )

    # 4. Step: Accessories, Warranty & Invoice Bill (Universal)
    c_acc, _ = ConditionCategory.objects.update_or_create(
        name='Accessories, Warranty & Age',
        brand=None,
        defaults={
            'step_number': 5,
            'subtitle': 'Select original accessories and purchase bill you have',
            'selection_type': 'MULTIPLE',
            'pro_tip': 'Without a valid GST invoice bill, warranty is treated as expired.',
            'icon_name': 'Package',
            'is_mandatory': False,
            'display_order': 5,
            'is_active': True,
        }
    )
    ConditionOption.objects.update_or_create(
        code='ACC_PHONE_BOX',
        defaults={
            'category': c_acc,
            'title': 'Phone Box',
            'description': 'Original box with matching IMEI barcode.',
            'default_deduction_value': 0,
            'is_defect': False,
            'is_accessory_bonus': True,
            'display_order': 1,
            'image_base64': SVG_PHONE_BOX,
        }
    )
    ConditionOption.objects.update_or_create(
        code='ACC_ORIGINAL_CHARGER',
        defaults={
            'category': c_acc,
            'title': 'Original Fast Charger',
            'description': 'Original brand wall adapter working properly.',
            'default_deduction_value': 0,
            'is_defect': False,
            'is_accessory_bonus': True,
            'display_order': 2,
            'image_base64': SVG_CHARGER,
        }
    )
    ConditionOption.objects.update_or_create(
        code='ACC_CHARGER_CABLE',
        defaults={
            'category': c_acc,
            'title': 'Charger Cable',
            'description': 'USB-C or Lightning cable in good working condition.',
            'default_deduction_value': 0,
            'is_defect': False,
            'is_accessory_bonus': True,
            'display_order': 3,
            'image_base64': SVG_CABLE,
        }
    )
    ConditionOption.objects.update_or_create(
        code='ACC_INVOICE_BILL',
        defaults={
            'category': c_acc,
            'title': 'Invoice Bill',
            'description': 'Valid original invoice bill with matching IMEI.',
            'default_deduction_value': 0,
            'is_defect': False,
            'is_warranty': True,
            'display_order': 4,
            'image_base64': SVG_INVOICE_BILL,
        }
    )

    print("Brand-specific & visual questionnaire seeded successfully!")

if __name__ == '__main__':
    seed_categories()
    seed_conditions()
