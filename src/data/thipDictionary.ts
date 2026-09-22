import rawDictionary from '@/data/thipKpiDictionary.json';
import type { IndicatorDirection, TargetScope } from '@/types/thip';

/**
 * Typed access over `thipKpiDictionary.json` — the verbatim extraction of the
 * THIP KPI 2025 PDF dictionary (232 codes). The JSON is the source of truth:
 * this module never rewrites, normalizes, or invents dictionary content.
 */
export type ThipDictionaryEntry = {
  code: string;
  /** PDF page of the indicator entry. */
  page: number;
  titleTh: string;
  title: string;
  /** Full printed นิยาม / ขอบเขต text. */
  definition: string;
  /** Printed formula, e.g. `(a/b) x 100`. */
  formula: string;
  numeratorLabel: string;
  /** Printed `a = ...` line, verbatim. */
  numeratorDefinition: string | null;
  denominatorLabel: string | null;
  /** Printed `b = ...` line, verbatim. */
  denominatorDefinition: string | null;
  inclusion: readonly string[];
  exclusion: readonly string[];
  /** Verbatim benchmark/เป้าหมาย text, or null when the PDF printed none. */
  target: string | null;
  direction: IndicatorDirection;
  targetScope: TargetScope | null;
  frequency: string;
  source: string | null;
  notes: string | null;
};

const dictionaryRecords = rawDictionary as unknown as Record<string, ThipDictionaryEntry>;

/** All 232 dictionary entries keyed by indicator code. */
export const thipDictionaryByCode: ReadonlyMap<string, ThipDictionaryEntry> = new Map(
  Object.entries(dictionaryRecords),
);

export function getDictionaryEntry(code: string): ThipDictionaryEntry | undefined {
  return thipDictionaryByCode.get(code);
}

export type ParsedBenchmark = {
  /** The single unambiguous printed target figure, or null when absent/ambiguous. */
  value: number | null;
  comparator: '>=' | '<=' | '>' | '<' | null;
  /** The verbatim printed benchmark text (never normalized). */
  label: string | null;
};

export type BenchmarkComparator = ParsedBenchmark['comparator'];

const FIGURE = String.raw`\d+(?:\.\d+)?`;
/** A Thai character must not follow a matched unit word (วันนอน is not วัน). */
const THAI_WORD_END = String.raw`(?![\u0E00-\u0E7F])`;

/**
 * Figure patterns, tried over the whole string; every match is a candidate.
 * A candidate is accepted only when it is unambiguous:
 * - `ร้อยละ 80 ...`            -> 80 (printed percent)
 * - `UK 8% (...)`, `65% ...`    -> 8 / 65 (printed percent sign)
 * - `U.S.A. National Median : 84`, `... = 92.1` -> 84 / 92.1 (explicit figure after : or =)
 * - `5.9 วัน (ค่า SD 2.2) ...`  -> 5.9 (figure with a printed unit; SD in parentheses is detail)
 * - `อัตราน้อยกว่า 3 ครั้งต่อ 1000 วันนอน` -> 3 (printed rate numerator)
 * - a bare figure may only lead the text (`75 (HIV HUB ...)` -> 75) so that
 *   years and page numbers anywhere else (`... ปี 2557`, `P520`) are never read
 *   as targets.
 */
const figurePatterns: readonly RegExp[] = [
  new RegExp(String.raw`ร้อยละ\s*(${FIGURE})`, 'g'),
  new RegExp(String.raw`(${FIGURE})\s*%`, 'g'),
  new RegExp(String.raw`(${FIGURE})\s*วัน${THAI_WORD_END}`, 'g'),
  new RegExp(String.raw`(${FIGURE})\s*ครั้งต่อ`, 'g'),
  new RegExp(String.raw`[:=]\s*(${FIGURE})(?![\d./])`, 'g'),
  new RegExp(String.raw`^(${FIGURE})(?=$|[\s%(])`, 'g'),
];

type FigureMatch = {
  start: number;
  end: number;
  /** Span of the whole printed match (e.g. `ร้อยละ 80`, `: 84`) for text surgery. */
  removeStart: number;
  removeEnd: number;
  value: number;
  inParen: boolean;
};

function parenDepths(text: string): number[] {
  const depths: number[] = [0];
  let depth = 0;
  for (let index = 0; index < text.length; index += 1) {
    if (text[index] === '(') depth += 1;
    else if (text[index] === ')') depth = Math.max(0, depth - 1);
    depths.push(depth);
  }
  return depths;
}

/**
 * Collects candidate figures from every pattern, left-to-right, deduplicated by
 * start position. Matches of `: N` / `= N` inside identifiers are skipped
 * (`doi:10.1111/jdi.13390`, `UN= 4`).
 */
function collectFigureMatches(text: string): FigureMatch[] {
  const depths = parenDepths(text);
  const matches: FigureMatch[] = [];
  for (const pattern of figurePatterns) {
    pattern.lastIndex = 0;
    let match: RegExpExecArray | null;
    while ((match = pattern.exec(text)) !== null) {
      const raw = match[1];
      if (match[0].length === 0) {
        pattern.lastIndex += 1;
        continue;
      }
      const start = match.index + match[0].indexOf(raw);
      const end = start + raw.length;
      // For the `: N` / `= N` pattern reject identifier-like contexts such as
      // `doi:10.1111` or `UN= 4` (a letter or digit directly before the sign).
      const separatorIndex = match[0].search(/[:=]/);
      if (separatorIndex >= 0) {
        const signIndex = match.index + separatorIndex;
        const beforeSign = signIndex > 0 ? text[signIndex - 1] : '';
        if (/[0-9A-Za-z.]/.test(beforeSign)) continue;
      }
      if (matches.some((existing) => existing.start === start)) continue;
      matches.push({
        start,
        end,
        removeStart: match.index,
        removeEnd: match.index + match[0].length,
        value: Number(raw),
        inParen: depths[start] > 0,
      });
    }
  }
  return matches.sort((left, right) => left.start - right.start || right.end - left.end);
}

