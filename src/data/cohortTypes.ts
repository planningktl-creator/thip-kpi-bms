export type CohortDefinition = {
  code: string; pdfPage: number; printedPages: number[]; ruleVersion: string;
  population: string | null; numeratorDefinition: string | null; denominatorDefinition: string | null;
  dictionaryDefinition: string; dictionaryUnit: string; formula: string;
  numeratorSql: string | null; denominatorSql: string | null; cohortSql: string | null; sourceSql: string;
  numeratorKind: 'count' | 'sum' | 'mixed' | 'external' | 'unverified'; denominatorKind: 'count' | 'sum' | 'mixed' | 'external' | 'unverified';
  currentGrain: string; keyCandidates: string[]; eventDateCandidates: string[];
  inclusion: string[]; exclusion: string[]; structuredCriteria: 'extracted' | 'not-structured';
  observationWindow: string; sourceTables: string[]; querySha256: string; evidence: string[];
  relationshipStatus: 'candidate-no-declared-FK'; reviewStatus: 'awaiting-hospital-confirmation'; publicationApproval: 'unapproved';
  limitations: string[];
};
