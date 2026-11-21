import os
import time
import threading
import urllib.request
import logging

logger = logging.getLogger(__name__)

_pinger_started = False

def start_keep_alive_daemon():
    """
    Spawns a background daemon thread that sends a lightweight HTTP ping
    every 60 seconds (1 minute) to keep the backend process, database connections,
    and cloud proxy tunnel permanently warm and active.
    """
    global _pinger_started
    if _pinger_started:
        return
    _pinger_started = True

    def ping_worker():
        # Give Gunicorn 10 seconds to bind and start accepting connections
        time.sleep(10)
        
        local_port = os.environ.get('PORT', '8010')
        local_url = f"http://127.0.0.1:{local_port}/health/"
        public_url = os.environ.get('PUBLIC_PING_URL', 'https://8010-agq5qlr2uletnjyzudtddvxrdq.instabox.tech/health/')

        targets = [local_url]
        if public_url and public_url not in targets:
            targets.append(public_url)

        headers = {'User-Agent': '1103RecellKeepAlive/1.0'}

        while True:
            for url in targets:
                try:
                    req = urllib.request.Request(url, headers=headers)
                    with urllib.request.urlopen(req, timeout=8) as res:
                        pass
                except Exception:
                    pass
            time.sleep(60)

    thread = threading.Thread(target=ping_worker, name="1103KeepAliveDaemon", daemon=True)
    thread.start()
