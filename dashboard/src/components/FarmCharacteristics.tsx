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

type ScenarioCategory = 'soil' | 'wildlife' | 'irrigation' | 'harvest';

const CATEGORIES: {
  id: ScenarioCategory;
  label: string;
  params: { id: ScenarioParam; label: string }[];
}[] = [
  {
    id: 'soil',
    label: 'Soil',
    params: [{ id: 'soil', label: 'Soil Amendment' }],
  },
  {
    id: 'wildlife',
    label: 'Wildlife',
    params: [
      { id: 'wildlifeType', label: 'Wildlife Type' },
      { id: 'fecesDepositLocations', label: 'Feces Deposit Locations' },
      { id: 'wildlifeFrequency', label: 'Intrusion Frequency' },
    ],
  },
  {
    id: 'irrigation',
    label: 'Irrigation',
    params: [
      { id: 'irrigation', label: 'Irrigation Stop' },
      { id: 'irrigationVolume', label: 'Irrigation Volume' },
      { id: 'regulatory', label: 'Water Quality' },
      { id: 'runoff', label: 'Rainfall Runoff' },
    ],
  },
  {
    id: 'harvest',
    label: 'Harvest',
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
  description,
  value,
  options,
  onChange,
}: {
  description: string;
  value: T;
  options: SegmentOption<T>[];
  onChange: (value: T) => void;
}) {
  return (
    <div>
      <p className="mb-3 text-lg leading-relaxed text-uga-dark-gray">{description}</p>
      <div className="flex flex-wrap gap-1.5" role="radiogroup" aria-label={description}>
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
      <div className="bg-uga-navy px-4 py-2">
        <h3 className="text-lg font-semibold text-white">Scenarios</h3>
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
            description="Soil Amendment: Materials added to the field to improve soil fertility or soil conditions, some of which may also introduce microbial contamination."
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
            description="Wildlife Type: Select the common wildlife species that may enter the onion field and contribute fecal contamination."
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
            description="Feces Deposit Locations: Set the number of randomly selected field locations affected by wildlife fecal deposits during each contamination event."
            value={farmCharacteristics.fecesDepositLocations}
            onChange={(fecesDepositLocations) =>
              setFarmCharacteristic('fecesDepositLocations', fecesDepositLocations)
            }
            options={[
              { value: 1, label: '1 location (baseline)' },
              { value: 9, label: '9 locations' },
            ]}
          />
        )}

        {activeParam === 'wildlifeFrequency' && (
          <SegmentedControl<WildlifeFrequencyDays>
            description="Wildlife Intrusion Frequency: Set how often wildlife enters the field and deposits feces."
            value={farmCharacteristics.wildlifeFrequencyDays}
            onChange={(wildlifeFrequencyDays) =>
              setFarmCharacteristic('wildlifeFrequencyDays', wildlifeFrequencyDays)
            }
            options={[
              { value: 1, label: 'Every day (baseline)' },
              { value: 3, label: 'Every 3 days' },
              { value: 7, label: 'Every 7 days' },
            ]}
          />
        )}

        {activeParam === 'irrigation' && (
          <SegmentedControl<IrrigationStopDays>
            description="Irrigation Stop: Set how many days before onion root undercutting irrigation is stopped."
            value={farmCharacteristics.irrigationStopDays}
            onChange={(irrigationStopDays) => setFarmCharacteristic('irrigationStopDays', irrigationStopDays)}
            options={[
              { value: 0, label: '0 days' },
              { value: 7, label: '7 days (baseline)' },
              { value: 10, label: '10 days' },
            ]}
          />
        )}

        {activeParam === 'irrigationVolume' && (
          <SegmentedControl<IrrigationVolumeFactor>
            description="Irrigation Volume: Scale the water depth applied in establishment, vegetative, and bulbing stages relative to the baseline schedule."
            value={farmCharacteristics.irrigationVolumeFactor}
            onChange={(irrigationVolumeFactor) =>
              setFarmCharacteristic('irrigationVolumeFactor', irrigationVolumeFactor)
            }
            options={[
              { value: 1, label: '100% (baseline)' },
              { value: 0.75, label: '75% (−25%)' },
              { value: 0.5, label: '50% (−50%)' },
              { value: 0.25, label: '25% (−75%)' },
            ]}
          />
        )}

        {activeParam === 'regulatory' && (
          <SegmentedControl<RegulatoryStandard>
            description="Water Quality: Select a controlled FDA outcome or unmanaged water. Unmanaged water is not screened for compliance and each sample has a 60% chance of being impacted."
            value={farmCharacteristics.regulatoryStandard}
            onChange={(regulatoryStandard) => setFarmCharacteristic('regulatoryStandard', regulatoryStandard)}
            options={[
              { value: 'fda_approved', label: 'Meets FDA criteria (baseline)' },
              { value: 'non_fda_approved', label: 'Does not meet FDA criteria' },
              { value: 'unmanaged', label: 'Unmanaged water (60% impacted)' },
            ]}
          />
        )}

        {activeParam === 'runoff' && (
          <SegmentedControl<RainfallRunoff>
            description="Rainfall Runoff: Include rainfall-driven CFU gain in irrigation source water (screened samples plus runoff contribution), or use screened source samples only."
            value={farmCharacteristics.rainfallRunoff}
            onChange={(rainfallRunoff) => setFarmCharacteristic('rainfallRunoff', rainfallRunoff)}
            options={[
              { value: 'with_runoff', label: 'With runoff (baseline)' },
              { value: 'no_runoff', label: 'No runoff' },
            ]}
          />
        )}

        {activeParam === 'curing' && (
          <SegmentedControl<CuringDays>
            description="Curing Duration: Set the number of days onions remain in the field between root undercutting and harvest."
            value={farmCharacteristics.curingDays}
            onChange={(curingDays) => setFarmCharacteristic('curingDays', curingDays)}
            options={[
              { value: 0, label: '0 days' },
              { value: 3, label: '3 days' },
              { value: 7, label: '7 days (baseline)' },
              { value: 14, label: '14 days' },
            ]}
          />
        )}
      </div>
    </Card>
  );
}
