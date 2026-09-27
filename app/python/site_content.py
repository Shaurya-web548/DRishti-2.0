"""
site_content.py - editable page content that lives outside the templates.

The team roster is kept in content/team.json so it can be updated without
touching HTML, and so the project report generator reads the same source.
"""

import json
import logging
import os
import re

log = logging.getLogger(__name__)

CONTENT_DIR = os.path.join(os.path.abspath(os.path.dirname(__file__)), "content")
TEAM_FILE = os.path.join(CONTENT_DIR, "team.json")


def _initials(name: str) -> str:
    parts = [p for p in (name or "").split() if p]
    if not parts:
        return ""
    if len(parts) == 1:
        return parts[0][:2].upper()
    return (parts[0][0] + parts[-1][0]).upper()


_EMAIL_RE = re.compile(r"^[^@\s:/]+@[^@\s:/]+\.[^@\s:/]+$")


def _safe_url(value) -> str:
    """Only http(s) links reach an href. A 'javascript:' or other scheme
    pasted into team.json is dropped rather than rendered as a live link."""
    url = (value or "").strip()
    return url if url.lower().startswith(("https://", "http://")) else ""


def _safe_email(value) -> str:
    email = (value or "").strip()
    return email if _EMAIL_RE.match(email) else ""


def _with_display_fields(person: dict) -> dict:
    """Return a copy with the fields the templates need, never mutating the
    loaded JSON. Links are sanitised here because team.json is hand-edited."""
    name = (person.get("name") or "").strip()
    return {
        **person,
        "name": name,
        "initials": _initials(name),
        "has_name": bool(name),
        "github": _safe_url(person.get("github")),
        "linkedin": _safe_url(person.get("linkedin")),
        "photo": _safe_url(person.get("photo")),
        "email": _safe_email(person.get("email")),
    }


def load_team() -> dict:
    """Read team.json fresh on every call, so edits show up on the next page
    load without restarting the server. A missing or broken file yields an
    empty roster rather than a crashed About page."""
    try:
        with open(TEAM_FILE, "r", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError) as exc:
        log.warning("Could not read %s: %s", TEAM_FILE, exc)
        data = {}

    return {
        "project": data.get("project", {}),
        "mentors": [_with_display_fields(m) for m in data.get("mentors", [])],
        "members": [_with_display_fields(m) for m in data.get("members", [])],
    }
