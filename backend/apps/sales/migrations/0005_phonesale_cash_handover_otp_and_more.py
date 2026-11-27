# Generated manually for cash_handover_otp and CASH beneficiary_type choice
from django.db import migrations, models

class Migration(migrations.Migration):

    dependencies = [
        ('sales', '0004_alter_phonesale_variant_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='phonesale',
            name='cash_handover_otp',
            field=models.CharField(blank=True, default='', help_text='In-app 4-digit verification OTP for cash handover', max_length=6),
        ),
        migrations.AlterField(
            model_name='phonesale',
            name='beneficiary_type',
            field=models.CharField(choices=[('UPI', 'UPI ID (Google Pay, PhonePe, Paytm)'), ('BANK', 'Direct Bank Transfer (IMPS/NEFT)'), ('CASH', 'Cash on Pickup')], default='UPI', max_length=10),
        ),
    ]
