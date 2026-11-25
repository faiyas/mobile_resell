import os
import sys
from decimal import Decimal
import django

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.db import transaction
from apps.catalog.models import DeviceCategory
from apps.valuation.models import ConditionCategory, ConditionOption


UNIVERSAL_STEPS = [
    {
        'step_number': 1,
        'name': 'Core 3 Diagnostic Checks',
        'subtitle': 'Confirm basic power, calling, and touchscreen functionality.',
        'selection_type': 'MULTIPLE',
        'icon_name': 'CheckCircle',
        'is_mandatory': True,
        'pro_tip': 'Select all checks that pass normally on your device.',
        'options': [
            {'code': 'CORE_SWITCH_ON', 'title': 'Device Switches On Normally', 'description': 'Powers on without staying stuck on boot logo', 'deduction_type': 'FLAT', 'val': '0', 'is_defect': False},
            {'code': 'CORE_CALLS_WORKING', 'title': 'Calls Can Be Made & Received', 'description': 'SIM network, mic, and earpiece work on calls', 'deduction_type': 'FLAT', 'val': '0', 'is_defect': False},
            {'code': 'CORE_TOUCH_SMOOTH', 'title': 'Touchscreen Responsive Across Edges', 'description': 'Smooth touch response across the entire screen', 'deduction_type': 'FLAT', 'val': '0', 'is_defect': False},
        ],
    },
    {
        'step_number': 2,
        'name': 'Display & Screen Glass Condition',
        'subtitle': 'Select the overall physical condition of your screen glass.',
        'selection_type': 'SINGLE',
        'icon_name': 'Smartphone',
        'is_mandatory': True,
        'pro_tip': 'Check under bright light for hairline scratches or micro-cracks.',
        'options': [
            {'code': 'DISP_NO_DEFECT', 'title': 'Flawless Screen / No Scratches', 'description': 'Original screen with zero scratches or cracks', 'deduction_type': 'FLAT', 'val': '0', 'is_defect': False},
            {'code': 'DISP_SCRATCHES', 'title': 'Minor Hairline Scratches', 'description': 'Light surface wear visible only under reflection', 'deduction_type': 'FLAT', 'val': '500', 'is_defect': True, 'exclusive_group': 'screen_glass'},
            {'code': 'DISP_BROKEN', 'title': 'Screen Glass Cracked / Broken', 'description': 'Visible cracks or chipped glass on display', 'deduction_type': 'FLAT', 'val': '2500', 'is_defect': True, 'exclusive_group': 'screen_glass'},
            {'code': 'DISPLAY_REPLACED', 'title': 'Replaced / Duplicate Display', 'description': 'Aftermarket or non-original replacement screen', 'deduction_type': 'FLAT', 'val': '1500', 'is_defect': True, 'exclusive_group': 'screen_glass'},
        ],
    },
    {
        'step_number': 3,
        'name': 'Display Defects & Spots',
        'subtitle': 'Select any display panel issues (skip if display is clean).',
        'selection_type': 'MULTIPLE',
        'icon_name': 'Monitor',
        'is_mandatory': False,
        'pro_tip': 'Check on a plain white background for dead spots, burn-in, or green/pink lines.',
        'options': [
            {'code': 'DEAD_SPOTS', 'title': 'Dead Pixels / Black Ink Spots', 'description': 'Black dots, ink bleeding, or bright pressure spots', 'deduction_type': 'FLAT', 'val': '1500', 'is_defect': True},
            {'code': 'GREEN_LINES', 'title': 'Display Lines / Discoloration', 'description': 'Vertical/horizontal lines, tint, or OLED burn-in', 'deduction_type': 'PERCENTAGE', 'val': '15', 'is_defect': True},
            {'code': 'TOUCH_ISSUE', 'title': 'Touch Erratic / Dead Zones', 'description': 'Ghost touch or unresponsive screen regions', 'deduction_type': 'FLAT', 'val': '2000', 'is_defect': True},
        ],
    },
    {
        'step_number': 4,
        'name': 'Body & Back Panel Condition',
        'subtitle': 'Select the physical condition of the frame and back glass.',
        'selection_type': 'SINGLE',
        'icon_name': 'Shield',
        'is_mandatory': True,
        'pro_tip': 'Remove any phone case before inspecting corners and back panel.',
        'options': [
            {'code': 'BODY_FLAWLESS', 'title': 'Flawless / Like New Body', 'description': 'No dents, scuffs, or back glass cracks', 'deduction_type': 'FLAT', 'val': '0', 'is_defect': False},
            {'code': 'BODY_MINOR_SCRATCHES', 'title': 'Minor Scratches / Case Marks', 'description': 'Light wear on frame or back panel', 'deduction_type': 'FLAT', 'val': '500', 'is_defect': True, 'exclusive_group': 'body_damage'},
            {'code': 'BODY_DENT', 'title': 'Dents or Chipped Corners', 'description': 'Visible impact marks or paint peeling on frame', 'deduction_type': 'FLAT', 'val': '1200', 'is_defect': True, 'exclusive_group': 'body_damage'},
            {'code': 'BACK_GLASS_BROKEN', 'title': 'Back Glass Cracked / Broken', 'description': 'Cracked or shattered rear glass panel', 'deduction_type': 'FLAT', 'val': '2000', 'is_defect': True, 'exclusive_group': 'body_damage'},
            {'code': 'BODY_BENT', 'title': 'Frame Bent / Loose Panel', 'description': 'Chassis bent or back panel lifting', 'deduction_type': 'FLAT', 'val': '2500', 'is_defect': True, 'exclusive_group': 'body_damage'},
        ],
    },
    {
        'step_number': 5,
        'name': 'Camera & Biometrics',
        'subtitle': 'Select any issues with cameras, Face ID, or fingerprint sensor.',
        'selection_type': 'MULTIPLE',
        'icon_name': 'Camera',
        'is_mandatory': False,
        'pro_tip': 'Test 1x, ultrawide, and selfie camera focus before submitting.',
        'options': [
            {'code': 'FRONT_CAM_FAULT', 'title': 'Front Camera Blurry or Faulty', 'description': 'Selfie camera fails to open or focus', 'deduction_type': 'FLAT', 'val': '1500', 'is_defect': True},
            {'code': 'BACK_CAM_FAULT', 'title': 'Rear Camera Blurry / OIS Issue', 'description': 'Main camera shakes, blurs, or shows black screen', 'deduction_type': 'FLAT', 'val': '2000', 'is_defect': True},
            {'code': 'CAM_GLASS_BROKEN', 'title': 'Camera Lens Glass Cracked', 'description': 'Scratch or crack over rear camera lens glass', 'deduction_type': 'FLAT', 'val': '800', 'is_defect': True},
            {'code': 'BIOMETRIC_FAIL', 'title': 'Face ID / Fingerprint Not Working', 'description': 'Biometric unlock fails or hardware disabled', 'deduction_type': 'FLAT', 'val': '1500', 'is_defect': True},
        ],
    },
    {
        'step_number': 6,
        'name': 'Hardware & Functional Faults',
        'subtitle': 'Report any audio, wireless, SIM, battery, or lock issues.',
        'selection_type': 'MULTIPLE',
        'icon_name': 'Wrench',
        'is_mandatory': False,
        'pro_tip': 'Ensure iCloud / Google account locks are signed out before pickup.',
        'options': [
            {'code': 'SPEAKER_MIC_FAIL', 'title': 'Speaker / Earpiece / Mic Issue', 'description': 'Distorted audio, low earpiece, or mic failure', 'deduction_type': 'FLAT', 'val': '800', 'is_defect': True},
            {'code': 'WIFI_BT_FAIL', 'title': 'Wi-Fi / Bluetooth / GPS Issue', 'description': 'Toggle greyed out or frequent disconnects', 'deduction_type': 'FLAT', 'val': '1200', 'is_defect': True},
            {'code': 'SIM_NETWORK_FAIL', 'title': 'SIM Not Detecting / No Service', 'description': 'Unable to read SIM card or hold mobile signal', 'deduction_type': 'FLAT', 'val': '1200', 'is_defect': True},
            {'code': 'BATTERY_LOW', 'title': 'Battery Health Below 80% / Drains Fast', 'description': 'Weak battery backup or Service Recommended alert', 'deduction_type': 'PERCENTAGE', 'val': '10', 'is_defect': True},
            {'code': 'BATTERY_SWOLLEN', 'title': 'Swollen Battery (Safety Risk)', 'description': 'Battery bulging or lifting the display', 'deduction_type': 'FLAT', 'val': '0', 'is_defect': True, 'is_rejection': True},
            {'code': 'ACCOUNT_LOCKED', 'title': 'iCloud / Google FRP Account Locked', 'description': 'Activation lock active with forgotten password', 'deduction_type': 'FLAT', 'val': '0', 'is_defect': True, 'is_rejection': True},
        ],
    },
    {
        'step_number': 7,
        'name': 'Original Accessories & Invoice',
        'subtitle': 'Select any original items you will hand over with the phone.',
        'selection_type': 'ACCESSORY',
        'icon_name': 'Package',
        'is_mandatory': False,
        'pro_tip': 'Having original box, charger, and valid invoice helps maximize your payout.',
        'options': [
            {'code': 'ACC_BOX', 'title': 'Original Phone Box', 'description': 'Matching IMEI retail box', 'deduction_type': 'FLAT', 'val': '0', 'is_defect': False, 'is_accessory_bonus': True},
            {'code': 'ACC_CHARGER', 'title': 'Original Charger & Cable', 'description': 'Original manufacturer adapter & USB cable', 'deduction_type': 'FLAT', 'val': '0', 'is_defect': False, 'is_accessory_bonus': True},
            {'code': 'ACC_BILL', 'title': 'Valid Purchase Invoice / Bill', 'description': 'GST bill with matching IMEI for warranty check', 'deduction_type': 'FLAT', 'val': '0', 'is_defect': False, 'is_warranty': True},
        ],
    },
]


