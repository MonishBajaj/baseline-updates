import { CartesianGrid, Legend, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { Card, CardContent, CardHeader, CardSubtitle, CardTitle } from '@/components/ui/Card';
import { MONTH_LABELS, MONTH_TICKS } from '@/constants';
import { log10p1 } from '@/lib/utils';

export interface ChartLine {
  data: number[]; // 365 daily values
  color: string;
  label: string;
  bold?: boolean;
  dashed?: boolean;
}

interface YearRoundLineChartProps {
  lines: ChartLine[];
  title: string;
  subtitle?: string;
  height?: number;
}

export function YearRoundLineChart({ lines, title, subtitle, height = 300 }: YearRoundLineChartProps) {
  const chartData = Array.from({ length: 365 }, (_, i) => {
    const point: Record<string, number> = { day: i + 1 };
    lines.forEach((line) => {
      point[line.label] = log10p1(line.data[i] ?? 0);
    });
    return point;
  });

  return (
    <Card>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
        {subtitle && <CardSubtitle>{subtitle}</CardSubtitle>}
      </CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={height}>
          <LineChart data={chartData} margin={{ top: 12, right: 20, bottom: 42, left: 28 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#E0E0E0" />
            <XAxis
              dataKey="day"
              ticks={MONTH_TICKS}
              tickFormatter={(v: number) => MONTH_LABELS[MONTH_TICKS.indexOf(v)] ?? ''}
              label={{ value: 'Month', position: 'insideBottom', offset: -26, fontSize: 20 }}
              tick={{ fontSize: 18 }}
            />
            <YAxis
              width={64}
              tickMargin={10}
              label={{
                value: 'log10 (CFU/g) soil',
                angle: -90,
                position: 'left',
                offset: 18,
                fontSize: 20,
                style: { textAnchor: 'middle' },
              }}
              tick={{ fontSize: 18 }}
            />
            <Tooltip
              labelFormatter={(d) => `Day ${d}`}
              formatter={(v) => Number(v).toFixed(2)}
              contentStyle={{ fontSize: 16 }}
            />
            <Legend verticalAlign="top" wrapperStyle={{ fontSize: 18 }} />
            {lines.map((line) => (
              <Line
                key={line.label}
                type="monotone"
                dataKey={line.label}
                stroke={line.color}
                dot={false}
                strokeWidth={line.bold ? 2.5 : 1.5}
                strokeDasharray={line.dashed ? '6 4' : undefined}
              />
            ))}
          </LineChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  );
}
