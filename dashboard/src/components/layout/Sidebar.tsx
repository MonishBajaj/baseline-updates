import { BookOpen, BarChart2, TrendingUp, GitCompare, Library, MapPin, Sprout, RefreshCw, CalendarDays } from 'lucide-react';
import { cn } from '@/lib/utils';
import { useScenarioStore, type PageId } from '@/store/scenarioStore';
import { useDataStore } from '@/store/dataStore';
import { FIELD_INFO } from '@/constants';

interface NavItem {
  id: PageId;
  label: string;
  icon: React.ReactNode;
  desc: string;
  requiresScenarioData: boolean;
}

const navItems: NavItem[] = [
  { id: 'introduction', label: 'Introduction', icon: <BookOpen size={16} />, desc: 'About this dashboard', requiresScenarioData: false },
  { id: 'baseline', label: 'Baseline & Scenarios', icon: <BarChart2 size={16} />, desc: 'Default season and farm what-ifs', requiresScenarioData: false },
  { id: 'sensitivity', label: 'Sensitivity Analysis', icon: <TrendingUp size={16} />, desc: 'Full gradient overview', requiresScenarioData: true },
  { id: 'comparison', label: 'Comparison', icon: <GitCompare size={16} />, desc: 'Compare up to 4 scenarios', requiresScenarioData: true },
  { id: 'references', label: 'References', icon: <Library size={16} />, desc: 'Sources and citations', requiresScenarioData: false },
];

export function Sidebar() {
  const { activeTab, setActiveTab } = useScenarioStore();
  const { baseline, wildlife, irrigation, wildlifePrevalence, irrigationPrevalence, bothPrevalence } =
    useDataStore();
  const scenarioDataReady = Boolean(
    wildlife && irrigation && wildlifePrevalence && irrigationPrevalence && bothPrevalence,
  );
  const iterations = baseline?.summary.iterations;

  return (
    <aside className="fixed top-16 bottom-0 left-0 flex w-64 flex-col bg-uga-sidebar-bg">
      <nav className="flex-1 space-y-1 p-3">
        {navItems.map((item) => {
          const pending = item.requiresScenarioData && !scenarioDataReady;
          const active = activeTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => setActiveTab(item.id)}
              className={cn(
                'flex w-full items-start gap-3 rounded-md px-3 py-2.5 text-left transition-colors',
                active ? 'bg-uga-sidebar-active text-white' : 'text-uga-sidebar-text hover:bg-white/10',
              )}
            >
              <span className={cn('mt-0.5', active ? 'text-white' : 'text-white/70')}>{item.icon}</span>
              <span className="flex-1">
                <span className="flex items-center gap-1.5 text-lg font-medium">
                  {item.label}
                  {pending && (
                    <span
                      title="Awaiting Scenario_Updated.m export files"
                      className="h-1.5 w-1.5 rounded-full bg-uga-warning"
                    />
                  )}
                </span>
                <span className={cn('block text-base', active ? 'text-white/80' : 'text-white/50')}>{item.desc}</span>
              </span>
            </button>
          );
        })}
      </nav>

      <div className="border-t border-white/10 p-4">
        <p className="mb-2 text-sm tracking-wide text-white/40 uppercase">Field Parameters</p>
        <div className="space-y-1.5">
          <p className="flex items-center gap-1.5 text-base text-white/70">
            <MapPin size={14} className="text-white/40" /> {FIELD_INFO.location}
          </p>
          <p className="flex items-center gap-1.5 text-base text-white/70">
            <Sprout size={14} className="text-white/40" /> {FIELD_INFO.fieldSize} · {FIELD_INFO.totalPlants.toLocaleString()} plants
          </p>
          <p className="flex items-center gap-1.5 text-base text-white/70">
            <RefreshCw size={14} className="text-white/40" /> n = {iterations ? iterations.toLocaleString() : 'N/A'} iterations
          </p>
          <p className="flex items-center gap-1.5 text-base text-white/70">
            <CalendarDays size={14} className="text-white/40" /> {FIELD_INFO.fiscalYearStart} fiscal year start
          </p>
        </div>
      </div>
    </aside>
  );
}
