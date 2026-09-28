import { useState } from 'react';
import { Card } from '@/components/ui/Card';
import { cn } from '@/lib/utils';
import {
  type FarmCharacteristicKey,
  useScenarioStore,
} from '@/store/scenarioStore';
import type {
  CuringDays,
  FecesDepositLocations,
  IrrigationStopDays,
  IrrigationVolumeFactor,
  RainfallRunoff,
  RegulatoryStandard,
  SoilAmendment,
  WildlifeFrequencyDays,
  WildlifeType,
} from '@/types';

type ScenarioParam =
  | 'soil'
  | 'wildlifeType'
  | 'fecesDepositLocations'
  | 'wildlifeFrequency'
  | 'irrigation'
  | 'irrigationVolume'
  | 'regulatory'
  | 'runoff'
  | 'curing';

type ScenarioCategory = 'soil' | 'wildlife' | 'water' | 'irrigationPractices' | 'harvest';

const CATEGORIES: {
  id: ScenarioCategory;
  label: string;
  params: { id: ScenarioParam; label: string }[];
}[] = [
  {
    id: 'soil',
    label: 'Soil',
    params: [{ id: 'soil', label: 'Soil amendment' }],
  },
  {
    id: 'wildlife',
    label: 'Wildlife',
    params: [
      { id: 'wildlifeType', label: 'Wildlife Type' },
      { id: 'fecesDepositLocations', label: 'Fecal Deposit Locations' },
      { id: 'wildlifeFrequency', label: 'Intrusion Frequency' },
    ],
  },
  {
    id: 'water',
    label: 'Water Source',
    params: [
      { id: 'regulatory', label: 'Water Quality' },
      { id: 'runoff', label: 'Rainfall Runoff' },
    ],
  },
  {
    id: 'irrigationPractices',
    label: 'Irrigation Practices',
    params: [
      { id: 'irrigationVolume', label: 'Irrigation Adjustment for Rainfall' },
      { id: 'irrigation', label: 'Irrigation Stop' },
    ],
  },
  {
    id: 'harvest',
    label: 'Field Curing',
    params: [{ id: 'curing', label: 'Curing Duration' }],
  },
];

const PARAM_CONFIG_KEY: Record<ScenarioParam, FarmCharacteristicKey> = {
  soil: 'soilAmendment',
  wildlifeType: 'wildlifeType',
  fecesDepositLocations: 'fecesDepositLocations',
  wildlifeFrequency: 'wildlifeFrequencyDays',
  irrigation: 'irrigationStopDays',
  irrigationVolume: 'irrigationVolumeFactor',
  regulatory: 'regulatoryStandard',
  runoff: 'rainfallRunoff',
  curing: 'curingDays',
};

interface SegmentOption<T extends string | number> {
  value: T;
  label: string;
}

function SegmentedControl<T extends string | number>({
  title,
  description,
  note,
  value,
  options,
  onChange,
}: {
  title?: string;
  description: string;
  note?: string;
  value: T;
  options: SegmentOption<T>[];
  onChange: (value: T) => void;
}) {
  return (
    <div>
      {title && <h4 className="text-lg font-semibold text-uga-black">{title}</h4>}
      <p className={cn('text-lg leading-relaxed text-uga-dark-gray', title && 'mt-1', note ? 'mb-1' : 'mb-3')}>
        {description}
      </p>
      {note && <p className="mb-3 text-lg leading-relaxed text-uga-dark-gray italic">{note}</p>}
      <div className="flex flex-wrap gap-1.5" role="radiogroup" aria-label={title ?? description}>
        {options.map((opt) => {
          const selected = value === opt.value;
          return (
            <button
              key={String(opt.value)}
              type="button"
              role="radio"
              aria-checked={selected}
              onClick={() => onChange(opt.value)}
              className={cn(
                'rounded-full border px-3.5 py-2 text-lg',
                selected
                  ? 'border-uga-navy bg-uga-navy font-medium text-white'
                  : 'border-uga-card-border bg-white text-uga-black hover:border-uga-navy hover:text-uga-navy',
              )}
            >
              {opt.label}
            </button>
          );
        })}
      </div>
    </div>
  );
}

