from django.urls import path
from .views import (
    register_view, login_view, me_view, collection_agents_view,
    customers_view, customer_detail_view
)

urlpatterns = [
    path('register/', register_view, name='auth-register'),
    path('login/', login_view, name='auth-login'),
    path('me/', me_view, name='auth-me'),
    path('agents/', collection_agents_view, name='auth-agents'),
    path('customers/', customers_view, name='auth-customers'),
    path('customers/<int:user_id>/', customer_detail_view, name='auth-customer-detail'),
    path('delete-account/', delete_account_view, name='auth-delete-account'),
]