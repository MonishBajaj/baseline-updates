import type { ReactNode } from 'react';
import { cn } from '@/lib/utils';

export function InsightBox({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <div
      className={cn(
        'rounded-md border border-l-4 border-uga-card-border border-l-uga-red bg-uga-red/5 p-4',
        className,
      )}
    >
      <div className="text-lg leading-relaxed text-uga-dark-gray">{children}</div>
    </div>
  );
}
