from django.urls import path
from .views import get_payment_qr_view, record_payout_view, payments_list_view, payment_receipt_view

urlpatterns = [
    path('', payments_list_view, name='payments-list'),
    path('record-payout/', record_payout_view, name='payments-record-payout'),
    path('qr/<str:sale_id>/', get_payment_qr_view, name='payments-qr'),
    path('receipt/<str:sale_code>/', payment_receipt_view, name='payments-receipt'),
]
