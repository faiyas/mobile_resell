from django.contrib import admin
from .models import Brand, PhoneModel, StorageVariant

class StorageVariantInline(admin.TabularInline):
    model = StorageVariant
    extra = 1

@admin.register(Brand)
class BrandAdmin(admin.ModelAdmin):
    list_display = ('name', 'slug', 'display_order', 'is_active', 'created_at')
    list_filter = ('is_active',)
    search_fields = ('name',)
    ordering = ('display_order', 'name')

@admin.register(PhoneModel)
class PhoneModelAdmin(admin.ModelAdmin):
    list_display = ('name', 'brand', 'release_year', 'is_active', 'created_at')
    list_filter = ('brand', 'is_active', 'release_year')
    search_fields = ('name', 'brand__name')
    inlines = [StorageVariantInline]

@admin.register(StorageVariant)
class StorageVariantAdmin(admin.ModelAdmin):
    list_display = ('model', 'ram', 'storage', 'base_price', 'min_price', 'is_active')
    list_filter = ('model__brand', 'is_active')
    search_fields = ('model__name', 'storage', 'ram')
