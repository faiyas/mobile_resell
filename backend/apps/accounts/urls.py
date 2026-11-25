from django.urls import path
from .views import (
    register_view, login_view, me_view, collection_agents_view,
    agent_detail_view, customers_view, customer_detail_view, delete_account_view,
    change_password_view, send_customer_otp_view, verify_register_customer_view,
    reset_password_customer_view, admin_reset_customer_password_view
)

urlpatterns = [
    path('register/', register_view, name='auth-register'),
    path('login/', login_view, name='auth-login'),
    path('me/', me_view, name='auth-me'),
    path('change-password/', change_password_view, name='auth-change-password'),
    path('customer/send-otp/', send_customer_otp_view, name='auth-customer-send-otp'),
    path('customer/verify-register/', verify_register_customer_view, name='auth-customer-verify-register'),
    path('customer/reset-password/', reset_password_customer_view, name='auth-customer-reset-password'),
    path('agents/', collection_agents_view, name='auth-agents'),
    path('agents/<int:agent_id>/', agent_detail_view, name='auth-agent-detail'),
    path('customers/', customers_view, name='auth-customers'),
    path('customers/<int:user_id>/', customer_detail_view, name='auth-customer-detail'),
    path('customers/<int:user_id>/reset-password/', admin_reset_customer_password_view, name='auth-admin-reset-customer-password-by-id'),
    path('customers/reset-password/', admin_reset_customer_password_view, name='auth-admin-reset-customer-password'),
    path('delete-account/', delete_account_view, name='auth-delete-account'),
]