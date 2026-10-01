import type { CohortDefinition } from './cohortTypes';
import type { ThipDictionaryEntry } from './thipDictionary';

type Evidence = { dictionary: ThipDictionaryEntry; cohort: CohortDefinition };
const families = import.meta.glob<{ default: Record<string, Evidence> }>('./evidence/*.json');
const loaded = new Map<string, Promise<Record<string, Evidence>>>();
export async function loadThipEvidence(code: string): Promise<Evidence | undefined> {
  const family = code.slice(0, 2);
  const load = families[`./evidence/${family}.json`];
  if (!load) return undefined;
  let promise = loaded.get(family);
  if (!promise) {
    promise = load().then((module) => module.default).catch((error) => { loaded.delete(family); throw error; });
    loaded.set(family, promise);
  }
  return (await promise)[code];
}
