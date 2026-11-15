from django.urls import path
from .views import register_view, login_view, me_view, collection_agents_view

urlpatterns = [
    path('register/', register_view, name='auth-register'),
    path('login/', login_view, name='auth-login'),
    path('me/', me_view, name='auth-me'),
    path('agents/', collection_agents_view, name='auth-agents'),
]
