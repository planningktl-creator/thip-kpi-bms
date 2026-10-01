-- ==============================================================================
-- #3.1 ตาราง staging สำหรับ 55 รหัสภายนอก (DDL + ตัวอย่างการโหลด)
-- รันก่อนใช้ 02-external - หนึ่งแถวต่อ indicator_code x period_start
-- ==============================================================================

-- Hospital-loaded aggregate staging for KPIs whose denominator or source lives
-- outside HOSxP (population registers, finance, surveys, custom registries).
-- Load exactly one row per indicator code x reporting-period anchor; rows read
-- by the thipExternalFoundation query and the refresh above through the
-- external_facts CTE. Aggregate values only - never patient rows.
CREATE TABLE IF NOT EXISTS reporting.thip_external_facts (
  indicator_code varchar(10)  NOT NULL,
  period_start   date         NOT NULL,
  numerator      numeric(18, 4),
  denominator    numeric(18, 4),
  value          numeric(18, 4),
  source_system  text         NOT NULL,
  loaded_at      timestamptz  NOT NULL DEFAULT NOW(),
  CHECK (numerator IS NULL OR numerator >= 0),
  CHECK (denominator IS NULL OR denominator >= 0),
  UNIQUE (indicator_code, period_start)
);

-- [ตัวอย่างเท่านั้น - ตัวเลขสมมติ]
INSERT INTO reporting.thip_external_facts
  (indicator_code, period_start, numerator, denominator, value, source_system)
VALUES
  ('SC0101', DATE '2025-10-01', 812, 1000, 81.2, 'survey'),
  ('SC0101', DATE '2026-04-01', 795, 1000, 79.5, 'survey')
ON CONFLICT (indicator_code, period_start)
DO UPDATE SET
  numerator = EXCLUDED.numerator,
  denominator = EXCLUDED.denominator,
  value = EXCLUDED.value,
  source_system = EXCLUDED.source_system,
  loaded_at = NOW();
