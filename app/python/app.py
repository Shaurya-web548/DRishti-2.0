"""
app.py - DRishti Flask backend.

Pages:
  GET  /                              animated landing page
  GET  /scan                          the screening tool
  GET  /how-it-works                  pipeline walkthrough
  GET  /simulink                      district capacity model (Simulink flow model + DES)
  GET  /about                         mission, team, safety and limitations

API:
  POST /api/scan                      upload an image, run the pipeline, return JSON
  GET  /api/report/<scan_id>          generate + download the PDF report
  POST /api/simulate                  run one capacity scenario, return JSON
  GET  /results/<scan_id>/<filename>  serve generated images (overlay/gradcam/original)

Run:
    ..\\..\\run-local.ps1      (from the repo root: .\\run-local.ps1)
Then open http://localhost:5000
"""

import functools
import logging
import os
import re
import uuid

from flask import (Flask, abort, jsonify, render_template, request,
                   send_file, send_from_directory, url_for)

from matlab_bridge import get_bridge
from ratelimit import RateLimiter, client_key
from report_generator import generate_pdf
from retention import purge_old_results
from site_content import load_team
from validation import (ValidationError, is_valid_scan_id, validate_patient,
                        validate_scenario)

BASE_DIR = os.path.abspath(os.path.dirname(__file__))
RESULTS_DIR = os.path.join(BASE_DIR, "results")
ALLOWED_EXT = {"png", "jpg", "jpeg"}

GRADE_LABELS = {
    0: "No apparent retinopathy",
    1: "Mild non-proliferative DR",
    2: "Moderate non-proliferative DR",
    3: "Severe non-proliferative DR",
    4: "Proliferative DR",
}

os.makedirs(RESULTS_DIR, exist_ok=True)

log = logging.getLogger("drishti")
logging.basicConfig(level=logging.INFO)

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 20 * 1024 * 1024  # 20MB uploads

# In-memory scan store - fine for a hackathon demo / single-machine kiosk.
# Swap for a DB if this needs to survive restarts or run multi-worker.
SCANS = {}

# Uploaded photographs are deleted after this many hours (0 keeps them).
RESULTS_MAX_AGE_HOURS = float(os.environ.get("RESULTS_MAX_AGE_HOURS", "24"))

# Per-visitor limits, requests per 10 minutes. A scan holds the one MATLAB
# engine for several seconds, so it gets the tightest limit.
LIMIT_WINDOW_SECONDS = 600
SCAN_LIMITER = RateLimiter(int(os.environ.get("SCAN_LIMIT", "10")), LIMIT_WINDOW_SECONDS)
REPORT_LIMITER = RateLimiter(int(os.environ.get("REPORT_LIMIT", "30")), LIMIT_WINDOW_SECONDS)
SIMULATE_LIMITER = RateLimiter(int(os.environ.get("SIMULATE_LIMIT", "120")), LIMIT_WINDOW_SECONDS)


def rate_limited(limiter_name):
    """Refuse a visitor with 429 once they exceed the named limiter.

    The limiter is looked up by name at request time, so tests can swap it.
    """
    def decorate(view):
        @functools.wraps(view)
        def wrapper(*args, **kwargs):
            allowed, retry_after = globals()[limiter_name].allow(client_key(request))
            if not allowed:
                res = jsonify({"error": f"Too many requests. Please wait {retry_after} seconds and try again."})
                res.status_code = 429
                res.headers["Retry-After"] = str(retry_after)
                return res
            return view(*args, **kwargs)
        return wrapper
    return decorate


# Set by tools/pages/build_pages.py when rendering the GitHub Pages copy,
# which has no MATLAB: the Simulink page then runs in the browser and the
# scan page points visitors at the live server instead.
app.config.setdefault("STATIC_SITE", False)

# The GitHub Pages site may ask the live server whether it is up.
PAGES_ORIGIN = os.environ.get("PAGES_ORIGIN", "https://shaurya-web548.github.io")


def _github_slug(url: str) -> str:
    url = (url or "").rstrip("/")
    return url.split("github.com/")[-1] if "github.com/" in url else ""


def _live_url(value) -> str:
    """The permanent live-server address from team.json, if it is a bare
    https:// origin. Anything else is dropped, since the scan page links to it."""
    url = (value or "").strip().rstrip("/")
    return url if re.fullmatch(r"https://[a-z0-9.-]+\.[a-z]{2,}", url) else ""


@app.context_processor
def site_mode():
    """Values every template may need. The live-status file lives in the
    public site repository, because the code repository may be private."""
    project = load_team().get("project", {})
    live_repo = project.get("siteRepository") or project.get("repository")
    return {
        "static_site": app.config["STATIC_SITE"],
        "repo_slug": _github_slug(live_repo),
        "project": project,
        "show_source_links": bool(project.get("showSourceLinks")),
        "live_url": _live_url(project.get("liveUrl")),
    }


@app.after_request
def security_headers(response):
    """Conservative defaults for a site reachable from the internet."""
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    response.headers.setdefault("X-Frame-Options", "DENY")
    response.headers.setdefault("Referrer-Policy", "strict-origin-when-cross-origin")
    return response


