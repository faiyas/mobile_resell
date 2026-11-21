from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse
from django.utils import timezone

def health_check(request):
    """Ultra-lightweight health endpoint for uptime monitors and keep-alive pingers"""
    return JsonResponse({
        'status': 'healthy',
        'engine': '1103_recell_backend',
        'timestamp': timezone.now().isoformat()
    })

urlpatterns = [
    path('health/', health_check),
    path('ping/', health_check),
    path('api/v1/health/', health_check),
    path('api/health/', health_check),

    path('admin/', admin.site.urls),

    # Standard API v1 endpoints
    path('api/v1/auth/', include('apps.accounts.urls')),
    path('api/v1/accounts/', include('apps.accounts.urls')),
    path('api/v1/catalog/', include('apps.catalog.urls')),
    path('api/v1/valuation/', include('apps.valuation.urls')),
    path('api/v1/sales/', include('apps.sales.urls')),
    path('api/v1/inspections/', include('apps.inspections.urls')),
    path('api/v1/payments/', include('apps.payments.urls')),

    # API without v1 prefix
    path('api/auth/', include('apps.accounts.urls')),
    path('api/accounts/', include('apps.accounts.urls')),
    path('api/catalog/', include('apps.catalog.urls')),
    path('api/valuation/', include('apps.valuation.urls')),
    path('api/sales/', include('apps.sales.urls')),
    path('api/inspections/', include('apps.inspections.urls')),
    path('api/payments/', include('apps.payments.urls')),

    # Fallback direct paths
    path('auth/', include('apps.accounts.urls')),
    path('accounts/', include('apps.accounts.urls')),
    path('catalog/', include('apps.catalog.urls')),
    path('valuation/', include('apps.valuation.urls')),
    path('sales/', include('apps.sales.urls')),
    path('inspections/', include('apps.inspections.urls')),
    path('payments/', include('apps.payments.urls')),
]
