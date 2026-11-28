from django.urls import path
from .views import (
    categories_list_view, category_detail_view,
    brands_list_view, brand_detail_view, 
    series_list_view, series_detail_view,
    models_list_view, model_detail_view, 
    variants_list_create_view, variant_detail_view,
    cms_sections_view, system_settings_view, business_settings_view,
    catalog_bulk_delete_view, catalog_sync_bundle_view,
    catalog_stats_view, catalog_versions_view
)

urlpatterns = [
    # Device Categories (Mobile, Tablet, Laptop, Watch, Dead Phone, Other)
    path('categories/', categories_list_view, name='catalog-categories'),
    path('categories/<int:pk>/', category_detail_view, name='catalog-category-detail'),

    # Brands
    path('brands/', brands_list_view, name='catalog-brands'),
    path('brands/<int:pk>/', brand_detail_view, name='catalog-brand-detail'),

    # Series
    path('series/', series_list_view, name='catalog-series'),
    path('series/<int:pk>/', series_detail_view, name='catalog-series-detail'),

    # Models
    path('models/', models_list_view, name='catalog-models'),
    path('models/<int:pk>/', model_detail_view, name='catalog-model-detail'),

    # Variants & Base Prices
    path('variants/', variants_list_create_view, name='catalog-variants'),
    path('variants/<int:pk>/', variant_detail_view, name='catalog-variant-detail'),

    # Dynamic CMS Home Sections
    path('cms/sections/', cms_sections_view, name='catalog-cms-sections'),

    # System Operational Settings
    path('settings/', system_settings_view, name='catalog-system-settings'),
    path('business-settings/', business_settings_view, name='catalog-business-settings'),

    # Fast Admin Sidebar Counts & Stats
    path('stats/', catalog_stats_view, name='catalog-stats'),
    path('versions/', catalog_versions_view, name='catalog-versions'),

    # Bulk Delete & Mobile Offline Sync Bundle
    path('bulk-delete/', catalog_bulk_delete_view, name='catalog-bulk-delete'),
    path('sync-bundle/', catalog_sync_bundle_view, name='catalog-sync-bundle'),
]
