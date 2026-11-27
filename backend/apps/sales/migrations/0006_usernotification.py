import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('sales', '0005_phonesale_cash_handover_otp_and_more'),
    ]

    operations = [
        migrations.CreateModel(
            name='UserNotification',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('target_audience', models.CharField(choices=[('ALL', 'All Users'), ('CUSTOMERS', 'Customers Only'), ('AGENTS', 'Field Agents Only'), ('ORDER', 'Specific Order/User')], default='ORDER', max_length=20)),
                ('title', models.CharField(max_length=200)),
                ('message', models.TextField()),
                ('category', models.CharField(choices=[('ORDERS', 'Order Milestones'), ('PAYOUTS', 'Payouts & Cash Handover'), ('SYSTEM', 'System & Announcements')], default='ORDERS', max_length=20)),
                ('redirect_route', models.CharField(blank=True, default='', max_length=255)),
                ('action_type', models.CharField(blank=True, default='', max_length=50)),
                ('is_read', models.BooleanField(default=False)),
                ('is_dismissed', models.BooleanField(default=False)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('recipient', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='notifications', to=settings.AUTH_USER_MODEL)),
                ('related_order', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='notifications', to='sales.phonesale')),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
        migrations.AddIndex(
            model_name='usernotification',
            index=models.Index(fields=['recipient', 'is_read', '-created_at'], name='sales_usern_recipie_f29910_idx'),
        ),
        migrations.AddIndex(
            model_name='usernotification',
            index=models.Index(fields=['target_audience', '-created_at'], name='sales_usern_target__722d42_idx'),
        ),
    ]
