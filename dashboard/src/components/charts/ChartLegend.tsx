interface LegendItem {
  label: string;
  color: string;
}

/**
 * Fixed-order legend, used as recharts' <Legend content={...} /> render prop.
 * Recharts' default legend payload order isn't guaranteed to match the
 * declared dataKey order, so we render our own from an explicit item list.
 */
export function ChartLegend({ items }: { items: LegendItem[] }) {
  return (
    <ul className="mb-1 flex flex-wrap justify-center gap-4 text-lg">
      {items.map((item) => (
        <li key={item.label} className="flex items-center gap-1.5">
          <span className="inline-block h-3 w-3 rounded-sm" style={{ backgroundColor: item.color }} />
          <span className="text-uga-dark-gray">{item.label}</span>
        </li>
      ))}
    </ul>
  );
}
