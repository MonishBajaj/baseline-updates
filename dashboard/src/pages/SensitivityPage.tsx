import { useEffect, useMemo, useState } from 'react';
import { HarvestBarChart } from '@/components/charts/HarvestBarChart';
import { YearRoundLineChart } from '@/components/charts/YearRoundLineChart';
import { Card, CardContent } from '@/components/ui/Card';
import { InsightBox } from '@/components/ui/InsightBox';
import { MetricCard } from '@/components/ui/MetricCard';
import { cn } from '@/lib/utils';
import {
  SWEEPS,
  buildSweep,
  colorsForSweep,
  dailyRow,
  monthThreshRow,
  referenceIndex,
  type SweepId,
  type SweepSources,
} from '@/lib/sensitivitySweeps';
import { useDataStore } from '@/store/dataStore';

export function SensitivityPage() {
  const wildlife = useDataStore((s) => s.wildlife);
  const irrigation = useDataStore((s) => s.irrigation);
  const wildlifePrevalence = useDataStore((s) => s.wildlifePrevalence);
  const irrigationPrevalence = useDataStore((s) => s.irrigationPrevalence);
  const bothPrevalence = useDataStore((s) => s.bothPrevalence);

  const [sweepId, setSweepId] = useState<SweepId>('wildlife_intensity');
  const [levelIdx, setLevelIdx] = useState(4);

  const sources = useMemo<SweepSources>(
    () => ({ wildlife, irrigation, wildlifePrevalence, irrigationPrevalence, bothPrevalence }),
    [wildlife, irrigation, wildlifePrevalence, irrigationPrevalence, bothPrevalence],
  );

  const sweep = useMemo(() => buildSweep(sweepId, sources), [sweepId, sources]);

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

      <Card>
        <CardContent className="space-y-5">
          <div>
            <p className="mb-2 text-base font-semibold text-uga-black">Sensitivity sweep</p>
            <div className="flex flex-wrap gap-2">
              {SWEEPS.map((item) => {
                const available = Boolean(buildSweep(item.id, sources));
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
              value={harvestMedian != null ? harvestMedian.toFixed(2) : '—'}
            />
            <MetricCard
              label={`Reference ${refLabel} harvest-day CFU`}
              value={harvestMedianRef != null ? harvestMedianRef.toFixed(2) : '—'}
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
