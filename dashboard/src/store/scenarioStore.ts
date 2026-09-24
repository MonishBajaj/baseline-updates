import { create } from 'zustand';
import type { ActiveWildlifeParameter, FarmCharacteristicsConfig } from '@/types';

export type PageId = 'introduction' | 'baseline' | 'sensitivity' | 'comparison' | 'references';
export type Source = 'wildlife' | 'irrigation';

export const DEFAULT_FARM_CHARACTERISTICS: FarmCharacteristicsConfig = {
  soilAmendment: 'none',
  wildlifeType: 'both',
  fecesDepositLocations: 1,
  wildlifeFrequencyDays: 1,
  irrigationStopDays: 7,
  irrigationVolumeFactor: 1,
  regulatoryStandard: 'fda_approved',
  curingDays: 7,
  rainfallRunoff: 'with_runoff',
  activeWildlifeParameter: null,
};

export function isFarmCharacteristicsDefault(config: FarmCharacteristicsConfig): boolean {
  return (
    config.soilAmendment === DEFAULT_FARM_CHARACTERISTICS.soilAmendment &&
    config.wildlifeType === DEFAULT_FARM_CHARACTERISTICS.wildlifeType &&
    config.fecesDepositLocations === DEFAULT_FARM_CHARACTERISTICS.fecesDepositLocations &&
    config.wildlifeFrequencyDays === DEFAULT_FARM_CHARACTERISTICS.wildlifeFrequencyDays &&
    config.irrigationStopDays === DEFAULT_FARM_CHARACTERISTICS.irrigationStopDays &&
    config.irrigationVolumeFactor === DEFAULT_FARM_CHARACTERISTICS.irrigationVolumeFactor &&
    config.regulatoryStandard === DEFAULT_FARM_CHARACTERISTICS.regulatoryStandard &&
    config.curingDays === DEFAULT_FARM_CHARACTERISTICS.curingDays &&
    config.rainfallRunoff === DEFAULT_FARM_CHARACTERISTICS.rainfallRunoff &&
    config.activeWildlifeParameter === DEFAULT_FARM_CHARACTERISTICS.activeWildlifeParameter
  );
}

export type FarmCharacteristicKey = Exclude<keyof FarmCharacteristicsConfig, 'activeWildlifeParameter'>;

/** Each scenario JSON varies one parameter from baseline; reset all others on every change. */
export function applySingleParameterScenario<K extends FarmCharacteristicKey>(
  key: K,
  value: FarmCharacteristicsConfig[K],
): FarmCharacteristicsConfig {
  const activeWildlifeParameter: ActiveWildlifeParameter =
    key === 'wildlifeType' || key === 'fecesDepositLocations' || key === 'wildlifeFrequencyDays' ? key : null;

  return {
    ...DEFAULT_FARM_CHARACTERISTICS,
    [key]: value,
    activeWildlifeParameter,
  };
}

interface ScenarioState {
  activeTab: PageId;
  setActiveTab: (tab: PageId) => void;

  // Intensity selection (reserved for Sensitivity / Comparison pages)
  source: Source;
  setSource: (source: Source) => void;
  levelIdx: number;
  setLevelIdx: (idx: number) => void;

  // Farm Characteristics — one parameter varies from baseline at a time
  farmCharacteristics: FarmCharacteristicsConfig;
  setFarmCharacteristic: <K extends FarmCharacteristicKey>(
    key: K,
    value: FarmCharacteristicsConfig[K],
  ) => void;
}

export const useScenarioStore = create<ScenarioState>((set) => ({
  activeTab: 'introduction',
  setActiveTab: (tab) => set({ activeTab: tab }),

  source: 'irrigation',
  setSource: (source) => set({ source }),
  levelIdx: 4,
  setLevelIdx: (levelIdx) => set({ levelIdx }),

  farmCharacteristics: DEFAULT_FARM_CHARACTERISTICS,
  setFarmCharacteristic: (key, value) =>
    set({ farmCharacteristics: applySingleParameterScenario(key, value) }),
}));