const rangeConnectorAfter = /^\s*(?:-{1,3}\s*>|[-–—~−]|ถึง)\s*\d/;
const rangeConnectorBefore = /\d\s*(?:-{1,3}\s*>|[-–—~−]|ถึง)\s*$/;

/**
 * A figure glued to another figure through a range/trend connector is not one
 * target number: `UK 1-3 %`, `3.3-6.8`, `1105 – 12`, `ร้อยละ 17 ---> 15`.
 */
function isRangeBound(text: string, match: FigureMatch): boolean {
  return (
    rangeConnectorAfter.test(text.slice(match.end))
    || rangeConnectorBefore.test(text.slice(Math.max(0, match.start - 12), match.start))
  );
}

/**
 * Returns the one unambiguous figure of a benchmark text, following the rules
 * documented on `figurePatterns`. Parenthesized content counts as supporting
 * detail: an outside-paren figure wins, and only when no outside figure exists
 * (e.g. `U.S.A. 2005(74.5% )`) may an inside-paren figure be the target.
 * Two different outside figures (`Malaysia = 4 , UK = 3`) mean the text offers
 * several benchmarks, so nothing is picked.
 */
function chooseFigure(text: string): FigureMatch | null {
  const candidates = collectFigureMatches(text).filter((match) => !isRangeBound(text, match));
  const outside = candidates.filter((match) => !match.inParen);
  const pool = outside.length ? outside : candidates;
  if (pool.length === 0) return null;
  if (new Set(pool.map((match) => match.value)).size > 1) return null;
  return pool[0];
}

/**
 * Comparator is read from the printed wording right before the chosen figure
 * (`ไม่เกิน` -> <=, `น้อยกว่า` -> <, `ไม่น้อยกว่า` / `อย่างน้อย` -> >=,
 * `มากกว่า` -> >). Wording elsewhere in the text (e.g. inside a parenthetical
 * like `(... ไม่เกิน 7.5%)`) does not describe the chosen figure and is ignored.
 */
function detectComparator(text: string, figureStart: number): BenchmarkComparator {
  const window = text.slice(Math.max(0, figureStart - 40), figureStart);
  if (/ไม่เกิน|<=|≤/.test(window)) return '<=';
  if (/ไม่น้อยกว่า|อย่างน้อย|at least|>=|≥/i.test(window)) return '>=';
  if (/น้อยกว่า|ต่ำกว่า|less than|</.test(window)) return '<';
  if (/มากกว่า|สูงกว่า|more than|>/.test(window)) return '>';
  return null;
}

/**
 * Extracts a numeric target from verbatim benchmark text ONLY when the printed
 * figure is unambiguous. Ranges (`UK 1-3 %`), multi-benchmark comparisons
 * (`Malaysia = 4 , UK = 3`), citations (`Dejkhamron P., ... P520`,
 * `Crit Care Med 2007; 35 (4): 1105 – 12`) and years (`Definition CDC 2014`)
 * are never read as targets: `value` stays null and `label` keeps the verbatim
 * text. `null`/empty input yields an all-null result.
 */
export function parseBenchmark(text: string | null): ParsedBenchmark {
  if (typeof text !== 'string' || text.trim() === '') {
    return { value: null, comparator: null, label: null };
  }
  const chosen = chooseFigure(text);
  if (!chosen) return { value: null, comparator: null, label: text };
  return {
    value: chosen.value,
    comparator: detectComparator(text, chosen.start),
    label: text,
  };
}

const comparatorWords = /(ไม่เกิน|ไม่น้อยกว่า|อย่างน้อย|น้อยกว่า|ต่ำกว่า|มากกว่า|สูงกว่า|at least|less than|more than)\s*$/i;

/**
 * The benchmark citation part of a printed target string: the verbatim text
 * with the chosen figure (and its comparator wording) removed, e.g.
 * `ร้อยละ 80 ศูนย์ข้อมูลระบบประสาท ปี 2555-2558` -> `ศูนย์ข้อมูลระบบประสาท ปี 2555-2558`,
 * `U.S.A. National Median : 84` -> `U.S.A. National Median`.
 * When there is no distinct citation part (or no printed target at all) the
 * full printed string is kept as-is.
 */
export function benchmarkSourceFromTarget(text: string | null): string | null {
  if (typeof text !== 'string' || text.trim() === '') return null;
  const chosen = chooseFigure(text);
  if (!chosen) return text;
  const before = text.slice(Math.max(0, chosen.removeStart - 40), chosen.removeStart);
  const comparatorLead = before.match(comparatorWords);
  const removalStart = comparatorLead ? chosen.removeStart - comparatorLead[0].length : chosen.removeStart;
  const remainder = `${text.slice(0, removalStart)} ${text.slice(chosen.removeEnd)}`
    .replace(/\(\s*\)/g, ' ')
    .replace(/\s{2,}/g, ' ')
    .trim()
    .replace(/^[\s:,\-–—/·]+/, '')
    .replace(/[\s:,\-–—/·]+$/, '')
    .trim();
  return remainder.length ? remainder : text;
}
