import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatNumber(n: number, decimals = 0): string {
  return n.toLocaleString('en-US', { maximumFractionDigits: decimals, minimumFractionDigits: decimals });
}

export function formatCompact(n: number): string {
  if (Math.abs(n) >= 1000) {
    return n.toLocaleString('en-US', { maximumFractionDigits: 1 });
  }
  return n.toLocaleString('en-US', { maximumFractionDigits: 2 });
}

export function formatPct(n: number, decimals = 1): string {
  return `${n >= 0 ? '' : ''}${n.toFixed(decimals)}%`;
}

export function log10p1(n: number): number {
  return Math.log10(Math.max(0, n) + 1);
}
