import type { ReactNode } from 'react';

const E_COLI = 'E. coli';

/** Italicize the species name wherever it appears in a text string. */
export function withItalicEColi(text: string): ReactNode {
  const parts = text.split(E_COLI);
  if (parts.length === 1) return text;
  return parts.flatMap((part, index) => {
    const nodes: ReactNode[] = [];
    if (part) nodes.push(part);
    if (index < parts.length - 1) {
      nodes.push(
        <em key={`ecoli-${index}`} className="italic normal-case">
          {E_COLI}
        </em>,
      );
    }
    return nodes;
  });
}
