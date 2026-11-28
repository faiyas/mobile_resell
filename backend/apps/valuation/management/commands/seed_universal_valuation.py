from decimal import Decimal
from django.core.management.base import BaseCommand
from django.db import transaction
from apps.valuation.models import (
    EvaluationTriageQuestion,
    ConditionCategory,
    ConditionOption,
)


class Command(BaseCommand):
    help = 'Clears old triage/questionnaire steps and seeds the universal market-researched valuation flow.'

    @transaction.atomic
    def handle(self, *args, **options):
        self.stdout.write('Clearing old triage questions and condition categories/options...')
        EvaluationTriageQuestion.objects.all().delete()
        ConditionOption.objects.all().delete()
        ConditionCategory.objects.all().delete()

        # 1. Cascading Triage Questions (Universal)
        triage_data = [
            {
                'code': 'WORKING_CONDITION',
                'question_text': 'Does your phone switch on and boot normally?',
                'subtitle': 'Check if the phone powers on and boots to the home screen without issues',
                'is_power_on_gate': False,
                'deduction_type': 'PERCENTAGE',
                'deduction_value_on_no': Decimal('60.00'),
                'disables_question_codes': ['TOUCH_WORKING', 'DISPLAY_ORIGINAL', 'VALID_WARRANTY'],
                'display_order': 1,
            },
            {
                'code': 'TOUCH_WORKING',
                'question_text': 'Is the touchscreen on your phone working properly?',
                'subtitle': 'Check the touch screen functionality across all areas of the display',
                'is_power_on_gate': False,
                'deduction_type': 'PERCENTAGE',
                'deduction_value_on_no': Decimal('35.00'),
                'disables_question_codes': ['DISPLAY_ORIGINAL', 'VALID_WARRANTY'],
                'display_order': 2,
            },
            {
                'code': 'DISPLAY_ORIGINAL',
                'question_text': "Is the phone's display original?",
                'subtitle': 'Select "Yes" if never changed or changed at an Authorized Service Center. Select "No" if changed locally.',
                'is_power_on_gate': False,
                'deduction_type': 'PERCENTAGE',
                'deduction_value_on_no': Decimal('20.00'),
                'disables_question_codes': ['VALID_WARRANTY'],
                'display_order': 3,
            },
            {
                'code': 'VALID_WARRANTY',
                'question_text': 'Is there a valid warranty for your phone?',
                'subtitle': "You'll get a better price if your device has a valid manufacturer warranty",
                'is_power_on_gate': False,
                'deduction_type': 'PERCENTAGE',
                'deduction_value_on_no': Decimal('3.00'),
                'disables_question_codes': [],
                'display_order': 4,
            },
        ]
        for tq in triage_data:
            EvaluationTriageQuestion.objects.create(**tq, is_active=True)

        # 2. Universal Questionnaire Steps (brand=None, device_category=None)
        steps = [
            {
                'step_number': 1,
                'name': 'Screen Condition',
                'subtitle': 'Check for dead pixels, discoloration, or spots on the display',
                'selection_type': 'SINGLE',
                'is_mandatory': True,
                'icon_name': 'Smartphone',
                'options': [
                    ('SCREEN_NO_SPOT', 'No Spot', Decimal('0.00'), False, False, 'display_assembly'),
                    ('SCREEN_MINOR_SPOT', 'Minor Spot', Decimal('10.00'), True, False, 'display_assembly'),
                    ('SCREEN_MAJOR_SPOT', 'Major Spot', Decimal('25.00'), True, False, 'display_assembly'),
                ],
            },
            {
                'step_number': 2,
                'name': 'Touch Glass Condition',
                'subtitle': 'Inspect the front glass for scratches or cracks under bright light',
                'selection_type': 'SINGLE',
                'is_mandatory': True,
                'icon_name': 'ShieldAlert',
                'options': [
                    ('GLASS_NO_SCRATCH', 'No scratch or crack', Decimal('0.00'), False, False, 'display_assembly'),
                    ('GLASS_MINOR_SCRATCH', 'Minor Scratches or less than 2 scratches', Decimal('3.00'), True, False, 'display_assembly'),
                    ('GLASS_HEAVY_SCRATCH', 'Heavy Scratches', Decimal('8.00'), True, False, 'display_assembly'),
                    ('GLASS_CRACKED', 'Screen Cracked or Glass Broken', Decimal('30.00'), True, False, 'display_assembly'),
                ],
            },
            {
                'step_number': 3,
                'name': 'Back Panel Condition',
                'subtitle': 'Inspect the rear glass or back cover for scratches or cracks',
                'selection_type': 'SINGLE',
                'is_mandatory': True,
                'icon_name': 'Layers',
                'options': [
                    ('BACK_NO_DEFECT', 'No defects on back panel', Decimal('0.00'), False, False, 'back_panel'),
                    ('BACK_MINOR_SCRATCH', 'Minor Scratches or less than 2 scratches', Decimal('2.00'), True, False, 'back_panel'),
                    ('BACK_HEAVY_SCRATCH', 'Heavy Scratches', Decimal('5.00'), True, False, 'back_panel'),
                    ('BACK_BROKEN', 'Back Panel broken', Decimal('12.00'), True, False, 'back_panel'),
                ],
            },
            {
                'step_number': 4,
                'name': 'Center or Side Panel Condition',
                'subtitle': 'Inspect the side frame, corners, and physical frame alignment',
                'selection_type': 'SINGLE',
                'is_mandatory': True,
                'icon_name': 'Maximize2',
                'options': [
                    ('FRAME_NO_DEFECT', 'No defects on center panel', Decimal('0.00'), False, False, 'frame_panel'),
                    ('FRAME_MINOR_DENT', 'Minor dent or scratches', Decimal('3.00'), True, False, 'frame_panel'),
                    ('FRAME_MAJOR_DENT', 'Major dent or heavy scratches', Decimal('7.00'), True, False, 'frame_panel'),
                    ('FRAME_CRACKED_BENT', 'Center panel cracked or buttons missing or bent panel', Decimal('18.00'), True, False, 'frame_panel'),
                ],
            },
            {
                'step_number': 5,
                'name': 'Select all issues identified in your Phone',
                'subtitle': 'Select any hardware or functional defects (leave unselected if none)',
                'selection_type': 'MULTIPLE',
                'is_mandatory': False,
                'icon_name': 'Wrench',
                'options': [
                    ('FUNC_BATTERY_LOW', 'Battery Health is 83% & below 83%', Decimal('10.00'), True, False, ''),
                    ('FUNC_FRONT_CAM', 'Front Camera not working', Decimal('7.00'), True, False, ''),
                    ('FUNC_BACK_CAM', 'Back Camera not working', Decimal('12.00'), True, False, ''),
                    ('FUNC_CAM_GLASS', 'Camera Glass Broken', Decimal('4.00'), True, False, ''),
                    ('FUNC_NETWORK', 'Network problem', Decimal('25.00'), True, False, 'network_board'),
                    ('FUNC_SPEAKER', 'Speaker not working', Decimal('5.00'), True, False, ''),
                    ('FUNC_MIC', 'Mic not working', Decimal('5.00'), True, False, ''),
                    ('FUNC_BIOMETRIC', 'Touch Id or Face Id not working', Decimal('20.00'), True, False, ''),
                    ('FUNC_VOLUME_BTN', 'Volume Button not working', Decimal('3.00'), True, False, ''),
                    ('FUNC_WIFI_BT', 'WiFi or Bluetooth not working', Decimal('15.00'), True, False, 'network_board'),
                    ('FUNC_CHARGING', 'Charging Port not working', Decimal('8.00'), True, False, ''),
                    ('FUNC_PROXIMITY', 'Proximity Sensor not working', Decimal('3.00'), True, False, ''),
                    ('FUNC_POWER_BTN', 'Power button not working', Decimal('5.00'), True, False, ''),
                    ('FUNC_EAR_SPEAKER', 'Ear Speaker not working or low', Decimal('4.00'), True, False, ''),
                    ('FUNC_VIBRATOR', 'Vibrator not working', Decimal('3.00'), True, False, ''),
                ],
            },
            {
                'step_number': 6,
                'name': 'Select all accessories details',
                'subtitle': 'Select original accessories available (or skip if none)',
                'selection_type': 'MULTIPLE',
                'is_mandatory': False,
                'icon_name': 'PackageCheck',
                'options': [
                    ('ACC_CHARGER', 'Original Charger of Device', Decimal('1.50'), False, True, ''),
                    ('ACC_BOX', 'Box with same IMEI', Decimal('0.50'), False, True, ''),
                    ('ACC_BILL', 'Bill with same IMEI', Decimal('1.00'), False, True, ''),
                ],
            },
        ]

        for step in steps:
            cat = ConditionCategory.objects.create(
                device_category=None,
                brand=None,
                step_number=step['step_number'],
                name=step['name'],
                subtitle=step['subtitle'],
                selection_type=step['selection_type'],
                is_mandatory=step['is_mandatory'],
                icon_name=step['icon_name'],
                display_order=step['step_number'],
                is_active=True,
            )
            for idx, (code, title, pct, is_def, is_acc, grp) in enumerate(step['options'], start=1):
                ConditionOption.objects.create(
                    category=cat,
                    code=code,
                    title=title,
                    is_defect=is_def,
                    is_accessory_bonus=is_acc,
                    deduction_type='PERCENTAGE',
                    default_deduction_value=pct,
                    exclusive_group=grp,
                    display_order=idx,
                    is_active=True,
                )

        self.stdout.write(self.style.SUCCESS(
            f'Seeded {len(triage_data)} triage questions and {len(steps)} universal condition steps.'
        ))
