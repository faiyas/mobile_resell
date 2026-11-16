from django.urls import path
from .views import (
    condition_categories_view, condition_category_detail_view,
    condition_options_view, condition_option_detail_view,
    calculate_estimate_view, price_history_list_view
)

urlpatterns = [
    # Categories
    path('conditions/', condition_categories_view, name='valuation-conditions'),
    path('conditions/<int:pk>/', condition_category_detail_view, name='valuation-category-detail'),
    
    # Options & Deduction Rules
    path('options/', condition_options_view, name='valuation-options'),
    path('options/<int:pk>/', condition_option_detail_view, name='valuation-option-detail'),
    
    # Dynamic Valuation Calculation Engine & Simulator
    path('estimate/', calculate_estimate_view, name='valuation-estimate'),
    path('pricing/preview/', calculate_estimate_view, name='valuation-preview'),
    
    # Price History & Audit Log
    path('pricing/history/', price_history_list_view, name='valuation-price-history'),
]
