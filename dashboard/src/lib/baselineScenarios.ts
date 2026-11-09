/** Single-parameter baseline scenarios, labeled the same way as the scenario explorer. */
export interface BaselineScenarioOption {
  id: string;
  group: string;
  label: string;
  filename: string;
  description: string;
}

export const BASELINE_SCENARIOS: BaselineScenarioOption[] = [
  {
    id: 'baseline',
    group: 'Baseline',
    label: 'Baseline',
    filename: 'baseline_fin.json',
    description: 'Reference production scenario. All other scenarios change one condition from this baseline.',
  },
  {
    id: 'htpp',
    group: 'Soil amendment',
    label: 'Heat-treated poultry pellet',
    filename: 'S_soil amendment_HTPP.json',
    description: 'Heat-treated poultry pellet applied instead of no soil amendment.',
  },
  {
    id: 'poultry_litter',
    group: 'Soil amendment',
    label: 'Poultry litter',
    filename: 'S_soil amendment_PL.json',
    description: 'Poultry litter applied instead of no soil amendment.',
  },
  {
    id: 'deer',
    group: 'Wildlife',
    label: 'White-tailed deer',
    filename: 'baseline_deer.json',
    description: 'Wildlife intrusion limited to white-tailed deer.',
  },
  {
    id: 'boar',
    group: 'Wildlife',
    label: 'Feral swine',
    filename: 'baseline_boar.json',
    description: 'Wildlife intrusion limited to feral swine.',
  },
  {
    id: 'feces_9',
    group: 'Wildlife',
    label: 'Multiple fecal deposit locations',
    filename: 'baseline_feces_9.json',
    description: 'Wildlife fecal deposits spread across multiple locations per event.',
  },
  {
    id: 'wildlife_3',
    group: 'Wildlife',
    label: 'Intrusion every 3 days',
    filename: 'baseline_wildlife_3.json',
    description: 'Wildlife enters the field every 3 days.',
  },
  {
    id: 'wildlife_7',
    group: 'Wildlife',
    label: 'Intrusion every 7 days',
    filename: 'Wildlife_freq_7.json',
    description: 'Wildlife enters the field every 7 days.',
  },
  {
    id: 'water_exceeds',
    group: 'Water source',
    label: 'Exceeds model reference threshold',
    filename: 'S_irrigation_FDA_not approved.json',
    description: 'Irrigation water exceeds the model microbial reference threshold.',
  },
  {
    id: 'water_unmanaged',
    group: 'Water source',
    label: 'Not sure / Not tested',
    filename: 'S_irrigation_unmanaged.json',
    description: 'Irrigation water quality has not been tested.',
  },
  {
    id: 'no_runoff',
    group: 'Water source',
    label: 'No rainfall runoff',
    filename: 'S_irrigation_runoff_no.json',
    description: 'Rainfall runoff does not enter the irrigation water source.',
  },
  {
    id: 'volume_75',
    group: 'Irrigation practices',
    label: '75% of recommended amount',
    filename: 'S_irrigation_volume_25pct.json',
    description: 'Irrigation applied at 75% of the recommended amount.',
  },
  {
    id: 'volume_50',
    group: 'Irrigation practices',
    label: '50% of recommended amount',
    filename: 'S_irrigation_volume_50pct.json',
    description: 'Irrigation applied at 50% of the recommended amount.',
  },
  {
    id: 'volume_25',
    group: 'Irrigation practices',
    label: '25% of recommended amount',
    filename: 'S_irrigation_volume_75pct.json',
    description: 'Irrigation applied at 25% of the recommended amount.',
  },
  {
    id: 'stop_0',
    group: 'Irrigation practices',
    label: 'Stop irrigation same day',
    filename: 'S_irrigation_stop at 0 d.json',
    description: 'Irrigation stops the same day as root undercutting.',
  },
  {
    id: 'stop_10',
    group: 'Irrigation practices',
    label: 'Stop irrigation 10 days before',
    filename: 'S_irrigation_stop at 10 d.json',
    description: 'Irrigation stops 10 days before root undercutting.',
  },
  {
    id: 'curing_0',
    group: 'Field curing',
    label: 'Curing 0 days',
    filename: 'baseline_curing_0.json',
    description: 'Onions are harvested the day of root undercutting.',
  },
  {
    id: 'curing_3',
    group: 'Field curing',
    label: 'Curing 3 days',
    filename: 'baseline_curing_3.json',
    description: 'Onions cure in the field for 3 days after root undercutting.',
  },
  {
    id: 'curing_14',
    group: 'Field curing',
    label: 'Curing 14 days',
    filename: 'baseline_curing_14_pond_well_50pct.json',
    description: 'Onions cure in the field for 14 days after root undercutting.',
  },
];

export const BASELINE_SCENARIO_GROUPS = [...new Set(BASELINE_SCENARIOS.map((item) => item.group))];

export function scenarioById(id: string): BaselineScenarioOption | undefined {
  return BASELINE_SCENARIOS.find((item) => item.id === id);
}
