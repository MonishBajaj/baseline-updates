import { BOTH_COLORS, IRRIGATION_COLORS, WILDLIFE_COLORS } from '@/constants';
import type { IntensityData, PrevalenceData, SweepThresholdByMonth } from '@/types';

export type SweepId =
  | 'wildlife_intensity'
  | 'irrigation_intensity'
  | 'wildlife_prevalence'
  | 'irrigation_prevalence'
  | 'both_prevalence';

export const SWEEPS: {
  id: SweepId;
  label: string;
  group: 'Intensity' | 'Prevalence';
  description: string;
}[] = [
  {
    id: 'wildlife_intensity',
    label: 'Wildlife intensity',
    group: 'Intensity',
    description: 'Wildlife fecal load 20–200%; irrigation held at 100%.',
  },
  {
    id: 'irrigation_intensity',
    label: 'Irrigation intensity',
    group: 'Intensity',
    description: 'Irrigation CFU 20–200%; wildlife held at 100%.',
  },
  {
    id: 'wildlife_prevalence',
    label: 'Wildlife prevalence',
    group: 'Prevalence',
    description: 'Chance a wildlife event is contaminated, 0–100%.',
  },
  {
    id: 'irrigation_prevalence',
    label: 'Irrigation prevalence',
    group: 'Prevalence',
    description: 'Chance an irrigation event is contaminated, 0–100%.',
  },
  {
    id: 'both_prevalence',
    label: 'Combined prevalence',
    group: 'Prevalence',
    description: 'Both sources share the same contamination probability.',
  },
];

const EMPTY_DAYS = Array.from({ length: 365 }, () => 0);
const EMPTY_MONTH_THRESH = Array.from({ length: 12 }, () => [0, 0, 0, 0]);

export function dailyRow(rows: number[][] | undefined, idx: number): number[] {
  const row = rows?.[idx];
  return Array.isArray(row) && row.length > 0 ? row : EMPTY_DAYS;
}

export function monthThreshRow(block: SweepThresholdByMonth | undefined, idx: number): number[][] {
  const level = block?.meanPct?.[idx];
  if (!Array.isArray(level) || level.length === 0) return EMPTY_MONTH_THRESH;
  return level;
}

export function colorsForSweep(id: SweepId): string[] {
  if (id === 'irrigation_intensity' || id === 'irrigation_prevalence') return IRRIGATION_COLORS;
  if (id === 'both_prevalence') return BOTH_COLORS;
  return WILDLIFE_COLORS;
}

export function referenceIndex(labels: string[]): number {
  const exact = labels.findIndex((label) => label === '100%');
  return exact >= 0 ? exact : Math.max(0, labels.length - 1);
}

export interface SweepView {
  id: SweepId;
  title: string;
  description: string;
  labels: string[];
  dailyP50: number[][];
  thresholdByMonth?: SweepThresholdByMonth;
  harvestMedian?: number[];
}

export interface SweepSources {
  wildlife: IntensityData | null;
  irrigation: IntensityData | null;
  wildlifePrevalence: PrevalenceData | null;
  irrigationPrevalence: PrevalenceData | null;
  bothPrevalence: PrevalenceData | null;
}

export function buildSweep(id: SweepId, sources: SweepSources): SweepView | null {
  const meta = SWEEPS.find((s) => s.id === id);
  if (!meta) return null;

  if (id === 'wildlife_intensity' && sources.wildlife) {
    return {
      id,
      title: meta.label,
      description: meta.description,
      labels: sources.wildlife.labels,
      dailyP50: sources.wildlife.daily.p50,
      thresholdByMonth: sources.wildlife.thresholdByMonth,
      harvestMedian: sources.wildlife.harvestDay.median,
    };
  }
  if (id === 'irrigation_intensity' && sources.irrigation) {
    return {
      id,
      title: meta.label,
      description: meta.description,
      labels: sources.irrigation.labels,
      dailyP50: sources.irrigation.daily.p50,
      thresholdByMonth: sources.irrigation.thresholdByMonth,
      harvestMedian: sources.irrigation.harvestDay.median,
    };
  }
  if (id === 'wildlife_prevalence' && sources.wildlifePrevalence) {
    return {
      id,
      title: meta.label,
      description: meta.description,
      labels: sources.wildlifePrevalence.labels,
      dailyP50: sources.wildlifePrevalence.daily.p50,
      thresholdByMonth: sources.wildlifePrevalence.thresholdByMonth,
      harvestMedian: sources.wildlifePrevalence.harvestDay.median,
    };
  }
  if (id === 'irrigation_prevalence' && sources.irrigationPrevalence) {
    return {
      id,
      title: meta.label,
      description: meta.description,
      labels: sources.irrigationPrevalence.labels,
      dailyP50: sources.irrigationPrevalence.daily.p50,
      thresholdByMonth: sources.irrigationPrevalence.thresholdByMonth,
      harvestMedian: sources.irrigationPrevalence.harvestDay.median,
    };
  }
  if (id === 'both_prevalence' && sources.bothPrevalence) {
    return {
      id,
      title: meta.label,
      description: meta.description,
      labels: sources.bothPrevalence.labels,
      dailyP50: sources.bothPrevalence.daily.p50,
      thresholdByMonth: sources.bothPrevalence.thresholdByMonth,
      harvestMedian: sources.bothPrevalence.harvestDay.median,
    };
  }
  return null;
}
