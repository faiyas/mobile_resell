from django.urls import path
from .views import (
    brands_list_view, brand_detail_view, 
    models_list_view, model_detail_view, 
    variants_list_create_view, variant_detail_view
)

urlpatterns = [
    path('brands/', brands_list_view, name='catalog-brands'),
    path('brands/<int:pk>/', brand_detail_view, name='catalog-brand-detail'),
    path('models/', models_list_view, name='catalog-models'),
    path('models/<int:pk>/', model_detail_view, name='catalog-model-detail'),
    path('variants/', variants_list_create_view, name='catalog-variants'),
    path('variants/<int:pk>/', variant_detail_view, name='catalog-variant-detail'),
]
