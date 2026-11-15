from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/v1/auth/', include('apps.accounts.urls')),
    path('api/v1/catalog/', include('apps.catalog.urls')),
    path('api/v1/valuation/', include('apps.valuation.urls')),
    path('api/v1/sales/', include('apps.sales.urls')),
    path('api/v1/inspections/', include('apps.inspections.urls')),
    path('api/v1/payments/', include('apps.payments.urls')),
]
