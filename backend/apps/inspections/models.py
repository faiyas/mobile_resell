from django.db import models
from django.conf import settings
from apps.sales.models import PhoneSale

class DeviceInspection(models.Model):
    BODY_GRADES = (
        ('FLAWLESS', 'Flawless (Like New)'),
        ('GOOD', 'Good (Minor micro-scratches)'),
        ('FAIR', 'Fair (Visible scratches or small dent)'),
        ('HEAVY_WEAR', 'Heavy Wear (Cracked glass or severe dent)'),
    )

    sale = models.OneToOneField(PhoneSale, on_delete=models.CASCADE, related_name='inspection')
    inspected_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='inspections_performed')
    
    # Core verification checks
    switches_on = models.BooleanField(default=True)
    screen_working = models.BooleanField(default=True)
    screen_glass_broken = models.BooleanField(default=False)
    touch_working = models.BooleanField(default=True)
    camera_working = models.BooleanField(default=True)
    battery_healthy = models.BooleanField(default=True)
    body_condition = models.CharField(max_length=20, choices=BODY_GRADES, default='GOOD')
    
    # Mandatory Security & Ownership checks
    cloud_locks_removed = models.BooleanField(default=True, help_text="iCloud / Google FRP account removed")
    imei_verified = models.BooleanField(default=True)
    verified_imei = models.CharField(max_length=30)
    customer_id_verified = models.BooleanField(default=True)

    suggested_final_price = models.DecimalField(max_digits=10, decimal_places=2)
    inspector_notes = models.TextField(blank=True, default='')

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Inspection for {self.sale.sale_code} - Suggested: ₹{self.suggested_final_price}"

class InspectionPhoto(models.Model):
    inspection = models.ForeignKey(DeviceInspection, on_delete=models.CASCADE, related_name='photos')
    label = models.CharField(max_length=100, default='Device Photo')
    image_base64 = models.TextField(help_text="Base64 encoded inspection photo")
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Photo ({self.label}) for {self.inspection.sale.sale_code}"
