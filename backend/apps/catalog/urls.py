from django.urls import path
from .views import (
    categories_list_view, category_detail_view,
    brands_list_view, brand_detail_view, 
    series_list_view, series_detail_view,
    models_list_view, model_detail_view, 
    variants_list_create_view, variant_detail_view,
    cms_sections_view
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
]
