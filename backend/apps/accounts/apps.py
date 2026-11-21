import os
from django.apps import AppConfig

class AccountsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'apps.accounts'

    def ready(self):
        # Start keep-alive daemon on server startup (ignoring autoreload parent process)
        if os.environ.get('RUN_MAIN') == 'true' or not os.environ.get('RUN_MAIN'):
            try:
                from config.keep_alive import start_keep_alive_daemon
                start_keep_alive_daemon()
            except Exception:
                pass
