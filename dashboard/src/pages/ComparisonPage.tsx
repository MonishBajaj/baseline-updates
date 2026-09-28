import { useMemo, useState } from 'react';
import { Plus, X } from 'lucide-react';
import { HarvestBarChart } from '@/components/charts/HarvestBarChart';
import { YearRoundLineChart, type ChartLine } from '@/components/charts/YearRoundLineChart';
import { Card, CardContent } from '@/components/ui/Card';
import { InsightBox } from '@/components/ui/InsightBox';
import { MetricCard } from '@/components/ui/MetricCard';
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
import { cn } from '@/lib/utils';
import { useDataStore } from '@/store/dataStore';

const MAX_SLOTS = 4;

const DEFAULT_SWEEP_IDS: SweepId[] = [
  'wildlife_intensity',
  'irrigation_intensity',
  'wildlife_prevalence',
  'irrigation_prevalence',
];

interface ComparisonSlot {
  key: string;
  sweepId: SweepId;
  levelIdx: number;
}

function readSources(): SweepSources {
  const state = useDataStore.getState();
  return {
    wildlife: state.wildlife,
    irrigation: state.irrigation,
    wildlifePrevalence: state.wildlifePrevalence,
    irrigationPrevalence: state.irrigationPrevalence,
    bothPrevalence: state.bothPrevalence,
  };
}

function createDefaultSlots(sources: SweepSources): ComparisonSlot[] {
  return DEFAULT_SWEEP_IDS.flatMap((sweepId, index) => {
    const sweep = buildSweep(sweepId, sources);
    if (!sweep) return [];
    return [{ key: `slot-${index}`, sweepId, levelIdx: referenceIndex(sweep.labels) }];
  });
}

const selectClass =
  'w-full rounded-md border border-uga-card-border bg-white px-2 py-1.5 text-base text-uga-black';

