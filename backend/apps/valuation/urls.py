from django.urls import path
from .views import condition_categories_view, calculate_estimate_view, update_condition_option_view

urlpatterns = [
    path('conditions/', condition_categories_view, name='valuation-conditions'),
    path('conditions/<int:pk>/', update_condition_option_view, name='valuation-condition-update'),
    path('estimate/', calculate_estimate_view, name='valuation-estimate'),
]
