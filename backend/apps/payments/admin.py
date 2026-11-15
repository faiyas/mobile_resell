from django.contrib import admin
from .models import Payment

@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = (
        'sale', 'amount', 'payment_method', 'beneficiary_name',
        'beneficiary_upi_id', 'utr_number', 'paid_by', 'paid_at', 'is_verified'
    )
    list_filter = ('payment_method', 'is_verified', 'paid_at')
    search_fields = ('sale__sale_code', 'utr_number', 'beneficiary_name', 'beneficiary_upi_id')
    readonly_fields = ('paid_at',)
