import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from apps.valuation.models import EvaluationTriageQuestion

QUESTIONS = [
    {
        'code': 'WORKING_CONDITION',
        'question_text': 'Is the phone in proper working condition?',
        'subtitle': 'Check if the phone powers on and confirm that it is in working condition',
        'is_power_on_gate': True,
        'deduction_type': 'PERCENTAGE',
        'deduction_value_on_no': 70.00,
        'display_order': 1,
        'is_active': True,
    },
    {
        'code': 'TOUCH_WORKING',
        'question_text': 'Is the touchscreen on your phone working properly?',
        'subtitle': 'Check the touch screen functionality of your phone',
        'is_power_on_gate': False,
        'deduction_type': 'PERCENTAGE',
        'deduction_value_on_no': 20.00,
        'display_order': 2,
        'is_active': True,
    },
    {
        'code': 'DISPLAY_ORIGINAL',
        'question_text': "Is the phone's display original?",
        'subtitle': 'Select "Yes" if the screen was never changed or was changed by the Authorized Service Center. Select "No" if the screen was changed at a local shop or UnAuthorized Service Center',
        'is_power_on_gate': False,
        'deduction_type': 'PERCENTAGE',
        'deduction_value_on_no': 15.00,
        'display_order': 3,
        'is_active': True,
    },
    {
        'code': 'VALID_WARRANTY',
        'question_text': 'Is there a valid warranty for your phone?',
        'subtitle': "You'll get a better price if your device has a manufacturer warranty",
        'is_power_on_gate': False,
        'deduction_type': 'PERCENTAGE',
        'deduction_value_on_no': 5.00,
        'display_order': 4,
        'is_active': True,
    },
]

for q in QUESTIONS:
    code = q.pop('code')
    obj, created = EvaluationTriageQuestion.objects.update_or_create(code=code, defaults=q)
    action = "Created" if created else "Updated"
    print(f"[{action}] {obj}")

print(f"\nTotal Triage Questions: {EvaluationTriageQuestion.objects.count()}")
