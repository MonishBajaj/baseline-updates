import { FarmCharacteristics } from '@/components/FarmCharacteristics';
import { MetricCard } from '@/components/ui/MetricCard';
import { HarvestBarChart } from '@/components/charts/HarvestBarChart';
import { YearRoundLineChart } from '@/components/charts/YearRoundLineChart';
import { SourceDonut } from '@/components/charts/SourceDonut';
import { InsightBox } from '@/components/ui/InsightBox';
import { HARVEST_INDICES, HARVEST_MONTH_NAMES, PREVALENCE_LOD } from '@/constants';
import { resolveScenarioFilename } from '@/lib/scenarioFiles';
import { getMedianOnionCFUPerPlant, getOverallPrevalencePct } from '@/lib/summaryMetrics';
import { useDataStore } from '@/store/dataStore';
import { isFarmCharacteristicsDefault, useScenarioStore } from '@/store/scenarioStore';
import type { BaselineData } from '@/types';

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
  const scenarioFilename = resolveScenarioFilename(farmCharacteristics);
  const isBaseline = isFarmCharacteristicsDefault(farmCharacteristics);
  const hasResults = scenarioData !== null;
  const missingFilename = resolveScenarioFilename(farmCharacteristics) === null && !isBaseline;

  if (!hasResults) {
    return (
      <div className="space-y-6">
        <div>
          <h2 className="text-3xl font-bold text-uga-black">Baseline Reference Scenario</h2>
          <p className="text-lg text-uga-dark-gray">
            Both contamination sources (irrigation water and wildlife) at 100% of their
            standard modeled levels.
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
  const showCarryover =
    hasSourceContribution && sourceContribution.carryoverPct >= 0.5;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold text-uga-black">
          {isBaseline ? 'Baseline Reference Scenario' : 'Farm Characteristic Scenario'}
        </h2>
        <p className="text-lg text-uga-dark-gray">
          {isBaseline
            ? `Both contamination sources (irrigation water and wildlife) at 100% of their standard modeled levels. Based on ${summary.iterations.toLocaleString()} simulation runs and ${summary.totalPlants.toLocaleString()} plants.`
            : `Single-parameter change from baseline; all other farm characteristics held at baseline defaults. Based on ${summary.iterations.toLocaleString()} simulation runs and ${summary.totalPlants.toLocaleString()} plants.`}
        </p>
      </div>

      <FarmCharacteristics />

      {!isBaseline && (
        <div className="rounded-md border border-uga-card-border bg-white px-4 py-3 text-lg text-uga-dark-gray">
          Showing pre-run simulation results for the selected farm characteristic change
          {scenarioFilename ? (
            <>
              {' '}
              (<code className="rounded bg-uga-mid-gray/60 px-1 py-0.5 text-base">{scenarioFilename}</code>).
            </>
          ) : (
            '.'
          )}
        </div>
      )}

      {/* KPI groups */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <div>
          <h3 className="mb-3 text-lg font-semibold text-uga-black">Contamination Outcomes</h3>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <MetricCard
              label="Median CFU per Plant"
              value={medianOnionCFU.toFixed(3)}
              unit="CFU/plant"
              subtext="Onion-surface CFU at harvest, all plants and iterations"
            />
            <MetricCard
              label="Onion Contamination Prevalence"
              value={overallPrevalencePct.toFixed(3)}
              unit="%"
              subtext={`Onion-surface CFU \u2265 LOD (${PREVALENCE_LOD})`}
            />
          </div>
        </div>

        <div>
          <h3 className="mb-3 text-lg font-semibold text-uga-black">Source Contribution</h3>
          {hasSourceContribution ? (
            <div
              className={`grid grid-cols-1 gap-4 ${showCarryover ? 'sm:grid-cols-3' : 'sm:grid-cols-2'}`}
            >
              <MetricCard
                label="Irrigation Water"
                value={sourceContribution.irrigationPct.toFixed(1)}
                unit="% of total"
                subtext="Harvest CFU from irrigation via soil route"
              />
              <MetricCard
                label="Wildlife Intrusion"
                value={sourceContribution.wildlifePct.toFixed(1)}
                unit="% of total"
                subtext="Harvest onion-surface CFU from wildlife"
              />
              {showCarryover && (
                <MetricCard
                  label="Prior-Season Carryover"
                  value={sourceContribution.carryoverPct.toFixed(1)}
                  unit="% of total"
                  subtext="Legacy soil CFU from prior season"
                />
              )}
            </div>
          ) : (
            <div className="rounded-md border border-uga-card-border bg-white px-4 py-3 text-lg text-uga-dark-gray">
              Re-export baseline JSON to populate source attribution (wildlife / irrigation / carryover).
            </div>
          )}
        </div>
      </div>

      {/* Row 2 — year round fan + donut */}
      <div className="grid grid-cols-1 gap-4 lg:grid-cols-3">
        <div className="lg:col-span-2">
          <YearRoundLineChart
            title={isBaseline ? 'Year-Round Soil CFU: Baseline' : 'Year-Round Soil CFU: Scenario'}
            subtitle="Median across all iterations, both contamination sources combined"
            lines={[{ data: daily.p50, color: '#BA0C2F', label: 'Median Soil CFU', bold: true }]}
          />
        </div>
        {hasSourceContribution ? (
          <SourceDonut
            title="Source Contribution"
            subtitle="Share of harvest onion-surface CFU by contamination source"
            irrigationPct={sourceContribution.irrigationPct}
            wildlifePct={sourceContribution.wildlifePct}
            carryoverPct={sourceContribution.carryoverPct}
          />
        ) : (
          <div className="rounded-md border border-uga-card-border bg-white px-4 py-6 text-center">
            <h3 className="text-lg font-semibold text-uga-black">Source Contribution</h3>
            <p className="mt-2 text-base text-uga-dark-gray">
              Re-export <code className="rounded bg-uga-mid-gray/60 px-1 py-0.5">baseline_fin.json</code> from
              Updated_Baseline.m to show wildlife vs irrigation harvest attribution.
            </p>
          </div>
        )}
      </div>

      {/* Row 3 — harvest month bar chart */}
      <HarvestBarChart
        threshByMonth={scenarioData.thresholdByMonth.meanPct}
        title={
          isBaseline
            ? 'Baseline Harvest Contamination: Percent of Plants Exceeding E. coli Threshold'
            : 'Harvest Contamination: Percent of Plants Exceeding E. coli Threshold'
        }
        subtitle={`n = ${summary.iterations.toLocaleString()} Monte Carlo iterations \u00b7 Both sources at 100% \u00b7 ${summary.totalPlants.toLocaleString()} plants total`}
      />

      <InsightBox>
        {isBaseline ? (
          hasSourceContribution ? (
            <>
              At harvest, <strong>irrigation</strong> accounts for{' '}
              <strong>{sourceContribution.irrigationPct.toFixed(1)}%</strong> of onion-surface E.&nbsp;coli (via
              soil) and <strong>wildlife intrusion</strong> accounts for{' '}
              <strong>{sourceContribution.wildlifePct.toFixed(1)}%</strong>
              {showCarryover ? (
                <>
                  , with <strong>{sourceContribution.carryoverPct.toFixed(1)}%</strong> from prior-season soil
                  carryover
                </>
              ) : null}
              . All contamination uses the soil-transfer route (bulbing to harvest, daily). Among harvest months
              (Jan-May), <strong>{peakMonth}</strong> shows the highest mean number of plants exceeding the &gt;1 CFU
              threshold.
            </>
          ) : (
            <>
              Re-export baseline JSON to populate source attribution. Among harvest months (Jan-May),{' '}
              <strong>{peakMonth}</strong> shows the highest mean number of plants exceeding the &gt;1 CFU threshold.
            </>
          )
        ) : hasSourceContribution ? (
          <>
            Compared to baseline, this scenario shows a median onion-surface CFU per plant of{' '}
            <strong>{medianOnionCFU.toFixed(3)}</strong> and overall onion-surface prevalence of{' '}
            <strong>{overallPrevalencePct.toFixed(3)}%</strong>. Irrigation source contributes{' '}
            <strong>{sourceContribution.irrigationPct.toFixed(1)}%</strong> (via soil) and wildlife contributes{' '}
            <strong>{sourceContribution.wildlifePct.toFixed(1)}%</strong> of harvest onion-surface CFU.
          </>
        ) : (
          <>
            Compared to baseline, this scenario shows a median onion-surface CFU per plant of{' '}
            <strong>{medianOnionCFU.toFixed(3)}</strong> and overall onion-surface prevalence of{' '}
            <strong>{overallPrevalencePct.toFixed(3)}%</strong>. All contamination reaches the onion surface through
            the soil-transfer route.
          </>
        )}
      </InsightBox>
    </div>
  );
}
