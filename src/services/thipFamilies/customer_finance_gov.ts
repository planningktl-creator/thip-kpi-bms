/**
 * THIP family batch `customer_finance_gov`: CUSTOMER satisfaction (SC0101 to
 * SC0106), FINANCE ratios (SF0101 to SF0106) and GOVERNANCE recycled waste
 * (SG0104). One fact branch per code, UNION-ed into the reporting-layer
 * refresh and the `thipExternalFoundation` query.
 *
 * Every branch of this batch reads `reporting.thip_external_facts` through
 * `branchExternal` (thipFamilyBase) because no defensible HOSxP source exists
 * for any of the thirteen indicators. The evidence, verified column by column
 * against the HOSxP Structure workbook:
 *
 * - CUSTOMER: the printed definitions are tied to a questionnaire instrument
 *   and version (the OPD and IPD satisfaction questionnaires, 5-level overall
 *   satisfaction item plus binary return and recommend items). The HOSxP
 *   survey tables cannot confirm that instrument or its score scale:
 *   `survey_satisfy_head_pcu` carries no visit, patient, service-point or
 *   questionnaire-version column, so OPD respondents can never be separated
 *   from IPD respondents (fatal for SC0101 versus SC0102 and for the IPD
 *   length-of-stay-over-3-days restriction), and the integer columns
 *   `survey_satisfy_sum_1` to `survey_satisfy_sum_5` have no confirmable
 *   level semantics. `survey_satisfy_screen_pcu` and
 *   `survey_satisfy_choice_pcu` only record a chosen `survey_satisfy_choice_no`
 *   per question row of the local `survey_satisfy_pcu` master
 *   (`survey_satisfy_name`, `survey_satisfy_part`), whose installed wording
 *   version is unverifiable local data. `dis_satisfied`, `dis_satisfied_result`
 *   and `dis_satisfied_topic` belong to the drug information service
 *   instrument (`dis_satisfied.drug_information_service_id`), a different
 *   questionnaire altogether.
 *
 * - FINANCE: audited financial statements are outside HOSxP. The stock tables
 *   listed as candidates (`stock_item`, `stock_trancation`) only hold
 *   consumable stock cards (quantities and money flows), never the balance
 *   sheet and income statement items the printed a and b definitions need.
 *
 * - GOVERNANCE SG0104: no HOSxP table records waste weights. `stock_item` and
 *   `stock_trancation` track pharmacy and supply stock in issue units,
 *   `supply_sterile` and `supply_sterile_item` track sterile supply
 *   processing counts, and `house_survey_garbage`, `provis_garbage`,
 *   `village_garbage_place`, `village_recycle_tank` are village health survey
 *   lookup lists without weights or dates. Monthly recycled-waste kilograms
 *   live in the hospital environment office waste log.
 *
 * Exact staging rows the hospital must load per reporting period are recorded
 * in `CUSTOMER_FINANCE_GOV_APPROXIMATIONS` (one row per indicator code x
 * reporting-period anchor with numerator, denominator, value, source_system).
 *
 * This batch is read-only: it only aggregates hospital-loaded staging rows and
 * never queries HOSxP directly. No PHI is projected; the outer projection is
 * exactly the seven contract columns. No ICD literals appear (dotless or
 * otherwise) and no SQL division is needed because the staged `value` arrives
 * precomputed.
 */

import { branchExternal } from '@/services/thipFamilyBase';

const STAGING_COLUMNS = `        numerator,
        denominator,
        value`;

const STAGING_COLUMNS_ALIASED = `        numerator AS numerator,
        denominator AS denominator,
        value AS value`;

/**
 * `branchExternal` renders the staging projection with bare column names; bind
 * them with the contract aliases so every branch carries `AS numerator`,
 * `AS denominator` and `AS value` like the helper-rendered fact branches.
 * Throws if `branchExternal` ever changes shape so the batch fails loudly
 * instead of silently losing the aliases.
 */
function externalBranch(code: string): string {
  const rendered = branchExternal(code);
  if (!rendered.includes(STAGING_COLUMNS)) {
    throw new Error(
      `branchExternal shape changed: cannot bind staging column aliases for ${code}`,
    );
  }
  return rendered.replace(STAGING_COLUMNS, STAGING_COLUMNS_ALIASED);
}

