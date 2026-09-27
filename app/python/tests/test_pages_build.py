"""The GitHub Pages build renders every page in static mode."""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.abspath(os.path.join(HERE, "..", "..", "..", "tools", "pages")))

import app as app_module  # noqa: E402
import build_pages  # noqa: E402


def _read(root, rel):
    with open(os.path.join(root, rel), encoding="utf-8") as fh:
        return fh.read()


def test_static_build(tmp_path):
    out = tmp_path / "site"
    build_pages.build("/DRishti-site", str(out))

    for rel in ["index.html", "scan/index.html", "how-it-works/index.html",
                "simulink/index.html", "about/index.html", "404.html", ".nojekyll",
                "static/js/capacity-engine.js", "static/css/base.css"]:
        assert (out / rel).exists(), rel

    home = _read(out, "index.html")
    assert 'href="/DRishti-site/static/css/base.css"' in home
    assert 'href="/DRishti-site/simulink"' in home

    sim = _read(out, "simulink/index.html")
    assert "window.DRISHTI_STATIC = true" in sim and "capacity-engine.js" in sim

    scan = _read(out, "scan/index.html")
    assert "live-status.js" in scan and 'data-repo="Shaurya-web548/DRishti-site"' in scan
    assert "scan.js" not in scan.replace("live-status.js", "")

    # code repos are private, so no source links on the public site
    assert "github.com/Shaurya-web548/DRishti-2.0" not in home
    assert 'href="https://shaurya-web548.github.io/DRishti-site/"' in home

    # the running app is back in normal mode afterwards
    assert app_module.app.config["STATIC_SITE"] is False


def test_health_endpoint_allows_only_the_pages_origin(client):
    res = client.get("/api/health")
    assert res.get_json() == {"ok": True}
    assert res.headers["Access-Control-Allow-Origin"] == "https://shaurya-web548.github.io"
    assert res.headers["Cache-Control"] == "no-store"
