/** Mask SQL literals/comments before reading CTE syntax and relation names. */
function syntax(sql: string): string {
  return sql.replace(/'(?:''|[^'])*'|"(?:""|[^"])*"|--[^\n]*|\/\*[\s\S]*?\*\//g, token => ' '.repeat(token.length));
}
export type Cte = { name: string; sql: string; dependencies: readonly string[] };
export function parseCtes(chain: string): readonly Cte[] {
  const raw = chain.replace(/^\s*WITH\s+/i, '');
  const clean = syntax(raw);
  const pieces: string[] = []; let depth = 0, start = 0;
  for (let index = 0; index < clean.length; index++) {
    if (clean[index] === '(') depth++;
    else if (clean[index] === ')') depth--;
    else if (clean[index] === ',' && depth === 0) { pieces.push(raw.slice(start, index).trim()); start = index + 1; }
    if (depth < 0) throw new Error('Unbalanced registered CTE chain');
  }
  if (depth !== 0) throw new Error('Unbalanced registered CTE chain');
  pieces.push(raw.slice(start).trim());
  const entries = pieces.map(sql => {
    const name = sql.match(/^([a-z_][\w]*)\s+AS\s*\(/i)?.[1]?.toLowerCase();
    if (!name) throw new Error('Unsupported registered CTE declaration');
    return { name, sql };
  });
  const names = new Set(entries.map(entry => entry.name));
  return entries.map(entry => ({ ...entry, dependencies: relationNames(entry.sql).filter(name => names.has(name)) }));
}
function relationNames(sql: string): string[] {
  return [...syntax(sql).matchAll(/\b(?:FROM|JOIN)\s+([a-z_][\w]*)\b/gi)].map(match => match[1].toLowerCase());
}
export function requiredCtes(ctes: readonly Cte[], branches: readonly string[], required: readonly string[] = ['fiscal_periods']): readonly Cte[] {
  const byName = new Map(ctes.map(cte => [cte.name, cte]));
  const needed = new Set<string>();
  const visit = (name: string) => {
    const cte = byName.get(name); if (!cte || needed.has(name)) return;
    needed.add(name); cte.dependencies.forEach(visit);
  };
  [...required, ...branches.flatMap(relationNames)].forEach(visit);
  return ctes.filter(cte => needed.has(cte.name));
}
