"""
ratelimit.py - per-visitor request limits for the public deployment.

Every scan occupies the single MATLAB engine for several seconds, so an
unthrottled public link could be queued into uselessness by one visitor.
This is a sliding-window limiter kept in memory: fine for one process on one
machine, which is exactly how DRishti is deployed through the tunnel.
"""

import threading
import time
from collections import deque

# Keys idle for longer than this are forgotten, which bounds memory.
_FORGET_AFTER_WINDOWS = 2


class RateLimiter:
    """Allow at most `limit` calls per `window_seconds` for each key."""

    def __init__(self, limit: int, window_seconds: float, clock=time.monotonic):
        if limit < 1 or window_seconds <= 0:
            raise ValueError("limit must be >= 1 and window_seconds > 0")
        self.limit = limit
        self.window = window_seconds
        self._clock = clock
        self._hits = {}
        self._lock = threading.Lock()
        self._last_sweep = clock()

    def allow(self, key: str):
        """Record a call for `key`.

        Returns (allowed, retry_after_seconds). retry_after is 0 when allowed.
        """
        now = self._clock()
        with self._lock:
            self._sweep(now)
            hits = self._hits.setdefault(key, deque())
            while hits and now - hits[0] >= self.window:
                hits.popleft()
            if len(hits) >= self.limit:
                retry_after = self.window - (now - hits[0])
                return False, max(1, int(retry_after + 0.999))
            hits.append(now)
            return True, 0

    def _sweep(self, now: float):
        """Drop keys that have been quiet for a while (called under the lock)."""
        if now - self._last_sweep < self.window:
            return
        self._last_sweep = now
        stale = [k for k, h in self._hits.items()
                 if not h or now - h[-1] >= self.window * _FORGET_AFTER_WINDOWS]
        for k in stale:
            del self._hits[k]


def client_key(request) -> str:
    """Identify the visitor.

    Behind the Cloudflare tunnel every request arrives from 127.0.0.1, so the
    real address comes from the CF-Connecting-IP header that cloudflared adds.
    The server only listens on 127.0.0.1, so nothing but cloudflared (or
    someone already on this machine) can set that header.
    """
    forwarded = (request.headers.get("CF-Connecting-IP") or "").strip()
    return forwarded or (request.remote_addr or "unknown")
