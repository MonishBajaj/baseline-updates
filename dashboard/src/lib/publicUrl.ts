/**
 * Resolve a path under the Vite public base (important for GitHub Pages subpaths).
 * Accepts paths with or without a leading slash.
 */
export function withBase(path: string): string {
  const base = import.meta.env.BASE_URL || '/';
  const normalizedBase = base.endsWith('/') ? base : `${base}/`;
  const clean = path.replace(/^\//, '');
  return `${normalizedBase}${clean}`;
}

/** True when building/serving the static Pages (or local static) data mode. */
export function isStaticDataMode(): boolean {
  const mode = import.meta.env.VITE_DATA_MODE;
  // Default static: this app has no FastAPI backend; all data is bundled JSON.
  return mode !== 'api';
}
