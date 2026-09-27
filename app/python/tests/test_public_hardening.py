"""Protections added for the public (tunnel) deployment."""

import os
import time

import pytest

import app as app_module
from ratelimit import RateLimiter, client_key
from retention import purge_old_results


class FakeClock:
    def __init__(self):
        self.t = 1000.0

    def __call__(self):
        return self.t


class TestRateLimiter:
    def test_allows_up_to_the_limit_then_blocks(self):
        clock = FakeClock()
        rl = RateLimiter(3, 60, clock=clock)
        assert [rl.allow("a")[0] for _ in range(3)] == [True, True, True]
        allowed, retry = rl.allow("a")
        assert not allowed and retry == 60

    def test_window_slides(self):
        clock = FakeClock()
        rl = RateLimiter(2, 60, clock=clock)
        rl.allow("a"); rl.allow("a")
        clock.t += 30
        assert rl.allow("a") == (False, 30)
        clock.t += 31
        assert rl.allow("a")[0]

    def test_visitors_are_independent(self):
        rl = RateLimiter(1, 60, clock=FakeClock())
        assert rl.allow("a")[0]
        assert rl.allow("b")[0]
        assert not rl.allow("a")[0]

    def test_idle_visitors_are_forgotten(self):
        clock = FakeClock()
        rl = RateLimiter(1, 10, clock=clock)
        rl.allow("a")
        clock.t += 25
        rl.allow("b")
        assert "a" not in rl._hits

    @pytest.mark.parametrize("limit,window", [(0, 10), (1, 0)])
    def test_rejects_nonsense_configuration(self, limit, window):
        with pytest.raises(ValueError):
            RateLimiter(limit, window)


class _Req:
    def __init__(self, headers, remote):
        self.headers = headers
        self.remote_addr = remote


def test_client_key_prefers_cloudflare_header():
    assert client_key(_Req({"CF-Connecting-IP": "203.0.113.9"}, "127.0.0.1")) == "203.0.113.9"
    assert client_key(_Req({}, "127.0.0.1")) == "127.0.0.1"


def test_scan_endpoint_returns_429_with_retry_after(client, monkeypatch, bridge, tmp_path):
    monkeypatch.setattr(app_module, "RESULTS_DIR", str(tmp_path))
    monkeypatch.setattr(app_module, "SCAN_LIMITER", RateLimiter(1, 600))
    headers = {"CF-Connecting-IP": "198.51.100.7"}
    first = client.post("/api/scan", headers=headers)          # no file -> 400, but counted
    second = client.post("/api/scan", headers=headers)
    assert first.status_code == 400
    assert second.status_code == 429
    assert int(second.headers["Retry-After"]) > 0
    assert "Too many requests" in second.get_json()["error"]
    # a different visitor is unaffected
    assert client.post("/api/scan", headers={"CF-Connecting-IP": "198.51.100.8"}).status_code == 400


def test_simulate_and_report_are_limited_too(client, monkeypatch, bridge):
    monkeypatch.setattr(app_module, "SIMULATE_LIMITER", RateLimiter(1, 600))
    monkeypatch.setattr(app_module, "REPORT_LIMITER", RateLimiter(1, 600))
    client.post("/api/simulate", json={})
    assert client.post("/api/simulate", json={}).status_code == 429
    client.get("/api/report/ffffffffffff")
    assert client.get("/api/report/ffffffffffff").status_code == 429


def test_security_headers_on_every_response(client):
    res = client.get("/")
    assert res.headers["X-Content-Type-Options"] == "nosniff"
    assert res.headers["X-Frame-Options"] == "DENY"
    assert "Referrer-Policy" in res.headers


class TestRetention:
    def _scan_dir(self, root, name, age_hours):
        path = root / name
        path.mkdir()
        (path / "original.png").write_bytes(b"x")
        old = time.time() - age_hours * 3600
        os.utime(path, (old, old))
        return path

    def test_removes_only_old_scan_folders(self, tmp_path):
        old = self._scan_dir(tmp_path, "aaaaaaaaaaaa", 30)
        fresh = self._scan_dir(tmp_path, "bbbbbbbbbbbb", 1)
        other = tmp_path / "not-a-scan"
        other.mkdir()
        os.utime(other, (0, 0))
        scans = {"aaaaaaaaaaaa": {}, "bbbbbbbbbbbb": {}}

        removed = purge_old_results(str(tmp_path), 24, scans)

        assert removed == ["aaaaaaaaaaaa"]
        assert not old.exists() and fresh.exists() and other.exists()
        assert list(scans) == ["bbbbbbbbbbbb"]

    def test_zero_hours_keeps_everything(self, tmp_path):
        self._scan_dir(tmp_path, "cccccccccccc", 1000)
        assert purge_old_results(str(tmp_path), 0, {}) == []

    def test_missing_folder_is_harmless(self, tmp_path):
        assert purge_old_results(str(tmp_path / "nope"), 24, {}) == []
