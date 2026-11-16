from django.db import models
from django.conf import settings
from apps.catalog.models import PhoneModel, StorageVariant

class ConditionCategory(models.Model):
    name = models.CharField(max_length=100) # e.g. Display & Screen, Battery Health, Camera & FaceID, Body Condition
    description = models.CharField(max_length=255, blank=True, default='')
    icon_name = models.CharField(max_length=50, default='Smartphone', help_text="Lucide icon name")
    display_order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['display_order']

    def __str__(self):
        return self.name

class ConditionOption(models.Model):
    DEDUCTION_TYPE_CHOICES = (
        ('FLAT', 'Flat Amount (₹)'),
        ('PERCENTAGE', 'Percentage of Base (%)'),
    )

    category = models.ForeignKey(ConditionCategory, on_delete=models.CASCADE, related_name='options')
    code = models.CharField(max_length=50, unique=True, help_text="e.g. SCREEN_CRACKED, BATTERY_SERVICE")
    title = models.CharField(max_length=150) # e.g. "Screen is broken or cracked"
    description = models.CharField(max_length=255, blank=True, default='')
    is_defect = models.BooleanField(default=True, help_text="True if this condition deducts money")
    
    deduction_type = models.CharField(max_length=20, choices=DEDUCTION_TYPE_CHOICES, default='FLAT')
    default_deduction_value = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)

    # Smart Valuation Controls
    exclusive_group = models.CharField(
        max_length=50, blank=True, default='', 
        help_text="Mutually exclusive group (e.g. 'screen_glass'). Options in the same group take highest deduction instead of double-penalizing."
    )
    is_rejection = models.BooleanField(
        default=False, 
        help_text="If True, selecting this flags safety rejection or zero payout (e.g. swollen battery, activation lock)"
    )
    
    display_order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ['display_order']

    def __str__(self):
        return f"[{self.category.name}] {self.title} ({self.deduction_type} {self.default_deduction_value})"

class ModelPricingOverride(models.Model):
    """Allows admin to override condition deductions specifically for high-end or specific phone models"""
    phone_model = models.ForeignKey(PhoneModel, on_delete=models.CASCADE, related_name='pricing_overrides')
    option = models.ForeignKey(ConditionOption, on_delete=models.CASCADE, related_name='model_overrides')
    override_deduction_value = models.DecimalField(max_digits=10, decimal_places=2)

    class Meta:
        unique_together = ('phone_model', 'option')

    def __str__(self):
        return f"{self.phone_model} - {self.option.code}: ₹{self.override_deduction_value}"

class PriceHistory(models.Model):
    """Audit log of historical price changes for variant base prices"""
    variant = models.ForeignKey(StorageVariant, on_delete=models.CASCADE, related_name='price_history')
    old_base_price = models.DecimalField(max_digits=10, decimal_places=2)
    new_base_price = models.DecimalField(max_digits=10, decimal_places=2)
    changed_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True)
    reason = models.CharField(max_length=255, default='Market price adjustment')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.variant}: ₹{self.old_base_price} ➔ ₹{self.new_base_price} on {self.created_at.strftime('%Y-%m-%d')}"

