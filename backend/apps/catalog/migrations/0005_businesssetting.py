from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('catalog', '0004_alter_cmshomesection_section_type'),
    ]

    operations = [
        migrations.CreateModel(
            name='BusinessSetting',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('company_name', models.CharField(default='Dolly Buyback Services Pvt Ltd', max_length=150)),
                ('business_logo', models.TextField(blank=True, default='', help_text='Base64 encoded logo')),
                ('customer_helpline', models.CharField(default='+91 99885 52211', max_length=30)),
                ('agent_helpline', models.CharField(default='+91 99885 52211', max_length=30)),
                ('whatsapp_number', models.CharField(default='+91 99885 52211', max_length=30)),
                ('support_email', models.EmailField(default='support@dollyresell.com', max_length=254)),
                ('office_address', models.TextField(default='1103 TechStudios, MG Road, Whitefield, Bangalore, Karnataka 560066')),
                ('google_maps_url', models.URLField(blank=True, default='')),
                ('working_hours', models.CharField(default='Mon-Sat: 9:00 AM - 8:00 PM IST', max_length=100)),
                ('instagram_url', models.URLField(blank=True, default='')),
                ('facebook_url', models.URLField(blank=True, default='')),
                ('youtube_url', models.URLField(blank=True, default='')),
                ('terms_and_conditions', models.TextField(blank=True, default='')),
                ('privacy_policy_text', models.TextField(blank=True, default='')),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={
                'verbose_name': 'Business Setting',
                'verbose_name_plural': 'Business Settings',
            },
        ),
    ]
