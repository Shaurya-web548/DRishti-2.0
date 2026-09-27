"""
validation.py - input checks at the web boundary.

Everything that arrives from the browser is checked here before it reaches
MATLAB or the PDF generator. Each validator returns clean values or raises
ValidationError with a message that is safe to show the user.
"""

import re

SCAN_ID_RE = re.compile(r"^[0-9a-f]{12}$")

MAX_TEXT_LEN = 80
MIN_AGE = 0
MAX_AGE = 120


class ValidationError(ValueError):
    """Raised when user input is rejected. The message is user-facing."""


def is_valid_scan_id(scan_id: str) -> bool:
    """Scan ids are the 12-hex-character tokens app.py generates. Anything
    else - including '..' or a path - is refused before touching the disk."""
    return bool(SCAN_ID_RE.match(scan_id or ""))


def _clean_text(value, field_label: str) -> str:
    text = (value or "").strip()
    if not text:
        return "-"
    if len(text) > MAX_TEXT_LEN:
        raise ValidationError(f"{field_label} must be {MAX_TEXT_LEN} characters or fewer.")
    return text


def parse_age(raw) -> str:
    """Age is optional. When given it must be a whole number from 0 to 120.

    Returned as a string because it is only ever printed on the report.
    """
    text = (raw or "").strip()
    if text in ("", "-"):
        return "-"
    if not re.fullmatch(r"[+-]?\d+", text):
        raise ValidationError("Age must be a whole number of years.")
    age = int(text)
    if age < MIN_AGE:
        raise ValidationError("Age cannot be negative.")
    if age > MAX_AGE:
        raise ValidationError(f"Age must be {MAX_AGE} or less.")
    return str(age)


def validate_patient(args) -> dict:
    """Patient details for the PDF report, from the query string."""
    return {
        "name": _clean_text(args.get("name"), "Patient name"),
        "age": parse_age(args.get("age")),
        "location": _clean_text(args.get("location"), "Clinic / location"),
    }


# name: (minimum, maximum, whole_number)
# Kept in step with allowedLimits() in capacity-model/drishtiRunScenario.m,
# which checks the same ranges again on the MATLAB side.
SCENARIO_LIMITS = {
    "annualPatients": (10_000, 400_000, True),
    "sites": (1, 30, True),
    "workers": (1, 16, True),
    "procMeanSec": (2, 180, False),
    "graderFTE": (0.5, 10, False),
    "ophthFTE": (0.25, 6, False),
    "uplinkMbps": (0.1, 50, False),
    "pReferable": (0.01, 0.40, False),
    "pDisagree": (0.0, 0.60, False),
}


def validate_scenario(payload) -> dict:
    """What-if parameters for the capacity model.

    Unknown keys, non-numbers, booleans and out-of-range values are all
    rejected rather than silently clamped, so the user always sees the
    scenario they asked for or a clear reason why not.
    """
    if payload is None:
        return {}
    if not isinstance(payload, dict):
        raise ValidationError("Scenario must be a JSON object of parameters.")

    clean = {}
    for key, value in payload.items():
        if key not in SCENARIO_LIMITS:
            raise ValidationError(f"Unknown parameter: {key}")
        low, high, whole = SCENARIO_LIMITS[key]
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            raise ValidationError(f"{key} must be a number.")
        if value != value or value in (float("inf"), float("-inf")):
            raise ValidationError(f"{key} must be a finite number.")
        if value < low or value > high:
            raise ValidationError(f"{key} must be between {low:g} and {high:g}.")
        clean[key] = int(round(value)) if whole else float(value)
    return clean
