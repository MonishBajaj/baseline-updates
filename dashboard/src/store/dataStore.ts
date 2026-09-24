import { create } from 'zustand';
import type { BaselineData, IntensityData, PrevalenceData, ScenariosData } from '@/types';
import type { FarmCharacteristicsConfig } from '@/types';
import { withBase } from '@/lib/publicUrl';
import { SCENARIO_JSON_FILES, resolveScenarioFilename, scenarioDataUrl } from '@/lib/scenarioFiles';
import { SENSITIVITY_CANONICAL_FILES, SENSITIVITY_TEST_FILES, sensitivityTestDataUrl } from '@/lib/sensitivityFiles';

async function tryFetchJson<T>(path: string): Promise<T | null> {
  try {
    const res = await fetch(path);
    if (!res.ok) return null;
    return (await res.json()) as T;
  } catch {
    return null;
  }
}

/** Prefer a copied full-run file in /data/, then the 2-iteration test export. */
async function loadSensitivityJson<T>(canonical: string, testFile: string): Promise<T | null> {
  return (
    (await tryFetchJson<T>(scenarioDataUrl(canonical))) ??
    (await tryFetchJson<T>(sensitivityTestDataUrl(testFile)))
  );
}

interface DataState {
  baseline: BaselineData | null;
  scenarioCache: Record<string, BaselineData>;
  scenarios: ScenariosData | null;
  wildlife: IntensityData | null;
  irrigation: IntensityData | null;
  wildlifePrevalence: PrevalenceData | null;
  irrigationPrevalence: PrevalenceData | null;
  bothPrevalence: PrevalenceData | null;

  loading: boolean;
  error: string | null;
  loadData: () => Promise<void>;
  getScenarioData: (config: FarmCharacteristicsConfig) => BaselineData | null;
}

export const useDataStore = create<DataState>((set, get) => ({
  baseline: null,
  scenarioCache: {},
  scenarios: null,
  wildlife: null,
  irrigation: null,
  wildlifePrevalence: null,
  irrigationPrevalence: null,
  bothPrevalence: null,
  loading: true,
  error: null,

  getScenarioData: (config) => {
    const filename = resolveScenarioFilename(config);
    if (!filename) return null;
    return get().scenarioCache[filename] ?? null;
  },

  loadData: async () => {
    set({ loading: true, error: null });
    try {
      const uniqueFiles = [...new Set(SCENARIO_JSON_FILES)];

      const [scenarioEntries, scenarios, wildlife, irrigation, wildlifePrevalence, irrigationPrevalence, bothPrevalence] =
        await Promise.all([
          Promise.all(
            uniqueFiles.map(async (file) => {
              const data = await tryFetchJson<BaselineData>(scenarioDataUrl(file));
              return [file, data] as const;
            }),
          ),
          tryFetchJson<ScenariosData>(withBase('data/scenarios.json')),
          loadSensitivityJson<IntensityData>(
            SENSITIVITY_CANONICAL_FILES.wildlifeIntensity,
            SENSITIVITY_TEST_FILES.wildlifeIntensity,
          ),
          loadSensitivityJson<IntensityData>(
            SENSITIVITY_CANONICAL_FILES.irrigationIntensity,
            SENSITIVITY_TEST_FILES.irrigationIntensity,
          ),
          loadSensitivityJson<PrevalenceData>(
            SENSITIVITY_CANONICAL_FILES.wildlifePrevalence,
            SENSITIVITY_TEST_FILES.wildlifePrevalence,
          ),
          loadSensitivityJson<PrevalenceData>(
            SENSITIVITY_CANONICAL_FILES.irrigationPrevalence,
            SENSITIVITY_TEST_FILES.irrigationPrevalence,
          ),
          loadSensitivityJson<PrevalenceData>(
            SENSITIVITY_CANONICAL_FILES.bothPrevalence,
            SENSITIVITY_TEST_FILES.bothPrevalence,
          ),
        ]);

      const scenarioCache: Record<string, BaselineData> = {};
      for (const [file, data] of scenarioEntries) {
        if (data) scenarioCache[file] = data;
      }

      const baseline = scenarioCache['baseline_fin.json'] ?? null;
      if (!baseline) {
        set({
          loading: false,
          error: 'baseline_fin.json failed to load. Check that /public/data/baseline_fin.json exists.',
        });
        return;
      }

      set({
        baseline,
        scenarioCache,
        scenarios,
        wildlife,
        irrigation,
        wildlifePrevalence,
        irrigationPrevalence,
        bothPrevalence,
        loading: false,
      });
    } catch (err) {
      set({ error: String(err), loading: false });
    }
  },
}));
