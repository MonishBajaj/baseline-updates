import type { HTMLAttributes, ReactNode } from 'react';
import { withItalicEColi } from '@/lib/eColi';
import { cn } from '@/lib/utils';

function italicizeText(children: ReactNode): ReactNode {
  return typeof children === 'string' ? withItalicEColi(children) : children;
}

export function Card({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn('rounded-md border border-uga-card-border bg-white shadow-sm', className)}
      {...props}
    />
  );
}

export function CardHeader({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return <div className={cn('px-4 pt-4', className)} {...props} />;
}

export function CardTitle({ className, children, ...props }: HTMLAttributes<HTMLHeadingElement>) {
  return (
    <h3 className={cn('text-lg font-semibold text-uga-black', className)} {...props}>
      {italicizeText(children)}
    </h3>
  );
}

export function CardSubtitle({ className, children, ...props }: HTMLAttributes<HTMLParagraphElement>) {
  return (
    <p className={cn('mt-0.5 text-base text-uga-dark-gray', className)} {...props}>
      {italicizeText(children)}
    </p>
  );
}

export function CardContent({ className, ...props }: HTMLAttributes<HTMLDivElement>) {
  return <div className={cn('p-4', className)} {...props} />;
}
