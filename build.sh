#!/usr/bin/env bash
# Render (or local) build: install Node, build Vite dashboard, install Python deps.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

echo "==> Installing Node.js 20 (if needed)"
if ! command -v node >/dev/null 2>&1 || [[ "$(node -v 2>/dev/null | sed 's/^v//' | cut -d. -f1)" -lt 18 ]]; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi

echo "==> Node $(node -v) / npm $(npm -v)"

echo "==> Building dashboard (static)"
cd dashboard
npm ci
export VITE_DATA_MODE=static
export VITE_BASE_PATH=/
npm run build:static

if [[ ! -f dist/index.html ]]; then
  echo "ERROR: dashboard/dist/index.html was not created" >&2
  exit 1
fi
echo "==> Built dashboard/dist ($(du -sh dist | cut -f1))"
cd "$ROOT"

echo "==> Installing Python dependencies"
python -m pip install --upgrade pip
python -m pip install -r requirements.txt

echo "==> Build complete"
