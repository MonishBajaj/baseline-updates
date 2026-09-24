/**
 * QMRA Model Context — Sweet Onion E. coli Risk Assessment
 * University of Georgia, FMRA Lab
 *
 * MODEL: Two-file MATLAB Monte Carlo simulation
 *   Updated_Baseline.m  — reference (100%/100%) scenario, exports baseline_fin.json
 *                         (and S_irrigation_runoff_no.json when runoff is off)
 *   Scenario_Updated.m  — scenario/sensitivity/prevalence sweeps, exports 6 more files
 *
 * FIELD: 1 acre, Southeastern U.S., 58,080 plants, Jul-Jun fiscal year
 *
 * CONTAMINATION SOURCES: irrigation water and wildlife fecal matter (deer +
 * wild boar). All sources enter soil first, then transfer to the onion surface
 * (bulbing to harvest, daily). sourceContribution reports wildlife vs irrigation
 * vs carryover at harvest.
 *
 * THRESHOLDS: [1, 5, 10, 20] CFU/plant on onion surface
 * HARVEST MONTHS: January, February, March, April, May
 * SENSITIVITY RANGE (Scenario_Updated.m): 20% to 200% of baseline, 10 levels
 * PREVALENCE RANGE (Scenario_Updated.m): 0% to 100% of baseline, 6 levels
 *
 * BASELINE FARM DEFAULTS: feces at 1 location, wildlife every 1 day, curing 7 days,
 * irrigation stop 7 days before undercut, full irrigation volume, FDA-approved water,
 * with rainfall runoff.
 *
 * All numeric findings (contribution %, threshold counts, etc.) shown in
 * this dashboard are read directly from the JSON exports at load time —
 * nothing scientific is hardcoded, so the dashboard always reflects
 * whatever the most recent MATLAB run produced.
 */

export const FIELD_INFO = {
  location: 'Southeastern U.S.',
  fieldSize: '1 acre',
  totalPlants: 58080,
  fiscalYearStart: 'July 1',
};

export const LEVELS_10 = ['20%', '40%', '60%', '80%', '100%', '120%', '140%', '160%', '180%', '200%'];
export const BASELINE_LEVEL_IDX = 4; // 100% — index into the 10-level sweep

/** LOD for the headline onion-surface prevalence KPI (CFU/plant at harvest). */
export const PREVALENCE_LOD = 10;

export const THRESHOLDS = [1, 5, 10, 20];
export const THRESHOLD_LABELS = ['> 1 CFU', '> 5 CFU', '> 10 CFU', '> 20 CFU'];
export const THRESHOLD_KEYS = ['gt1', 'gt5', 'gt10', 'gt20'] as const;
export const THRESHOLD_COLORS: Record<(typeof THRESHOLD_KEYS)[number], string> = {
  gt1: '#388E3C',
  gt5: '#1976D2',
  gt10: '#F57C00',
  gt20: '#C62828',
};

// Wildlife intensity gradient — green, light to dark (index 0 = 20% ... 9 = 200%)
export const WILDLIFE_COLORS = [
  '#C8E6C8', '#A5D6A7', '#66BB6A', '#43A047',
  '#2E7D32', '#1B5E20', '#33691E', '#827717', '#6D4C41', '#4E342E',
];

// Irrigation intensity gradient — blue, light to dark (index 0 = 20% ... 9 = 200%)
export const IRRIGATION_COLORS = [
  '#BBDEFB', '#90CAF9', '#64B5F6', '#42A5F5',
  '#1565C0', '#0D47A1', '#1A237E', '#283593', '#311B92', '#4A148C',
];

// Combined-prevalence gradient — red, light to dark
export const BOTH_COLORS = [
  '#FFCDD2', '#EF9A9A', '#E57373', '#EF5350', '#C62828', '#8B0000',
];

export const MONTH_LABELS = [
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
];
// Approximate day-of-year tick position for the middle of each month (Jul-start fiscal year)
export const MONTH_TICKS = [15, 46, 77, 107, 138, 168, 199, 230, 258, 289, 319, 350];

export const HARVEST_INDICES = [6, 7, 8, 9, 10]; // Jan, Feb, Mar, Apr, May
export const HARVEST_MONTH_NAMES = ['Jan', 'Feb', 'Mar', 'Apr', 'May'];
