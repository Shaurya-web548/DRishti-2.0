import os
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

import app as app_module  # noqa: E402


class FakeBridge:
    """Stands in for the MATLAB Engine so tests run without MATLAB."""

    def __init__(self):
        self.scenarios = []

    def run_capacity_scenario(self, overrides):
        self.scenarios.append(overrides)
        return {"engine": "matlab", "bottleneck": {"key": "ophthalmologist", "pct": 74.9},
                "received": overrides}

    def run_pipeline(self, image_path, output_dir):
        return {"mode": "real_no_cnn", "decision": {"grade": 1, "referable": False},
                "overlayPath": "x", "confidence": []}


@pytest.fixture
def bridge(monkeypatch):
    fake = FakeBridge()
    monkeypatch.setattr(app_module, "get_bridge", lambda: fake)
    return fake


@pytest.fixture
def client():
    app_module.app.config["TESTING"] = True
    with app_module.app.test_client() as c:
        yield c