/** Shared evidence for the CUSTOMER survey fallback (see module header). */
const SURVEY_SOURCE_CHECK =
  'Source check: the HOSxP survey tables were verified column by column and cannot confirm the printed instrument or score scale. ' +
  'survey_satisfy_head_pcu (survey_satisfy_head_id, survey_satisfy_age, survey_satisfy_suggest, survey_satisfy_date, survey_satisfy_sum_1 to survey_satisfy_sum_5, hos_guid) has no visit, patient, service-point or questionnaire-version column, so OPD respondents cannot be separated from IPD respondents and the unconfirmed semantics of survey_satisfy_sum_1 to survey_satisfy_sum_5 cannot define the printed 5-level scale. ' +
  'survey_satisfy_screen_pcu (survey_satisfy_screen_id, survey_satisfy_head_id, survey_satisfy_id, survey_satisfy_choice_id) and survey_satisfy_choice_pcu (survey_satisfy_choice_id, survey_satisfy_id, survey_satisfy_choice_no, survey_satisfy_choice_name, survey_satisfy_choice_code) only record one chosen choice per question of the local survey_satisfy_pcu master (survey_satisfy_id, survey_satisfy_name, survey_satisfy_part), whose installed wording version is unverifiable local data. ' +
  'dis_satisfied (dis_satisfied_id, drug_information_service_id, dis_satisfied_topic_id, dis_satisfied_result_id, note), dis_satisfied_result and dis_satisfied_topic belong to the drug information service instrument, not to the printed patient satisfaction questionnaire.';

const SEMIANNUAL_ANCHORS =
  'Anchor rows: one row per semiannual reporting anchor with period_start 2025-10-01 and 2026-04-01 (fiscal months 1 and 7 of fiscal year 2026; anchors are always 1 October and 1 April).';

const ANNUAL_ANCHOR =
  'Anchor rows: one row per annual reporting anchor with period_start 2025-10-01 (fiscal month 1 of fiscal year 2026; the anchor is always 1 October).';

function surveyEntry(input: {
  measures: string;
  pdfBeyond: string;
  confirm: string;
  numerator: string;
  denominator: string;
  sourceSystem: string;
}): string {
  return [
    `Measures: ${input.measures} The branch is branchExternal over reporting.thip_external_facts.`,
    `PDF beyond the branch: ${input.pdfBeyond}`,
    `Confirm with the hospital owner: ${input.confirm}`,
    `Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): ${SEMIANNUAL_ANCHORS} numerator (a) = ${input.numerator} denominator (b) = ${input.denominator} value = ROUND(a * 100.0 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100. source_system = ${input.sourceSystem}.`,
    SURVEY_SOURCE_CHECK,
  ].join(' ');
}

function financeEntry(input: {
  measures: string;
  numerator: string;
  denominator: string;
  confirm: string;
  scale: string;
}): string {
  return [
    `Measures: ${input.measures} The branch is branchExternal over reporting.thip_external_facts because the audited financial statements of the hospital are outside HOSxP (the stock_item and stock_trancation candidates only hold consumable stock card quantities and money flows, never balance sheet or income statement items).`,
    `PDF beyond the branch: the a and b amounts of the printed definition taken from the audited financial statements of the fiscal year.`,
    `Confirm with the hospital owner: ${input.confirm}`,
    `Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): ${ANNUAL_ANCHOR} numerator (a) = ${input.numerator} denominator (b) = ${input.denominator} value = ${input.scale} source_system = 'thip-finance-audited'.`,
  ].join(' ');
}

