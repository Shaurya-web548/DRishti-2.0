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

import logging
import os
import uuid

from flask import (Flask, abort, jsonify, render_template, request,
                   send_file, send_from_directory, url_for)

from matlab_bridge import get_bridge
from report_generator import generate_pdf
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

@app.route("/api/scan", methods=["POST"])
def scan():
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
