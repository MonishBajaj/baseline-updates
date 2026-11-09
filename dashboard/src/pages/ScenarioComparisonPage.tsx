import { useMemo, useState } from 'react';
import { Layers, Plus, X } from 'lucide-react';
import { HarvestBarChart } from '@/components/charts/HarvestBarChart';
import { YearRoundLineChart, type ChartLine } from '@/components/charts/YearRoundLineChart';
import { Card, CardContent } from '@/components/ui/Card';
import { InsightBox } from '@/components/ui/InsightBox';
import { MetricCard } from '@/components/ui/MetricCard';
import {
  BASELINE_SCENARIO_GROUPS,
  BASELINE_SCENARIOS,
  scenarioById,
  type BaselineScenarioOption,
} from '@/lib/baselineScenarios';
import { withItalicEColi } from '@/lib/eColi';
import { getMedianOnionCFUPerPlant } from '@/lib/summaryMetrics';
import { cn } from '@/lib/utils';
import { useDataStore } from '@/store/dataStore';

const MAX_SLOTS = 4;
const SLOT_COLORS = ['#BA0C2F', '#1565C0', '#2E7D32', '#F57C00'];
const DEFAULT_SCENARIO_IDS = ['baseline', 'poultry_litter', 'deer', 'no_runoff'];

interface ComparisonSlot {
  key: string;
  scenarioId: string;
}

const selectClass =
  'w-full rounded-md border border-uga-card-border bg-white px-2 py-1.5 text-base text-uga-black';

function availableScenarios(cache: Record<string, unknown>): BaselineScenarioOption[] {
  return BASELINE_SCENARIOS.filter((item) => cache[item.filename]);
}

