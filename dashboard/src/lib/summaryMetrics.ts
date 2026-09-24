import { PREVALENCE_LOD } from '@/constants';
import type { BaselineData } from '@/types';

type LogHistogram = { counts: number[]; edges: number[] };

/** Median harvest onion-surface CFU/plant from combined positive CFU histogram (MATLAB export). */
export function medianOnionCFUFromHistogram(
  summary: BaselineData['summary'],
  histogram: LogHistogram,
): number {
  const { counts, edges } = histogram;
  const n = summary.iterations * summary.totalPlants;
  if (n <= 0 || counts.length === 0) return 0;

  const nPositive = counts.reduce((sum, c) => sum + c, 0);
  const nZero = n - nPositive;

  const pos1 = n / 2;
  const pos2 = n / 2 + 1;
  let cum = nZero;
  let v1: number | null = pos1 <= nZero ? 0 : null;
  let v2: number | null = pos2 <= nZero ? 0 : null;

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

/** Share of plants with harvest onion-surface CFU >= lod (matches MATLAB >= LOD). */
export function prevalenceAtLodFromHistogram(
  summary: BaselineData['summary'],
  histogram: LogHistogram,
  lod: number,
): number {
  const { counts, edges } = histogram;
  const total = summary.iterations * summary.totalPlants;
  if (total <= 0 || counts.length === 0) return 0;

  const lodLog = Math.log10(lod);
  let nAtOrAboveLod = 0;

  for (let i = 0; i < counts.length; i++) {
    const logLo = edges[i];
    const logHi = edges[i + 1];
    if (logHi <= lodLog) continue;
    if (logLo >= lodLog) {
      nAtOrAboveLod += counts[i];
    } else {
      const frac = (logHi - lodLog) / (logHi - logLo);
      nAtOrAboveLod += counts[i] * frac;
    }
  }

  return (nAtOrAboveLod / total) * 100;
}

/** Headline KPI: overall onion-surface prevalence at PREVALENCE_LOD. */
export function getOverallPrevalencePct(data: BaselineData): number {
  const lod = PREVALENCE_LOD;
  if (typeof data.summary.overallPrevalencePct === 'number' && data.summary.lod === lod) {
    return data.summary.overallPrevalencePct;
  }
  if (data.histograms?.combinedLog10?.counts?.length) {
    return prevalenceAtLodFromHistogram(data.summary, data.histograms.combinedLog10, lod);
  }
  return data.summary.overallPrevalencePct;
}

/** Headline KPI: median onion-surface CFU per plant at harvest. */
export function getMedianOnionCFUPerPlant(data: BaselineData): number {
  if (typeof data.summary.medianOnionCFU === 'number') {
    return data.summary.medianOnionCFU;
  }
  if (typeof data.summary.medianSoilCFU === 'number') {
    return medianOnionCFUFromHistogram(data.summary, data.histograms.combinedLog10);
  }
  return medianOnionCFUFromHistogram(data.summary, data.histograms.combinedLog10);
}
