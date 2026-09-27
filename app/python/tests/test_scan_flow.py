"""Upload -> pipeline -> result -> report, with MATLAB replaced by fakes."""

import io
import json

import pytest

import app as app_module
import site_content


@pytest.fixture
def results_dir(tmp_path, monkeypatch):
    monkeypatch.setattr(app_module, "RESULTS_DIR", str(tmp_path))
    return tmp_path


def _upload(client, name="eye.png", data=b"\x89PNG fake"):
    return client.post("/api/scan", data={"image": (io.BytesIO(data), name)},
                       content_type="multipart/form-data")


def test_scan_without_file_is_rejected(client):
    assert client.post("/api/scan").status_code == 400


def test_scan_with_wrong_extension_is_rejected(client, results_dir):
    res = _upload(client, name="notes.txt")
    assert res.status_code == 400
    assert "PNG or JPG" in res.get_json()["error"]


def test_successful_scan_returns_grade_and_urls(client, bridge, results_dir):
    res = _upload(client)
    body = res.get_json()
    assert res.status_code == 200
    assert body["grade"] == 1
    assert body["grade_label"] == "Mild non-proliferative DR"
    assert body["referable"] is False
    assert body["original_url"].endswith("/original.png")
    assert body["gradcam_url"] is None
    app_module.SCANS.pop(body["scan_id"], None)


def test_rejected_image_reports_quality_message(client, monkeypatch, results_dir):
    class Rejecting:
        def run_pipeline(self, *_):
            return {"mode": "rejected", "error": "Too blurry."}
    monkeypatch.setattr(app_module, "get_bridge", lambda: Rejecting())
    body = _upload(client).get_json()
    assert body["mode"] == "rejected"
    assert body["message"] == "Too blurry."


def test_pipeline_crash_returns_readable_500(client, monkeypatch, results_dir):
    class Broken:
        def run_pipeline(self, *_):
            raise RuntimeError("File x.m, line 55\nThe Image Processing Toolbox is required.")
    monkeypatch.setattr(app_module, "get_bridge", lambda: Broken())
    res = _upload(client)
    assert res.status_code == 500
    assert res.get_json()["error"] == "Pipeline failed: The Image Processing Toolbox is required."


def test_uploaded_image_is_served_back(client, bridge, results_dir):
    body = _upload(client, data=b"image-bytes").get_json()
    res = client.get(body["original_url"])
    assert res.status_code == 200
    assert res.data == b"image-bytes"
    app_module.SCANS.pop(body["scan_id"], None)


def test_report_download_passes_clean_patient_details(client, bridge, results_dir, monkeypatch):
    seen = {}

    def fake_pdf(report, patient, path):
        seen.update(patient)
        with open(path, "wb") as fh:
            fh.write(b"%PDF-1.3 fake")

    monkeypatch.setattr(app_module, "generate_pdf", fake_pdf)
    scan_id = _upload(client).get_json()["scan_id"]
    res = client.get(f"/api/report/{scan_id}?name=%20Asha%20&age=0&location=PHC")
    assert res.status_code == 200
    assert res.data.startswith(b"%PDF")
    assert seen == {"name": "Asha", "age": "0", "location": "PHC", "scan_id": scan_id}
    app_module.SCANS.pop(scan_id, None)


def test_simulation_failure_returns_500(client, monkeypatch):
    class Broken:
        def run_capacity_scenario(self, _):
            raise RuntimeError("engine died")
    monkeypatch.setattr(app_module, "get_bridge", lambda: Broken())
    res = client.post("/api/simulate", json={})
    assert res.status_code == 500
    assert "engine died" in res.get_json()["error"]


def test_team_loader_survives_missing_or_broken_file(tmp_path, monkeypatch):
    monkeypatch.setattr(site_content, "TEAM_FILE", str(tmp_path / "absent.json"))
    assert site_content.load_team() == {"project": {}, "mentors": [], "members": []}

    broken = tmp_path / "team.json"
    broken.write_text("{not json", encoding="utf-8")
    monkeypatch.setattr(site_content, "TEAM_FILE", str(broken))
    assert site_content.load_team()["members"] == []


def test_team_loader_adds_initials_without_mutating(tmp_path, monkeypatch):
    raw = {"members": [{"name": "Asha Rao Verma"}, {"name": "Ravi"}, {"name": ""}]}
    f = tmp_path / "team.json"
    f.write_text(json.dumps(raw), encoding="utf-8")
    monkeypatch.setattr(site_content, "TEAM_FILE", str(f))
    members = site_content.load_team()["members"]
    assert [m["initials"] for m in members] == ["AV", "RA", ""]
    assert [m["has_name"] for m in members] == [True, True, False]


def test_team_links_only_allow_http_and_plain_email(tmp_path, monkeypatch):
    raw = {"members": [{
        "name": "Asha", "github": "javascript:alert(1)", "linkedin": "https://linkedin.com/in/asha",
        "email": "asha@example.org", "photo": "data:text/html,x",
    }, {"name": "Ravi", "github": "  HTTPS://github.com/ravi ", "email": "javascript:x@y.z"}]}
    f = tmp_path / "team.json"
    f.write_text(json.dumps(raw), encoding="utf-8")
    monkeypatch.setattr(site_content, "TEAM_FILE", str(f))
    asha, ravi = site_content.load_team()["members"]
    assert asha["github"] == ""
    assert asha["linkedin"] == "https://linkedin.com/in/asha"
    assert asha["email"] == "asha@example.org"
    assert asha["photo"] == ""
    assert ravi["github"] == "HTTPS://github.com/ravi"
    assert ravi["email"] == ""
