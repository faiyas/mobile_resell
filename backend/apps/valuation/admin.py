from django.contrib import admin
from .models import ConditionCategory, ConditionOption, ModelPricingOverride, PriceHistory

class ConditionOptionInline(admin.TabularInline):
    model = ConditionOption
    extra = 1

@admin.register(ConditionCategory)
class ConditionCategoryAdmin(admin.ModelAdmin):
    list_display = ('name', 'display_order', 'icon_name', 'is_active')
    list_filter = ('is_active',)
    inlines = [ConditionOptionInline]

@admin.register(ConditionOption)
class ConditionOptionAdmin(admin.ModelAdmin):
    list_display = ('title', 'category', 'code', 'deduction_type', 'default_deduction_value', 'exclusive_group', 'is_rejection', 'is_active')
    list_filter = ('category', 'deduction_type', 'is_defect', 'is_rejection', 'is_active')
    search_fields = ('title', 'code', 'exclusive_group')

@admin.register(ModelPricingOverride)
class ModelPricingOverrideAdmin(admin.ModelAdmin):
    list_display = ('phone_model', 'option', 'override_deduction_value')
    list_filter = ('phone_model__brand',)
    search_fields = ('phone_model__name', 'option__title')

@admin.register(PriceHistory)
class PriceHistoryAdmin(admin.ModelAdmin):
    list_display = ('variant', 'old_base_price', 'new_base_price', 'changed_by', 'reason', 'created_at')
    list_filter = ('created_at',)
    search_fields = ('variant__model__name', 'reason', 'changed_by__email')
