import { cn } from '@/lib/utils';

interface MetricCardProps {
  label: string;
  value: string;
  unit?: string;
  subtext?: string;
  changePct?: number; // positive = worse (red), negative = better (green)
  className?: string;
}

export function MetricCard({ label, value, unit, subtext, changePct, className }: MetricCardProps) {
  return (
    <div
      className={cn(
        'rounded-md border border-uga-card-border bg-white p-4 shadow-sm border-l-4 border-l-uga-red',
        className,
      )}
    >
      <p className="text-base font-semibold uppercase tracking-wide text-uga-dark-gray">{label}</p>
      <div className="mt-2 flex items-baseline gap-1.5">
        <span className="text-3xl font-bold text-uga-black">{value}</span>
        {unit && <span className="text-lg text-uga-dark-gray">{unit}</span>}
      </div>
      {typeof changePct === 'number' && (
        <p className={cn('mt-1 text-base font-medium', changePct > 0 ? 'text-uga-danger' : 'text-uga-success')}>
          {changePct > 0 ? '+' : ''}
          {changePct.toFixed(1)}% vs. baseline
        </p>
      )}
      {subtext && <p className="mt-1 text-base text-uga-dark-gray">{subtext}</p>}
    </div>
  );
}
