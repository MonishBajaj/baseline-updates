import { Cell, Legend, Pie, PieChart, ResponsiveContainer, Tooltip } from 'recharts';
import { Card, CardContent, CardHeader, CardSubtitle, CardTitle } from '@/components/ui/Card';

interface SourceDonutProps {
  irrigationPct: number;
  wildlifePct: number;
  carryoverPct?: number;
  irrigationLabel?: string;
  wildlifeLabel?: string;
  title: string;
  subtitle?: string;
}

const IRRIGATION_COLOR = '#1565C0';
const WILDLIFE_COLOR = '#2E7D32';
const CARRYOVER_COLOR = '#6D4C41';

export function SourceDonut({
  irrigationPct,
  wildlifePct,
  carryoverPct,
  irrigationLabel = 'Irrigation Water',
  wildlifeLabel = 'Wildlife Intrusion',
  title,
  subtitle,
}: SourceDonutProps) {
  const showCarryover = carryoverPct !== undefined && carryoverPct >= 0.5;
  const data = showCarryover
    ? [
        { name: irrigationLabel, value: irrigationPct, color: IRRIGATION_COLOR },
        { name: wildlifeLabel, value: wildlifePct, color: WILDLIFE_COLOR },
        { name: 'Prior-Season Carryover', value: carryoverPct, color: CARRYOVER_COLOR },
      ]
    : [
        { name: irrigationLabel, value: irrigationPct, color: IRRIGATION_COLOR },
        { name: wildlifeLabel, value: wildlifePct, color: WILDLIFE_COLOR },
      ];

  return (
    <Card>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
        {subtitle && <CardSubtitle>{subtitle}</CardSubtitle>}
      </CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={260}>
          <PieChart>
            <Pie data={data} dataKey="value" nameKey="name" innerRadius={60} outerRadius={90} paddingAngle={2}>
              {data.map((entry) => (
                <Cell key={entry.name} fill={entry.color} />
              ))}
            </Pie>
            <Tooltip formatter={(v) => `${Number(v).toFixed(1)}%`} contentStyle={{ fontSize: 16 }} />
            <Legend verticalAlign="bottom" wrapperStyle={{ fontSize: 18 }} />
          </PieChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  );
}
