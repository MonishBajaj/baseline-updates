import { FarmCharacteristics } from '@/components/FarmCharacteristics';
import { MetricCard } from '@/components/ui/MetricCard';
import { HarvestBarChart } from '@/components/charts/HarvestBarChart';
import { YearRoundLineChart } from '@/components/charts/YearRoundLineChart';
import { SourceDonut } from '@/components/charts/SourceDonut';
import { BarChart3 } from 'lucide-react';
import { HARVEST_INDICES, HARVEST_MONTH_NAMES, PREVALENCE_LOD } from '@/constants';
import { resolveScenarioFilename } from '@/lib/scenarioFiles';
import { getMedianOnionCFUPerPlant, getOverallPrevalencePct } from '@/lib/summaryMetrics';
import { useDataStore } from '@/store/dataStore';
import { isFarmCharacteristicsDefault, useScenarioStore } from '@/store/scenarioStore';
import type { BaselineData } from '@/types';

const HARVEST_MONTH_FULL: Record<string, string> = {
  Jan: 'January',
  Feb: 'February',
  Mar: 'March',
  Apr: 'April',
  May: 'May',
};

function peakRiskMonth(baseline: BaselineData, thresholdIdx = 0): string {
  let best = HARVEST_MONTH_NAMES[0];
  let bestVal = -Infinity;
  HARVEST_INDICES.forEach((monthIdx, i) => {
    const val = baseline.thresholdByMonth.mean[monthIdx]?.[thresholdIdx] ?? 0;
    if (val > bestVal) {
      bestVal = val;
      best = HARVEST_MONTH_NAMES[i];
    }
  });
  return best;
}

export function BaselinePage() {
  const farmCharacteristics = useScenarioStore((s) => s.farmCharacteristics);
  const getScenarioData = useDataStore((s) => s.getScenarioData);
  const scenarioData = getScenarioData(farmCharacteristics);
  const isBaseline = isFarmCharacteristicsDefault(farmCharacteristics);
  const hasResults = scenarioData !== null;
  const missingFilename = resolveScenarioFilename(farmCharacteristics) === null && !isBaseline;

  if (!hasResults) {
    return (
      <div className="space-y-6">
        <div>
          <h2 className="text-3xl font-bold text-uga-black">Baseline Model</h2>
          <p className="text-lg text-uga-dark-gray">
            The baseline represents the reference production scenario used throughout the dashboard. When you change
            one variable, all other variables remain at their baseline levels unless otherwise specified.
          </p>
        </div>
        <FarmCharacteristics />
        <div className="rounded-md border border-uga-card-border bg-white px-4 py-3 text-lg text-uga-dark-gray">
          {missingFilename
            ? 'Multiple farm characteristics differ from baseline at once. Change one setting at a time to view pre-run scenario results.'
            : 'Scenario results are not available for the current selection.'}
        </div>
      </div>
    );
  }

  const { summary, sourceContribution, daily } = scenarioData;
  const medianOnionCFU = getMedianOnionCFUPerPlant(scenarioData);
  const overallPrevalencePct = getOverallPrevalencePct(scenarioData);
  const peakMonth = peakRiskMonth(scenarioData);
  const hasSourceContribution = sourceContribution !== undefined;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold text-uga-black">
          {isBaseline ? 'Baseline Model' : 'Farm Characteristic Scenario'}
        </h2>
        <p className="text-lg text-uga-dark-gray">
          {isBaseline
            ? 'The baseline represents the reference production scenario used throughout the dashboard. When you change one variable, all other variables remain at their baseline levels unless otherwise specified.'
            : `Single-parameter change from baseline; all other farm characteristics held at baseline defaults. Based on ${summary.iterations.toLocaleString()} simulation runs and ${summary.totalPlants.toLocaleString()} plants.`}
        </p>
      </div>

      <FarmCharacteristics />

      {/* KPI groups */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <div>
          <h3 className="mb-3 text-lg font-semibold text-uga-black">Predicted Harvest Outcomes</h3>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <MetricCard
              label="Predicted E. coli per onion at harvest"
              value={medianOnionCFU.toFixed(3)}
              unit="CFU/onion"
              subtext="Median onion-surface generic E. coli across all plants and simulation runs"
            />
            <MetricCard
              label="Predicted contaminated onions at harvest"
              value={overallPrevalencePct.toFixed(3)}
              unit="%"
              subtext={`Percent of onions with generic E. coli \u2265 ${PREVALENCE_LOD} CFU/onion`}
            />
          </div>
        </div>

        <div>
          <h3 className="mb-3 text-lg font-semibold text-uga-black">Estimated Source Contribution</h3>
          {hasSourceContribution ? (
            <SourceDonut
              irrigationPct={sourceContribution.irrigationPct}
              wildlifePct={sourceContribution.wildlifePct}
              carryoverPct={sourceContribution.carryoverPct}
            />
          ) : (
            <div className="rounded-md border border-uga-card-border bg-white px-4 py-3 text-lg text-uga-dark-gray">
              Re-export baseline JSON to populate source attribution (wildlife / irrigation / carryover).
            </div>
          )}
        </div>
      </div>

      <div className="grid grid-cols-1 items-start gap-4 lg:grid-cols-2">
        <YearRoundLineChart
          title="Predicted Soil Generic E. coli Over the Production Year"
          subtitle="Median modeled soil generic E. coli across all simulation runs"
          lines={[{ data: daily.p50, color: '#BA0C2F', label: 'Median Soil CFU', bold: true }]}
          height={400}
        />
        <HarvestBarChart
          threshByMonth={scenarioData.thresholdByMonth.meanPct}
          title="Predicted Harvest Contamination by Month and Threshold"
          subtitle="Percent of onions exceeding selected generic E. coli thresholds by harvest month"
        />
      </div>

      <div className="rounded-md border border-l-4 border-uga-card-border border-l-uga-red bg-uga-red/5 p-4">
        <div className="flex items-center gap-2.5">
          <span className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-uga-red/15 text-uga-red">
            <BarChart3 size={16} />
          </span>
          <h3 className="text-lg font-semibold text-uga-red">Key Takeaways</h3>
        </div>
        <ol className="mt-3 space-y-2">
          {hasSourceContribution && (
            <>
              <li className="flex items-start gap-2.5 text-lg leading-relaxed text-uga-dark-gray">
                <span className="mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-uga-red/15 text-base font-semibold text-uga-red">
                  1
                </span>
                <span>
                  Main source:{' '}
                  <strong className="font-semibold text-uga-red">
                    Irrigation water ({sourceContribution.irrigationPct.toFixed(1)}%)
                  </strong>
                </span>
              </li>
              <li className="flex items-start gap-2.5 text-lg leading-relaxed text-uga-dark-gray">
                <span className="mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-uga-red/15 text-base font-semibold text-uga-red">
                  2
                </span>
                <span>
                  Secondary source:{' '}
                  <strong className="font-semibold text-uga-red">
                    Wildlife ({sourceContribution.wildlifePct.toFixed(1)}%)
                  </strong>
                </span>
              </li>
            </>
          )}
          <li className="flex items-start gap-2.5 text-lg leading-relaxed text-uga-dark-gray">
            <span className="mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-uga-red/15 text-base font-semibold text-uga-red">
              {hasSourceContribution ? 3 : 1}
            </span>
            <span>
              Highest harvest contamination month:{' '}
              <strong className="font-semibold text-uga-red">
                {HARVEST_MONTH_FULL[peakMonth] ?? peakMonth}
              </strong>{' '}
              for onions exceeding &gt;1 CFU
            </span>
          </li>
        </ol>
      </div>
    </div>
  );
}