export function ComparisonPage() {
  const wildlife = useDataStore((s) => s.wildlife);
  const irrigation = useDataStore((s) => s.irrigation);
  const wildlifePrevalence = useDataStore((s) => s.wildlifePrevalence);
  const irrigationPrevalence = useDataStore((s) => s.irrigationPrevalence);
  const bothPrevalence = useDataStore((s) => s.bothPrevalence);

  const sources = useMemo<SweepSources>(
    () => ({ wildlife, irrigation, wildlifePrevalence, irrigationPrevalence, bothPrevalence }),
    [wildlife, irrigation, wildlifePrevalence, irrigationPrevalence, bothPrevalence],
  );

  const [slots, setSlots] = useState<ComparisonSlot[]>(() => createDefaultSlots(readSources()));

  const availableSweeps = SWEEPS.filter((item) => buildSweep(item.id, sources));

  const columns = useMemo(() => {
    const labelCounts = new Map<string, number>();
    return slots.flatMap((slot) => {
      const sweep = buildSweep(slot.sweepId, sources);
      if (!sweep || sweep.labels.length === 0) return [];
      const levelIdx = Math.min(Math.max(slot.levelIdx, 0), sweep.labels.length - 1);
      const levelLabel = sweep.labels[levelIdx] ?? '—';
      const palette = colorsForSweep(slot.sweepId);
      const color = palette[Math.min(levelIdx, palette.length - 1)] ?? palette[0];
      const baseLabel = `${sweep.title} ${levelLabel}`;
      const seen = (labelCounts.get(baseLabel) ?? 0) + 1;
      labelCounts.set(baseLabel, seen);
      const seriesLabel = seen === 1 ? baseLabel : `${baseLabel} (${seen})`;
      return [
        {
          key: slot.key,
          sweep,
          levelIdx,
          levelLabel,
          color,
          seriesLabel,
          daily: dailyRow(sweep.dailyP50, levelIdx),
          thresh: monthThreshRow(sweep.thresholdByMonth, levelIdx),
          hasThresholds: Boolean(sweep.thresholdByMonth),
          harvestMedian: sweep.harvestMedian?.[levelIdx],
        },
      ];
    });
  }, [slots, sources]);

  const yearRoundLines: ChartLine[] = columns.map((column) => ({
    data: column.daily,
    color: column.color,
    label: column.seriesLabel,
    bold: true,
  }));

  function updateSweep(key: string, sweepId: SweepId) {
    const sweep = buildSweep(sweepId, sources);
    if (!sweep) return;
    setSlots((prev) =>
      prev.map((slot) =>
        slot.key === key ? { ...slot, sweepId, levelIdx: referenceIndex(sweep.labels) } : slot,
      ),
    );
  }

  function updateLevel(key: string, levelIdx: number) {
    setSlots((prev) => prev.map((slot) => (slot.key === key ? { ...slot, levelIdx } : slot)));
  }

  function removeSlot(key: string) {
    setSlots((prev) => (prev.length <= 1 ? prev : prev.filter((slot) => slot.key !== key)));
  }

  function addSlot() {
    setSlots((prev) => {
      if (prev.length >= MAX_SLOTS) return prev;
      const used = new Set(prev.map((slot) => slot.sweepId));
      const next =
        availableSweeps.find((item) => !used.has(item.id)) ?? availableSweeps[0];
      if (!next) return prev;
      const sweep = buildSweep(next.id, sources);
      if (!sweep) return prev;
      return [
        ...prev,
        {
          key: `slot-${Date.now()}`,
          sweepId: next.id,
          levelIdx: referenceIndex(sweep.labels),
        },
      ];
    });
  }

  if (availableSweeps.length === 0) {
    return (
      <div className="space-y-6">
        <div>
          <h2 className="text-3xl font-bold text-uga-black">Scenario Comparison</h2>
          <p className="text-lg text-uga-dark-gray">
            Compare intensity and prevalence sweeps side by side.
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

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold text-uga-black">Scenario Comparison</h2>
        <p className="text-lg text-uga-dark-gray">
          Pick up to four sensitivity sweeps and levels. Year-round soil CFU is overlaid, and harvest
          threshold charts sit side by side.
        </p>
      </div>

      <div
        className={cn(
          'grid grid-cols-1 gap-4',
          slots.length === 2 && 'md:grid-cols-2',
          slots.length === 3 && 'md:grid-cols-2 xl:grid-cols-3',
          slots.length >= 4 && 'md:grid-cols-2 xl:grid-cols-4',
        )}
      >
        {slots.map((slot, index) => {
          const sweep = buildSweep(slot.sweepId, sources);
          const labels = sweep?.labels ?? [];
          const levelIdx = Math.min(Math.max(slot.levelIdx, 0), Math.max(labels.length - 1, 0));
          const column = columns.find((item) => item.key === slot.key);
          return (
            <Card key={slot.key}>
              <CardContent className="space-y-3">
                <div className="flex items-center justify-between gap-2">
                  <p className="flex items-center gap-2 text-base font-semibold text-uga-black">
                    <span
                      className="inline-block h-3 w-3 rounded-full"
                      style={{ backgroundColor: column?.color ?? '#4A4A4A' }}
                    />
                    Comparison {index + 1}
                  </p>
                  <button
                    type="button"
                    onClick={() => removeSlot(slot.key)}
                    disabled={slots.length <= 1}
                    className="rounded p-1 text-uga-dark-gray hover:bg-uga-mid-gray/60 hover:text-uga-black disabled:cursor-not-allowed disabled:opacity-30"
                    aria-label={`Remove comparison ${index + 1}`}
                  >
                    <X size={16} />
                  </button>
                </div>

                <label className="block space-y-1">
                  <span className="text-sm font-medium text-uga-dark-gray">Sensitivity</span>
                  <select
                    className={selectClass}
                    value={slot.sweepId}
                    onChange={(event) => updateSweep(slot.key, event.target.value as SweepId)}
                  >
                    {availableSweeps.map((item) => (
                      <option key={item.id} value={item.id}>
                        {item.label}
                      </option>
                    ))}
                  </select>
                </label>

                <label className="block space-y-1">
                  <span className="text-sm font-medium text-uga-dark-gray">Level</span>
                  <select
                    className={selectClass}
                    value={levelIdx}
                    onChange={(event) => updateLevel(slot.key, Number(event.target.value))}
                    disabled={labels.length === 0}
                  >
                    {labels.map((label, labelIndex) => (
                      <option key={label} value={labelIndex}>
                        {label}
                      </option>
                    ))}
                  </select>
                </label>

                <p className="text-sm text-uga-dark-gray">{sweep?.description}</p>
              </CardContent>
            </Card>
          );
        })}
      </div>

      {slots.length < MAX_SLOTS && (
        <button
          type="button"
          onClick={addSlot}
          className="inline-flex items-center gap-2 rounded-md border border-uga-card-border bg-white px-3 py-2 text-base font-medium text-uga-black hover:border-uga-red/50"
        >
          <Plus size={16} />
          Add comparison
        </button>
      )}

      <div
        className={cn(
          'grid grid-cols-1 gap-4',
          columns.length === 2 && 'md:grid-cols-2',
          columns.length === 3 && 'md:grid-cols-2 xl:grid-cols-3',
          columns.length >= 4 && 'md:grid-cols-2 xl:grid-cols-4',
        )}
      >
        {columns.map((column) => (
          <MetricCard
            key={column.key}
            label="Median harvest-day soil CFU"
            value={column.harvestMedian != null ? column.harvestMedian.toFixed(2) : '—'}
            subtext={column.seriesLabel}
          />
        ))}
      </div>

      <YearRoundLineChart
        title="Year-Round Soil CFU"
        subtitle="Median soil CFU for each selected sensitivity and level"
        lines={yearRoundLines}
        height={360}
      />

      <div className={cn('grid grid-cols-1 gap-4', columns.length > 1 && 'xl:grid-cols-2')}>
        {columns.map((column) =>
          column.hasThresholds ? (
            <HarvestBarChart
              key={column.key}
              threshByMonth={column.thresh}
              title={`Harvest Contamination: ${column.seriesLabel}`}
              subtitle="% of plants exceeding 1 / 5 / 10 / 20 CFU on the onion surface (Jan–May)"
            />
          ) : (
            <Card key={column.key}>
              <CardContent className="py-8 text-base text-uga-dark-gray">
                Harvest threshold bars were not in the JSON for {column.seriesLabel}.
              </CardContent>
            </Card>
          ),
        )}
      </div>

      <InsightBox>
        Each card is one sensitivity sweep at one level. The year-round chart overlays those medians.
        Harvest charts use the same 1, 5, 10, and 20 CFU thresholds as the Sensitivity page.
      </InsightBox>
    </div>
  );
}