const _APPROXIMATIONS: Readonly<Record<string, string>> = {
  SC0101: surveyEntry({
    measures:
      'Percent of outpatient satisfaction (overall): share of OPD questionnaire respondents selecting satisfaction level 4 or 5 on the overall question (THIP page 259).',
    pdfBeyond:
      'the sampled OPD respondents of the printed OPD satisfaction questionnaire with the overall-satisfaction item scored on the confirmed 5-level scale where only levels 4 and 5 count as satisfied.',
    confirm:
      'which installed questionnaire version is the printed OPD instrument, that choice_no 4 and choice_no 5 are the two highest satisfaction levels, and that the tally covers respondents sampled across the whole OPD service process.',
    numerator: 'count of sampled OPD respondents with overall satisfaction level 4 or 5. ',
    denominator: 'count of all sampled OPD respondents in the period. ',
    sourceSystem: "'thip-survey-opd'",
  }),
  SC0102: surveyEntry({
    measures:
      'Percent of inpatient satisfaction (overall): share of IPD questionnaire respondents selecting satisfaction level 4 or 5 on the overall question, sampled from admissions with length of stay more than 3 days (THIP page 260).',
    pdfBeyond:
      'the sampled IPD respondents of the printed IPD satisfaction questionnaire, restricted to admissions with more than 3 inpatient days, with the overall item scored on the confirmed 5-level scale where only levels 4 and 5 count as satisfied.',
    confirm:
      'which installed questionnaire version is the printed IPD instrument, that choice_no 4 and choice_no 5 are the two highest satisfaction levels, and that the respondent sample is restricted to stays of more than 3 days.',
    numerator: 'count of sampled IPD respondents with overall satisfaction level 4 or 5 (stays over 3 days). ',
    denominator: 'count of all sampled IPD respondents in the period (stays over 3 days). ',
    sourceSystem: "'thip-survey-ipd'",
  }),
  SC0103: surveyEntry({
    measures:
      'Percent of outpatients who return to receive care: share of OPD questionnaire respondents answering yes (come) to the question asking whether they would choose this hospital again (THIP page 261).',
    pdfBeyond:
      'the binary return-intention item of the printed OPD questionnaire (answers come or not come), answered by roughly 20 percent of the OPD volume of the period.',
    confirm:
      'which installed question of the OPD instrument is the printed return-intention item, that its positive answer is the come option, and that the sample is roughly 20 percent of OPD visits in the period.',
    numerator: 'count of sampled OPD respondents answering they would come back. ',
    denominator: 'count of all sampled OPD respondents answering the questionnaire in the period. ',
    sourceSystem: "'thip-survey-opd'",
  }),
  SC0104: surveyEntry({
    measures:
      'Percent of inpatients who return to receive care: share of IPD questionnaire respondents answering yes (come) to the question asking whether they would choose this hospital again (THIP page 262).',
    pdfBeyond:
      'the binary return-intention item of the printed IPD questionnaire (answers come or not come), answered by roughly 20 percent of the inpatient volume of the period.',
    confirm:
      'which installed question of the IPD instrument is the printed return-intention item, that its positive answer is the come option, and that the sample is roughly 20 percent of inpatient admissions in the period.',
    numerator: 'count of sampled IPD respondents answering they would come back. ',
    denominator: 'count of all sampled IPD respondents answering the questionnaire in the period. ',
    sourceSystem: "'thip-survey-ipd'",
  }),
  SC0105: surveyEntry({
    measures:
      'Percent of outpatients who would recommend friends or family: share of OPD questionnaire respondents answering yes (recommend) to the question asking whether they would recommend others to this hospital (THIP page 263).',
    pdfBeyond:
      'the binary recommend item of the printed OPD questionnaire (answers recommend or not recommend), answered across the OPD service process sample.',
    confirm:
      'which installed question of the OPD instrument is the printed recommend item and that its positive answer is the recommend option.',
    numerator: 'count of sampled OPD respondents choosing the recommend answer. ',
    denominator: 'count of all sampled OPD respondents in the period. ',
    sourceSystem: "'thip-survey-opd'",
  }),
  SC0106: surveyEntry({
    measures:
      'Percent of inpatients who would recommend friends or family: share of IPD questionnaire respondents (patient or relative) answering yes (recommend) to the question asking whether they would recommend others to this hospital, counted per respondent group (THIP page 264).',
    pdfBeyond:
      'the binary recommend item of the printed IPD questionnaire answered by patients or relatives, tallied per respondent group, with a sample of roughly 20 percent of inpatient admissions.',
    confirm:
      'which installed question of the IPD instrument is the printed recommend item, which respondent groups (patient versus relative) are reported separately, and that the sample is roughly 20 percent of inpatient admissions.',
    numerator: 'count of sampled IPD respondents (patient or relative) answering they would recommend others, per respondent group. ',
    denominator: 'count of all sampled IPD respondents in that respondent group in the period. ',
    sourceSystem: "'thip-survey-ipd'",
  }),
  SF0101: financeEntry({
    measures: 'Current ratio: liquidity of the hospital as current assets over current liabilities (THIP page 253).',
    numerator:
      'current assets in THB per the audited financial statements of the fiscal year (cash, bank deposits, short-term investments, trade receivables, notes receivable, inventory, other receivables, accrued income, prepaid expenses, supplies). ',
    denominator:
      'current liabilities in THB per the same statements (bank overdrafts, short-term bank loans, trade payables, notes payable, advances received, accrued expenses, other payables). ',
    confirm:
      'the finance office account mapping of current assets and current liabilities, and that the figures come from the audited statements of the reported fiscal year (a value under 1 signals short-term liquidity strain).',
    scale: 'ROUND(a * 1.0 divided by NULLIF(b, 0), 2) per formulaScale a over b.',
  }),
  SF0102: financeEntry({
    measures:
      'Quick ratio (liquid asset ratio): immediate solvency as liquid assets over current liabilities, excluding inventory (THIP page 254).',
    numerator:
      'liquid assets in THB per the audited financial statements (current assets excluding inventory: cash, bank deposits, short-term investments, trade receivables, notes receivable, marketable assets). ',
    denominator: 'current liabilities in THB per the same statements (same items as SF0101 b). ',
    confirm:
      'the finance office definition of liquid assets (which receivables and marketable instruments qualify) and that inventory is excluded from a.',
    scale: 'ROUND(a * 1.0 divided by NULLIF(b, 0), 2) per formulaScale a over b.',
  }),
  SF0103: financeEntry({
    measures:
      'Fixed asset turnover: how productively tangible long-life assets generate service revenue (THIP page 255).',
    numerator:
      'net sales (service operating revenue) of the fiscal year per the audited financial statements. ',
    denominator:
      'fixed assets in THB per the same statements (tangible assets with useful life over one year held to produce services). ',
    confirm:
      'the finance office mapping of net sales and fixed assets, and that both amounts cover the same fiscal-year evaluation round.',
    scale: 'ROUND(a * 1.0 divided by NULLIF(b, 0), 2) per formulaScale a over b.',
  }),
  SF0104: financeEntry({
    measures:
      'Average collection period of net medical receivables, in days (THIP page 256; lower is better).',
    numerator: 'net accounts receivable in THB at the end of the fiscal year. ',
    denominator:
      'average credit sales per day in THB (net credit sales of the fiscal year prorated to one day by the finance office before loading). ',
    confirm:
      'the finance office computation of average credit sales per day and that the receivable balance is the year-end net figure; the resulting value is a day count, not a percent.',
    scale: 'ROUND(a * 1.0 divided by NULLIF(b, 0), 2) per formulaScale a over b (unit: days).',
  }),
  SF0105: financeEntry({
    measures:
      'Net profit margin: net profit over net sales in percent (THIP page 257; higher is better).',
    numerator:
      'net profit in THB (total income including service and other income minus expenses, depreciation and costs). ',
    denominator: 'net sales in THB (service revenue only). ',
    confirm:
      'the finance office mapping of net profit and net sales, in particular that b counts service revenue only while a includes other income.',
    scale: 'ROUND(a * 100.0 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100.',
  }),
  SF0106: financeEntry({
    measures:
      'Return on assets (ROA): net profit over total assets in percent (THIP page 258; higher is better).',
    numerator: 'net profit in THB per the audited financial statements of the fiscal year. ',
    denominator: 'total assets in THB per the same statements. ',
    confirm:
      'the finance office mapping of net profit and total assets and that both amounts come from the same audited fiscal-year statements.',
    scale: 'ROUND(a * 100.0 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100.',
  }),
  SG0104:
    'Measures: Percent of recycled waste: month-over-month ratio of recycled-waste weight (THIP page 265), a = weight of recycled waste of the month in kilograms, b = weight of recycled waste of the previous month in kilograms. The branch is branchExternal over reporting.thip_external_facts because no HOSxP table records waste weights. ' +
    'PDF beyond the branch: the monthly kilogram weights of waste classified as recyclable (waste that can be reprocessed in the industrial system), including the previous month weight that the printed b definition needs. ' +
    'Confirm with the hospital owner: that the hospital environment office waste log measures kilograms, which waste streams count as recycled waste, and that month-over-month comparison against the previous month weight is the intended denominator. ' +
    "Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): Anchor rows: one row per monthly reporting anchor with period_start = first day of each calendar month (for example 2025-10-01, 2025-11-01). numerator (a) = weight of recycled waste of that month in kilograms. denominator (b) = weight of recycled waste of the immediately previous month in kilograms (the first loaded month needs its predecessor weight from the waste log). value = ROUND(a * 1.0 divided by NULLIF(b, 0), 2) per formulaScale a over b. source_system = 'thip-environment-waste-log'. " +
    'Source check: stock_item and stock_trancation track consumable stock cards (item_id, transaction_date, in_qty, out_qty, unit quantities and money columns) with no waste weights or waste-type registry; supply_sterile and supply_sterile_item track sterile supply processing counts (supply_sterile_item_qty); house_survey_garbage, provis_garbage, village_garbage_place and village_recycle_tank are village health survey lookup lists without weights or dates.',
};

export const CUSTOMER_FINANCE_GOV_BRANCHES: readonly string[] = [
  externalBranch('SC0101'),
  externalBranch('SC0102'),
  externalBranch('SC0103'),
  externalBranch('SC0104'),
  externalBranch('SC0105'),
  externalBranch('SC0106'),
  externalBranch('SF0101'),
  externalBranch('SF0102'),
  externalBranch('SF0103'),
  externalBranch('SF0104'),
  externalBranch('SF0105'),
  externalBranch('SF0106'),
  externalBranch('SG0104'),
];

export const CUSTOMER_FINANCE_GOV_APPROXIMATIONS: Readonly<Record<string, string>> =
  _APPROXIMATIONS;
