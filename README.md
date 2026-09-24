# Vidalia Onion E. coli QMRA Dashboard

Interactive decision-support dashboard for the UGA FMRA Lab Vidalia onion
generic *E. coli* QMRA model. The React frontend reads pre-exported Monte Carlo
JSON (no live MATLAB or FastAPI server required for viewing results).

## Live URL

https://monishbajaj.github.io/baseline-updates/

## Repository

https://github.com/MonishBajaj/baseline-updates

## Run locally

### Prerequisites

- Node.js LTS and npm

### Static data mode (recommended — same as GitHub Pages)

All pages load simulation exports from `dashboard/public/data/`.

```bash
cd dashboard
cp .env.example .env   # optional; defaults already use static JSON
npm ci
npm run dev
```

Open http://localhost:5173/

### Production / Pages-style build

```bash
cd dashboard
VITE_DATA_MODE=static VITE_BASE_PATH=/ npm run build:static
npm run preview
```

For a GitHub Pages–shaped base path locally:

```bash
VITE_DATA_MODE=static VITE_BASE_PATH=/baseline-updates/ npm run build:static
npm run preview -- --base /baseline-updates/
```

### API mode

There is **no FastAPI backend** in this project. Setting `VITE_DATA_MODE=api`
is not supported; leave `VITE_DATA_MODE=static` (or unset).

MATLAB model sources (`Updated_Baseline.m`, `new_scenario/Scenario_Updated.m`)
are used offline to regenerate JSON; they are not invoked by the dashboard.

## Pages

| Page | Static mode |
| --- | --- |
| Introduction | Works (bundled images + text) |
| Baseline & Scenarios | Works for scenarios whose JSON is in `public/data/` |
| Sensitivity Analysis | Works (uses 2-iteration pond/well test export until full run is copied in) |
| Comparison | Placeholder only (UI not built yet) |
| References | Works |

Missing farm-characteristic JSONs (e.g. irrigation volume 25/50/75%, unmanaged water)
show “results not available” when selected — that is expected until those exports are added.
