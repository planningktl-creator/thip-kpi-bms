import { BmsRequestError } from '@/services/bmsErrors';

export type BmsParamType = 'string' | 'integer' | 'float' | 'date' | 'time' | 'datetime' | 'text';

export type BmsParam = {
  value: string | number | null;
  value_type: BmsParamType;
};

export type RegisteredQuery = {
  key: string;
  sql: string;
  description: string;
  params?: Record<string, BmsParam>;
};

export type BmsSqlResponse = {
  MessageCode?: number;
  Message?: string;
  data?: Array<Record<string, unknown>>;
  result?: Array<Record<string, unknown>>;
  record_count?: number;
};

export const queryRegistry = {
  versionProbe: {
    key: 'versionProbe',
    description: 'ตรวจสอบชนิดฐานข้อมูลของ BMS session',
    sql: 'SELECT VERSION() AS version',
  },
  ipdMonthlyFoundation: {
    key: 'ipdMonthlyFoundation',
    description: 'โครงสร้างตั้งต้นสำหรับตรวจสอบข้อมูล IPD รายเดือน (ยังไม่ใช่ THIP calculation)',
    sql: `
      SELECT
        DATE_TRUNC('month', ipt.dchdate)::date AS month_start,
        COUNT(DISTINCT ipt.an)::integer AS discharges,
        COUNT(DISTINCT CASE WHEN NULLIF(TRIM(ipt.drg), '') IS NULL THEN ipt.an END)::integer AS uncoded_cases,
        AVG(ipt.adjrw)::numeric AS mean_adjrw
      FROM ipt
      WHERE ipt.dchdate >= :start_date
        AND ipt.dchdate < :end_date
      GROUP BY DATE_TRUNC('month', ipt.dchdate)
      ORDER BY month_start
    `.trim(),
  },
  thipMortalityFoundation: {
    key: 'thipMortalityFoundation',
    description: 'ผลลัพธ์จริงรายเดือนสำหรับ DH0101, DN0101 และ DR0101 จาก HOSxP IPD',
    sql: `
      WITH ipd AS (
        SELECT
          i.an,
          i.dchdate,
          s.age_y,
          UPPER(TRIM(s.pdx)) AS pdx,
          EXISTS (
            SELECT 1
            FROM death d
            WHERE d.an = i.an
          ) AS died,
          EXISTS (
            SELECT 1
            FROM iptdiag sd
            WHERE sd.an = i.an
              AND UPPER(TRIM(sd.icd10)) <> UPPER(TRIM(s.pdx))
              AND UPPER(TRIM(sd.icd10)) IN ('I21.0', 'I21.1', 'I21.2', 'I21.3', 'I21.4', 'I21.9')
          ) AS has_acs_sdx,
          EXISTS (
            SELECT 1
            FROM death d
            WHERE d.an = i.an
              AND (
                UPPER(TRIM(d.death_diag_icd10)) IN ('I21.0', 'I21.1', 'I21.2', 'I21.3', 'I21.4', 'I21.9')
                OR UPPER(TRIM(d.death_cause)) IN ('I21.0', 'I21.1', 'I21.2', 'I21.3', 'I21.4', 'I21.9')
                OR UPPER(TRIM(d.death_diag_1)) IN ('I21.0', 'I21.1', 'I21.2', 'I21.3', 'I21.4', 'I21.9')
                OR UPPER(TRIM(d.death_diag_2)) IN ('I21.0', 'I21.1', 'I21.2', 'I21.3', 'I21.4', 'I21.9')
                OR UPPER(TRIM(d.death_diag_3)) IN ('I21.0', 'I21.1', 'I21.2', 'I21.3', 'I21.4', 'I21.9')
                OR UPPER(TRIM(d.death_diag_4)) IN ('I21.0', 'I21.1', 'I21.2', 'I21.3', 'I21.4', 'I21.9')
              )
          ) AS died_from_acs,
          EXISTS (
            SELECT 1
            FROM iptdiag sd
            WHERE sd.an = i.an
              AND UPPER(TRIM(sd.icd10)) <> UPPER(TRIM(s.pdx))
              AND (
                LEFT(UPPER(TRIM(sd.icd10)), 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')
                OR LEFT(UPPER(TRIM(sd.icd10)), 5) IN ('J10.0', 'J11.0', 'J17.0', 'J17.1', 'J17.2', 'J17.3', 'J17.8', 'J85.0', 'J85.1')
              )
          ) AS has_pneumonia_sdx,
          EXISTS (
            SELECT 1
            FROM death d
            WHERE d.an = i.an
              AND (
                LEFT(UPPER(TRIM(d.death_diag_icd10)), 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')
                OR LEFT(UPPER(TRIM(d.death_diag_icd10)), 5) IN ('J10.0', 'J11.0', 'J17.0', 'J17.1', 'J17.2', 'J17.3', 'J17.8', 'J85.0', 'J85.1')
                OR LEFT(UPPER(TRIM(d.death_cause)), 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')
                OR LEFT(UPPER(TRIM(d.death_cause)), 5) IN ('J10.0', 'J11.0', 'J17.0', 'J17.1', 'J17.2', 'J17.3', 'J17.8', 'J85.0', 'J85.1')
                OR LEFT(UPPER(TRIM(d.death_diag_1)), 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')
                OR LEFT(UPPER(TRIM(d.death_diag_1)), 5) IN ('J10.0', 'J11.0', 'J17.0', 'J17.1', 'J17.2', 'J17.3', 'J17.8', 'J85.0', 'J85.1')
                OR LEFT(UPPER(TRIM(d.death_diag_2)), 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')
                OR LEFT(UPPER(TRIM(d.death_diag_2)), 5) IN ('J10.0', 'J11.0', 'J17.0', 'J17.1', 'J17.2', 'J17.3', 'J17.8', 'J85.0', 'J85.1')
                OR LEFT(UPPER(TRIM(d.death_diag_3)), 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')
                OR LEFT(UPPER(TRIM(d.death_diag_3)), 5) IN ('J10.0', 'J11.0', 'J17.0', 'J17.1', 'J17.2', 'J17.3', 'J17.8', 'J85.0', 'J85.1')
                OR LEFT(UPPER(TRIM(d.death_diag_4)), 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')
                OR LEFT(UPPER(TRIM(d.death_diag_4)), 5) IN ('J10.0', 'J11.0', 'J17.0', 'J17.1', 'J17.2', 'J17.3', 'J17.8', 'J85.0', 'J85.1')
              )
          ) AS died_from_pneumonia
        FROM ipt i
        JOIN an_stat s ON s.an = i.an
        WHERE i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND i.regdate IS NOT NULL
          AND EXTRACT(EPOCH FROM (
            (i.dchdate + COALESCE(i.dchtime, TIME '23:59:59')) -
            (i.regdate + COALESCE(i.regtime, TIME '00:00:00'))
          )) >= 14400
      ), periodized AS (
        SELECT
          *,
          DATE_TRUNC('month', dchdate)::date AS period_start,
          EXTRACT(MONTH FROM dchdate)::integer AS calendar_month
        FROM ipd
      )
      SELECT
        'DH0101' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE (pdx IN ('I21.0', 'I21.1', 'I21.2', 'I21.3', 'I21.4', 'I21.9') AND died) OR (has_acs_sdx AND died_from_acs))::integer AS numerator,
        COUNT(*)::integer AS denominator,
        ROUND((COUNT(*) FILTER (WHERE (pdx IN ('I21.0', 'I21.1', 'I21.2', 'I21.3', 'I21.4', 'I21.9') AND died) OR (has_acs_sdx AND died_from_acs)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE age_y >= 18
        AND pdx IN ('I21.0', 'I21.1', 'I21.2', 'I21.3', 'I21.4', 'I21.9')
      GROUP BY period_start, calendar_month

      UNION ALL

      SELECT
        'DN0101' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE died)::integer AS numerator,
        COUNT(*)::integer AS denominator,
        ROUND((COUNT(*) FILTER (WHERE died) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 3) IN ('I60', 'I61', 'I62', 'I63', 'I64', 'I65', 'I66', 'I67')
      GROUP BY period_start, calendar_month

      UNION ALL

      SELECT
        'DR0101' AS indicator_code,
        period_start,
        CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
        CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1 ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
        COUNT(*) FILTER (WHERE (LEFT(pdx, 5) IN ('J10.0', 'J11.0', 'J17.0', 'J17.1', 'J17.2', 'J17.3', 'J17.8', 'J85.0', 'J85.1') OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')) AND died OR (has_pneumonia_sdx AND died_from_pneumonia))::integer AS numerator,
        COUNT(*)::integer AS denominator,
        ROUND((COUNT(*) FILTER (WHERE (LEFT(pdx, 5) IN ('J10.0', 'J11.0', 'J17.0', 'J17.1', 'J17.2', 'J17.3', 'J17.8', 'J85.0', 'J85.1') OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')) AND died OR (has_pneumonia_sdx AND died_from_pneumonia)) * 100.0) / NULLIF(COUNT(*), 0), 2) AS value
      FROM periodized
      WHERE LEFT(pdx, 5) IN ('J10.0', 'J11.0', 'J17.0', 'J17.1', 'J17.2', 'J17.3', 'J17.8', 'J85.0', 'J85.1')
         OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')
         OR has_pneumonia_sdx
      GROUP BY period_start, calendar_month
      ORDER BY indicator_code, period_start
    `.trim(),
  },
} as const satisfies Record<string, RegisteredQuery>;

