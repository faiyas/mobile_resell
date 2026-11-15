from django.contrib import admin
from .models import DeviceInspection, InspectionPhoto

class InspectionPhotoInline(admin.TabularInline):
    model = InspectionPhoto
    extra = 0
    readonly_fields = ('label', 'created_at')

@admin.register(DeviceInspection)
class DeviceInspectionAdmin(admin.ModelAdmin):
    list_display = (
        'sale', 'inspected_by', 'verified_imei', 'body_condition',
        'switches_on', 'cloud_locks_removed', 'suggested_final_price', 'created_at'
    )
    list_filter = ('body_condition', 'cloud_locks_removed', 'switches_on')
    search_fields = ('sale__sale_code', 'verified_imei', 'inspected_by__full_name')
    inlines = [InspectionPhotoInline]

@admin.register(InspectionPhoto)
class InspectionPhotoAdmin(admin.ModelAdmin):
    list_display = ('inspection', 'label', 'created_at')
