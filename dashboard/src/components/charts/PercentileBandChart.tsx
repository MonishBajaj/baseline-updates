import { Area, CartesianGrid, ComposedChart, Line, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { Card, CardContent, CardHeader, CardSubtitle, CardTitle } from '@/components/ui/Card';
import { MONTH_LABELS, MONTH_TICKS } from '@/constants';
import { log10p1 } from '@/lib/utils';

interface PercentileBandChartProps {
  p25: number[];
  p50: number[];
  p75: number[];
  color: string;
  title: string;
  subtitle?: string;
  height?: number;
}

/** Median line with a shaded 25th-75th percentile band, over the 365-day fiscal year. */
export function PercentileBandChart({ p25, p50, p75, color, title, subtitle, height = 260 }: PercentileBandChartProps) {
  const chartData = Array.from({ length: 365 }, (_, i) => ({
    day: i + 1,
    p25: log10p1(p25[i] ?? 0),
    band: Math.max(0, log10p1(p75[i] ?? 0) - log10p1(p25[i] ?? 0)),
    median: log10p1(p50[i] ?? 0),
  }));

  return (
    <Card>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
        {subtitle && <CardSubtitle>{subtitle}</CardSubtitle>}
      </CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={height}>
          <ComposedChart data={chartData} margin={{ top: 10, right: 20, bottom: 30, left: 10 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#E0E0E0" />
            <XAxis
              dataKey="day"
              ticks={MONTH_TICKS}
              tickFormatter={(v: number) => MONTH_LABELS[MONTH_TICKS.indexOf(v)] ?? ''}
              tick={{ fontSize: 15 }}
            />
            <YAxis
              label={{ value: 'log\u2081\u2080(CFU + 1)', angle: -90, position: 'insideLeft', fontSize: 15 }}
              tick={{ fontSize: 15 }}
            />
            <Tooltip labelFormatter={(d) => `Day ${d}`} formatter={(v) => Number(v).toFixed(2)} />
            {/* stacked invisible base (p25) + visible band (p75-p25) creates a floating IQR ribbon */}
            <Area type="monotone" dataKey="p25" stackId="band" stroke="none" fill="transparent" />
            <Area type="monotone" dataKey="band" stackId="band" stroke="none" fill={color} fillOpacity={0.15} name="P25-P75" />
            <Line type="monotone" dataKey="median" stroke={color} strokeWidth={2} dot={false} name="Median" />
          </ComposedChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  );
}
