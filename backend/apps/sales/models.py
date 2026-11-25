import uuid
from decimal import Decimal
from django.db import models
from django.conf import settings
from apps.catalog.models import StorageVariant
from apps.valuation.models import ConditionOption

class PhoneSale(models.Model):
    STATUS_CHOICES = (
        ('DRAFT', 'Draft'),
        ('SUBMITTED', 'Submitted / Request Received'),
        ('PICKUP_SCHEDULED', 'Pickup Scheduled'),
        ('PICKED_UP', 'Device Picked Up'),
        ('INSPECTION_PENDING', 'Inspection Pending'),
        ('INSPECTION_COMPLETED', 'Inspection Completed'),
        ('FINAL_OFFER_SENT', 'Final Offer Sent to Customer'),
        ('CUSTOMER_ACCEPTED', 'Offer Accepted by Customer'),
        ('CUSTOMER_REJECTED', 'Offer Rejected by Customer'),
        ('OWNERSHIP_TRANSFERRED', 'Ownership Transferred'),
        ('PAYMENT_PENDING', 'Awaiting Payout Authorization'),
        ('PAYMENT_COMPLETED', 'Payment Completed (Paid)'),
        ('PAYMENT_FAILED', 'Payment Failed'),
        ('CANCELLED', 'Cancelled'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    sale_code = models.CharField(max_length=30, unique=True, blank=True)
    
    customer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='phone_sales'
    )
    customer_name = models.CharField(max_length=150)
    customer_phone = models.CharField(max_length=20, db_index=True)
    customer_email = models.EmailField(blank=True, db_index=True)

    # Variant is optional to support 'Others' category custom devices or archived SKUs
    variant = models.ForeignKey(StorageVariant, on_delete=models.SET_NULL, related_name='sales', null=True, blank=True)
    
    # Custom Device Fields (for Others, Tablets, Dead Phones without fixed SKUs)
    is_custom_device = models.BooleanField(default=False)
    custom_device_name = models.CharField(max_length=200, blank=True, default='')
    custom_device_category = models.CharField(max_length=50, blank=True, default='Mobile')
    custom_device_specs = models.TextField(blank=True, default='')
    
    # Consolidated user-entered custom defect notes from all steps
    other_defects_notes = models.TextField(blank=True, default='')

    # Financial valuation - DecimalFields per essential rules
    base_price = models.DecimalField(max_digits=10, decimal_places=2)
    estimated_price = models.DecimalField(max_digits=10, decimal_places=2)
    final_price = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)

    status = models.CharField(max_length=30, choices=STATUS_CHOICES, default='SUBMITTED', db_index=True)

    # Pickup Details
    assigned_agent = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='assigned_pickups'
    )
    pickup_address = models.TextField()
    pickup_city = models.CharField(max_length=100, default='City')
    pickup_pincode = models.CharField(max_length=10)
    pickup_date = models.DateField(null=True, blank=True, db_index=True)
    pickup_slot = models.CharField(max_length=50, blank=True, default='Morning (10:00 AM - 1:00 PM)')

    # Payment Details for Customer receiving funds
    BENEFICIARY_CHOICES = (
        ('UPI', 'UPI ID (Google Pay, PhonePe, Paytm)'),
        ('BANK', 'Direct Bank Transfer (IMPS/NEFT)'),
    )
    beneficiary_type = models.CharField(max_length=10, choices=BENEFICIARY_CHOICES, default='UPI')
    beneficiary_name = models.CharField(max_length=150)
    beneficiary_upi_id = models.CharField(max_length=100, blank=True, default='')
    beneficiary_account_no = models.CharField(max_length=50, blank=True, default='')
    beneficiary_ifsc = models.CharField(max_length=20, blank=True, default='')

    # Device verification & physical legal transfer
    imei_number = models.CharField(max_length=30, blank=True, default='')
    customer_handover_signed = models.BooleanField(default=False)
    admin_notes = models.TextField(blank=True, default='')

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['customer_phone', '-created_at']),
            models.Index(fields=['assigned_agent', 'status']),
            models.Index(fields=['status', '-created_at']),
            models.Index(fields=['pickup_date', 'status']),
        ]

    def save(self, *args, **kwargs):
        if not self.sale_code:
            short_id = str(self.id)[:6].upper()
            self.sale_code = f"PHN-2026-{short_id}"
        super().save(*args, **kwargs)

    def __str__(self):
        device_name = self.custom_device_name if self.is_custom_device else (self.variant.model.name if self.variant else "Custom Device")
        return f"{self.sale_code} - {device_name} ({self.get_status_display()})"

class PhoneSaleConditionAnswer(models.Model):
    sale = models.ForeignKey(PhoneSale, on_delete=models.CASCADE, related_name='answers')
    option = models.ForeignKey(ConditionOption, on_delete=models.SET_NULL, null=True, blank=True)
    step_name = models.CharField(max_length=150, blank=True, default='')
    custom_text = models.CharField(max_length=500, blank=True, default='')
    deduction_applied = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)

    class Meta:
        ordering = ['id']

    def __str__(self):
        title = self.option.title if self.option else (self.step_name or "Custom Note")
        return f"{self.sale.sale_code} - {title} (-₹{self.deduction_applied})"
