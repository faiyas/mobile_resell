from django.contrib import admin
from .models import PhoneSale, PhoneSaleConditionAnswer

class PhoneSaleConditionAnswerInline(admin.TabularInline):
    model = PhoneSaleConditionAnswer
    extra = 0
    readonly_fields = ('option', 'deduction_applied')

@admin.register(PhoneSale)
class PhoneSaleAdmin(admin.ModelAdmin):
    list_display = (
        'sale_code', 'customer_name', 'customer_phone', 'variant',
        'base_price', 'estimated_price', 'final_price', 'status',
        'beneficiary_type', 'created_at'
    )
    list_filter = ('status', 'beneficiary_type', 'variant__model__brand')
    search_fields = ('sale_code', 'customer_name', 'customer_phone', 'imei_number')
    readonly_fields = ('id', 'sale_code', 'created_at', 'updated_at')
    inlines = [PhoneSaleConditionAnswerInline]
