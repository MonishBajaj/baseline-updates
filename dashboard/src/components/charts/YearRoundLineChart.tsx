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

function SoilYAxisLabel(props: {
  viewBox?: Partial<{ x: number; y: number; width: number; height: number }> | unknown;
}) {
  const viewBox = props.viewBox as
    | Partial<{ x: number; y: number; width: number; height: number }>
    | undefined;
  const x = (viewBox?.x ?? 0) + 16;
  const y = (viewBox?.y ?? 0) + (viewBox?.height ?? 0) / 2;
  return (
    <text
      x={x}
      y={y}
      textAnchor="middle"
      fill="#4a4a4a"
      fontSize={16}
      transform={`rotate(-90, ${x}, ${y})`}
    >
      <tspan fontStyle="italic">E. coli</tspan>
      <tspan>(log</tspan>
      <tspan dy="5" fontSize="11">10</tspan>
      <tspan dy="-5">CFU/g) in the soil</tspan>
    </text>
  );
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
              width={78}
              tickMargin={10}
              label={{ content: SoilYAxisLabel }}
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
