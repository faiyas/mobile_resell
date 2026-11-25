from django.urls import path
from .views import (
    condition_categories_view, condition_category_detail_view,
    condition_options_view, condition_option_detail_view,
    calculate_estimate_view, price_history_list_view,
    copy_questions_from_brand_view, valuation_bulk_delete_view
)

urlpatterns = [
    # Categories
    path('conditions/', condition_categories_view, name='valuation-conditions'),
    path('conditions/<int:pk>/', condition_category_detail_view, name='valuation-category-detail'),
    path('conditions/copy-from-brand/', copy_questions_from_brand_view, name='valuation-copy-questions'),
    
    # Options & Deduction Rules
    path('options/', condition_options_view, name='valuation-options'),
    path('options/<int:pk>/', condition_option_detail_view, name='valuation-option-detail'),
    
    # Dynamic Valuation Calculation Engine & Simulator
    path('estimate/', calculate_estimate_view, name='valuation-estimate'),
    path('calculate-estimate/', calculate_estimate_view, name='valuation-calc-estimate'),
    path('pricing/preview/', calculate_estimate_view, name='valuation-preview'),
    
    # Price History & Audit Log
    path('pricing/history/', price_history_list_view, name='valuation-price-history'),

    # Bulk Delete
    path('bulk-delete/', valuation_bulk_delete_view, name='valuation-bulk-delete'),
]