export function FarmCharacteristics() {
  const { farmCharacteristics, setFarmCharacteristic } = useScenarioStore();
  const [activeCategory, setActiveCategory] = useState<ScenarioCategory>('soil');
  const [activeParam, setActiveParam] = useState<ScenarioParam>('soil');

  const category = CATEGORIES.find((c) => c.id === activeCategory)!;
  const showParamTabs = category.params.length > 1;

  const selectCategory = (next: ScenarioCategory) => {
    const nextCategory = CATEGORIES.find((c) => c.id === next)!;
    const firstParam = nextCategory.params[0].id;
    setActiveCategory(next);
    setActiveParam(firstParam);
    const key = PARAM_CONFIG_KEY[firstParam];
    setFarmCharacteristic(key, farmCharacteristics[key]);
  };

  const selectParam = (param: ScenarioParam) => {
    setActiveParam(param);
    const key = PARAM_CONFIG_KEY[param];
    setFarmCharacteristic(key, farmCharacteristics[key]);
  };

  return (
    <Card className="overflow-hidden">
      <div className="bg-uga-navy px-4 py-3">
        <h3 className="text-lg font-semibold text-white">Scenario Explorer</h3>
        <p className="mt-0.5 text-base text-white/80">
          Change one condition at a time. All other model conditions remain at baseline levels.
        </p>
      </div>

      <div className="border-b border-uga-card-border bg-uga-light-gray px-3 py-2">
        <div className="flex flex-wrap gap-1.5" role="tablist" aria-label="Scenario categories">
          {CATEGORIES.map((cat) => {
            const active = activeCategory === cat.id;
            return (
              <button
                key={cat.id}
                type="button"
                role="tab"
                aria-selected={active}
                onClick={() => selectCategory(cat.id)}
                className={cn(
                  'rounded-full border px-3.5 py-2 text-lg',
                  active
                    ? 'border-uga-navy bg-uga-navy font-semibold text-white'
                    : 'border-uga-card-border bg-white text-[#3d5a80] hover:border-uga-navy hover:text-uga-navy',
                )}
              >
                {cat.label}
              </button>
            );
          })}
        </div>
      </div>

      {showParamTabs && (
        <div className="border-b border-uga-card-border bg-uga-light-gray px-2 pt-2">
          <div className="flex flex-wrap" role="tablist" aria-label={`${category.label} scenarios`}>
            {category.params.map((param) => {
              const active = activeParam === param.id;
              return (
                <button
                  key={param.id}
                  type="button"
                  role="tab"
                  aria-selected={active}
                  onClick={() => selectParam(param.id)}
                  className={cn(
                    '-mb-px whitespace-nowrap px-3 py-2 text-lg',
                    active
                      ? 'rounded-t-sm border border-uga-card-border border-b-white bg-white font-semibold text-uga-black'
                      : 'border border-transparent text-[#3d5a80] hover:text-uga-navy',
                  )}
                >
                  {param.label}
                </button>
              );
            })}
          </div>
        </div>
      )}

      <div className="bg-white px-4 py-4" role="tabpanel">
        {activeParam === 'soil' && (
          <SegmentedControl<SoilAmendment>
            title="Soil amendment"
            description="Which soil amendment do you typically apply to your field?"
            value={farmCharacteristics.soilAmendment}
            onChange={(soilAmendment) => setFarmCharacteristic('soilAmendment', soilAmendment)}
            options={[
              { value: 'none', label: 'None (baseline)' },
              { value: 'heat_treated_poultry_pellet', label: 'Heat-treated poultry pellet' },
              { value: 'poultry_litter', label: 'Poultry litter' },
            ]}
          />
        )}

        {activeParam === 'wildlifeType' && (
          <SegmentedControl<WildlifeType>
            title="Wildlife Type"
            description="What wildlife do you commonly see in or around your onion fields?"
            value={farmCharacteristics.wildlifeType}
            onChange={(wildlifeType) => setFarmCharacteristic('wildlifeType', wildlifeType)}
            options={[
              { value: 'both', label: 'Both (baseline)' },
              { value: 'deer', label: 'White-tailed deer' },
              { value: 'pig', label: 'Feral swine' },
            ]}
          />
        )}

        {activeParam === 'fecesDepositLocations' && (
          <SegmentedControl<FecesDepositLocations>
            title="Fecal Deposit Locations"
            description="How widespread are wildlife fecal deposits in your field?"
            value={farmCharacteristics.fecesDepositLocations}
            onChange={(fecesDepositLocations) =>
              setFarmCharacteristic('fecesDepositLocations', fecesDepositLocations)
            }
            options={[
              { value: 1, label: '1 location per event' },
              { value: 9, label: 'Multiple locations per event' },
            ]}
          />
        )}

        {activeParam === 'wildlifeFrequency' && (
          <SegmentedControl<WildlifeFrequencyDays>
            title="Intrusion Frequency"
            description="How often do you typically see wildlife entering the field?"
            value={farmCharacteristics.wildlifeFrequencyDays}
            onChange={(wildlifeFrequencyDays) =>
              setFarmCharacteristic('wildlifeFrequencyDays', wildlifeFrequencyDays)
            }
            options={[
              { value: 1, label: 'Daily' },
              { value: 3, label: 'Every 3 days' },
              { value: 7, label: 'Every 7 days' },
            ]}
          />
        )}

        {activeParam === 'irrigation' && (
          <SegmentedControl<IrrigationStopDays>
            title="Irrigation Stop"
            description="When do you typically stop irrigation before root undercutting?"
            value={farmCharacteristics.irrigationStopDays}
            onChange={(irrigationStopDays) => setFarmCharacteristic('irrigationStopDays', irrigationStopDays)}
            options={[
              { value: 0, label: 'Same day' },
              { value: 7, label: '7 days' },
              { value: 10, label: '10 days' },
            ]}
          />
        )}

        {activeParam === 'irrigationVolume' && (
          <SegmentedControl<IrrigationVolumeFactor>
            title="Irrigation Adjustment for Rainfall"
            description="How should irrigation be adjusted based on rainfall?"
            value={farmCharacteristics.irrigationVolumeFactor}
            onChange={(irrigationVolumeFactor) =>
              setFarmCharacteristic('irrigationVolumeFactor', irrigationVolumeFactor)
            }
            options={[
              { value: 1, label: '100% of recommended irrigation amount' },
              { value: 0.75, label: '75% of recommended amount' },
              { value: 0.5, label: '50% of recommended amount' },
              { value: 0.25, label: '25% of recommended amount' },
            ]}
          />
        )}

        {activeParam === 'regulatory' && (
          <SegmentedControl<RegulatoryStandard>
            title="Water Quality"
            description="How would you describe the quality of your irrigation water?"
            note="Model reference threshold: GM ≤126 and STV ≤410 CFU/100 mL, based on the microbial water quality criteria established in the 2015 FDA Produce Safety Rule."
            value={farmCharacteristics.regulatoryStandard}
            onChange={(regulatoryStandard) => setFarmCharacteristic('regulatoryStandard', regulatoryStandard)}
            options={[
              { value: 'fda_approved', label: 'Meets model reference threshold' },
              { value: 'non_fda_approved', label: 'Exceeds model reference threshold' },
              { value: 'unmanaged', label: 'Not sure / Not tested' },
            ]}
          />
        )}

        {activeParam === 'runoff' && (
          <SegmentedControl<RainfallRunoff>
            title="Rainfall Runoff"
            description="Can rainfall runoff enter your irrigation water source?"
            value={farmCharacteristics.rainfallRunoff}
            onChange={(rainfallRunoff) => setFarmCharacteristic('rainfallRunoff', rainfallRunoff)}
            options={[
              { value: 'with_runoff', label: 'Yes' },
              { value: 'no_runoff', label: 'No' },
            ]}
          />
        )}

        {activeParam === 'curing' && (
          <SegmentedControl<CuringDays>
            title="Curing Duration"
            description="How long do you typically leave onions in the field after root undercutting before harvest?"
            value={farmCharacteristics.curingDays}
            onChange={(curingDays) => setFarmCharacteristic('curingDays', curingDays)}
            options={[
              { value: 0, label: '0 days' },
              { value: 3, label: '3 days' },
              { value: 7, label: '7 days' },
              { value: 14, label: '14 days' },
            ]}
          />
        )}
      </div>
    </Card>
  );
}
