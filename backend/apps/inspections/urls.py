from django.urls import path
from .views import record_inspection_view

urlpatterns = [
    path('', record_inspection_view, name='record-inspection'),
]