const allowedStart = /^(select|with|show|describe|desc|explain)\b/i;
const blockedSql = /\b(insert|update|delete|merge|drop|alter|truncate|create|grant|revoke|copy|call|do|execute|begin|commit|rollback)\b/i;

export function assertRegisteredReadOnlyQuery(query: RegisteredQuery): void {
  const normalized = query.sql.trim();
  if (!allowedStart.test(normalized) || blockedSql.test(normalized)) {
    throw new Error(`Query ${query.key} is not an allowed read-only statement.`);
  }
}

export async function executeRegisteredQuery(
  query: RegisteredQuery,
  config: { apiUrl: string; bearerToken: string; appIdentifier: string },
  params?: Record<string, BmsParam>,
  marketplaceToken?: string,
): Promise<BmsSqlResponse> {
  assertRegisteredReadOnlyQuery(query);
  const body: Record<string, unknown> = {
    sql: query.sql,
    app: config.appIdentifier,
  };
  if (params && Object.keys(params).length > 0) body.params = params;
  if (marketplaceToken) body['marketplace-token'] = marketplaceToken;

  let response: Response;
  try {
    response = await fetch(`${config.apiUrl.replace(/\/$/, '')}/api/sql`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${config.bearerToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });
  } catch (error) {
    throw new BmsRequestError('api', 'network', 'BMS API request failed', undefined, { cause: error });
  }

  const responseText = await response.text();
  if (!response.ok) {
    throw new BmsRequestError('api', 'http', `BMS API returned HTTP ${response.status}`, response.status);
  }

  let payload: BmsSqlResponse = {};
  if (responseText.trim()) {
    try {
      payload = JSON.parse(responseText) as BmsSqlResponse;
    } catch (error) {
      throw new BmsRequestError('api', 'response', 'BMS API returned invalid JSON', response.status, { cause: error });
    }
  }
  if (payload.MessageCode !== undefined && payload.MessageCode >= 400) {
    throw new BmsRequestError('api', 'message', payload.Message || 'BMS API rejected the query', response.status);
  }
  return payload;
}