def seed_universal_questions():
    print("Seeding clean Universal Mobile Questionnaire (7 Steps)...")
    with transaction.atomic():
        mobile_cat = DeviceCategory.objects.filter(slug='mobile').first()
        steps_created = 0
        opts_created = 0
        opts_updated = 0

        for idx, step_data in enumerate(UNIVERSAL_STEPS):
            cat_obj = ConditionCategory.objects.filter(
                brand__isnull=True,
                name__iexact=step_data['name']
            ).first()

            if not cat_obj:
                cat_obj = ConditionCategory.objects.create(
                    device_category=mobile_cat,
                    brand=None,
                    step_number=step_data['step_number'],
                    name=step_data['name'],
                    subtitle=step_data['subtitle'],
                    selection_type=step_data['selection_type'],
                    pro_tip=step_data['pro_tip'],
                    icon_name=step_data['icon_name'],
                    is_mandatory=step_data['is_mandatory'],
                    display_order=idx + 1,
                    is_active=True,
                )
                steps_created += 1
            else:
                cat_obj.device_category = mobile_cat
                cat_obj.step_number = step_data['step_number']
                cat_obj.subtitle = step_data['subtitle']
                cat_obj.selection_type = step_data['selection_type']
                cat_obj.pro_tip = step_data['pro_tip']
                cat_obj.icon_name = step_data['icon_name']
                cat_obj.is_mandatory = step_data['is_mandatory']
                cat_obj.display_order = idx + 1
                cat_obj.is_active = True
                cat_obj.save()

            for o_idx, opt in enumerate(step_data['options']):
                opt_obj, created = ConditionOption.objects.update_or_create(
                    code=opt['code'],
                    defaults={
                        'category': cat_obj,
                        'title': opt['title'],
                        'description': opt.get('description', ''),
                        'deduction_type': opt.get('deduction_type', 'FLAT'),
                        'default_deduction_value': Decimal(opt.get('val', '0')),
                        'is_defect': opt.get('is_defect', True),
                        'is_accessory_bonus': opt.get('is_accessory_bonus', False),
                        'is_warranty': opt.get('is_warranty', False),
                        'is_rejection': opt.get('is_rejection', False),
                        'exclusive_group': opt.get('exclusive_group', ''),
                        'display_order': o_idx + 1,
                        'is_active': True,
                    }
                )
                if created:
                    opts_created += 1
                else:
                    opts_updated += 1

    print(f"Completed! Steps created: {steps_created}/{len(UNIVERSAL_STEPS)} | Options: {opts_created} created, {opts_updated} updated.")


if __name__ == '__main__':
    seed_universal_questions()
