"""
WSGI config for Mobile Buyback Platform.

It exposes the WSGI callable as a module-level variable named ``application``.
"""

import os
from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

application = get_wsgi_application()

# Start background keep-alive ping daemon to keep cloud host & tunnel permanently active
try:
    from config.keep_alive import start_keep_alive_daemon
    start_keep_alive_daemon()
except Exception:
    pass
