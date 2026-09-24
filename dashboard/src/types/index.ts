// Shared data-shape contracts for the QMRA dashboard.
// These mirror exactly what Updated_Baseline.m / Scenario_Updated.m write to
// export/*.json via jsonencode — see "SECTION: EXPORT TO JSON" in each file.

export interface PercentileBand {
  min: number[];
  p05: number[];
  p25: number[];
  p50: number[];
  p75: number[];
  p95: number[];
  max: number[];
}

export interface ThresholdByMonth {
  thresholds: number[]; // [1, 5, 10, 20]
  months: string[]; // Jul-start order, length 12
  activeMonths: string[]; // months where harvests actually land
  mean: number[][]; // [12 months][4 thresholds]
  meanPct: number[][]; // [12 months][4 thresholds], as % of plantnum
  quartiles?: number[][][]; // [12 months][4 thresholds][p25/median/p75/max]
  quartileLabels?: string[];
}

/** Mirrors wildlifeIntrusion block in baseline_fin.json / scenarios.json. */
export interface WildlifeIntrusionSettings {
  useSchedule: boolean;
  intervalDays: number;
  /** Number of plant locations per pooping event; total CFU conserved. Optional for older exports. */
  fecesDepositLocations?: 1 | 9;
  note: string;
}

/** Mirrors waterQuality block (FDA GM/STV gate for surface irrigation water). */
export interface WaterQualitySettings {
  scenario?: 'fda' | 'non_fda' | 'unmanaged';
  /** null for unmanaged water, where compliance varies by iteration. */
  meetsFda: boolean | null;
  gmLimit: number;
  stvLimit: number;
  gmMean?: number;
  gmMin?: number;
  gmMax?: number;
  stvMean?: number;
  stvMin?: number;
  stvMax?: number;
  note?: string;
}

// --- baseline_fin.json (produced by Updated_Baseline.m) ---
export interface BaselineData {
  parameter: 'baseline';
  daily: PercentileBand;
  monthly: PercentileBand & {
    irrigationPathway: number[]; // mean CFU contributed by irrigation, per month
    soilPathway: number[]; // mean CFU contributed by soil/wildlife transfer, per month
    months: string[];
    meanCrop1: number[];
    meanIrrigation: number[];
    meanSoil: number[];
    prevalencePct: number[];
  };
  summary: {
    meanCFU: number;
    /** Harvest onion-surface CFU/plant (headline KPI). Legacy exports used soil median here. */
    medianCFU: number;
    /** Year-round field-mean soil CFU (median over all days and iterations). */
    medianSoilCFU?: number;
    /** Harvest onion-surface CFU/plant (median over all plants and iterations). */
    medianOnionCFU?: number;
    maxCFU: number;
    stdCFU: number;
    lod: number;
    overallPrevalencePct: number;
    totalPlants: number;
    iterations: number;
  };
  pathwayContribution: {
    irrigationPct: number;
    soilPct: number;
  };
  /** Harvest onion-surface CFU by contamination source (proportional soil tagging). */
  sourceContribution?: {
    wildlifePct: number;
    irrigationPct: number;
    carryoverPct: number;
    note?: string;
  };
  irrigationDaily: PercentileBand;
  soilPathwayDaily: PercentileBand;
  thresholdByMonth: ThresholdByMonth;
  curingDecay: {
    k: number[];
    mpn0: number[];
    mpn14: number[];
    /** Legacy: curing length undercut→harvest (same as curingDays). */
    irrStopDay: number;
    curingDays?: number;
    irrStopBeforeUndercutDays?: number;
    kMean: number;
    kStd: number;
    mpn14Mean: number;
    mpn14Std: number;
    fractionZero: number;
  };
  /** Irrigation stop before undercut + curing undercut→harvest. Optional for older exports. */
  harvestTiming?: {
    irrStopBeforeUndercutDays: number;
    curingDays: number;
    note?: string;
  };
  curingPeriod: {
    soilCFU: PercentileBand;
    daysRelativeToHarvest: number[];
    thresholdExceedance: {
      mean: number[];
      meanPct: number[];
      thresholds: number[];
      daysRelativeToHarvest: number[];
    };
  };
  onionSurface: {
    min: number[];
    p05: number[];
    p25: number[];
    p50: number[];
    p75: number[];
    p95: number[];
    max: number[];
    maxDuration: number;
    medianIrrStop: number;
    medianTotal: number;
    medianIrrigComp: number;
    medianSoilComp: number;
  };
  histograms: {
    irrigationLog10: { counts: number[]; edges: number[] };
    soilLog10: { counts: number[]; edges: number[] };
    combinedLog10: { counts: number[]; edges: number[] };
  };
  /** Additive species attribution (irrigation ON). Optional for older exports. */
  wildlifeSpecies?: {
    irrigationIncluded: boolean;
    note: string;
    both: { daily: PercentileBand };
    deerOnly: { daily: PercentileBand };
    boarOnly: { daily: PercentileBand };
    summary: {
      meanBoth: number;
      meanDeerOnly: number;
      meanBoarOnly: number;
      deerPctOfBoth: number;
      boarPctOfBoth: number;
    };
  };
  /** Manual wildlife intrusion schedule settings. Optional for older exports. */
  wildlifeIntrusion?: WildlifeIntrusionSettings;
  /** Surface water FDA GM/STV gate. Optional for older exports. */
  waterQuality?: WaterQualitySettings;
  /** Rainfall CFU gain in irrigation water. Optional for older exports. */
  rainfallRunoff?: {
    useRainfallCfuGain: boolean;
    note?: string;
  };
}

