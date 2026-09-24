import type { HTMLAttributes } from 'react';
import { cn } from '@/lib/utils';

type BadgeVariant = 'default' | 'success' | 'warning' | 'danger' | 'outline';

const variantClasses: Record<BadgeVariant, string> = {
  default: 'bg-uga-red text-white',
  success: 'bg-uga-success/10 text-uga-success border border-uga-success/30',
  warning: 'bg-uga-warning/10 text-uga-warning border border-uga-warning/30',
  danger: 'bg-uga-danger/10 text-uga-danger border border-uga-danger/30',
  outline: 'border border-uga-mid-gray text-uga-dark-gray',
};

export function Badge({
  className,
  variant = 'default',
  ...props
}: HTMLAttributes<HTMLSpanElement> & { variant?: BadgeVariant }) {
  return (
    <span
      className={cn(
        'inline-flex items-center rounded-full px-2.5 py-0.5 text-base font-medium',
        variantClasses[variant],
        className,
      )}
      {...props}
    />
  );
}