export function ScenarioComparisonPage() {
  const scenarioCache = useDataStore((s) => s.scenarioCache);
  const options = useMemo(() => availableScenarios(scenarioCache), [scenarioCache]);
  const groups = BASELINE_SCENARIO_GROUPS.filter((group) => options.some((item) => item.group === group));

  const [slots, setSlots] = useState<ComparisonSlot[]>(() => {
    const loaded = availableScenarios(useDataStore.getState().scenarioCache);
    const chosen = DEFAULT_SCENARIO_IDS.map((id) => loaded.find((item) => item.id === id)).filter(
      (item): item is BaselineScenarioOption => Boolean(item),
    );
    const initial = chosen.length > 0 ? chosen : loaded.slice(0, 2);
    return initial.map((item, index) => ({ key: `slot-${index}`, scenarioId: item.id }));
  });

  const columns = useMemo(() => {
    const labelCounts = new Map<string, number>();
    return slots.flatMap((slot, index) => {
      const scenario = scenarioById(slot.scenarioId);
      if (!scenario) return [];
      const data = scenarioCache[scenario.filename];
      if (!data) return [];
      const baseLabel = scenario.label;
      const seen = (labelCounts.get(baseLabel) ?? 0) + 1;
      labelCounts.set(baseLabel, seen);
      const seriesLabel = seen === 1 ? baseLabel : `${baseLabel} (${seen})`;
      return [
        {
          key: slot.key,
          scenario,
          color: SLOT_COLORS[index % SLOT_COLORS.length],
          seriesLabel,
          daily: data.daily.p50,
          thresh: data.thresholdByMonth.meanPct,
          harvestMedian: getMedianOnionCFUPerPlant(data),
        },
      ];
    });
  }, [slots, scenarioCache]);

  const yearRoundLines: ChartLine[] = columns.map((column) => ({
    data: column.daily,
    color: column.color,
    label: column.seriesLabel,
    bold: true,
  }));

  function scenariosInGroup(group: string) {
    return options.filter((item) => item.group === group);
  }

  function updateGroup(key: string, group: string) {
    const next = scenariosInGroup(group)[0];
    if (!next) return;
    setSlots((prev) => prev.map((slot) => (slot.key === key ? { ...slot, scenarioId: next.id } : slot)));
  }

  function updateScenario(key: string, scenarioId: string) {
    setSlots((prev) => prev.map((slot) => (slot.key === key ? { ...slot, scenarioId } : slot)));
  }

  function removeSlot(key: string) {
    setSlots((prev) => (prev.length <= 1 ? prev : prev.filter((slot) => slot.key !== key)));
  }

  function addSlot() {
    setSlots((prev) => {
      if (prev.length >= MAX_SLOTS || options.length === 0) return prev;
      const used = new Set(prev.map((slot) => slot.scenarioId));
      const next = options.find((item) => !used.has(item.id)) ?? options[0];
      return [...prev, { key: `slot-${Date.now()}`, scenarioId: next.id }];
    });
  }

  if (options.length === 0) {
    return (
      <div className="space-y-6">
        <div>
          <h2 className="text-3xl font-bold text-uga-black">Scenario Comparison</h2>
          <p className="text-lg text-uga-dark-gray">
          {withItalicEColi('Compare baseline farm scenarios side by side.')}
        </p>
        </div>
        <Card className="border-uga-warning/40 bg-uga-warning/5">
          <CardContent className="py-12 text-center text-lg text-uga-dark-gray">
            Scenario JSON files are not available in{' '}
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
          {withItalicEColi(
            'Pick up to four baseline scenarios. Year-round soil E. coli is overlaid, and harvest threshold charts sit side by side.',
          )}
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
          const scenario = scenarioById(slot.scenarioId);
          const group = scenario?.group ?? groups[0];
          const groupOptions = scenariosInGroup(group);
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
                  <span className="text-sm font-medium text-uga-dark-gray">Scenario group</span>
                  <select
                    className={selectClass}
                    value={group}
                    onChange={(event) => updateGroup(slot.key, event.target.value)}
                  >
                    {groups.map((item) => (
                      <option key={item} value={item}>
                        {item}
                      </option>
                    ))}
                  </select>
                </label>

                <label className="block space-y-1">
                  <span className="text-sm font-medium text-uga-dark-gray">Scenario</span>
                  <select
                    className={selectClass}
                    value={slot.scenarioId}
                    onChange={(event) => updateScenario(slot.key, event.target.value)}
                  >
                    {groupOptions.map((item) => (
                      <option key={item.id} value={item.id}>
                        {item.label}
                      </option>
                    ))}
                  </select>
                </label>

                <p className="text-sm text-uga-dark-gray">{scenario?.description}</p>
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
            label="Median E. coli per onion at harvest"
            value={column.harvestMedian.toFixed(3)}
            unit="CFU/onion"
            subtext={column.seriesLabel}
          />
        ))}
      </div>

      <YearRoundLineChart
        title="Year-Round Soil CFU"
        subtitle="Median soil E. coli for each selected baseline scenario"
        lines={yearRoundLines}
        height={360}
      />

      <div className={cn('grid grid-cols-1 gap-4', columns.length > 1 && 'xl:grid-cols-2')}>
        {columns.map((column) => (
          <HarvestBarChart
            key={column.key}
            threshByMonth={column.thresh}
            title={`Harvest Contamination: ${column.seriesLabel}`}
            subtitle="% of plants exceeding 1 / 5 / 10 / 20 CFU on the onion surface (Jan–May)"
            headerClassName={columns.length > 1 ? 'min-h-36' : undefined}
          />
        ))}
      </div>

      <InsightBox>
        <span className="inline-flex items-start gap-2">
          <Layers size={16} className="mt-1 shrink-0 text-uga-red" />
          <span>
            Each card is one baseline scenario, with every other farm condition held at baseline. The
            year-round chart overlays those soil medians. Harvest charts use the same 1, 5, 10, and 20 CFU
            thresholds as the Baseline page.
          </span>
        </span>
      </InsightBox>
    </div>
  );
}
