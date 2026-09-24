import { Bar, BarChart, CartesianGrid, Legend, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { ChartLegend } from './ChartLegend';
import { Card, CardContent, CardHeader, CardSubtitle, CardTitle } from '@/components/ui/Card';
import { HARVEST_INDICES, HARVEST_MONTH_NAMES, THRESHOLD_COLORS, THRESHOLD_KEYS, THRESHOLD_LABELS } from '@/constants';

interface HarvestBarChartProps {
  /** [12 months][4 thresholds], Jul-start month order — matches thresholdByMonth.meanPct */
  threshByMonth: number[][];
  title: string;
  subtitle?: string;
}

function formatAxisPct(v: number): string {
  return `${v.toFixed(1)}%`;
}

function formatTooltipPct(v: number): string {
  return `${v.toFixed(3)}%`;
}

function thresholdItemOrder(dataKey: unknown): number {
  const idx = THRESHOLD_KEYS.indexOf(dataKey as (typeof THRESHOLD_KEYS)[number]);
  return idx === -1 ? Number.MAX_SAFE_INTEGER : idx;
}

export function HarvestBarChart({ threshByMonth, title, subtitle }: HarvestBarChartProps) {
  const chartData = HARVEST_MONTH_NAMES.map((month, i) => {
    const row = threshByMonth[HARVEST_INDICES[i]] ?? [0, 0, 0, 0];
    return {
      month,
      gt1: row[0] ?? 0,
      gt5: row[1] ?? 0,
      gt10: row[2] ?? 0,
      gt20: row[3] ?? 0,
    };
  });

  return (
    <Card>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
        {subtitle && <CardSubtitle>{subtitle}</CardSubtitle>}
      </CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={340}>
          <BarChart data={chartData} margin={{ top: 12, right: 20, bottom: 36, left: 40 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#E0E0E0" />
            <XAxis
              dataKey="month"
              label={{ value: 'Harvest Month', position: 'insideBottom', offset: -14, fontSize: 20 }}
              tick={{ fontSize: 18 }}
            />
            <YAxis
              width={84}
              tickMargin={10}
              label={{
                value: '% of Plants Exceeding Threshold',
                angle: -90,
                position: 'left',
                offset: 22,
                fontSize: 20,
                style: { textAnchor: 'middle' },
              }}
              tick={{ fontSize: 18 }}
              tickFormatter={formatAxisPct}
              domain={[0, 'auto']}
            />
            <Tooltip
              formatter={(v, name) => [formatTooltipPct(Number(v)), name]}
              itemSorter={(item) => thresholdItemOrder(item.dataKey)}
              contentStyle={{ fontSize: 16 }}
            />
            <Legend
              verticalAlign="top"
              content={
                <ChartLegend
                  items={THRESHOLD_KEYS.map((key, i) => ({ label: THRESHOLD_LABELS[i], color: THRESHOLD_COLORS[key] }))}
                />
              }
            />
            {THRESHOLD_KEYS.map((key, i) => (
              <Bar key={key} dataKey={key} name={THRESHOLD_LABELS[i]} fill={THRESHOLD_COLORS[key]} />
            ))}
          </BarChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  );
}
