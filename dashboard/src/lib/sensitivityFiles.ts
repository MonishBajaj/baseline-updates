import { withBase } from '@/lib/publicUrl';

/** Canonical names preferred when a full Scenario run is copied into public/data/. */
export const SENSITIVITY_CANONICAL_FILES = {
  wildlifeIntensity: 'wildlife_intensity.json',
  irrigationIntensity: 'irrigation_intensity.json',
  wildlifePrevalence: 'wildlife_prevalence.json',
  irrigationPrevalence: 'irrigation_prevalence.json',
  bothPrevalence: 'both_prevalence.json',
} as const;

/** Pond/well 50% blend sensitivity export under public/data/export_fin_Sensitivity/. */
export const SENSITIVITY_TEST_FILES = {
  wildlifeIntensity: 'wildlife_intensity_pond_well_50pct.json',
  irrigationIntensity: 'irrigation_intensity_pond_well_50pct.json',
  wildlifePrevalence: 'wildlife_prevalence_pond_well_50pct.json',
  irrigationPrevalence: 'irrigation_prevalence_pond_well_50pct.json',
  bothPrevalence: 'both_prevalence_pond_well_50pct.json',
} as const;

const TEST_EXPORT_SEGMENTS = ['data', 'export_fin_Sensitivity'] as const;

export function sensitivityTestDataUrl(filename: string): string {
  return withBase([...TEST_EXPORT_SEGMENTS, filename].map(encodeURIComponent).join('/'));
}
