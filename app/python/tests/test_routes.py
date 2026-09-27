import pytest

import app as app_module


@pytest.mark.parametrize("path", ["/", "/scan", "/how-it-works", "/simulink", "/about"])
def test_every_page_renders(client, path):
    res = client.get(path)
    assert res.status_code == 200
    assert b"DRishti" in res.data


def test_every_page_links_to_simulink(client):
    for path in ["/", "/scan", "/how-it-works", "/about"]:
        assert b'href="/simulink"' in client.get(path).data


def test_scan_page_age_field_refuses_negatives(client):
    html = client.get("/scan").data.decode()
    assert 'id="patientAge"' in html
    assert 'min="0"' in html and 'max="120"' in html


def test_about_page_lists_team_from_json(client):
    html = client.get("/about").data.decode()
    assert "Shaurya Agarwal" in html


def test_simulate_passes_clean_overrides(client, bridge):
    res = client.post("/api/simulate", json={"annualPatients": 150000, "sites": 10.0})
    assert res.status_code == 200
    assert bridge.scenarios[-1] == {"annualPatients": 150000, "sites": 10}


def test_simulate_rejects_bad_input_without_calling_matlab(client, bridge):
    res = client.post("/api/simulate", json={"annualPatients": -1})
    assert res.status_code == 400
    assert "between" in res.get_json()["error"]
    assert bridge.scenarios == []


def test_report_rejects_negative_age(client, bridge):
    app_module.SCANS["0123456789ab"] = {"mode": "real_no_cnn", "decision": {"grade": 0}}
    try:
        res = client.get("/api/report/0123456789ab?age=-4")
        assert res.status_code == 400
        assert res.get_json()["error"] == "Age cannot be negative."
    finally:
        app_module.SCANS.pop("0123456789ab", None)


def test_report_unknown_scan_is_404(client):
    assert client.get("/api/report/ffffffffffff").status_code == 404


@pytest.mark.parametrize("path", [
    "/results/../app.py",
    "/results/..%2F..%2Fapp.py/x",
    "/results/0123456789ab/..%2F..%2Fapp.py",
])
def test_results_route_blocks_path_traversal(client, path):
    res = client.get(path)
    assert res.status_code in (400, 404)
    assert b"Flask" not in res.data