def _allowed(filename):
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXT


def _first_line(exc: Exception) -> str:
    """A short, readable reason for the browser; the full error is logged."""
    text = str(exc).strip()
    return text.splitlines()[-1] if text else exc.__class__.__name__


# ---------------------------------------------------------------- pages

@app.route("/")
def landing():
    return render_template("landing.html", page="home")


@app.route("/scan")
def scan_page():
    return render_template("scan.html", page="scan")


@app.route("/how-it-works")
def how_it_works():
    return render_template("how_it_works.html", page="how")


@app.route("/simulink")
def simulink_page():
    return render_template("simulink.html", page="simulink")


@app.route("/about")
def about():
    return render_template("about.html", page="about", team=load_team())


# ------------------------------------------------------------------ API

@app.route("/api/health")
def health():
    """Tiny liveness check. The GitHub Pages site calls it cross-origin to
    decide whether to offer the live screening link, so it allows exactly that
    one origin and nothing else."""
    res = jsonify({"ok": True})
    res.headers["Access-Control-Allow-Origin"] = PAGES_ORIGIN
    res.headers["Cache-Control"] = "no-store"
    return res


@app.route("/api/scan", methods=["POST"])
@rate_limited("SCAN_LIMITER")
def scan():
    purge_old_results(RESULTS_DIR, RESULTS_MAX_AGE_HOURS, SCANS)
    if "image" not in request.files:
        return jsonify({"error": "No image uploaded."}), 400
    f = request.files["image"]
    if f.filename == "" or not _allowed(f.filename):
        return jsonify({"error": "Please upload a PNG or JPG fundus image."}), 400

    scan_id = uuid.uuid4().hex[:12]
    scan_dir = os.path.join(RESULTS_DIR, scan_id)
    os.makedirs(scan_dir, exist_ok=True)

    ext = f.filename.rsplit(".", 1)[1].lower()
    image_filename = f"original.{ext}"
    image_path = os.path.join(scan_dir, image_filename)
    f.save(image_path)

    try:
        bridge = get_bridge()
        report = bridge.run_pipeline(image_path, scan_dir)
    except Exception as exc:                                    # noqa: BLE001
        log.exception("Pipeline failed for scan %s", scan_id)
        return jsonify({"error": f"Pipeline failed: {_first_line(exc)}"}), 500

    if report.get("mode") == "rejected":
        return jsonify({
            "scan_id": scan_id,
            "mode": "rejected",
            "message": report.get("error", "Image quality too low for grading."),
        }), 200

    SCANS[scan_id] = report

    grade = report["decision"]["grade"]
    response = {
        "scan_id": scan_id,
        "mode": report["mode"],
        "grade": grade,
        "grade_label": GRADE_LABELS.get(grade, "Unknown"),
        "referable": report["decision"].get("referable", grade >= 2),
        "confidence": report.get("confidence"),
        "overlay_url": url_for("serve_result", scan_id=scan_id, filename="lesion_overlay.png") if report.get("overlayPath") else None,
        "gradcam_url": url_for("serve_result", scan_id=scan_id, filename="gradcam.png") if report.get("heatmapPath") else None,
        "original_url": url_for("serve_result", scan_id=scan_id, filename=image_filename),
    }
    return jsonify(response)


@app.route("/results/<scan_id>/<path:filename>")
def serve_result(scan_id, filename):
    # send_from_directory refuses paths that escape the folder, and the scan
    # id check stops '..' or an absolute path from choosing the folder.
    if not is_valid_scan_id(scan_id):
        abort(404)
    return send_from_directory(os.path.join(RESULTS_DIR, scan_id), filename)


@app.route("/api/report/<scan_id>")
@rate_limited("REPORT_LIMITER")
def report(scan_id):
    if not is_valid_scan_id(scan_id) or scan_id not in SCANS:
        return jsonify({"error": "Unknown scan_id."}), 404
    try:
        patient = validate_patient(request.args)
    except ValidationError as exc:
        return jsonify({"error": str(exc)}), 400

    patient_info = {**patient, "scan_id": scan_id}
    pdf_path = os.path.join(RESULTS_DIR, scan_id, "report.pdf")
    generate_pdf(SCANS[scan_id], patient_info, pdf_path)
    return send_file(pdf_path, as_attachment=True, download_name=f"DRishti_report_{scan_id}.pdf")


@app.route("/api/simulate", methods=["POST"])
@rate_limited("SIMULATE_LIMITER")
def simulate():
    try:
        overrides = validate_scenario(request.get_json(silent=True))
    except ValidationError as exc:
        return jsonify({"error": str(exc)}), 400

    try:
        result = get_bridge().run_capacity_scenario(overrides)
    except Exception as exc:                                    # noqa: BLE001
        log.exception("Capacity scenario failed: %s", overrides)
        return jsonify({"error": f"Simulation failed: {_first_line(exc)}"}), 500

    return jsonify(result)


if __name__ == "__main__":
    app.run(debug=True, port=5000)