// --- scenarios.json (produced by Scenario_Updated.m, Section 12) ---
export interface WildlifeSpeciesSummary {
  meanBoth: number;
  meanDeerOnly: number;
  meanBoarOnly: number;
  deerPctOfBoth: number;
  boarPctOfBoth: number;
}

export interface ScenariosData {
  irrigationOnly: { daily: PercentileBand };
  wildlifeOnly: { daily: PercentileBand };
  baseline: { daily: PercentileBand };
  /** Additive species attribution (irrigation OFF). Optional for older exports. */
  deerOnly?: { daily: PercentileBand };
  boarOnly?: { daily: PercentileBand };
  wildlifeSpecies?: {
    irrigationIncluded: boolean;
    note: string;
    both: { daily: PercentileBand };
    summary: WildlifeSpeciesSummary;
  };
  wildlifeIntrusion?: WildlifeIntrusionSettings;
  harvestTiming?: {
    irrStopBeforeUndercutDays: number;
    curingDays: number;
    note?: string;
  };
  waterQuality?: WaterQualitySettings;
}

// Shared 3-D harvest-threshold block used by intensity and prevalence sweeps.
export interface SweepThresholdByMonth {
  thresholds: number[]; // [1, 5, 10, 20]
  months: string[];
  activeMonths: string[];
  mean: number[][][]; // [levels][12 months][4 thresholds]
  meanPct: number[][][]; // [levels][12 months][4 thresholds]
  itersPerMonth: number[][]; // [levels][12 months]
  overallMean: number[][]; // [levels][4 thresholds]
  levels: string[];
}

// --- wildlife_intensity.json / irrigation_intensity.json (Section 13) ---
export interface IntensityData {
  parameter: 'wildlife_intensity' | 'irrigation_intensity';
  levels: number[]; // [0.2 ... 2.0], 10 entries
  labels: string[]; // ["20%", ..., "200%"], 10 entries
  daily: {
    min: number[][];
    p05: number[][];
    p25: number[][];
    p50: number[][];
    p75: number[][];
    p95: number[][];
    max: number[][];
  }; // each [10 levels][365 days]
  monthly: {
    min: number[][];
    p05: number[][];
    p25: number[][];
    p50: number[][];
    p75: number[][];
    p95: number[][];
    max: number[][];
  }; // each [10 levels][12 months]
  harvestDay: {
    median: number[]; // [10 levels]
    pctChangeFromBaseline: number[]; // [10 levels], vs level index 4 (100%)
  };
  thresholdByMonth: SweepThresholdByMonth;
}

