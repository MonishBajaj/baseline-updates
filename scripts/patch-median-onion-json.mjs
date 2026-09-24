/**
 * Patch baseline/scenario JSON exports with medianSoilCFU + medianOnionCFU.
 * Does not alter model outputs — only adds explicit summary fields and updates medianCFU KPI.
 */
import fs from 'node:fs';
import path from 'node:path';

function medianOnionCFUFromHistogram(summary, histogram) {
  const { counts, edges } = histogram;
  const n = summary.iterations * summary.totalPlants;
  if (n <= 0 || !counts?.length) return 0;

  const nPositive = counts.reduce((sum, c) => sum + c, 0);
  const nZero = n - nPositive;

  const pos1 = n / 2;
  const pos2 = n / 2 + 1;
  let cum = nZero;
  let v1 = pos1 <= nZero ? 0 : null;
  let v2 = pos2 <= nZero ? 0 : null;

  for (let i = 0; i < counts.length; i++) {
    const logLo = edges[i];
    const logHi = edges[i + 1];
    const cfu = Math.sqrt(10 ** logLo * 10 ** logHi);
    cum += counts[i];
    if (v1 === null && pos1 <= cum) v1 = cfu;
    if (v2 === null && pos2 <= cum) v2 = cfu;
  }

  if (v1 === null || v2 === null) return 0;
  return (v1 + v2) / 2;
}

function patchFile(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8');
  const data = JSON.parse(raw);
  if (!data.summary || !data.histograms?.combinedLog10) {
    return { filePath, skipped: true };
  }

  if (typeof data.summary.medianSoilCFU !== 'number') {
    data.summary.medianSoilCFU = data.summary.medianCFU;
  }

  const medianSoilCFU = data.summary.medianSoilCFU;
  const medianOnionCFU = medianOnionCFUFromHistogram(data.summary, data.histograms.combinedLog10);

  data.summary.medianOnionCFU = medianOnionCFU;
  data.summary.medianCFU = medianOnionCFU;

  fs.writeFileSync(filePath, JSON.stringify(data, null, 2) + '\n');
  return {
    filePath,
    skipped: false,
    medianSoilCFU,
    medianOnionCFU,
  };
}

const root = path.resolve(import.meta.dirname, '..');
const dirs = [
  path.join(root, 'dashboard/public/data'),
  path.join(root, 'dashboard/dist/data'),
  path.join(root, 'export (2)'),
];

const results = [];
for (const dir of dirs) {
  if (!fs.existsSync(dir)) continue;
  for (const name of fs.readdirSync(dir)) {
    if (!name.endsWith('.json')) continue;
    results.push(patchFile(path.join(dir, name)));
  }
}

for (const r of results) {
  if (r.skipped) {
    console.log(`skip ${r.filePath}`);
  } else {
    console.log(
      `patched ${r.filePath}: soil=${r.medianSoilCFU.toFixed(6)} onion=${r.medianOnionCFU.toFixed(6)}`,
    );
  }
}
