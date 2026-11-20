from django.urls import path
from .views import (
    sales_list_create_view,
    sale_detail_view,
    accept_final_offer_view,
    reject_final_offer_view,
    assign_pickup_view,
    transfer_ownership_view,
    admin_approve_final_offer_view,
    shift_pickup_to_next_day_view,
    pincode_lookup_view,
)

urlpatterns = [
    path('', sales_list_create_view, name='sales-list-create'),
    path('pincode-lookup/', pincode_lookup_view, name='sales-pincode-lookup'),
    path('<str:pk>/', sale_detail_view, name='sales-detail'),
    path('<str:pk>/accept-offer/', accept_final_offer_view, name='sales-accept-offer'),
    path('<str:pk>/reject-offer/', reject_final_offer_view, name='sales-reject-offer'),
    path('<str:pk>/schedule-pickup/', assign_pickup_view, name='sales-schedule-pickup'),
    path('<str:pk>/schedule_pickup/', assign_pickup_view, name='sales-schedule-pickup-under'),
    path('<str:pk>/assign-pickup/', assign_pickup_view, name='sales-assign-pickup'),
    path('<str:pk>/assign_pickup/', assign_pickup_view, name='sales-assign-pickup-under'),
    path('<str:pk>/shift-next-day/', shift_pickup_to_next_day_view, name='sales-shift-next-day'),
    path('<str:pk>/shift_next_day/', shift_pickup_to_next_day_view, name='sales-shift-next-day-under'),
    path('<str:pk>/transfer-ownership/', transfer_ownership_view, name='sales-transfer-ownership'),
    path('<str:pk>/approve-final-offer/', admin_approve_final_offer_view, name='sales-approve-final-offer'),
]
