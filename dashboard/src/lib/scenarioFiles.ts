import type { FarmCharacteristicsConfig } from '@/types';
import { withBase } from '@/lib/publicUrl';
import { DEFAULT_FARM_CHARACTERISTICS } from '@/store/scenarioStore';

/** Pre-exported single-parameter scenario runs in dashboard/public/data/. */
export const SCENARIO_JSON_FILES = [
  'baseline_fin.json',
  'baseline_deer.json',
  'baseline_boar.json',
  'baseline_feces_9.json',
  'baseline_curing_0.json',
  'baseline_curing_3.json',
  'baseline_curing_14_pond_well_50pct.json',
  'baseline_wildlife_3.json',
  'Wildlife_freq_7.json',
  'S_irrigation_stop at 0 d.json',
  'S_irrigation_stop at 10 d.json',
  'S_irrigation_FDA_not approved.json',
  'S_irrigation_unmanaged.json',
  'S_irrigation_runoff_no.json',
  'S_irrigation_volume_75pct.json',
  'S_irrigation_volume_50pct.json',
  'S_irrigation_volume_25pct.json',
  'S_soil amendment_HTPP.json',
  'S_soil amendment_PL.json',
] as const;

type ConfigKey = Exclude<keyof FarmCharacteristicsConfig, 'activeWildlifeParameter'>;

function differingKeys(config: FarmCharacteristicsConfig): ConfigKey[] {
  const d = DEFAULT_FARM_CHARACTERISTICS;
  const keys: ConfigKey[] = [
    'soilAmendment',
    'wildlifeType',
    'fecesDepositLocations',
    'wildlifeFrequencyDays',
    'irrigationStopDays',
    'irrigationVolumeFactor',
    'regulatoryStandard',
    'curingDays',
    'rainfallRunoff',
  ];
  return keys.filter((key) => config[key] !== d[key]);
}

/** Maps a single changed farm characteristic (vs baseline defaults) to its JSON export. */
export function resolveScenarioFilename(config: FarmCharacteristicsConfig): string | null {
  const diffs = differingKeys(config);
  if (diffs.length === 0) return 'baseline_fin.json';
  if (diffs.length > 1) return null;

  switch (diffs[0]) {
    case 'soilAmendment':
      if (config.soilAmendment === 'heat_treated_poultry_pellet') return 'S_soil amendment_HTPP.json';
      if (config.soilAmendment === 'poultry_litter') return 'S_soil amendment_PL.json';
      return null;
    case 'wildlifeType':
      if (config.wildlifeType === 'deer') return 'baseline_deer.json';
      if (config.wildlifeType === 'pig') return 'baseline_boar.json';
      return null;
    case 'fecesDepositLocations':
      if (config.fecesDepositLocations === 9) return 'baseline_feces_9.json';
      return null;
    case 'wildlifeFrequencyDays':
      if (config.wildlifeFrequencyDays === 3) return 'baseline_wildlife_3.json';
      if (config.wildlifeFrequencyDays === 7) return 'Wildlife_freq_7.json';
      return null;
    case 'irrigationStopDays':
      if (config.irrigationStopDays === 0) return 'S_irrigation_stop at 0 d.json';
      if (config.irrigationStopDays === 10) return 'S_irrigation_stop at 10 d.json';
      return null;
    case 'irrigationVolumeFactor':
      if (config.irrigationVolumeFactor === 0.75) return 'S_irrigation_volume_25pct.json';
      if (config.irrigationVolumeFactor === 0.5) return 'S_irrigation_volume_50pct.json';
      if (config.irrigationVolumeFactor === 0.25) return 'S_irrigation_volume_75pct.json';
      return null;
    case 'regulatoryStandard':
      if (config.regulatoryStandard === 'non_fda_approved') return 'S_irrigation_FDA_not approved.json';
      if (config.regulatoryStandard === 'unmanaged') return 'S_irrigation_unmanaged.json';
      return null;
    case 'curingDays':
      if (config.curingDays === 0) return 'baseline_curing_0.json';
      if (config.curingDays === 3) return 'baseline_curing_3.json';
      if (config.curingDays === 14) return 'baseline_curing_14_pond_well_50pct.json';
      return null;
    case 'rainfallRunoff':
      if (config.rainfallRunoff === 'no_runoff') return 'S_irrigation_runoff_no.json';
      return null;
    default:
      return null;
  }
}

export function scenarioDataUrl(filename: string): string {
  return withBase(`data/${encodeURIComponent(filename)}`);
}
