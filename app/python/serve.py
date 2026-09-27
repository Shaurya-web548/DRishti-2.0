"""
serve.py - production server for the public deployment.

Runs the Flask app under waitress with debugging OFF. Flask's development
server with --debug exposes an interactive debugger, which must never be
reachable from the internet.

    python serve.py            (listens on 127.0.0.1:5000)

It binds to 127.0.0.1 only: the Cloudflare tunnel connects locally, and
nobody else on the network can reach the server directly.
"""

import logging
import os
import threading

from waitress import serve

from app import app
from matlab_bridge import get_bridge

HOST = "127.0.0.1"
PORT = int(os.environ.get("PORT", "5000"))
THREADS = int(os.environ.get("WAITRESS_THREADS", "8"))

log = logging.getLogger("drishti.serve")


def warm_up():
    """Start MATLAB before the first visitor arrives, so their scan does not
    pay the 20-second engine start-up."""
    try:
        get_bridge()
        log.info("MATLAB engine ready")
    except Exception:                                           # noqa: BLE001
        log.exception("MATLAB engine failed to start; scans will retry on demand")


if __name__ == "__main__":
    app.debug = False
    threading.Thread(target=warm_up, name="matlab-warmup", daemon=True).start()
    log.info("Serving DRishti on http://%s:%d (debug off)", HOST, PORT)
    serve(app, host=HOST, port=PORT, threads=THREADS, ident="DRishti")
