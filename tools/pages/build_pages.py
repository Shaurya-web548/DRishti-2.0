"""
build_pages.py - render the DRishti web app into a static site for GitHub Pages.

    python tools/pages/build_pages.py              -> site/
    python tools/pages/build_pages.py --base /DRishti-site --out site

The same Flask templates are rendered with STATIC_SITE on, which makes:
  - the Simulink page run the JavaScript ports of the models in the browser;
  - the scan page check whether the live server is up and link to it.

MATLAB is not needed: the MATLAB Engine module is replaced by a stub before
the app is imported, so this also runs on GitHub's build machines.
"""

import argparse
import os
import shutil
import sys
import types

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
APP_DIR = os.path.join(ROOT, "app", "python")

PAGES = {
    "/": "index.html",
    "/scan": "scan/index.html",
    "/how-it-works": "how-it-works/index.html",
    "/simulink": "simulink/index.html",
    "/about": "about/index.html",
}

# Only the new site's assets; the pre-2.0 style.css/app.js are not used.
STATIC_SUBDIRS = ("css", "js")


def stub_matlab():
    """Let app.py import without the MATLAB Engine installed."""
    matlab = types.ModuleType("matlab")
    matlab.engine = types.ModuleType("matlab.engine")
    sys.modules.setdefault("matlab", matlab)
    sys.modules.setdefault("matlab.engine", matlab.engine)


def build(base: str, out: str) -> None:
    stub_matlab()
    sys.path.insert(0, APP_DIR)
    import app as app_module  # noqa: E402  (after the stub)

    app = app_module.app
    saved = {k: app.config.get(k) for k in ("STATIC_SITE", "TESTING")}
    app.config.update(STATIC_SITE=True, TESTING=True)
    try:
        _render(app, base, out)
    finally:
        app.config.update(saved)


def _render(app, base: str, out: str) -> None:
    if os.path.isdir(out):
        shutil.rmtree(out)
    os.makedirs(out)

    base = "/" + base.strip("/") if base.strip("/") else ""
    with app.test_client() as client:
        for route, target in PAGES.items():
            res = client.get(route, base_url=f"http://localhost{base}/")
            if res.status_code != 200:
                raise SystemExit(f"{route} rendered HTTP {res.status_code}")
            html = res.get_data(as_text=True)
            path = os.path.join(out, target)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(html)
            print(f"  {route:15s} -> {target}")

    for sub in STATIC_SUBDIRS:
        shutil.copytree(os.path.join(APP_DIR, "static", sub), os.path.join(out, "static", sub))

    # A 404 page that sends lost visitors home, and no Jekyll processing.
    shutil.copyfile(os.path.join(out, "index.html"), os.path.join(out, "404.html"))
    open(os.path.join(out, ".nojekyll"), "w").close()
    print(f"Built static site in {out} (base path '{base or '/'}')")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    parser.add_argument("--base", default=os.environ.get("PAGES_BASE_PATH", "/DRishti-site"),
                        help="URL path the site is served under (GitHub project pages: /<repo>)")
    parser.add_argument("--out", default=os.path.join(ROOT, "site"), help="output folder")
    args = parser.parse_args()
    build(args.base, os.path.abspath(args.out))


if __name__ == "__main__":
    main()
