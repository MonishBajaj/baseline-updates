"""WSGI app for Render: serve the static Vite build from dashboard/dist."""

from __future__ import annotations

import os
from pathlib import Path

from flask import Flask, abort, send_from_directory
from whitenoise import WhiteNoise

DIST_DIR = Path(__file__).resolve().parent / "dashboard" / "dist"

app = Flask(__name__, static_folder=None)


@app.get("/")
def index():
    if not (DIST_DIR / "index.html").is_file():
        abort(
            503,
            description=(
                "dashboard/dist is missing. Build with: "
                "cd dashboard && VITE_DATA_MODE=static VITE_BASE_PATH=/ npm run build:static"
            ),
        )
    return send_from_directory(DIST_DIR, "index.html")


@app.get("/<path:path>")
def spa(path: str):
    """Serve built assets; fall back to index.html for client-side routes."""
    target = (DIST_DIR / path).resolve()
    try:
        target.relative_to(DIST_DIR.resolve())
    except ValueError:
        abort(404)
    if target.is_file():
        return send_from_directory(DIST_DIR, path)
    if (DIST_DIR / "index.html").is_file():
        return send_from_directory(DIST_DIR, "index.html")
    abort(404)


# WhiteNoise serves hashed assets efficiently; unknown paths fall through to Flask.
app.wsgi_app = WhiteNoise(app.wsgi_app, root=str(DIST_DIR), index_file=True)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "10000"))
    app.run(host="0.0.0.0", port=port)