// --- wildlife_prevalence.json / irrigation_prevalence.json / both_prevalence.json (Section 14) ---
// Median-only soil series; harvestOnion and thresholdByMonth are present on
// current Scenario_Updated.m exports (older files may omit them).
export interface PrevalenceData {
  parameter: 'wildlife_prevalence' | 'irrigation_prevalence' | 'both_prevalence';
  levels: number[]; // [0.0, 0.2, 0.4, 0.6, 0.8, 1.0], 6 entries
  labels: string[]; // ["0%", ..., "100%"], 6 entries
  daily: { p50: number[][] }; // [6 levels][365 days]
  monthly: { p50: number[][] }; // [6 levels][12 months]
  harvestDay: {
    median: number[]; // [6 levels]
    medHarvestDay: number;
  };
  harvestOnion?: {
    mean: number[];
    median: number[];
    max: number[];
  };
  thresholdByMonth?: SweepThresholdByMonth;
}

export const HARVEST_INDICES = [6, 7, 8, 9, 10]; // Jan, Feb, Mar, Apr, May in Jul-start order
export const HARVEST_MONTH_NAMES = ['Jan', 'Feb', 'Mar', 'Apr', 'May'];
export const MONTH_LABELS = [
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
];
export const THRESHOLDS = [1, 5, 10, 20];
export const THRESHOLD_LABELS = ['> 1 CFU', '> 5 CFU', '> 10 CFU', '> 20 CFU'];
export const THRESHOLD_KEYS = ['gt1', 'gt5', 'gt10', 'gt20'] as const;

// --- Farm characteristics (dashboard scenario configuration; not a MATLAB export) ---
export type SoilAmendment = 'none' | 'heat_treated_poultry_pellet' | 'poultry_litter';
export type WildlifeType = 'deer' | 'pig' | 'both';
/** Random plant locations receiving each pooping event (MATLAB feces_deposit_locations). */
export type FecesDepositLocations = 1 | 9;
export type WildlifeFrequencyDays = 1 | 3 | 7;
/** Days irrigation stops before undercutting (MATLAB irr_stop_before_undercut). */
export type IrrigationStopDays = 0 | 7 | 10;
/** Fraction of baseline irrigation depth across all stages (MATLAB irrigation_volume_factor). */
export type IrrigationVolumeFactor = 1 | 0.75 | 0.5 | 0.25;
export type RegulatoryStandard = 'fda_approved' | 'non_fda_approved' | 'unmanaged';
/** Days undercutting → harvest (MATLAB curing_days; baseline = 7). */
export type CuringDays = 0 | 3 | 7 | 14;
/** Rainfall-driven irrigation CFU gain (MATLAB use_rainfall_cfu_gain). */
export type RainfallRunoff = 'with_runoff' | 'no_runoff';
export type ActiveWildlifeParameter = 'wildlifeType' | 'fecesDepositLocations' | 'wildlifeFrequencyDays' | null;

export interface FarmCharacteristicsConfig {
  soilAmendment: SoilAmendment;
  wildlifeType: WildlifeType;
  fecesDepositLocations: FecesDepositLocations;
  wildlifeFrequencyDays: WildlifeFrequencyDays;
  /** Days before undercutting to stop irrigation (MATLAB irr_stop_before_undercut). */
  irrigationStopDays: IrrigationStopDays;
  /** Applied irrigation depth relative to baseline stage depths (1 = full volume). */
  irrigationVolumeFactor: IrrigationVolumeFactor;
  /** Surface water FDA GM/STV scenario, including unmanaged water with a variable outcome. */
  regulatoryStandard: RegulatoryStandard;
  curingDays: CuringDays;
  /** Rainfall runoff contribution to irrigation source CFU; with_runoff is baseline. */
  rainfallRunoff: RainfallRunoff;
  /** Only one wildlife setting can be varied at a time; others stay at baseline defaults. */
  activeWildlifeParameter: ActiveWildlifeParameter;
}
