"""
retention.py - delete uploaded scans after a fixed time.

Once the site is public, visitors may upload real patients' eye photographs.
Nothing needs them after the report has been downloaded, so scan folders are
removed once they are older than RESULTS_MAX_AGE_HOURS (24 by default).
"""

import logging
import os
import shutil
import time

from validation import is_valid_scan_id

log = logging.getLogger(__name__)


def purge_old_results(results_dir: str, max_age_hours: float, scans: dict, now=None) -> list:
    """Remove scan folders older than max_age_hours and forget them in `scans`.

    Only folders whose names are genuine scan ids are ever touched, so a
    misconfigured results_dir cannot make this delete anything else.
    Returns the ids that were removed.
    """
    if max_age_hours <= 0 or not os.path.isdir(results_dir):
        return []
    cutoff = (now if now is not None else time.time()) - max_age_hours * 3600
    removed = []
    for name in os.listdir(results_dir):
        path = os.path.join(results_dir, name)
        if not (is_valid_scan_id(name) and os.path.isdir(path)):
            continue
        try:
            if os.path.getmtime(path) >= cutoff:
                continue
            shutil.rmtree(path)
        except OSError as exc:
            log.warning("Could not remove old scan %s: %s", name, exc)
            continue
        scans.pop(name, None)
        removed.append(name)
    if removed:
        log.info("Removed %d scan(s) older than %s h", len(removed), max_age_hours)
    return removed
