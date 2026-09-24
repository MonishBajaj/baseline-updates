import type { ReactNode } from 'react';
import { Card, CardContent, CardHeader, CardSubtitle, CardTitle } from '@/components/ui/Card';

export const SCENARIO_RESULTS_PLACEHOLDER = 'Scenario results will appear here after simulation.';

interface ScenarioChartShellProps {
  title: string;
  subtitle?: string;
  height?: number;
  children?: ReactNode;
}

/** Card shell for charts — renders a placeholder when no children are provided. */
export function ScenarioChartShell({ title, subtitle, height = 300, children }: ScenarioChartShellProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
        {subtitle && <CardSubtitle>{subtitle}</CardSubtitle>}
      </CardHeader>
      <CardContent>
        {children ?? (
          <div
            className="flex items-center justify-center rounded-sm border border-dashed border-uga-mid-gray bg-uga-light-gray/50 px-4 text-center text-lg text-uga-dark-gray"
            style={{ height }}
          >
            {SCENARIO_RESULTS_PLACEHOLDER}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
