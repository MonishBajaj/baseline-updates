import { useEffect, useMemo, useState } from 'react';
import { HarvestBarChart } from '@/components/charts/HarvestBarChart';
import { YearRoundLineChart } from '@/components/charts/YearRoundLineChart';
import { Card, CardContent } from '@/components/ui/Card';
import { InsightBox } from '@/components/ui/InsightBox';
import { MetricCard } from '@/components/ui/MetricCard';
import { BOTH_COLORS, IRRIGATION_COLORS, WILDLIFE_COLORS } from '@/constants';
import { cn } from '@/lib/utils';
import { useDataStore } from '@/store/dataStore';
import type { IntensityData, PrevalenceData, SweepThresholdByMonth } from '@/types';

export type SweepId =
  | 'wildlife_intensity'
  | 'irrigation_intensity'
  | 'wildlife_prevalence'
  | 'irrigation_prevalence'
  | 'both_prevalence';

const SWEEPS: {
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

function dailyRow(rows: number[][] | undefined, idx: number): number[] {
  const row = rows?.[idx];
  return Array.isArray(row) && row.length > 0 ? row : EMPTY_DAYS;
}

function monthThreshRow(block: SweepThresholdByMonth | undefined, idx: number): number[][] {
  const level = block?.meanPct?.[idx];
  if (!Array.isArray(level) || level.length === 0) return EMPTY_MONTH_THRESH;
  return level;
}

function colorsForSweep(id: SweepId): string[] {
  if (id === 'irrigation_intensity' || id === 'irrigation_prevalence') return IRRIGATION_COLORS;
  if (id === 'both_prevalence') return BOTH_COLORS;
  return WILDLIFE_COLORS;
}

function referenceIndex(labels: string[]): number {
  const exact = labels.findIndex((label) => label === '100%');
  return exact >= 0 ? exact : Math.max(0, labels.length - 1);
}

interface SweepView {
  id: SweepId;
  title: string;
  description: string;
  labels: string[];
  dailyP50: number[][];
  thresholdByMonth?: SweepThresholdByMonth;
  harvestMedian?: number[];
}

function buildSweep(
  id: SweepId,
  wildlife: IntensityData | null,
  irrigation: IntensityData | null,
  wildlifePrevalence: PrevalenceData | null,
  irrigationPrevalence: PrevalenceData | null,
  bothPrevalence: PrevalenceData | null,
): SweepView | null {
  const meta = SWEEPS.find((s) => s.id === id);
  if (!meta) return null;

  if (id === 'wildlife_intensity' && wildlife) {
    return {
      id,
      title: meta.label,
      description: meta.description,
      labels: wildlife.labels,
      dailyP50: wildlife.daily.p50,
      thresholdByMonth: wildlife.thresholdByMonth,
      harvestMedian: wildlife.harvestDay.median,
    };
  }
  if (id === 'irrigation_intensity' && irrigation) {
    return {
      id,
      title: meta.label,
      description: meta.description,
      labels: irrigation.labels,
      dailyP50: irrigation.daily.p50,
      thresholdByMonth: irrigation.thresholdByMonth,
      harvestMedian: irrigation.harvestDay.median,
    };
  }
  if (id === 'wildlife_prevalence' && wildlifePrevalence) {
    return {
      id,
      title: meta.label,
      description: meta.description,
      labels: wildlifePrevalence.labels,
      dailyP50: wildlifePrevalence.daily.p50,
      thresholdByMonth: wildlifePrevalence.thresholdByMonth,
      harvestMedian: wildlifePrevalence.harvestDay.median,
    };
  }
  if (id === 'irrigation_prevalence' && irrigationPrevalence) {
    return {
      id,
      title: meta.label,
      description: meta.description,
      labels: irrigationPrevalence.labels,
      dailyP50: irrigationPrevalence.daily.p50,
      thresholdByMonth: irrigationPrevalence.thresholdByMonth,
      harvestMedian: irrigationPrevalence.harvestDay.median,
    };
  }
  if (id === 'both_prevalence' && bothPrevalence) {
    return {
      id,
      title: meta.label,
      description: meta.description,
      labels: bothPrevalence.labels,
      dailyP50: bothPrevalence.daily.p50,
      thresholdByMonth: bothPrevalence.thresholdByMonth,
      harvestMedian: bothPrevalence.harvestDay.median,
    };
  }
  return null;
}

export function SensitivityPage() {
  const wildlife = useDataStore((s) => s.wildlife);
  const irrigation = useDataStore((s) => s.irrigation);
  const wildlifePrevalence = useDataStore((s) => s.wildlifePrevalence);
  const irrigationPrevalence = useDataStore((s) => s.irrigationPrevalence);
  const bothPrevalence = useDataStore((s) => s.bothPrevalence);

  const [sweepId, setSweepId] = useState<SweepId>('wildlife_intensity');
  const [levelIdx, setLevelIdx] = useState(4);

  const sweep = useMemo(
    () =>
      buildSweep(
        sweepId,
        wildlife,
        irrigation,
        wildlifePrevalence,
        irrigationPrevalence,
        bothPrevalence,
      ),
    [sweepId, wildlife, irrigation, wildlifePrevalence, irrigationPrevalence, bothPrevalence],
  );

  useEffect(() => {
    if (!sweep) return;
    setLevelIdx(referenceIndex(sweep.labels));
    // Reset only when the sweep family changes, not when the slider moves.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sweepId]);

  const loadedCount = [wildlife, irrigation, wildlifePrevalence, irrigationPrevalence, bothPrevalence].filter(
    Boolean,
  ).length;

  if (loadedCount === 0) {
    return (
      <div className="space-y-6">
        <div>
          <h2 className="text-3xl font-bold text-uga-black">Sensitivity Analysis</h2>
          <p className="text-lg text-uga-dark-gray">
            Full-gradient view across intensity and prevalence levels for both contamination sources.
          </p>
        </div>
        <Card className="border-uga-warning/40 bg-uga-warning/5">
          <CardContent className="py-12 text-center text-lg text-uga-dark-gray">
            Sensitivity JSON files are not available. Copy a Scenario_Updated.m export into{' '}
            <code className="rounded bg-uga-mid-gray/60 px-1 py-0.5">dashboard/public/data/</code>.
          </CardContent>
        </Card>
      </div>
    );
  }

  const labels = sweep?.labels ?? [];
  const safeIdx = Math.min(Math.max(levelIdx, 0), Math.max(labels.length - 1, 0));
  const selectedLabel = labels[safeIdx] ?? '—';
  const refIdx = sweep ? referenceIndex(sweep.labels) : 0;
  const refLabel = labels[refIdx] ?? '100%';
  const showReference = sweep != null && safeIdx !== refIdx;
  const palette = colorsForSweep(sweepId);
  const selectedColor = palette[Math.min(safeIdx, palette.length - 1)];
  const selectedDaily = dailyRow(sweep?.dailyP50, safeIdx);
  const referenceDaily = dailyRow(sweep?.dailyP50, refIdx);
  const selectedThresh = monthThreshRow(sweep?.thresholdByMonth, safeIdx);
  const referenceThresh = monthThreshRow(sweep?.thresholdByMonth, refIdx);
  const harvestMedian = sweep?.harvestMedian?.[safeIdx];
  const harvestMedianRef = sweep?.harvestMedian?.[refIdx];
  const meta = SWEEPS.find((s) => s.id === sweepId);

  const yearRoundLines = [
    {
      data: selectedDaily,
      color: selectedColor,
      label: `${meta?.label ?? 'Selected'} ${selectedLabel}`,
      bold: true,
    },
    ...(showReference
      ? [
          {
            data: referenceDaily,
            color: '#4A4A4A',
            label: `Reference ${refLabel}`,
            dashed: true,
          },
        ]
      : []),
  ];

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold text-uga-black">Sensitivity Analysis</h2>
        <p className="text-lg text-uga-dark-gray">
          Step through each intensity or prevalence level and compare year-round soil CFU and harvest
          threshold exceedance to the 100% reference.
        </p>
      </div>

      <div className="rounded-md border border-uga-warning/40 bg-uga-warning/5 px-4 py-3 text-base text-uga-dark-gray">
        Showing the 2-iteration pond/well test export. Use this page to confirm plots and the slider;
        harvest percentages will look jumpy until the 1000-iteration run is copied in.
      </div>

      <Card>
        <CardContent className="space-y-5">
          <div>
            <p className="mb-2 text-base font-semibold text-uga-black">Sensitivity sweep</p>
            <div className="flex flex-wrap gap-2">
              {SWEEPS.map((item) => {
                const available = Boolean(
                  buildSweep(
                    item.id,
                    wildlife,
                    irrigation,
                    wildlifePrevalence,
                    irrigationPrevalence,
                    bothPrevalence,
                  ),
                );
                return (
                  <button
                    key={item.id}
                    type="button"
                    disabled={!available}
                    onClick={() => setSweepId(item.id)}
                    className={cn(
                      'rounded-md border px-3 py-1.5 text-base transition-colors',
                      sweepId === item.id
                        ? 'border-uga-red bg-uga-red text-white'
                        : 'border-uga-card-border bg-white text-uga-black hover:border-uga-red/50',
                      !available && 'cursor-not-allowed opacity-40 hover:border-uga-card-border',
                    )}
                  >
                    {item.label}
                  </button>
                );
              })}
            </div>
            <p className="mt-2 text-base text-uga-dark-gray">{meta?.description}</p>
          </div>

          {sweep && labels.length > 0 && (
            <div>
              <div className="mb-2 flex items-end justify-between gap-3">
                <p className="text-base font-semibold text-uga-black">Level</p>
                <p className="text-lg font-semibold text-uga-red">{selectedLabel}</p>
              </div>
              <input
                type="range"
                min={0}
                max={labels.length - 1}
                step={1}
                value={safeIdx}
                onChange={(e) => setLevelIdx(Number(e.target.value))}
                className="h-2 w-full cursor-pointer appearance-none rounded-full bg-uga-mid-gray accent-uga-red"
                aria-label={`${meta?.label ?? 'Sensitivity'} level`}
              />
              <div className="mt-2 flex justify-between text-sm text-uga-dark-gray">
                {labels.map((label, i) => (
                  <button
                    key={label}
                    type="button"
                    onClick={() => setLevelIdx(i)}
                    className={cn(
                      'min-w-0 flex-1 text-center',
                      i === safeIdx ? 'font-semibold text-uga-red' : 'hover:text-uga-black',
                    )}
                  >
                    {label}
                  </button>
                ))}
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      {sweep && (
        <>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
            <MetricCard label="Selected level" value={selectedLabel} />
            <MetricCard
              label="Median soil CFU on harvest day"
              value={harvestMedian != null ? harvestMedian.toExponential(2) : '—'}
            />
            <MetricCard
              label={`Reference ${refLabel} harvest-day CFU`}
              value={harvestMedianRef != null ? harvestMedianRef.toExponential(2) : '—'}
            />
          </div>

          <YearRoundLineChart
            title={`Year-Round Soil CFU: ${meta?.label ?? ''} ${selectedLabel}`}
            subtitle={
              showReference
                ? `Median soil CFU at ${selectedLabel} versus the ${refLabel} reference`
                : `Median soil CFU at the ${selectedLabel} reference level`
            }
            lines={yearRoundLines}
          />

          <HarvestBarChart
            threshByMonth={selectedThresh}
            title={`Harvest Contamination at ${selectedLabel}`}
            subtitle="% of plants exceeding 1 / 5 / 10 / 20 CFU on the onion surface (Jan–May)"
          />

          {showReference && (
            <HarvestBarChart
              threshByMonth={referenceThresh}
              title={`Harvest Contamination at reference ${refLabel}`}
              subtitle="Same thresholds at the 100% level of this sweep, for comparison"
            />
          )}

          <InsightBox>
            {sweep.thresholdByMonth
              ? showReference
                ? `Move the slider to compare each ${meta?.label.toLowerCase() ?? 'level'} against ${refLabel}. The year-round line and harvest bars update together.`
                : `This is the ${refLabel} reference for ${meta?.label.toLowerCase() ?? 'this sweep'}. Slide away from 100% to overlay the comparison line and show both harvest charts.`
              : 'Year-round soil CFU is available for this sweep, but harvest threshold bars were not in the JSON.'}
          </InsightBox>
        </>
      )}
    </div>
  );
}
