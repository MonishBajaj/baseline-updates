import { useEffect } from 'react';
import { Header } from '@/components/layout/Header';
import { Sidebar } from '@/components/layout/Sidebar';
import { useDataStore } from '@/store/dataStore';
import { useScenarioStore } from '@/store/scenarioStore';
import { BaselinePage } from '@/pages/BaselinePage';
import { IntroductionPage } from '@/pages/IntroductionPage';
import { ComparisonPage } from '@/pages/ComparisonPage';
import { SensitivityPage } from '@/pages/SensitivityPage';
import { ReferencesPage } from '@/pages/ReferencesPage';

function LoadingScreen() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-uga-light-gray">
      <div className="text-center">
        <div className="mx-auto mb-4 h-16 w-16 animate-spin rounded-full border-4 border-uga-red border-t-transparent" />
        <p className="font-semibold text-uga-black">Loading QMRA Data</p>
        <p className="mt-1 text-base text-uga-dark-gray">Preparing Monte Carlo simulation results...</p>
      </div>
    </div>
  );
}

function ErrorScreen({ message }: { message: string }) {
  return (
    <div className="flex min-h-screen items-center justify-center bg-uga-light-gray px-6">
      <div className="max-w-md rounded-md border border-uga-danger/40 bg-white p-6 text-center shadow-sm">
        <p className="font-semibold text-uga-danger">Failed to load simulation data</p>
        <p className="mt-2 text-base text-uga-dark-gray">{message}</p>
      </div>
    </div>
  );
}

function App() {
  const { baseline, loading, error, loadData } = useDataStore();
  const { activeTab } = useScenarioStore();

  useEffect(() => {
    loadData();
  }, [loadData]);

  if (loading) return <LoadingScreen />;
  if (error || !baseline) return <ErrorScreen message={error ?? 'Unknown error'} />;

  return (
    <div className="min-h-screen bg-uga-light-gray">
      <Header />
      <Sidebar />
      <main className="min-h-screen pt-16 pl-64">
        <div className="p-6">
          {activeTab === 'introduction' && <IntroductionPage />}
          {activeTab === 'baseline' && <BaselinePage />}
          {activeTab === 'sensitivity' && <SensitivityPage />}
          {activeTab === 'comparison' && <ComparisonPage />}
          {activeTab === 'references' && <ReferencesPage />}
        </div>
      </main>
    </div>
  );
}

export default App;
