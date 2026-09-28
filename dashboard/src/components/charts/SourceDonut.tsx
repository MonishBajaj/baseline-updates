import { Card, CardContent, CardHeader, CardSubtitle, CardTitle } from '@/components/ui/Card';

interface SourceDonutProps {
  irrigationPct: number;
  wildlifePct: number;
  carryoverPct?: number;
  irrigationLabel?: string;
  wildlifeLabel?: string;
  title?: string;
  subtitle?: string;
}

const IRRIGATION_COLOR = '#1E88E5';
const WILDLIFE_COLOR = '#43A047';
const CARRYOVER_COLOR = '#6D4C41';

interface Segment {
  name: string;
  value: number;
  color: string;
  detail: string;
}

export function SourceDonut({
  irrigationPct,
  wildlifePct,
  carryoverPct,
  irrigationLabel = 'Irrigation water',
  wildlifeLabel = 'Wildlife',
  title,
  subtitle,
}: SourceDonutProps) {
  const showCarryover = carryoverPct !== undefined && carryoverPct >= 0.5;
  const segments: Segment[] = [
    {
      name: irrigationLabel,
      value: irrigationPct,
      color: IRRIGATION_COLOR,
      detail: 'Estimated share of harvest onion-surface E. coli originating from irrigation water',
    },
    {
      name: wildlifeLabel,
      value: wildlifePct,
      color: WILDLIFE_COLOR,
      detail: 'Estimated share of harvest onion-surface E. coli originating from wildlife',
    },
    ...(showCarryover
      ? [
          {
            name: 'Prior-season carryover',
            value: carryoverPct,
            color: CARRYOVER_COLOR,
            detail: 'Legacy soil CFU from prior season',
          },
        ]
      : []),
  ].filter((segment) => segment.value > 0);

  const summary = segments.map((segment) => `${segment.value.toFixed(1)}% ${segment.name}`).join(', ');

  return (
    <Card className="self-start">
      {(title || subtitle) && (
        <CardHeader>
          {title && <CardTitle>{title}</CardTitle>}
          {subtitle && <CardSubtitle>{subtitle}</CardSubtitle>}
        </CardHeader>
      )}
      <CardContent>
        <div
          className="flex h-8 w-full overflow-hidden rounded-sm"
          role="img"
          aria-label={summary}
        >
          {segments.map((segment) => (
            <div
              key={segment.name}
              title={`${segment.name}: ${segment.value.toFixed(1)}%`}
              className="h-full"
              style={{
                flexGrow: segment.value,
                flexBasis: 0,
                minWidth: 4,
                backgroundColor: segment.color,
              }}
            />
          ))}
        </div>
        <div className="mt-3 flex justify-between gap-3">
          {segments.map((segment, index) => {
            const align =
              segments.length === 1
                ? 'text-left'
                : index === 0
                  ? 'text-left'
                  : index === segments.length - 1
                    ? 'text-right'
                    : 'text-center';
            return (
              <div key={segment.name} className={align}>
                <p className="text-2xl font-bold leading-none" style={{ color: segment.color }}>
                  {segment.value.toFixed(1)}%
                </p>
                <p className="mt-1 text-base text-uga-dark-gray">{segment.name}</p>
                <p className="mt-1 max-w-56 text-base leading-snug text-uga-dark-gray">{segment.detail}</p>
              </div>
            );
          })}
        </div>
      </CardContent>
    </Card>
  );
}
