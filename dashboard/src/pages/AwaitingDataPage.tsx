import { Card, CardContent } from '@/components/ui/Card';

interface AwaitingDataPageProps {
  pageTitle: string;
  description: string;
  requiredFiles: string[];
}

export function AwaitingDataPage({ pageTitle, description, requiredFiles }: AwaitingDataPageProps) {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-3xl font-bold text-uga-black">{pageTitle}</h2>
        <p className="text-lg text-uga-dark-gray">{description}</p>
      </div>

      <Card className="border-uga-warning/40 bg-uga-warning/5">
        <CardContent className="flex flex-col items-center gap-3 py-12 text-center">
          <p className="text-lg font-semibold text-uga-black">Waiting on simulation output</p>
          <p className="max-w-md text-lg text-uga-dark-gray">
            This page renders as soon as the required JSON file(s) below are present in{' '}
            <code className="rounded bg-uga-mid-gray/60 px-1 py-0.5 text-base">dashboard/public/data/</code>. Run{' '}
            <code className="rounded bg-uga-mid-gray/60 px-1 py-0.5 text-base">Scenario_Updated.m</code> in MATLAB, then
            copy the generated files over.
          </p>
          <ul className="mt-1 space-y-1 text-base text-uga-dark-gray">
            {requiredFiles.map((f) => (
              <li key={f} className="font-mono">
                {f}
              </li>
            ))}
          </ul>
        </CardContent>
      </Card>
    </div>
  );
}
