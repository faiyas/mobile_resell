from django.db import models
from django.conf import settings
from apps.sales.models import PhoneSale

class Payment(models.Model):
    METHOD_CHOICES = (
        ('GPAY', 'Google Pay'),
        ('PHONEPE', 'PhonePe'),
        ('PAYTM', 'Paytm UPI'),
        ('BHIM', 'BHIM UPI'),
        ('IMPS', 'Bank IMPS / NEFT'),
        ('CASH', 'Cash Transfer'),
    )

    sale = models.OneToOneField(PhoneSale, on_delete=models.CASCADE, related_name='payment')
    amount = models.DecimalField(max_digits=10, decimal_places=2, help_text="Amount disbursed to customer")
    payment_method = models.CharField(max_length=20, choices=METHOD_CHOICES, default='GPAY')

    # Beneficiary snapshot at time of payout
    beneficiary_name = models.CharField(max_length=150)
    beneficiary_upi_id = models.CharField(max_length=100, blank=True, default='')
    beneficiary_account_no = models.CharField(max_length=50, blank=True, default='')
    beneficiary_ifsc = models.CharField(max_length=20, blank=True, default='')

    # Bank Reference / UTR Number - Unique to prevent duplicate payouts
    utr_number = models.CharField(max_length=50, unique=True, help_text="Bank/UPI 12-digit Reference Number (UTR)")
    
    # 100% Base64 encoded screenshot of payment confirmation (GPay, PhonePe, Paytm, etc.)
    payment_proof_base64 = models.TextField(help_text="Base64 encoded payment screenshot")

    admin_notes = models.TextField(blank=True, default='')
    paid_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.PROTECT, related_name='payouts_authorized')
    paid_at = models.DateTimeField(auto_now_add=True)
    is_verified = models.BooleanField(default=True)

    class Meta:
        ordering = ['-paid_at']

    def __str__(self):
        return f"Payment for {self.sale.sale_code} - ₹{self.amount} (UTR: {self.utr_number})"
