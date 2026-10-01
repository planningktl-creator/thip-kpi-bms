# THIP cohort mapping — 232 รหัส

Generated from the verbatim dictionary, current registered SQL and structural audit. ทุกสูตรยังไม่ผ่าน hospital publication approval. ไม่มีการเรียกฐานจริง.

JSON schema snapshot: 6,109 tables / 56,891 columns. Obsidian July snapshot: 6,617 tables / 81,554 columns. ต่าง snapshot; ไม่ใช้ชื่อคอลัมน์หรือ primary key รับรอง cardinality. `patient` PK = hos_guid, ไม่ใช่ HN; `person.patient_hn` ไม่ใช่ person.hn; `emp` แยกจาก `opduser`.

Inclusion/exclusion ที่ยังไม่ได้แยกจากนิยามจะระบุ not-structured ไม่ได้แปลว่าไม่มีเงื่อนไข. Key/date/grain เป็น candidate ต้องยืนยันกับโรงพยาบาล. Query hash ใช้ SQL เต็มของ single-code query สำหรับ native; external ใช้ branch hash. Cadence THIP 1,552 ช่องและ monitoring 2,784 ช่องคงเดิม.

## AA0101

PDF physical 295; printed 286 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งที่ผู้ป่วยอายุ 15-74 ปีทุกสิทธิการรักษา ที่ลงทะเบียนของหน่วยบริการ ประจำเข้ารักษาในโรงพยาบาลในโรคลมชัก (epilepsy)

ตัวหาร / population: b = จำนวนประชากรกลางปีทุกสิทธิการรักษาในพื้นที่รับผิดชอบ อายุ 15-74 ปี

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ต่อแสนประชากร; formula: (a/b) x 100,000. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*)
-- denominator (count)
NULLIF((SELECT COUNT(DISTINCT p.hn) FROM patient p), 0)
-- outer FROM / source
periodized
-- outer cohort predicate
LEFT(pdx, 3) IN ('G40', 'G41')
```

- Counts discharges (>= 4h stay) with Pdx G40 or G41 per fiscal year, one row per admission. Denominator follows the registered AA0104/AA0105 precedent (COUNT(DISTINCT patient.hn) over the whole patient table), not the printed mid-year population aged 15-74 in the responsible area, and the numerator is not filtered to ages 15-74; the hospital owner must confirm the official population denominator and age band (or load the population rate into reporting.thip_external_facts).
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- patient HN ปัจจุบันไม่ใช่ population กลางปีอายุ 15–74 ในพื้นที่รับผิดชอบ; ต้องใช้ population denominator ภายนอก

Source tables: an_stat, death, ipt, iptdiag, patient. SQL SHA256: e397fb5417825fc2d8e2132d60a9180a4cb407c8637caee016a3cb4173b93e36

## AA0102

PDF physical 296; printed 287 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งที่ผู้ป่วยอายุ 15-74 ปีทุกสิทธิการรักษา ที่ลงทะเบียนของหน่วยบริการ ประจำเข้ารักษาในโรงพยาบาลในโรคปอดอุดกั้นเรื้อรัง (COPD)

ตัวหาร / population: b = จำนวนประชากรกลางปีทุกสิทธิการรักษาในพื้นที่รับผิดชอบ อายุ 15-74 ปี

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ต่อแสนประชากร; formula: (a/b) x 100,000. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*)
-- denominator (count)
NULLIF((SELECT COUNT(DISTINCT p.hn) FROM patient p), 0)
-- outer FROM / source
periodized
-- outer cohort predicate
(
      LEFT(pdx, 3) IN ('J40', 'J41', 'J42', 'J43', 'J44', 'J47')
      OR (
        (pdx = 'J100' OR pdx = 'J110' OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18', 'J20', 'J21', 'J22'))
        AND EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'J44'
        )
      )
    )
```

- Counts discharges with Pdx in J40-J44 or J47, or Pdx J100, J110, J12-J16, J18, J20-J22 carrying a secondary diagnosis J44 (EXISTS over iptdiag). Denominator follows the registered AA0104/AA0105 precedent (COUNT(DISTINCT patient.hn) over the whole patient table), not the printed mid-year population aged 15-74 in the responsible area, and the numerator is not filtered to ages 15-74; the hospital owner must confirm the official population denominator and age band (or load the population rate into reporting.thip_external_facts).
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- patient HN ปัจจุบันไม่ใช่ population กลางปีอายุ 15–74 ในพื้นที่รับผิดชอบ; ต้องใช้ population denominator ภายนอก

Source tables: an_stat, death, ipt, iptdiag, patient. SQL SHA256: 075d892658b645e9ed9cedf243a9492dcee8e2c95f12a053935213685424bce9

## AA0103

PDF physical 297; printed 288 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งที่ผู้ป่วยอายุ 15-74 ปีทุกสิทธิการรักษา ที่ลงทะเบียนของหน่วยบริการ ประจำเข้ารักษาในโรงพยาบาลในโรคหืด (Asthma)

ตัวหาร / population: b = จำนวนประชากรกลางปีทุกสิทธิการรักษาในพื้นที่รับผิดชอบ อายุ 15-74 ปี

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ต่อแสนประชากร; formula: (a/b) x 100,000. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*)
-- denominator (count)
NULLIF((SELECT COUNT(DISTINCT p.hn) FROM patient p), 0)
-- outer FROM / source
periodized
-- outer cohort predicate
LEFT(pdx, 3) IN ('J45', 'J46')
```

- Counts discharges with Pdx J45 or J46 (asthma). Denominator follows the registered AA0104/AA0105 precedent (COUNT(DISTINCT patient.hn) over the whole patient table), not the printed mid-year population aged 15-74 in the responsible area, and the numerator is not filtered to ages 15-74; the hospital owner must confirm the official population denominator and age band (or load the population rate into reporting.thip_external_facts).
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- patient HN ปัจจุบันไม่ใช่ population กลางปีอายุ 15–74 ในพื้นที่รับผิดชอบ; ต้องใช้ population denominator ภายนอก

Source tables: an_stat, death, ipt, iptdiag, patient. SQL SHA256: fa24e18f777b9ece094c4e816945e38faf5894f4a1e05c4c1fcd7990d0195d28

## AA0104

PDF physical 298; printed 289 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งที่ผู้ป่วยอายุ 15-74 ปีทุกสิทธิการรักษา ที่ลงทะเบียนของหน่วยบริการ ประจำเข้ารักษาในโรงพยาบาลในโรคเบาหวาน (Diabetes)

ตัวหาร / population: b = จำนวนประชากรกลางปีทุกสิทธิการรักษาในพื้นที่รับผิดชอบ อายุ 15-74 ปี

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ต่อแสนประชากร; formula: (a/b) x 100,000. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*)
-- denominator (count)
NULLIF((SELECT COUNT(DISTINCT p.hn) FROM patient p), 0)
-- outer FROM / source
periodized
-- outer cohort predicate
pdx IN ('E100', 'E101', 'E106', 'E109', 'E110', 'E111', 'E116', 'E119', 'E130', 'E131', 'E136', 'E139', 'E140', 'E141', 'E146', 'E149')
```

- Counts discharges with the printed DM Pdx set E100, E101, E106, E109, E110, E111, E116, E119, E130, E131, E136, E139, E140, E141, E146, E149 (registered precedent). Denominator follows the registered AA0104/AA0105 precedent (COUNT(DISTINCT patient.hn) over the whole patient table), not the printed mid-year population aged 15-74 in the responsible area, and the numerator is not filtered to ages 15-74; the hospital owner must confirm the official population denominator and age band (or load the population rate into reporting.thip_external_facts).
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- patient HN ปัจจุบันไม่ใช่ population กลางปีอายุ 15–74 ในพื้นที่รับผิดชอบ; ต้องใช้ population denominator ภายนอก

Source tables: an_stat, death, ipt, iptdiag, patient. SQL SHA256: d8e0a438748b3eb3f8b885210c9cd2ac35deac80e11464de636aaf11f38abbc6

## AA0105

PDF physical 299; printed 290 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งที่ผู้ป่วยอายุ 15-74 ปีทุกสิทธิการรักษา ที่ลงทะเบียนของหน่วยบริการ ประจำเข้ารักษาในโรงพยาบาลในโรคความดันโลหิตสูง (HT)

ตัวหาร / population: b = จำนวนประชากรกลางปีทุกสิทธิการรักษาในพื้นที่รับผิดชอบ อายุ 15-74 ปี

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ต่อแสนประชากร; formula: (a/b) x 100,000. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*)
-- denominator (count)
NULLIF((SELECT COUNT(DISTINCT p.hn) FROM patient p), 0)
-- outer FROM / source
periodized
-- outer cohort predicate
pdx IN ('I10', 'I110', 'I119')
```

- Counts discharges with Pdx I10, I110, I119 (registered precedent). The printed definition also excludes admissions with cardiac procedures 33.6, 35, 36, 37.3, 37.5, 37.7, 37.8, 37.94, 37.98 (dotless 336, 35, 36, 373, 375, 377, 378, 3794, 3798 in iptoprt); that exclusion is NOT applied here to stay identical to the registered branch - the hospital owner must confirm which variant governs. Denominator follows the registered AA0104/AA0105 precedent (COUNT(DISTINCT patient.hn) over the whole patient table), not the printed mid-year population aged 15-74 in the responsible area, and the numerator is not filtered to ages 15-74; the hospital owner must confirm the official population denominator and age band (or load the population rate into reporting.thip_external_facts).
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- patient HN ปัจจุบันไม่ใช่ population กลางปีอายุ 15–74 ในพื้นที่รับผิดชอบ; ต้องใช้ population denominator ภายนอก

Source tables: an_stat, death, ipt, iptdiag, patient. SQL SHA256: 304f2b1c18c25b017958026f30de5f322197b230d25af2167ca8e4691ef49e61

## CA0101

PDF physical 189; printed 180 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยที่มีภาวะ ASA physical status I, II ที่เกิดภาวะหัวใจหยุดเต้นระหว่าง ผ่าตัด ใน 1 เดือน

ตัวหาร / population: b = จำนวนผู้ป่วยที่มีภาวะ ASA physical status I, II ก่อนผ่าตัดทั้งหมด (ในเดือน เดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ต่อ 10,000 ราย; formula: (a/b) x 10,000. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_anes_physical_status_id IN (1, 2)
          OR EXISTS (
            SELECT 1
            FROM operation_anes_detail ad
            WHERE ad.operation_id = ol.operation_id
              AND ad.asa_id IN (1, 2)
          )
        )
        AND (
          EXISTS (
            SELECT 1
            FROM operation_cpr cpr
            WHERE cpr.operation_id = ol.operation_id
          )
          OR ol.intra_anes_operation_note ILIKE '%หัวใจหยุดเต้น%'
          OR LOWER(ol.intra_anes_operation_note) LIKE '%cardiac arrest%'
        )
    ))
-- denominator (count)
COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_anes_physical_status_id IN (1, 2)
          OR EXISTS (
            SELECT 1
            FROM operation_anes_detail ad
            WHERE ad.operation_id = ol.operation_id
              AND ad.asa_id IN (1, 2)
          )
        )
    ))
-- outer FROM / source
periodized
-- outer cohort predicate
TRUE
```

- Measures IPD admissions with an operation_list case carrying ASA physical status I or II (operation_anes_physical_status_id IN (1,2) or operation_anes_detail.asa_id IN (1,2)) whose intra-operative cardiac arrest is evidenced by an operation_cpr record or a cardiac-arrest note in operation_list.intra_anes_operation_note. PDF needs: arrests among ASA I or II patients only, counted per anesthetized patient, with event time strictly inside the operation. Confirm with the hospital owner: the id-to-ASA mapping of operation_anes_physical_status (assumed 1 = ASA I, 2 = ASA II), that operation_cpr is filled for every intra-operative arrest, and that arrests documented only in anesthesia free text are captured by the note keywords. OPD-only operations are out of scope of the IPD discharge base.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, operation_anes_detail, operation_cpr, operation_list. SQL SHA256: c9954925433279d276432b6fdfd759cb9a8af467197bc584313f9feec42f7e5b

## CA0102

PDF physical 190; printed 181 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยผ่าตัดแบบไม่ฉุกเฉินที่ได้รับการเยี่ยมก่อนผ่าตัด ใน 1 เดือน

ตัวหาร / population: b = จำนวนผู้ป่วยผ่าตัดแบบไม่ฉุกเฉินทั้งหมด (ในเดือนเดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_list_anes_type_id IS NOT NULL
          OR ol.anes_complete = 'Y'
          OR EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
          )
        )
        AND NOT EXISTS (
          SELECT 1
          FROM operation_emergency oe
          WHERE oe.emergency_id = ol.emergency_id
            AND (
              oe.emergency_name ILIKE '%ฉุกเฉิน%'
              OR LOWER(oe.emergency_name) LIKE '%emergen%'
            )
        )
        AND (
          ol.pre_anes_operation_note IS NOT NULL
          OR EXISTS (
            SELECT 1
            FROM operation_visit_list ov
            WHERE ov.operation_id = ol.operation_id
              AND (
                ov.pre_anes_note IS NOT NULL
                OR ov.operation_visit_anes_type_id IS NOT NULL
              )
          )
        )
    ))
-- denominator (count)
COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_list_anes_type_id IS NOT NULL
          OR ol.anes_complete = 'Y'
          OR EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
          )
        )
        AND NOT EXISTS (
          SELECT 1
          FROM operation_emergency oe
          WHERE oe.emergency_id = ol.emergency_id
            AND (
              oe.emergency_name ILIKE '%ฉุกเฉิน%'
              OR LOWER(oe.emergency_name) LIKE '%emergen%'
            )
        )
    ))
-- outer FROM / source
periodized
-- outer cohort predicate
TRUE
```

- Measures the share of elective anesthetized IPD operation cases with a documented pre-anesthetic visit (operation_list.pre_anes_operation_note or operation_visit_list rows with pre_anes_note or operation_visit_anes_type_id). PDF needs: major elective operations only and a true pre-anesthetic visit within the recommended pre-operative window. Confirm with the hospital owner: the operation_emergency name convention used to flag emergency cases (matched on "ฉุกเฉิน" or "emergen"), how major operations are marked (oper_type lookup), and that pre-anesthetic visits are recorded in operation_visit_list rather than paper forms.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, operation_anes, operation_emergency, operation_list, operation_visit_list. SQL SHA256: 083ae263467537f7d6f46db6d77b7c6be9b0b6278e17e4ea45dfc6aef1b05680

## CA0103

PDF physical 191; printed 182 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยที่ได้รับยาระงับความรู้สึกและได้รับการดูแลในห้องพักฟื้น ใน 1 เดือน

ตัวหาร / population: b = จำนวนผู้ป่วยที่ได้ยาระงับความรู้สึกทั้งหมด (ในเดือนเดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_list_anes_type_id IS NOT NULL
          OR ol.anes_complete = 'Y'
          OR EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
          )
        )
        AND EXISTS (
            SELECT 1
            FROM operation_recovery_room rr
            WHERE rr.operation_id = ol.operation_id
          )
    ))
-- denominator (count)
COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND (
          ol.operation_list_anes_type_id IS NOT NULL
          OR ol.anes_complete = 'Y'
          OR EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
          )
        )
    ))
-- outer FROM / source
periodized
-- outer cohort predicate
TRUE
```

- Measures the share of anesthetized IPD operation cases with a recovery-room record (operation_recovery_room rows for the operation). PDF needs: care in the recovery room for the clinically appropriate duration per anesthesia type. Confirm with the hospital owner: that every post-anesthesia recovery stay is charted in operation_recovery_room (enter/leave times present) and whether direct-to-ICU transfers should be excluded.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, operation_anes, operation_list, operation_recovery_room. SQL SHA256: e22b6b30e7e904d71df57abc23506774901a2efdb3b3dffd395653f03bc7e19d

## CA0104

PDF physical 192; printed 183 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยที่ใส่ท่อหายใจซ้ำภายใน 2 ชั่วโมงหลังการถอดท่อหายใจ ใน 1 เดือน

ตัวหาร / population: b = จำนวนผู้ป่วยที่ได้รับการให้ยาระงับความรู้สึกแบบทั้งตัวที่ใส่ท่อหายใจทั้งหมด (ใน เดือนเดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
              AND (
                oa.anes_tube_type_id IS NOT NULL
                OR oa.anes_intubation_time IS NOT NULL
              )
          )
        AND EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
              AND (
                oa.anes_tube_type_id IS NOT NULL
                OR oa.anes_intubation_time IS NOT NULL
              )
              AND EXISTS (
                SELECT 1
                FROM operation_anes_problem ap
                WHERE ap.operation_id = ol.operation_id
                  AND (
                    ap.comment ILIKE '%ใส่ท่อ%'
                    OR LOWER(ap.comment) LIKE '%intubat%'
                    OR ap.airway_solution_id IN (
                      SELECT asl.airway_solution_id
                      FROM operation_airway_solution asl
                      WHERE asl.airway_solution_name ILIKE '%ใส่ท่อ%'
                         OR LOWER(asl.airway_solution_name) LIKE '%intubat%'
                    )
                  )
                  AND (ap.problem_date + COALESCE(ap.problem_time, TIME '00:00:00')) >=
                    (COALESCE(oa.end_date_time, oa.end_date + COALESCE(oa.end_time, TIME '23:59:59')))
                  AND (ap.problem_date + COALESCE(ap.problem_time, TIME '00:00:00')) <=
                    (COALESCE(oa.end_date_time, oa.end_date + COALESCE(oa.end_time, TIME '23:59:59'))) + INTERVAL '2 hours'
              )
          )
    ))
-- denominator (count)
COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.an = periodized.an
        AND EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
              AND (
                oa.anes_tube_type_id IS NOT NULL
                OR oa.anes_intubation_time IS NOT NULL
              )
          )
    ))
-- outer FROM / source
periodized
-- outer cohort predicate
TRUE
```

- Measures re-intubation within 2 hours after extubation among intubated general-anesthesia IPD cases (operation_anes with tube type or intubation time), detecting the event from operation_anes_problem rows whose comment or operation_airway_solution lookup name mentions intubation, timestamped within 2 hours after the recorded anesthesia end. PDF needs: true extubation time and any re-intubation for any reason. Confirm with the hospital owner: that extubation is recorded (operation_anes.end), that airway problems and their solutions are charted in operation_anes_problem, and the lookup wording in operation_airway_solution used for re-intubation.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, operation_airway_solution, operation_anes, operation_anes_problem, operation_list. SQL SHA256: 918f5bb7152db853d82d3be9a86b52fad804a558eb65123aa6a06c67fa7e26c7

## CA0105

PDF physical 193; printed 184 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยที่ได้รับการเฝ้าระวังระดับก๊าซคาร์บอนไดออกไซด์ในลมหายใจออก ใน 1 เดือน

ตัวหาร / population: b = จำนวนผู้ป่วยที่ได้รับการให้ยาระงับความรู้สึกแบบทั้งตัวที่ใส่ท่อช่วยหายใจทั้งหมด (ใน เดือนเดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT periodized.an) FILTER (WHERE COALESCE(operation_flags.ga_capno, FALSE))
-- denominator (count)
COUNT(DISTINCT periodized.an) FILTER (WHERE COALESCE(operation_flags.ga, FALSE))
-- outer FROM / source
periodized
      LEFT JOIN LATERAL (
          SELECT
            BOOL_OR(EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
              AND (
                oa.anes_tube_type_id IS NOT NULL
                OR oa.anes_intubation_time IS NOT NULL
              )
          )) AS ga,
            BOOL_OR(EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
              AND (
                oa.anes_tube_type_id IS NOT NULL
                OR oa.anes_intubation_time IS NOT NULL
              )
          ) AND (
            EXISTS (
              SELECT 1
              FROM operation_anes_detail ad
              WHERE ad.operation_id = ol.operation_id
                AND (
                  LOWER(ad.monitor) LIKE '%capno%'
                  OR LOWER(ad.monitor) LIKE '%etco%'
                  OR ad.monitor ILIKE '%คาพโน%'
                )
            )
            OR EXISTS (
              SELECT 1
              FROM ipd_nurse_note nn
              WHERE nn.an = periodized.an
                AND nn.etco2 IS NOT NULL
            )
          )) AS ga_capno
          FROM operation_list ol
          WHERE ol.an = periodized.an
        ) operation_flags ON TRUE
-- outer cohort predicate
TRUE
```

- Measures the share of intubated general-anesthesia IPD cases with exhaled-CO2 (capnometry) monitoring, evidenced by the operation_anes_detail.monitor text (capno, etco, คาพโน) or a recorded ipd_nurse_note.etco2 value. PDF needs: capnometry use for the whole intubated general-anesthesia period. Confirm with the hospital owner: the monitor naming convention in operation_anes_detail, and whether capnometry is charted elsewhere (for example an anesthesia record sheet outside HOSxP).
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipd_nurse_note, ipt, iptdiag, operation_anes, operation_anes_detail, operation_list. SQL SHA256: 3a121a1beffd9e2d992cee7597e3932e9ecb759820b6c8b139b4230ae77df6a0

## CE0101

PDF physical 203; printed 194 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = ผู้ป่วยที่มีภาวะติดเชื้อในกระแสโลหิตที่รับการตรวจรักษาที่ ER และ ได้รับยาปฏิชีวนะ ใน 3 ชั่วโมง นับตั้งแต่ระยะเวลาที่ผู้ป่วยมาถึงห้องฉุกเฉินจนถึงเวลาได้รับยา ในช่วงเวลา หนึ่งเดือน

ตัวหาร / population: b = ผู้ป่วยที่มีภาวะติดเชื้อในกระแสโลหิตที่รับการตรวจรักษาที่ ER ทั้งหมด ในเดือน เดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND di.antibiotic = 'Y'
            AND di.drugcategory ILIKE '%broad%'
            AND EXTRACT(EPOCH FROM (oi.vstdate::timestamp + COALESCE(oi.vsttime, TIME '00:00:00') - (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00')))) <= 10800))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
pdx IN ('A400', 'A419', 'R572', 'R651') OR has_ce0101_sepsis
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, drugitems, ipt, iptdiag, opitemrece. SQL SHA256: 58e6cd0eb575b6a2cb5dc5dc254686cd4c21874988db36853ac8178747b2cb14

## CE0102

PDF physical 204; printed 195, 196 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = ระยะเวลา (นาที) รวมทั้งหมดของผู้ป่วยฉุกเฉินมาก ที่มารับบริการในห้องฉุกเฉินใน ช่วงเวลาที่กําหนด

ตัวหาร / population: b = จำนวนผู้ป่วยฉุกเฉินมาก (คน) ทั้งหมดที่มารับบริการในห้องฉุกเฉินในช่วงเวลาเดียวกัน

Grain: visit/event at ovst VN (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: นาที; formula: a/b. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (sum)
SUM(EXTRACT(EPOCH FROM (opd_periodized.finish_time - opd_periodized.enter_er_time)) / NULLIF(60, 0))
-- denominator (count)
COUNT(*)
-- outer FROM / source
opd_periodized
-- outer cohort predicate
opd_periodized.enter_er_time IS NOT NULL AND opd_periodized.finish_time IS NOT NULL AND opd_periodized.finish_time > opd_periodized.enter_er_time AND opd_periodized.er_emergency_level_id = 1 AND EXTRACT(DAY FROM opd_periodized.enter_er_time) IN (5, 15, 25)
```

- Mean minutes from ER time-in (er_regist.enter_er_time) to time-out (finish_time) for ER visits flagged er_emergency_level_id = 1 (triage level 1 / 1A emergency). The printed definition samples only days 5, 15, 25 of each month and excludes deaths, off-hour clinic patients and admissions held in the ED; the branch enforces days 5, 15, 25 using time-in and both clocks. The hospital owner must confirm the er_emergency_level_id value that maps to triage 1A, exclusions and vstdate versus time-in month boundaries.
- เก็บเฉพาะวันที่ 5, 15, 25 ของ enter_er_time แล้ว; ยังใช้ vstdate/vsttime เป็น arrival proxy และต้องยืนยัน triage/exclusions กับ ER
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: er_regist, ovst, ovstdiag, patient. SQL SHA256: 4436f22230e93641d3af36522f14df66f235c8baf4f24ebc9cc58bf727d5fe6b

## CE0103

PDF physical 206; printed 197 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จํานวนผู้ป่วย 1A ที่สามารถให้การรักษาที่ ED ได้ภายใน 60 นาที ในช่วงเวลาของการ เก็บข้อมูลในรอบหนึ่งเดือนนั้น

ตัวหาร / population: b = จํานวนผู้ป่วย 1A ทั้งหมดที่รับการตรวจรักษาที่ ED ในช่วงเวลาของการเก็บข้อมูลใน รอบหนึ่งเดือนนั้นในรอบเดือนเดียวกัน

Grain: visit/event at ovst VN (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXTRACT(EPOCH FROM (opd_periodized.finish_time - opd_periodized.enter_er_time)) <= 3600)
-- denominator (count)
COUNT(*)
-- outer FROM / source
opd_periodized
-- outer cohort predicate
opd_periodized.enter_er_time IS NOT NULL AND opd_periodized.finish_time IS NOT NULL AND opd_periodized.finish_time > opd_periodized.enter_er_time AND opd_periodized.er_emergency_level_id = 1 AND EXTRACT(DAY FROM opd_periodized.enter_er_time) IN (5, 15, 25)
```

- Percent of level-1 (er_emergency_level_id = 1) ER visits whose time-in to time-out span is at most 3600 seconds. Enforces days 5, 15, 25 using time-in as CE0102; the hospital owner must confirm the 1A level mapping, exclusions and vstdate versus time-in month boundaries.
- เก็บเฉพาะวันที่ 5, 15, 25 ของ enter_er_time แล้ว; ยังต้องยืนยัน sampling, triage และ exclusions กับ ER
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: er_regist, ovst, ovstdiag, patient. SQL SHA256: a4dc704d54cc5148fe03116b5c03381b8c8181ad663ae7e8e5ef236b80a2247c

## CE0104

PDF physical 207; printed 198 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = ผู้ป่วยที่มีภาวะติดเชื้อในกระแสโลหิตที่รับการตรวจรักษาที่ ER และ ได้รับยาปฏิชีวนะใน 1 ชั่วโมง นับตั้งแต่ระยะเวลาที่ผู้ป่วยได้รับการวินิจฉัยจนถึงเวลาได้รับยา ในช่วงเวลาหนึ่งเดือน

ตัวหาร / population: b = ผู้ป่วยที่มีภาวะติดเชื้อในกระแสโลหิตที่รับการตรวจรักษาที่ ER ทั้งหมด ในเดือนเดียวกัน

Grain: visit/event at ovst VN (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: ร้อยละ; formula: (a/b) x100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE antibiotics_datetime IS NOT NULL AND doctor_tx_time IS NOT NULL AND antibiotics_datetime >= doctor_tx_time AND antibiotics_datetime <= doctor_tx_time + INTERVAL '1 hour')
-- denominator (count)
COUNT(*)
-- outer FROM / source
opd_periodized
-- outer cohort predicate
age_y >= 18 AND (
          pdx IN ('A400', 'A419', 'R572', 'R651')
          OR EXISTS (
            SELECT 1
            FROM ovstdiag sd
            WHERE sd.vn = opd_periodized.vn
              AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('A400', 'A409', 'A410', 'A419', 'R572', 'R651')
          )
        ) AND enter_er_time IS NOT NULL
```

- Visit-grain branch over adult ER visits (opd_periodized with enter_er_time present) diagnosed with severe sepsis or septic shock (Pdx or secondary diagnosis A400, A409, A410, A419, R572, R651); numerator is visits whose er_regist antibiotics_datetime lies between doctor_tx_time and one hour after it. The PDF times antibiotics from the sepsis diagnosis moment; doctor_tx_time (first doctor contact) is the closest stored proxy and the sepsis criteria (SIRS plus organ dysfunction) are approximated by the diagnosis codes. Owner must confirm the diagnosis time convention and the antibiotic timestamp semantics.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: er_regist, ovst, ovstdiag, patient. SQL SHA256: c8005cbcc0ff184ad253c8d4e97db457a6e5359861d586dd57a48afdad0578cb

## CG0101

PDF physical 197; printed 188, 189 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a= จำนวนผู้ป่วยที่เกิดแผลกดทับที่เกิดใหม่ในโรงพยาบาล ที่มีความรุนแรงตั้งแต่ระดับ 1 ขึ้นไป ในเดือนนั้น

ตัวหาร / population: b= จำนวนวันของผู้ป่วยที่รับนอนในรพ.ทั้งหมดภายในเดือนเดียวกันนั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ครั้งต่อ 1,000 วันนอน; formula: (a/b) x 1,000. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT periodized.an) FILTER (WHERE (
          LEFT(periodized.pdx, 3) <> 'L89'
          AND (
            EXISTS (
              SELECT 1
              FROM iptdiag sd
              WHERE sd.an = periodized.an
                AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'L89'
            )
            OR EXISTS (
              SELECT 1
              FROM ipd_nurse_note nn
              WHERE nn.an = periodized.an
                AND nn.note_date > periodized.regdate
                AND (
                  nn.note ILIKE '%แผลกดทับ%'
                  OR LOWER(nn.note) LIKE '%pressure ulcer%'
                )
            )
          )
        ))
-- denominator (sum)
SUM(COALESCE(periodized.los, 0))
-- outer FROM / source
periodized
-- outer cohort predicate
TRUE
```

- Measures new hospital-acquired pressure ulcers stage 1 or worse per 1000 patient-days: numerator is IPD admissions whose secondary diagnosis carries dotless L89 codes or whose nursing notes mention a pressure ulcer strictly after the admission date (with principal diagnosis outside L89), denominator is SUM(an_stat.los) over the same discharge cohort. PDF needs: true present-on-admission status, UHNDC staging (1-4, unstageable, deep tissue injury) and onset date. Confirm with the hospital owner: the L89 staging convention, that patient-days should be census days rather than discharged-cohort length of stay, and whether ulcers present on admission are distinguishable in ipd_nurse_note. Staging and POA precision likely require the UHNDC survey forms loaded via branchExternal.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipd_nurse_note, ipt, iptdiag. SQL SHA256: 2866a3f62893222f142c786064c962347e09c38ed128b8a8d6da6a8818b4bd3b

## CG0102

PDF physical 199; printed 190 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a= จำนวนครั้งของการเกิดแผลกดทับที่เกิดใหม่ในโรงพยาบาล ที่มีความรุนแรงตั้งแต่ระดับ 1 ขึ้นไป ของผู้ป่วยที่ได้รับการประเมินว่ามีความเสี่ยงต่อการเกิดแผลกดทับ ในเดือนนั้น

ตัวหาร / population: b= จำนวนวันของผู้ป่วยที่รับนอนในโรงพยาบาล ของผู้ป่วยที่ได้รับการประเมินว่ามีความ เสี่ยงต่อการเกิดแผลกดทับ ทั้งหมดภายในเดือนเดียวกันนั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ครั้งต่อ 1,000 วันนอน; formula: (a/b) x 1,000. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT periodized.an) FILTER (WHERE EXISTS (
            SELECT 1
            FROM ipd_nurse_note rn
            WHERE rn.an = periodized.an
              AND (
                LOWER(rn.note) LIKE '%braden%'
                OR rn.note ILIKE '%เสี่ยงต่อการเกิดแผลกดทับ%'
                OR (rn.note ILIKE '%เสี่ยง%' AND rn.note ILIKE '%กดทับ%')
              )
          ) AND (
          LEFT(periodized.pdx, 3) <> 'L89'
          AND (
            EXISTS (
              SELECT 1
              FROM iptdiag sd
              WHERE sd.an = periodized.an
                AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'L89'
            )
            OR EXISTS (
              SELECT 1
              FROM ipd_nurse_note nn
              WHERE nn.an = periodized.an
                AND nn.note_date > periodized.regdate
                AND (
                  nn.note ILIKE '%แผลกดทับ%'
                  OR LOWER(nn.note) LIKE '%pressure ulcer%'
                )
            )
          )
        ))
-- denominator (sum)
SUM(COALESCE(periodized.los, 0)) FILTER (WHERE EXISTS (
            SELECT 1
            FROM ipd_nurse_note rn
            WHERE rn.an = periodized.an
              AND (
                LOWER(rn.note) LIKE '%braden%'
                OR rn.note ILIKE '%เสี่ยงต่อการเกิดแผลกดทับ%'
                OR (rn.note ILIKE '%เสี่ยง%' AND rn.note ILIKE '%กดทับ%')
              )
          ))
-- outer FROM / source
periodized
-- outer cohort predicate
TRUE
```

- Same rate restricted to risk-assessed patients: a risk assessment is approximated by nursing notes mentioning Braden or pressure-ulcer risk, the denominator being their total length of stay and the numerator the CG0101 evidence within that group. PDF needs: the documented Braden (or local) risk assessment population and their patient-days. Confirm with the hospital owner: where the risk assessment is recorded (structured Braden scores are not standard HOSxP columns) and the accepted wording; otherwise stage the risk-patient counts via branchExternal.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipd_nurse_note, ipt, iptdiag. SQL SHA256: 2d513073c381b187e784ce64a6b24011cc2aee0720986f8934d0f87adeb3195e

## CG0103

PDF physical 200; printed 191, 192 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a= จำนวนผู้ป่วยที่มีแผลกดทับที่พบทั้งหมดในโรงพยาบาล แบ่งเป็นเกิดก่อนมาโรงพยาบาล และเกิดในโรงพยาบาล ที่มีความรุนแรงตั้งแต่ระดับ 1 ขึ้นไป ในช่วงเวลาที่สำรวจ

ตัวหาร / population: b= จำนวนผู้ป่วยทั้งหมดที่มีอยู่ในโรงพยาบาลในช่วงเวลาเดียวกัน

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'CG0103'
```

- NOT computable from HOSxP: the PDF defines a point-prevalence survey (all pressure-ulcer patients present in the hospital at the survey moment, including pre-admission-onset, over the surveyed population). External staging: load one row per quarterly anchor (period_start = first day of Jan, Apr, Jul or Oct) into reporting.thip_external_facts with indicator_code = CG0103, numerator = surveyed patients with any pressure ulcer stage 1 or worse (present-on-admission plus hospital-acquired), denominator = all surveyed inpatients at that moment, value = ROUND(numerator * 100 / NULLIF(denominator, 0), 2), source_system = nursing_pui_survey. Confirm with the hospital owner: survey dates and the survey roster used.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 442c02843e6c62997414dd4e12799ebbe959b6ed4d2b4a54081a012643e9a46b

## CG0104

PDF physical 202; printed 193 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a= จำนวนผู้ป่วยที่มีแผลกดทับที่เกิดในโรงพยาบาล ที่มีความรุนแรงตั้งแต่ระดับ 1 ขึ้น ไป ในช่วงเวลาที่สำรวจ

ตัวหาร / population: b = จำนวนประชากรผู้ป่วยทั้งหมดในเวลาที่สำรวจ

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'CG0104'
```

- NOT computable from HOSxP: the PDF defines a point-prevalence survey counting only ulcers that developed after admission (chart review of the admission note required). External staging: load one row per quarterly anchor (period_start = first day of Jan, Apr, Jul or Oct) into reporting.thip_external_facts with indicator_code = CG0104, numerator = surveyed patients with a hospital-acquired pressure ulcer stage 1 or worse, denominator = the whole surveyed population at that moment, value = ROUND(numerator * 100 / NULLIF(denominator, 0), 2), source_system = nursing_pui_survey. Confirm with the hospital owner: the admission-note review process that separates hospital-acquired from present-on-admission ulcers.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 6670933bde88011cae6a6818a4d518fb06e939b9120d2b1e58dc777dfe42cffd

## CI0101

PDF physical 208; printed 199 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยติดเชื้อในกระแสโลหิตทั้งหมดที่รับไว้ในโรงพยาบาลที่เสียชีวิต

ตัวหาร / population: b = จำนวนผู้ป่วยติดเชื้อในกระแสโลหิตทั้งหมดที่รับไว้ในโรงพยาบาล

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE died)
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
pdx IN ('A400', 'A409', 'A410', 'A419', 'R572', 'R651') OR has_ci0101_sepsis
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: 709c4afb5fdadabc2b9e3352a62295813c27680d3a351b26e9709f752de4064f

## CM0101

PDF physical 170; printed 161 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนมารดาตายระหว่างการตั้งครรภ์ การคลอด หลังคลอดไม่เกิน 6 สัปดาห์ ในช่วง 1 ปีที่ประเมิน

ตัวหาร / population: b = จำนวนการเกิดมีชีพทั้งหมด (ในปีการประเมินเดียวกัน)

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: ipt.an, labor.an, death.an, death.hn, ipt.hn. Date candidates: death.death_date, death.death_time, ipt.dchdate, ipt.dchtime, ipt.regdate, ipt.regtime, ipt_newborn.born_date, labor.labour_finishdate, labor.labour_startdate.

Unit: ต่อการเกิดมีชีพแสนคน; formula: (a/b) x 100,000. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ipt m
          JOIN death d ON (d.an = m.an OR d.hn = m.hn)
          WHERE m.an = delivery_periodized.an
            AND d.death_date IS NOT NULL
            AND d.death_date >= COALESCE(delivery_periodized.labour_startdate, d.death_date)
            AND d.death_date <= COALESCE(delivery_periodized.labour_finishdate, delivery_periodized.labour_startdate, d.death_date) + INTERVAL '42 days'
            AND (
              d.death_preg_42_day = 'Y'
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_icd10, ''))), '.', ''), 1) = 'O'
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_cause, ''))), '.', ''), 1) = 'O'
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_1, ''))), '.', ''), 1) = 'O'
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_2, ''))), '.', ''), 1) = 'O'
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_3, ''))), '.', ''), 1) = 'O'
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_4, ''))), '.', ''), 1) = 'O'
            )
            AND NOT (
              LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_icd10, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_cause, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_1, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_2, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_3, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_4, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
            )
        ))
-- denominator (mixed)
SUM((
          SELECT COUNT(*)
          FROM ipt_newborn nb
          WHERE nb.mother_an = delivery_periodized.an
            AND COALESCE(nb.dead, 'N') <> 'Y'
        ))
-- outer FROM / source
delivery_periodized
-- outer cohort predicate
TRUE
```

- Measures maternal deaths tied to a delivery record of this hospital from labour start to 42 days after delivery with a pregnancy related cause (death_preg_42_day flag or O cause code, external V W X Y causes excluded), per 100,000 live newborns counted from ipt_newborn rows not flagged dead (babies counted individually). The printed definition also needs deaths during pregnancy before any hospital delivery and deaths of mothers referred out and lost to follow up, which no HOSxP table links back to the delivery. Confirm with the hospital owner: death_preg_42_day flag semantics, ipt_newborn.dead values as the stillbirth marker, and how referred out maternal deaths are recorded.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: death, ipt, ipt_newborn, labor. SQL SHA256: 0abf391e1258889ce195e5058ea27dcf70087bc240f3d1b98624ebaaae21afd1

## CM0104

PDF physical 171; printed 162 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้คลอด C/S ที่ต้องรับกลับเข้าโรงพยาบาล โดยไม่ได้วางแผน ภายใน 28 วัน หลังออกจากโรงพยาบาล

ตัวหาร / population: b = จำนวนผู้คลอด C/S ที่จำหน่าย ในเดือนก่อนหน้านั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        ))
-- denominator (count)
COUNT(*) FILTER (WHERE NOT died)
-- outer FROM / source
periodized
-- outer cohort predicate
pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: 0b839e02941c80623fac6dd6abc6a13d692f908918ffbe5ef5db3d0885793e46

## CM0105

PDF physical 172; printed 163 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนวันนอนรวมของผู้ป่วยที่ทำ Caesarean section ทั้งหมดในเดือนที่ประเมิน

ตัวหาร / population: b = จำนวนผู้ป่วยที่ทำ Caesarean section ที่จำหน่าย ในเดือนเดียวกันนั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: วัน; formula: a/b. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (sum)
ROUND(SUM(los)::numeric, 2)
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: f88161a893c48338e6c490b33af22698fa7cc0845bc1c62cbbdf7a34aafbf4db

## CM0107

PDF physical 173; printed 164 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนหญิงตั้งครรภ์คลอดอายุครรภ์ 28 สัปดาห์ขึ้นไปที่มีภาวะตกเลือดหลังคลอด เฉียบพลัน ที่รับไว้ในโรงพยาบาล ใน 1 เดือน

ตัวหาร / population: b = จำนวนหญิงตั้งครรภ์ทั้งหมดที่มาคลอดทางช่องคลอดในโรงพยาบาล (ในเดือนเดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (
        WHERE LEFT(pdx, 3) = 'O72'
           OR EXISTS (
             SELECT 1 FROM iptdiag sd
             WHERE sd.an = periodized.an
               AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'O72'
           )
           OR EXISTS (
              SELECT 1 FROM labor lb
              WHERE lb.an = periodized.an
                AND COALESCE(lb.placenta_bloodloss, 0) >= 500
            )
      )
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
(LEFT(pdx, 3) IN ('O80', 'O81', 'O83') OR pdx IN ('O840', 'O841', 'O848', 'O849'))
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, labor. SQL SHA256: 9fec227db32ab6f57d43ebdef86a931060dd594f21be2d1df8bfc1b8a0ef541c

## CM0109

PDF physical 174; printed 165 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนหญิงตั้งครรภ์ที่มีภาวะชักจากครรภ์เป็นพิษ ที่รับไว้ในโรงพยาบาลใน 1 เดือน

ตัวหาร / population: b = จำนวนหญิงตั้งครรภ์ คลอดหรือหลังคลอด ที่รับไว้รักษาในโรงพยาบาลทั้งหมด (ใน เดือนเดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (
        WHERE LEFT(pdx, 3) = 'O15'
           OR EXISTS (
             SELECT 1 FROM iptdiag sd
             WHERE sd.an = periodized.an
               AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'O15'
           )
      )
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
LEFT(pdx, 1) = 'O'
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: 12d1c99723bb361dfa3eb24a496d0db0cd46adfc05aaecf6f57bc2c456ea84b9

## CM0110

PDF physical 175; printed 166 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนหญิงตั้งครรภ์ที่มีภาวะเบาหวาน ที่รับไว้ในโรงพยาบาล ใน 1 เดือน

ตัวหาร / population: b = จำนวนหญิงตั้งครรภ์ คลอดหรือหลังคลอด ที่รับไว้รักษาในโรงพยาบาลทั้งหมด (ใน เดือนเดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (
        WHERE pdx = 'O244'
           OR EXISTS (
             SELECT 1 FROM iptdiag sd
             WHERE sd.an = periodized.an
               AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'O244'
           )
      )
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
LEFT(pdx, 1) = 'O'
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: 2a3dac693379f948b967817d1f9496af95e5f93f13b40547cb386eb5c71155f0

## CM0116

PDF physical 176; printed 167 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการผ่าตัด Abdominal hysterectomy ที่ได้รับ prophylactic antibiotic ภายใน 1 ชั่วโมง ก่อนลงมีดผ่าตัดใน 1 เดือน

ตัวหาร / population: b = จำนวนครั้งของการผ่าตัด Abdominal hysterectomy ทั้งหมดในเดือนเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          JOIN opitemrece oi ON oi.an = o.an
          JOIN drugitems di ON di.icode = oi.icode
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('683', '684', '686', '6860', '6861', '6862', '6863', '6864', '6865', '6866', '6867', '6868', '6869')
            AND (di.antibiotic = 'Y' OR di.drugcategory ILIKE '%antibio%')
            AND EXTRACT(EPOCH FROM (
              (o.opdate + COALESCE(o.optime, TIME '00:00:00')) -
              (oi.vstdate + COALESCE(oi.vsttime, TIME '00:00:00'))
            )) BETWEEN 0 AND 3600))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('683', '684', '686', '6860', '6861', '6862', '6863', '6864', '6865', '6866', '6867', '6868', '6869')
    )
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, drugitems, ipt, iptdiag, iptoprt, opitemrece. SQL SHA256: 8f264d78eae3f61338f926bffb22076ef9ffefe43d96056752c22bb3ba259781

## CM0117

PDF physical 177; printed 168 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการติดเชื้อแผลผ่าตัด Abdominal hysterectomy

ตัวหาร / population: b = จำนวนครั้งของการผ่าตัด Abdominal hysterectomy ทั้งหมด

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'T814'
          UNION
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          LEFT JOIN iptdiag rd ON rd.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '30 days'
            AND (
              REPLACE(UPPER(TRIM(rs.pdx)), '.', '') = 'T814'
              OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') = 'T814'
            )))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('683', '684', '686', '6860', '6861', '6862', '6863', '6864', '6865', '6866', '6867', '6868', '6869')
    )
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, iptoprt. SQL SHA256: 241a340ccd59082a1ca6985e0bd194f234b8f13c02aa0e42d0996f7e06169fcc

## CM0118

PDF physical 178; printed 169 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนหญิงตั้งครรภ์ที่คลอดบุตรในโรงพยาบาลด้วยวิธีการผ่าตัดคลอดครั้งแรกที่ไม่มี ประวัติการผ่าตัดคลอดบุตรทางหน้าท้อง (previous cesarean section) ทุกสิทธิการรักษาและ จำหน่ายในเดือนนั้น ในช่วงเวลา 1 เดือน

ตัวหาร / population: b = จำนวนหญิงตั้งครรภ์ที่คลอดบุตรในโรงพยาบาลที่ไม่มีประวัติการผ่าตัดคลอดบุตรทางหน้าท้อง (Previous Cesarean Section) และจำหน่ายในเดือนนั้นทั้งหมดทุกสิทธิการรักษาในเดือนเดียวกันนั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE (pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842') OR EXISTS (SELECT 1 FROM iptoprt o WHERE o.an = periodized.an AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('740', '741', '742', '744', '7499'))) AND NOT (EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'O342')))
-- denominator (count)
COUNT(*) FILTER (WHERE NOT (EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'O342')))
-- outer FROM / source
periodized
-- outer cohort predicate
LEFT(pdx, 3) BETWEEN 'O80' AND 'O84'
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, iptoprt. SQL SHA256: 05cc52b7cffc8a481b0dfe7b6c5d56b9e539055ce4e4e1dad234b25ac637c007

## CM0119

PDF physical 179; printed 170 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนหญิงตั้งครรภ์ที่คลอดบุตรในโรงพยาบาลด้วยวิธีการผ่าตัดคลอดทุกสิทธิการ รักษาและจำหน่ายในเดือนนั้น ในช่วงเวลา 1 เดือน

ตัวหาร / population: b = จำนวนหญิงตั้งครรภ์ที่คลอดบุตรในโรงพยาบาล และจำหน่ายในเดือนนั้นทั้งหมด ทุกสิทธิการรักษา ในเดือนเดียวกันนั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE pdx IN ('O820', 'O821', 'O822', 'O828', 'O829', 'O842') OR EXISTS (SELECT 1 FROM iptoprt o WHERE o.an = periodized.an AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('740', '741', '742', '744', '7499')))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
LEFT(pdx, 3) BETWEEN 'O80' AND 'O84'
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, iptoprt. SQL SHA256: 1d0ecc81c5f2e6fa8c6284f6236a10fbe819aba3a24aaf6c64a4f736e647c328

## CM0201

PDF physical 180; printed 171 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนทารกที่ตายปริกำเนิด ในช่วงเดือนนั้น

ตัวหาร / population: b = จำนวนทารกเกิดทั้งหมด ในช่วงเดือนเดียวกัน

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: รอตรวจ SQL. Date candidates: death.death_date, death.death_time, ipt_newborn.born_date.

Unit: ต่อ 1,000 การเกิดทั้งหมด; formula: (a/b) x 1,000. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE (COALESCE(newborn_periodized.dead, 'N') = 'Y' OR EXISTS (
          SELECT 1
          FROM death d
          WHERE d.an = newborn_periodized.an
            AND d.death_date IS NOT NULL
            AND d.death_date >= newborn_periodized.born_date
            AND d.death_date <= newborn_periodized.born_date + INTERVAL '7 days'
        )) AND (COALESCE(newborn_periodized.birth_weight, 0) >= 500 OR (newborn_periodized.birth_weight IS NULL AND EXISTS (
          SELECT 1
          FROM ipt_pregnancy pg
          WHERE pg.an = newborn_periodized.mother_an
            AND COALESCE(pg.ga, 0) >= 24
        ))))
-- denominator (count)
COUNT(*)
-- outer FROM / source
newborn_periodized
-- outer cohort predicate
TRUE
```

- Measures perinatal deaths per 1,000 births: newborn rows flagged dead (stillbirth proxy) or with a death record within 7 days of born_date among births of at least 500 g, or gestational age at least 24 weeks from ipt_pregnancy.ga of the mother admission when birth weight is missing. The printed WHO rule also needs follow up of transferred out infants to day 7 and exclusion of infants referred in from other hospitals, which HOSxP does not flag. Confirm ipt_newborn.dead semantics and that ipt_pregnancy.ga is gestational weeks at delivery.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: death, ipt_newborn, ipt_pregnancy. SQL SHA256: b949b272d66ba4bcdbadf8c606bdf1d7ece6a8fc6dc7becef3dee7ebc787f679

## CM0202

PDF physical 181; printed 172 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนการเสียชีวิตของทารกตั้งแต่อายุครรภ์28 สัปดาห์จนถึง7วันหลังคลอด

ตัวหาร / population: b = จำนวนทารกคลอดทั้งหมดในช่วงเวลาเดียวกัน

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: รอตรวจ SQL. Date candidates: death.death_date, death.death_time, ipt_newborn.born_date.

Unit: ต่อ 1,000 ทารกคลอด; formula: (a/b) x 1,000. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE (COALESCE(newborn_periodized.dead, 'N') = 'Y' OR EXISTS (
          SELECT 1
          FROM death d
          WHERE d.an = newborn_periodized.an
            AND d.death_date IS NOT NULL
            AND d.death_date >= newborn_periodized.born_date
            AND d.death_date <= newborn_periodized.born_date + INTERVAL '7 days'
        )) AND (COALESCE(newborn_periodized.birth_weight, 0) >= 1000 OR (newborn_periodized.birth_weight IS NULL AND EXISTS (
          SELECT 1
          FROM ipt_pregnancy pg
          WHERE pg.an = newborn_periodized.mother_an
            AND COALESCE(pg.ga, 0) >= 28
        ))))
-- denominator (count)
COUNT(*)
-- outer FROM / source
newborn_periodized
-- outer cohort predicate
TRUE
```

- Measures perinatal deaths per 1,000 births at the 28 week or 1000 g threshold: newborn rows flagged dead or with a death record within 7 days of born_date among births of at least 1000 g, or gestational age at least 28 weeks from ipt_pregnancy.ga when birth weight is missing. The printed definition adds sent out infant follow up and referred in exclusions that need local tracking. Confirm ipt_newborn.dead semantics and ipt_pregnancy.ga units with the hospital owner.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: death, ipt_newborn, ipt_pregnancy. SQL SHA256: 01230f2533e850fd49dd0c6e11e2bd0ccfb0172d1e2faf777c8c48103aeca1b5

## CM0203

PDF physical 182; printed 173 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนทารกแรกเกิดที่เสียชีวิตภายใน 28 วันหลังคลอด ในช่วงเวลา 1 เดือน

ตัวหาร / population: b = จำนวนทารกแรกเกิดมีชีพทั้งหมด ในเดือนเดียวกัน

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: รอตรวจ SQL. Date candidates: death.death_date, death.death_time, ipt_newborn.born_date.

Unit: ต่อ 1,000 ทารกเกิดมีชีพ; formula: (a/b) x 1,000. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM death d
          WHERE d.an = newborn_periodized.an
            AND d.death_date IS NOT NULL
            AND d.death_date >= newborn_periodized.born_date
            AND d.death_date <= newborn_periodized.born_date + INTERVAL '28 days'
        ))
-- denominator (count)
COUNT(*)
-- outer FROM / source
newborn_periodized
-- outer cohort predicate
COALESCE(newborn_periodized.dead, 'N') <> 'Y'
```

- Measures neonatal deaths per 1,000 live births: newborn rows not flagged dead with a death record between born_date and 28 days after. The printed definition needs follow up of transferred out infants to day 28 including deaths after discharge, and excludes births referred in from other hospitals. Confirm that post discharge neonatal deaths land in the death table with the newborn admission number and that ipt_newborn.dead marks stillbirth only.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: death, ipt_newborn. SQL SHA256: 23143d99ce55d0a36868b276797a42139e96056560e1e961a0e86e184628e05b

## CM0204

PDF physical 183; printed 174 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนทารกแรกเกิดมีชีพ ที่มีคะแนน APGAR ที่ 1 นาที ≤ 7 ใน 1 เดือน

ตัวหาร / population: b = จำนวนทารกแรกเกิดมีชีพทั้งหมด (ในเดือนเดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ต่อ 1,000 ทารกเกิดมีชีพ; formula: (a/b) x 1,000. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (
        WHERE LEFT(pdx, 3) = 'P21'
           OR EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'P21')
           OR EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND (nb.apgar1 <= 7 OR nb.has_asphyxia = 'Y'))
      )
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
(LEFT(pdx, 3) = 'Z38' OR age_y = 0)
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, ipt_newborn, iptdiag. SQL SHA256: 5f909b94c9dd959f487b56ee8bb868c5d05763a337118b41f1df23fe1b680b96

## CM0205

PDF physical 184; printed 175 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนทารกแรกเกิดมีชีพ ที่มีคะแนน APGAR ที่ 5 นาที ≤ 4 ใน 1 เดือน

ตัวหาร / population: b = จำนวนทารกแรกเกิดมีชีพทั้งหมด (ในเดือนเดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ต่อ 1,000 ทารกเกิดมีชีพ; formula: (a/b) x 1,000. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (
        WHERE pdx = 'P210'
           OR EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'P210')
           OR EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND (nb.apgar2 <= 4 OR nb.apgar1 <= 3))
      )
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
(LEFT(pdx, 3) = 'Z38' OR age_y = 0)
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, ipt_newborn, iptdiag. SQL SHA256: a41256dad3a6fb2a449b86e0b66e5063e7dbc10d40e56f62cf85c2f5d5ecc1c5

## CM0206

PDF physical 185; printed 176 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนทารกแรกเกิดมีชีพ น้ำหนักต่ำกว่า 2,500 กรัม ใน 1 เดือน

ตัวหาร / population: b = จำนวนทารกแรกเกิดมีชีพทั้งหมด (ในเดือนเดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (
        WHERE EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight < 2500)
           OR (periodized.bw > 0 AND periodized.bw < 2500)
      )
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
(LEFT(pdx, 3) = 'Z38' OR age_y = 0)
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, ipt_newborn, iptdiag. SQL SHA256: 5b681b31af684f9749f081d25498f7b1f437c90258f263f4e9233ca7fb35bf62

## CM0207

PDF physical 186; printed 177 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนทารกแรกเกิดมีชีพน้ำหนักต่ำกว่า 1,000 กรัมที่เสียชีวิตภายใน 28 วันหลังการ คลอด ใน 1 เดือน

ตัวหาร / population: b = จำนวนทารกแรกเกิดมีชีพน้ำหนักต่ำกว่า 1,000 กรัมทั้งหมด (ในเดือนเดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (
        WHERE died AND (
          EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight < 1000)
          OR (periodized.bw > 0 AND periodized.bw < 1000)
        )
      )
-- denominator (count)
COUNT(*) FILTER (
        WHERE EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight < 1000)
           OR (periodized.bw > 0 AND periodized.bw < 1000)
      )
-- outer FROM / source
periodized
-- outer cohort predicate
(LEFT(pdx, 3) = 'Z38' OR age_y = 0)
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, ipt_newborn, iptdiag. SQL SHA256: 4fee27d6fd287809e7305769863fd3dfc117822d91f1cef6f0fdbbfeb6a0ecdc

## CM0208

PDF physical 187; printed 178 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนทารกแรกเกิดมีชีพน้ำหนัก 1,000-1,499 กรัมที่เสียชีวิตภายใน 28 วันหลังการ คลอด ใน 1 เดือน

ตัวหาร / population: b = จำนวนทารกแรกเกิดมีชีพน้ำหนักต่ำกว่า 1,000-1,499 กรัมทั้งหมด (ในเดือนเดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (
        WHERE died AND (
          EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight BETWEEN 1000 AND 1499)
          OR (periodized.bw > 0 AND periodized.bw BETWEEN 1000 AND 1499)
        )
      )
-- denominator (count)
COUNT(*) FILTER (
        WHERE EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight BETWEEN 1000 AND 1499)
           OR (periodized.bw > 0 AND periodized.bw BETWEEN 1000 AND 1499)
      )
-- outer FROM / source
periodized
-- outer cohort predicate
(LEFT(pdx, 3) = 'Z38' OR age_y = 0)
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, ipt_newborn, iptdiag. SQL SHA256: 5f1440dd72c74eec0cfac174858b4275e37e2f57c72885f6cd02ea019915ec6e

## CM0209

PDF physical 188; printed 179 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนทารกแรกเกิดมีชีพน้ำหนัก 1,500-2,499 กรัมที่เสียชีวิตภายใน 28 วันหลังการ คลอด ใน 1 เดือน

ตัวหาร / population: b = จำนวนทารกแรกเกิดมีชีพน้ำหนัก 1,500-2,499 กรัมทั้งหมด (ในเดือนเดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (
        WHERE died AND (
          EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight BETWEEN 1500 AND 2499)
          OR (periodized.bw > 0 AND periodized.bw BETWEEN 1500 AND 2499)
        )
      )
-- denominator (count)
COUNT(*) FILTER (
        WHERE EXISTS (SELECT 1 FROM ipt_newborn nb WHERE nb.an = periodized.an AND nb.birth_weight BETWEEN 1500 AND 2499)
           OR (periodized.bw > 0 AND periodized.bw BETWEEN 1500 AND 2499)
      )
-- outer FROM / source
periodized
-- outer cohort predicate
(LEFT(pdx, 3) = 'Z38' OR age_y = 0)
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, ipt_newborn, iptdiag. SQL SHA256: 9cb8e4ef02d904bc9fc0a63feb097a6c2af4a80ddca07813d9d0e328e4a77da2

## CO0101

PDF physical 194; printed 185 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย (รายครั้ง) ที่ได้ทำแบบตรวจสอบฯ อย่างสมบูรณ์

ตัวหาร / population: b = จำนวนผู้ป่วย (รายครั้ง) ที่มารับการตรวจรักษาในห้องผ่าตัด

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT ol.operation_id) FILTER (WHERE (
          ol.operation_check_date IS NOT NULL
          AND EXISTS (
            SELECT 1
            FROM operation_detail od
            WHERE od.operation_id = ol.operation_id
              AND od.time_out_datetime IS NOT NULL
          )
          AND EXISTS (
            SELECT 1
            FROM operation_screen_in osi
            WHERE osi.operation_id = ol.operation_id
              AND osi.preoperative_nursing_record IS NOT NULL
              AND osi.perioperative_record IS NOT NULL
              AND osi.postoperative_record IS NOT NULL
          )
        ))
-- denominator (count)
COUNT(DISTINCT ol.operation_id)
-- outer FROM / source
periodized
      JOIN operation_list ol ON ol.an = periodized.an
-- outer cohort predicate
TRUE
```

- Measures the share of operating-room occasions with a complete surgical safety checklist: operation_list.operation_check_date set, an operation_detail row with time_out_datetime (time-out), and operation_screen_in rows with preoperative, perioperative and postoperative nursing records (sign in, time out, sign out). Denominator counts operation_list.operation_id occasions of IPD cases discharged in the period. PDF needs: every procedure in every OR, with each of the three parts completed correctly. Confirm with the hospital owner: the confirm_receive and confirm_complete flag semantics on operation_list, whether checklist completion is verified against paper checklists, and that OPD-only procedures (no admission) are out of scope here.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, operation_detail, operation_list, operation_screen_in. SQL SHA256: 113fec4e223e90bc5055bebe39209976cf7683e7777bf173d7ad56282e169200

## CO0105

PDF physical 195; printed 186 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยที่เข้ารับการผ่าตัดกรณีไม่ฉุกเฉินและเสียชีวิตระหว่างและหลังการผ่าตัด ภายใน 24 ชั่วโมงแรก

ตัวหาร / population: b = จำนวนผู้ป่วยที่เข้ารับการผ่าตัดกรณีไม่ฉุกเฉินในช่วงเวลาเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT periodized.an) FILTER (WHERE COALESCE(operation_flags.elective_anes_death_24h, FALSE))
-- denominator (count)
COUNT(DISTINCT periodized.an) FILTER (WHERE COALESCE(operation_flags.elective_anes, FALSE))
-- outer FROM / source
periodized
      LEFT JOIN LATERAL (
          SELECT
            BOOL_OR((
          ol.operation_list_anes_type_id IS NOT NULL
          OR ol.anes_complete = 'Y'
          OR EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
          )
        ) AND NOT EXISTS (
          SELECT 1
          FROM operation_emergency oe
          WHERE oe.emergency_id = ol.emergency_id
            AND (
              oe.emergency_name ILIKE '%ฉุกเฉิน%'
              OR LOWER(oe.emergency_name) LIKE '%emergen%'
            )
        )) AS elective_anes,
            BOOL_OR((
          ol.operation_list_anes_type_id IS NOT NULL
          OR ol.anes_complete = 'Y'
          OR EXISTS (
            SELECT 1
            FROM operation_anes oa
            WHERE oa.operation_id = ol.operation_id
          )
        ) AND NOT EXISTS (
          SELECT 1
          FROM operation_emergency oe
          WHERE oe.emergency_id = ol.emergency_id
            AND (
              oe.emergency_name ILIKE '%ฉุกเฉิน%'
              OR LOWER(oe.emergency_name) LIKE '%emergen%'
            )
        ) AND EXISTS (
            SELECT 1
            FROM operation_detail od
            WHERE od.operation_id = ol.operation_id
              AND EXISTS (
                SELECT 1
                FROM death d
                WHERE d.an = periodized.an
                  AND (d.death_date + COALESCE(d.death_time, TIME '23:59:59')) >=
                    COALESCE(od.begin_datetime, ol.operation_date + COALESCE(ol.operation_time, TIME '00:00:00'))
                  AND (d.death_date + COALESCE(d.death_time, TIME '23:59:59')) <=
                    COALESCE(od.begin_datetime, ol.operation_date + COALESCE(ol.operation_time, TIME '00:00:00')) + INTERVAL '24 hours'
              )
          )) AS elective_anes_death_24h
          FROM operation_list ol
          WHERE ol.an = periodized.an
        ) operation_flags ON TRUE
-- outer cohort predicate
TRUE
```

- Measures peri-operative mortality within 24 hours for elective anesthetized IPD operation cases: death (death table) timestamped between the first operation_detail begin time (falling back to operation_list operation_date + operation_time) and that anchor plus 24 hours. PDF needs: major elective operations only, with the window covering anesthesia induction through 24 hours after surgery. Confirm with the hospital owner: the operation_emergency name convention for emergency cases, the major-operation marker (oper_type lookup), and whether deaths between induction and incision would be missed by the incision-time anchor.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, operation_anes, operation_detail, operation_emergency, operation_list. SQL SHA256: 6f447be66ce92be2db50d3b33b1b85104c4df1b580088034855edd55b766b450

## CO0107

PDF physical 196; printed 187 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการผ่าตัดซ้ำในผู้ป่วยในโดยไม่ได้วางแผนและการผ่าตัดผู้ป่วยนอกที่ Admit หลังผ่าตัดทันที ใน 1 เดือน

ตัวหาร / population: b = จำนวนครั้งของผู้ป่วยที่เข้ารับการผ่าตัดทั้งหมด ในเดือนเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT ol.operation_id) FILTER (WHERE ol.re_operation = 'Y')
-- denominator (count)
COUNT(DISTINCT ol.operation_id)
-- outer FROM / source
periodized
      JOIN operation_list ol ON ol.an = periodized.an
-- outer cohort predicate
TRUE
```

- Measures the share of operating-room occasions flagged as re-operation (operation_list.re_operation = Y) among all operation occasions of IPD cases discharged in the period. PDF needs: unplanned re-operations for the same disease within one admission plus outpatient operations that force an immediate unplanned admission, excluding planned staged procedures. Confirm with the hospital owner: that re_operation is actively maintained (it is a char(1) flag whose Y convention must be verified), how planned staged operations are marked, and how the OPD-to-admission cases are recorded.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, operation_list. SQL SHA256: 43a2cb3732c7cdd32647704362123bfe44b0750cc66c3c3c633047a689beb02a

## CP0101

PDF physical 209; printed 200 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จํานวนเด็ก/ผู้ดูแลที่นัดมารับการบำบัดรักษาตามแผนการรักษา ในรอบ 6 เดือน (ราย)

ตัวหาร / population: b = จํานวนเด็ก/ผู้ดูแลทั้งหมดที่นัดมารับการบำบัดรักษาในรอบ 6 เดือน (ราย)

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: ovst.vn, psych_therapy.vn_an. Date candidates: clinicmember.dchdate, clinicmember.last_bp_date, clinicmember.last_hba1c_date, clinicmember.regdate, ovst.vstdate, psych_plan.psych_plan_date, psych_plan.psych_plan_finish_date, psych_therapy.psych_therapy_date.

Unit: ร้อยละ; formula: (a/b) ข 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT clinicmember_id) FILTER (WHERE attended.flagged)
-- denominator (count)
COUNT(DISTINCT clinicmember_id)
-- outer FROM / source
chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM psych_therapy th
        JOIN ovst tv ON tv.vn = th.vn_an
        WHERE tv.hn = chronic_periodized.hn
          AND th.psych_therapy_date >= chronic_periodized.regdate - INTERVAL '6 months'
          AND th.psych_therapy_date <= chronic_periodized.regdate
      ) OR EXISTS (
        SELECT 1
        FROM psych_plan pf
        WHERE pf.hn = chronic_periodized.hn
          AND pf.psych_plan_finish_date IS NOT NULL
          AND pf.psych_plan_finish_date >= chronic_periodized.regdate - INTERVAL '6 months'
          AND pf.psych_plan_finish_date <= chronic_periodized.regdate
      ) AS flagged
    ) attended ON TRUE
-- outer cohort predicate
chronic_periodized.age_y <= 18
    AND (EXISTS (
      SELECT 1
      FROM ovstdiag sdc
      WHERE sdc.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdc.icd10)), '.', ''), 3) IN ('F80', 'F81', 'F82', 'F83', 'F90', 'F32', 'F33') OR REPLACE(UPPER(TRIM(sdc.icd10)), '.', '') IN ('F341'))
    ))
    AND EXISTS (
      SELECT 1
      FROM psych_plan pps
      WHERE pps.hn = chronic_periodized.hn
        AND pps.psych_plan_date >= chronic_periodized.regdate - INTERVAL '6 months'
        AND pps.psych_plan_date <= chronic_periodized.regdate
    )
```

- Measures members aged 18 or under with an ADHD, LD or MDD diagnosis (F80-F83, F90, F32, F33, F341) and a psych_plan in the trailing 6 months who attended care: a psych_therapy session or a finished psych_plan in the same window. The PDF is about carers keeping every scheduled appointment in the 6-month period; HOSxP has no appointment-kept ledger here, so attendance is approximated by recorded therapy or plan completion and the owner must confirm the appointment source (clinic_app or psychiatric_clinic_psychia_appointment).
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: clinicmember, ovst, ovstdiag, psych_plan, psych_therapy. SQL SHA256: 3cbe2eb1405a61dba539472aebecb3efac0428bef55ed29c5fd0796625deaddd

## CP0201

PDF physical 210; printed 201 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนเด็กสงสัยพัฒนาการล่าช้าที่ได้รับการวินิจฉัยภายใน 90 วัน (คน)

ตัวหาร / population: b = จำนวนเด็กสงสัยพัฒนาการล่าช้าทั้งหมดที่มารับบริการวินิจฉัยและดูแลรักษา โดยไม่ นับรวมผู้ป่วยที่มาขอรับบริการเฉพาะการฝึก (คน)

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: รอตรวจ SQL. Date candidates: clinicmember.dchdate, clinicmember.last_bp_date, clinicmember.last_hba1c_date, clinicmember.regdate, ovstdiag.vstdate, psych_screen_child.psych_screen_child_date.

Unit: ร้อยละ; formula: (a/b) ข 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT clinicmember_id) FILTER (WHERE dx90.flagged)
-- denominator (count)
COUNT(DISTINCT clinicmember_id)
-- outer FROM / source
chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM ovstdiag sd9
        WHERE sd9.hn = chronic_periodized.hn
          AND LEFT(REPLACE(UPPER(TRIM(sd9.icd10)), '.', ''), 3) IN ('F83', 'R62', 'F84', 'G80')
          AND sd9.vstdate >= chronic_periodized.regdate
          AND sd9.vstdate <= chronic_periodized.regdate + INTERVAL '90 days'
      ) AS flagged
    ) dx90 ON TRUE
-- outer cohort predicate
chronic_periodized.age_y <= 6
    AND EXISTS (
      SELECT 1
      FROM psych_screen_child psc
      WHERE psc.hn = chronic_periodized.hn
        AND psc.psych_screen_child_date >= chronic_periodized.regdate - INTERVAL '3 months'
        AND psc.psych_screen_child_date <= chronic_periodized.regdate + INTERVAL '3 months'
    )
```

- Measures members aged 6 or under with a child development screen (psych_screen_child) around registration who received a neurodevelopmental diagnosis (F83, R62, F84, G80) within 90 days after registration. The PDF starts the 90-day clock at the first service visit for suspected delay and excludes therapy-only contacts; the screen date stands in for the suspicion entry, so the owner must confirm the suspicion flag and the first-visit anchor.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: clinicmember, ovstdiag, psych_screen_child. SQL SHA256: 71170143b7a0e23d17f9b73d41d88bdda584a7138c1b81fa395b05fde0a058c7

## DC0103

PDF physical 101; printed 92 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยเบาหวานที่ได้รับการตรวจจอประสาทตา อย่างน้อยปีละ 1 ครั้งต่อปี (คน)

ตัวหาร / population: b = จำนวนผู้ป่วยเบาหวานที่มารับบริการรักษาในโรงพยาบาลในรอบ 1 ปีเดียวกัน (คน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT periodized.hn) FILTER (
        WHERE EXISTS (
          SELECT 1 FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('9502', '9503', '9512')
        )
        OR EXISTS (
          SELECT 1 FROM ovstdiag od
          JOIN ovst ov ON ov.vn = od.vn
          WHERE ov.hn = periodized.hn
            AND REPLACE(UPPER(TRIM(od.icd10)), '.', '') IN ('Z010', 'Z135')
            AND ov.vstdate >= :start_date AND ov.vstdate < :end_date
        )
      )
-- denominator (count)
COUNT(DISTINCT periodized.hn)
-- outer FROM / source
periodized
-- outer cohort predicate
LEFT(pdx, 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, iptoprt, ovst, ovstdiag. SQL SHA256: 302181a8c4246c8c1a2cfde59ea8babea12980e699ce0f554dd5163b5bc913c1

## DC0107

PDF physical 102; printed 93 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยเบาหวานที่ได้รับการตัดขาจากภาวะแทรกซ้อนของโรคเบาหวานทั้งหมด

ตัวหาร / population: b = จำนวนผู้ป่วยเบาหวานที่ขึ้นทะเบียนรับการรักษาของโรงพยาบาลทั้งหมด (ในเดือน เดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (
        WHERE EXISTS (
          SELECT 1 FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8410', '8411', '8412', '8413', '8414', '8415', '8416', '8417', '8418', '8419')
        )
      )
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
LEFT(pdx, 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, iptoprt. SQL SHA256: 3443a643923e1e7912c268ef1e4d8be22e57f96df573bcdd955f5c8092a45d32

## DC0108

PDF physical 103; printed 94 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยเบาหวานผู้ใหญ่ที่ควบคุมระดับน้ำตาลในเลือดได้ดีตามเกณฑ์ที่กำหนด ในช่วงเวลา 6 เดือน (ครึ่งปี)

ตัวหาร / population: b = จำนวนผู้ป่วยเบาหวานผู้ใหญ่ที่ขึ้นทะเบียนรับการรักษากับโรงพยาบาลและมารับ บริการทั้งหมดในช่วงเวลาครึ่งปีเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (
        WHERE ((age_y < 60 AND EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= periodized.period_start - INTERVAL '6 months'
            AND lh.order_date <= periodized.period_start
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END <= 7.0))
            OR (age_y >= 60 AND EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= periodized.period_start - INTERVAL '6 months'
            AND lh.order_date <= periodized.period_start
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END <= 8.0)))
      )
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND LEFT(pdx, 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, lab_head, lab_items, lab_order. SQL SHA256: 072ba0089024690f462850b6b289ca4b3796f7f9e57256c91769459574aa1c12

## DC0108.1

PDF physical 104; printed 95 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยเบาหวานผู้ใหญ่อายุ ≥ 60 ปี ที่ควบคุมระดับน้ำตาลในเลือดได้ดีตาม เกณฑ์ที่กำหนด ในช่วงเวลา 6 เดือน (ครึ่งปี)

ตัวหาร / population: b = จำนวนผู้ป่วยเบาหวานผู้ใหญ่อายุ ≥ 60 ปี ที่ขึ้นทะเบียนรับการรักษากับโรงพยาบาล และมารับบริการทั้งหมดในช่วงเวลาครึ่งปีเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= periodized.period_start - INTERVAL '6 months'
            AND lh.order_date <= periodized.period_start
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END <= 8.0))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 60 AND LEFT(pdx, 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, lab_head, lab_items, lab_order. SQL SHA256: 53fd203b245a542b9b059ecbcd7e1efe09ba29f590b752b8ffeb8ec51f670525

## DC0108.2

PDF physical 105; printed 96 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยเบาหวานผู้ใหญ่อายุเกินกว่า 18 ปี แต่น้อยกว่า 60 ปี ที่ควบคุมระดับ น้ำตาลในเลือดได้ดีตามเกณฑ์ที่กำหนด ในช่วงเวลา 6 เดือน (ครึ่งปี)

ตัวหาร / population: b = จำนวนผู้ป่วยเบาหวานผู้ใหญ่อายุเกินกว่า 18 ปี แต่น้อยกว่า 60 ปี ที่ขึ้นทะเบียนรับ การรักษากับโรงพยาบาลและมารับบริการทั้งหมดในช่วงเวลาครึ่งปีเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= periodized.period_start - INTERVAL '6 months'
            AND lh.order_date <= periodized.period_start
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END <= 7.0))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND age_y < 60 AND LEFT(pdx, 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, lab_head, lab_items, lab_order. SQL SHA256: cf2a48204b5f1d81638c83e477dfeef2f360d50178d20853d6d53164c83b85e6

## DC0201

PDF physical 106; printed 97, 98 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยความดันโลหิตสูงควบคุมระดับความดันโลหิตได้ดีตามเกณฑ์ที่กำหนด ในช่วงเวลา 6 เดือน (ครึ่งปี)

ตัวหาร / population: b = จำนวนผู้ป่วยความดันโลหิตสูงที่ขึ้นทะเบียนรับการรักษากับโรงพยาบาลและมารับ บริการทั้งหมดในช่วงเวลาครึ่งปีเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (
        WHERE ((age_y < 65 AND EXISTS (
          SELECT 1 FROM opdscreen sc
          JOIN ovst v ON v.vn = sc.vn
          WHERE v.an = periodized.an
            AND sc.bps <= 130 AND sc.bpd <= 80))
            OR (age_y >= 65 AND EXISTS (
          SELECT 1 FROM opdscreen sc
          JOIN ovst v ON v.vn = sc.vn
          WHERE v.an = periodized.an
            AND sc.bps <= 140 AND sc.bpd <= 80)))
      )
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND LEFT(pdx, 3) IN ('I10', 'I11', 'I12', 'I13', 'I14', 'I15')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, opdscreen, ovst. SQL SHA256: ee15758d34ae5fbafe8f3ae9d935d0e5d055d568ce2dd9bafeada7a1b13f828b

## DC0201.1

PDF physical 108; printed 99 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยความดันโลหิตสูง อายุ ≥ 18 ปี แต่ < 65 ปี ที่ขึ้นทะเบียนรับการรักษากับ โรงพยาบาลและมารับบริการ ที่ควบคุมระดับความดันโลหิตได้ดีตามเกณฑ์ที่กำหนด ในช่วง เวลา 6 เดือน (ครึ่งปี)

ตัวหาร / population: b = จำนวนผู้ป่วยความดันโลหิตสูงอายุ ≥ 18 ปี แต่ < 65 ปี ที่ขึ้นทะเบียนรับการรักษากับ โรงพยาบาลและมารับบริการทั้งหมดในช่วงเวลาครึ่งปีเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1 FROM opdscreen sc
          JOIN ovst v ON v.vn = sc.vn
          WHERE v.an = periodized.an
            AND sc.bps <= 130 AND sc.bpd <= 80))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND age_y < 65 AND LEFT(pdx, 3) IN ('I10', 'I11', 'I12', 'I13', 'I14', 'I15')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, opdscreen, ovst. SQL SHA256: 97b8410f197ffb74f16185fc742b98558f7594a3000654583d154fb48c5d6235

## DC0201.2

PDF physical 109; printed 100 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยความดันโลหิตสูง อายุ ≥ 18 ปี แต่ < 65 ปี ที่ขึ้นทะเบียนรับการรักษากับ โรงพยาบาลและมารับบริการ ที่ควบคุมระดับความดันโลหิตได้ดีตามเกณฑ์ที่กำหนด ในช่วง เวลา 6 เดือน (ครึ่งปี)

ตัวหาร / population: b = จำนวนผู้ป่วยความดันโลหิตสูงอายุ ≥ 18 ปี แต่ < 65 ปี ที่ขึ้นทะเบียนรับการรักษากับ โรงพยาบาลและมารับบริการทั้งหมดในช่วงเวลาครึ่งปีเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1 FROM opdscreen sc
          JOIN ovst v ON v.vn = sc.vn
          WHERE v.an = periodized.an
            AND sc.bps <= 140 AND sc.bpd <= 80))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 65 AND LEFT(pdx, 3) IN ('I10', 'I11', 'I12', 'I13', 'I14', 'I15')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, opdscreen, ovst. SQL SHA256: c375130b4db65623c211d817f50b2e3722f4b39f69687f59f8d9577c50273277

## DC0301

PDF physical 110; printed 101 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย/ผู้ติดเชื้อเอชไอวีที่ได้รับยาต้านไวรัสได้รับการตรวจ VL อย่างน้อย 1 ครั้ง ในรอบ 1 ปี

ตัวหาร / population: b = จำนวนผู้ป่วย/ผู้ติดเชื้อเอชไอวีที่ได้รับการรักษาด้วยยาต้านไวรัสนานมากกว่า 6 เดือน ทั้งหมด (ในปีเดียวกัน)

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: lab_order.lab_order_number, lab_head.lab_order_number, lab_items.lab_items_code, lab_order.lab_items_code. Date candidates: arv_tx.date_entry, clinicmember.dchdate, clinicmember.last_bp_date, clinicmember.last_hba1c_date, clinicmember.regdate, lab_head.order_date.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT clinicmember_id) FILTER (WHERE vl_done.flagged)
-- denominator (count)
COUNT(DISTINCT clinicmember_id)
-- outer FROM / source
chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM lab_head lh
        JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
        JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
        WHERE lh.hn = chronic_periodized.hn
          AND (li.lab_items_name ILIKE '%viral%')
          AND lh.order_date >= chronic_periodized.regdate - INTERVAL '12 months'
          AND lh.order_date <= chronic_periodized.regdate
      ) AS flagged
    ) vl_done ON TRUE
-- outer cohort predicate
(EXISTS (
      SELECT 1
      FROM arv_tx axh
      WHERE axh.hn = chronic_periodized.hn
    ) OR EXISTS (
      SELECT 1
      FROM ovstdiag sdh
      WHERE sdh.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdh.icd10)), '.', ''), 3) IN ('B20', 'B21', 'B22', 'B23', 'B24') OR REPLACE(UPPER(TRIM(sdh.icd10)), '.', '') IN ('Z21'))
    ))
    AND EXISTS (
      SELECT 1
      FROM arv_tx ax
      WHERE ax.hn = chronic_periodized.hn
        AND ax.date_entry <= chronic_periodized.regdate - INTERVAL '6 months'
    )
```

- Measures clinicmember registrations of PLHIV (arv_tx row or B20-B24, Z21 diagnosis) whose ARV record predates registration by more than 6 months and who have at least one viral-load lab item (name match) in the trailing 12 months. The PDF wants all PLHIV on ARV for more than 6 months during the reporting year with one VL in that year; the hospital owner must confirm arv_tx.date_entry as the ARV start date, the VL lab item set (arv_lab_map is the candidate refinement) and whether the cohort must be widened from the registration year to every member active in the year.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: arv_tx, clinicmember, lab_head, lab_items, lab_order, ovstdiag. SQL SHA256: 64d8b759afbacbae0705d302da9b39ab35d5e7a139d54e79150f63421efcc8bc

## DC0302

PDF physical 111; printed 102 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย/ผู้ติดเชื้อเอชไอวีที่มี VL < 50 copies/ml หลังจากกินยาต้านไวรัส มาแล้ว 12 เดือน

ตัวหาร / population: b = จำนวนผู้ป่วย/ผู้ติดเชื้อเอชไอวีที่เริ่มยาต้านไวรัสครบ 12 เดือนในช่วงปีที่ประเมิน

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: lab_order.lab_order_number, lab_head.lab_order_number, lab_items.lab_items_code, lab_order.lab_items_code. Date candidates: arv_tx.date_entry, clinicmember.dchdate, clinicmember.last_bp_date, clinicmember.last_hba1c_date, clinicmember.regdate, lab_head.order_date.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT clinicmember_id) FILTER (WHERE vl50_done.flagged)
-- denominator (count)
COUNT(DISTINCT clinicmember_id)
-- outer FROM / source
chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM lab_head lh
        JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
        JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
        WHERE lh.hn = chronic_periodized.hn
          AND (li.lab_items_name ILIKE '%viral%')
          AND lh.order_date >= chronic_periodized.regdate - INTERVAL '12 months'
          AND lh.order_date <= chronic_periodized.regdate
          AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END IS NOT NULL AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END < 50
      ) AS flagged
    ) vl50_done ON TRUE
-- outer cohort predicate
(EXISTS (
      SELECT 1
      FROM arv_tx axh
      WHERE axh.hn = chronic_periodized.hn
    ) OR EXISTS (
      SELECT 1
      FROM ovstdiag sdh
      WHERE sdh.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdh.icd10)), '.', ''), 3) IN ('B20', 'B21', 'B22', 'B23', 'B24') OR REPLACE(UPPER(TRIM(sdh.icd10)), '.', '') IN ('Z21'))
    ))
    AND EXISTS (
      SELECT 1
      FROM arv_tx ax
      WHERE ax.hn = chronic_periodized.hn
        AND ax.date_entry <= chronic_periodized.regdate - INTERVAL '12 months'
    )
```

- Measures members on ARV for at least 12 months (arv_tx.date_entry) with a numeric viral-load result below 50 copies in the trailing 12 months. The PDF wants VL below 50 at 12 months after ART start; the branch cannot tie the lab to the exact ART month, so the owner must confirm the VL item codes, the numeric-cast tolerance for result text and the 12-month window anchor.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: arv_tx, clinicmember, lab_head, lab_items, lab_order, ovstdiag. SQL SHA256: b7c844296f6fbdd65fcf20fbf642aa67eb54a332db0552e0750cac181f017b8f

## DC0306

PDF physical 112; printed 103 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย/ผู้ติดเชื้อเอชไอวีเพศหญิงที่ได้รับการคัดกรองมะเร็งปากมดลูกอย่างน้อย 1 ครั้งในปีที่ประเมิน

ตัวหาร / population: b = จำนวนผู้ป่วย/ผู้ติดเชื้อเอชไอวีเพศหญิงทั้งหมด (ในรอบปีที่ประเมินเดียวกัน)

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: lab_order.lab_order_number, lab_head.lab_order_number, lab_items.lab_items_code, lab_order.lab_items_code. Date candidates: clinicmember.dchdate, clinicmember.last_bp_date, clinicmember.last_hba1c_date, clinicmember.regdate, lab_head.order_date.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT clinicmember_id) FILTER (WHERE pap_done.flagged)
-- denominator (count)
COUNT(DISTINCT clinicmember_id)
-- outer FROM / source
chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM lab_head lh
        JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
        JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
        WHERE lh.hn = chronic_periodized.hn
          AND (li.lab_items_name ILIKE '%pap%')
          AND lh.order_date >= chronic_periodized.regdate - INTERVAL '12 months'
          AND lh.order_date <= chronic_periodized.regdate
      ) AS flagged
    ) pap_done ON TRUE
-- outer cohort predicate
chronic_periodized.sex = '2'
    AND (EXISTS (
      SELECT 1
      FROM arv_tx axh
      WHERE axh.hn = chronic_periodized.hn
    ) OR EXISTS (
      SELECT 1
      FROM ovstdiag sdh
      WHERE sdh.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdh.icd10)), '.', ''), 3) IN ('B20', 'B21', 'B22', 'B23', 'B24') OR REPLACE(UPPER(TRIM(sdh.icd10)), '.', '') IN ('Z21'))
    ))
```

- Measures female PLHIV registrations with a Pap-smear lab item (name match) in the trailing 12 months. The PDF accepts Pap smear or VIA and counts each woman once per year; VIA procedures recorded outside the lab (for example sti_patient_register_lab) are missed, so the owner must confirm the Pap and VIA procedure coding and the sex field mapping.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: arv_tx, clinicmember, lab_head, lab_items, lab_order, ovstdiag. SQL SHA256: 65fa4e345ea62d4015f0e66c434806e62688f294439ff1a562bb61dfd9d4cc2e

## DC0307

PDF physical 113; printed 104 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย/ผู้ติดเชื้อเอชไอวีทีรายใหม่ ที่ได้รับการตรวจคัดกรองโรคซิฟิลิส ในรอบปี รายงาน

ตัวหาร / population: b = จำนวนผู้ป่วย/ผู้ติดเชื้อเอชไอวีรายใหม่ทั้งหมด ในรอบปีรายงาน

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: lab_order.lab_order_number, lab_head.lab_order_number, lab_items.lab_items_code, lab_order.lab_items_code. Date candidates: clinicmember.dchdate, clinicmember.last_bp_date, clinicmember.last_hba1c_date, clinicmember.regdate, lab_head.order_date.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT clinicmember_id) FILTER (WHERE syph_done.flagged)
-- denominator (count)
COUNT(DISTINCT clinicmember_id)
-- outer FROM / source
chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM lab_head lh
        JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
        JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
        WHERE lh.hn = chronic_periodized.hn
          AND (li.lab_items_name ILIKE '%vdrl%' OR li.lab_items_name ILIKE '%rpr%' OR li.lab_items_name ILIKE '%tpha%' OR li.lab_items_name ILIKE '%tppa%' OR li.lab_items_name ILIKE '%syphilis%' OR li.lab_items_name ILIKE '%ซิฟิลิส%')
          AND lh.order_date >= chronic_periodized.regdate
          AND lh.order_date <= chronic_periodized.regdate + INTERVAL '12 months'
      ) AS flagged
    ) syph_done ON TRUE
-- outer cohort predicate
(EXISTS (
      SELECT 1
      FROM arv_tx axh
      WHERE axh.hn = chronic_periodized.hn
    ) OR EXISTS (
      SELECT 1
      FROM ovstdiag sdh
      WHERE sdh.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdh.icd10)), '.', ''), 3) IN ('B20', 'B21', 'B22', 'B23', 'B24') OR REPLACE(UPPER(TRIM(sdh.icd10)), '.', '') IN ('Z21'))
    ))
```

- Measures newly registered PLHIV (registration rows in the period) with a syphilis serology lab item (VDRL, RPR, TPHA, TPPA or name match) within 12 months after registration. The PDF asks for syphilis screening within the reporting year for new cases; repeat registrations of the same member can double count and pre-registration tests are excluded, so the owner must confirm the new-case rule and the screening window.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: arv_tx, clinicmember, lab_head, lab_items, lab_order, ovstdiag. SQL SHA256: ee8665977e1eb30f42a05834d7a778708a2e84ebe5562b73f19e26b3bc71acb9

## DC0308

PDF physical 114; printed 105 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ติดเชื้อเอชไอวี/เอดส์ที่เข้าถึงยาต้านไวรัสตามนิยามข้อ 2

ตัวหาร / population: B = จำนวนผู้ป่วย/ ผู้ติดเชื้อเอชไอวีทั้งหมดตามนิยามข้อ 1

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: drugitems.icode, opitemrece.icode. Date candidates: clinicmember.dchdate, clinicmember.last_bp_date, clinicmember.last_hba1c_date, clinicmember.regdate, opitemrece.vstdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT clinicmember_id) FILTER (WHERE arv_pickup.flagged)
-- denominator (count)
COUNT(DISTINCT clinicmember_id)
-- outer FROM / source
chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.hn = chronic_periodized.hn
          AND (di.name ILIKE '%tenofovir%' OR di.name ILIKE '%lamivudine%' OR di.name ILIKE '%zidovudine%' OR di.name ILIKE '%emtricitabine%' OR di.name ILIKE '%abacavir%' OR di.name ILIKE '%efavirenz%' OR di.name ILIKE '%nevirapine%' OR di.name ILIKE '%lopinavir%' OR di.name ILIKE '%atazanavir%' OR di.name ILIKE '%darunavir%' OR di.name ILIKE '%dolutegravir%' OR di.name ILIKE '%raltegravir%')
          AND oi.vstdate >= chronic_periodized.regdate - INTERVAL '12 months'
          AND oi.vstdate <= chronic_periodized.regdate
      ) AS flagged
    ) arv_pickup ON TRUE
-- outer cohort predicate
(EXISTS (
      SELECT 1
      FROM arv_tx axh
      WHERE axh.hn = chronic_periodized.hn
    ) OR EXISTS (
      SELECT 1
      FROM ovstdiag sdh
      WHERE sdh.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdh.icd10)), '.', ''), 3) IN ('B20', 'B21', 'B22', 'B23', 'B24') OR REPLACE(UPPER(TRIM(sdh.icd10)), '.', '') IN ('Z21'))
    ))
```

- Measures PLHIV registrations with at least one ARV dispensing (opitemrece plus drugitems name set) in the trailing 12 months. The PDF wants all registered PLHIV in the denominator and those collecting ARV at least once in the year in the numerator; the denominator is limited to members registered in the period and the ARV name list must be signed off against the local formulary (arv_tx rows are the alternative signal).
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: arv_tx, clinicmember, drugitems, opitemrece, ovstdiag. SQL SHA256: 94b8d5c662b1d71c7fa5ccaa70d16a1013ad93bfec36f3b0e39725544dec063d

## DC0309

PDF physical 115; printed 106 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = ผู้ติดเชื้อเอชไอวีรายใหม่ได้รับยาป้องกันวัณโรค (TPT)

ตัวหาร / population: B = ผู้ติดเชื้อเอชไอวีรายใหม่ที่มีข้อบ่งชี้

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: drugitems.icode, opitemrece.icode. Date candidates: clinicmember.dchdate, clinicmember.last_bp_date, clinicmember.last_hba1c_date, clinicmember.regdate, opitemrece.vstdate, tb_register.tb_register_date.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT clinicmember_id) FILTER (WHERE tpt_done.flagged)
-- denominator (count)
COUNT(DISTINCT clinicmember_id)
-- outer FROM / source
chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.hn = chronic_periodized.hn
          AND (di.name ILIKE '%isoniazid%' OR di.name ILIKE '%rifapentine%' OR di.name ILIKE '%rifampicin%' OR di.name ILIKE '%inah%')
          AND oi.vstdate >= chronic_periodized.regdate
          AND oi.vstdate <= chronic_periodized.regdate + INTERVAL '6 months'
      ) AS flagged
    ) tpt_done ON TRUE
-- outer cohort predicate
(EXISTS (
      SELECT 1
      FROM arv_tx axh
      WHERE axh.hn = chronic_periodized.hn
    ) OR EXISTS (
      SELECT 1
      FROM ovstdiag sdh
      WHERE sdh.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdh.icd10)), '.', ''), 3) IN ('B20', 'B21', 'B22', 'B23', 'B24') OR REPLACE(UPPER(TRIM(sdh.icd10)), '.', '') IN ('Z21'))
    ))
    AND NOT EXISTS (
      SELECT 1
      FROM tb_register tba
      WHERE tba.hn = chronic_periodized.hn
        AND tba.tb_register_date >= chronic_periodized.regdate - INTERVAL '12 months'
        AND tba.tb_register_date <= chronic_periodized.regdate + INTERVAL '6 months'
    )
```

- Measures newly registered PLHIV without concurrent TB who received TB preventive therapy (isoniazid, rifapentine, rifampicin or INAH dispensing) within 6 months after registration. The PDF denominator needs the TPT indication (CD4 below 200, TST above 5 mm, IGRA or doctor decision), which has no HOSxP column, so the denominator approximates all new PLHIV without active TB; the owner must confirm the indication register or accept external staging.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: arv_tx, clinicmember, drugitems, opitemrece, ovstdiag, tb_register. SQL SHA256: af2d2fb283a1ab311ff2b7049ecc6d3364a729fed2a015075010fb36c700311f

## DC0401

PDF physical 116; printed 107 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของผู้ป่วยมะเร็งที่จำหน่ายด้วยการเสียชีวิต ใน 1 เดือน

ตัวหาร / population: b = จำนวนครั้งของผู้ป่วยมะเร็งที่จำหน่ายทุกสถานะ (ในเดือนเดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE died)
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
pdx IN ('C00','C01','C02','C03','C04','C05','C06','C07','C08','C09','C10','C11','C12','C13','C14','C15','C16','C17','C18','C19','C20','C21','C22','C23','C24','C25','C26','C30','C31','C32','C33','C34','C37','C38','C39','C40','C41','C43','C44','C45','C46','C47','C48','C49','C50','C51','C52','C53','C54','C55','C56','C57','C58','C60','C61','C62','C63','C64','C65','C66','C67','C68','C69','C70','C71','C72','C73','C74','C75','C76','C77','C78','C79','C80','C81','C82','C83','C84','C85','C86','C87','C88','C89','C90','C91','C92','C93','C94','C95','C96','C97','D00','D01','D02','D03','D04','D05','D06','D07','D08','D09','Z510','Z511')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: 94899be2c74fba45a5e13bcb2a699506a852d8176bf7373349f18904fffd1ed7

## DC0402

PDF physical 117; printed 108 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของผู้ป่วยมะเร็งที่มาตรวจก่อนถึงกำหนดวันนัดหมายและรับไว้ใน โรงพยาบาล

ตัวหาร / population: b = จำนวนครั้งของผู้ป่วยมะเร็งที่รับไว้ในโรงพยาบาลทั้งหมด (ในเดือนเดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.dchdate IS NOT NULL
            AND periodized.regdate > r.dchdate
            AND periodized.regdate <= r.dchdate + INTERVAL '28 days'
            AND (
              (LEFT(REPLACE(UPPER(TRIM(rs.pdx)), '.', ''), 1) = 'C' OR LEFT(REPLACE(UPPER(TRIM(rs.pdx)), '.', ''), 3) IN ('D00', 'D01', 'D02', 'D03', 'D04', 'D05', 'D06', 'D07', 'D08', 'D09') OR REPLACE(UPPER(TRIM(rs.pdx)), '.', '') IN ('Z510', 'Z511'))
              OR EXISTS (
                SELECT 1
                FROM iptdiag rd
                WHERE rd.an = r.an
                  AND (LEFT(REPLACE(UPPER(TRIM(rd.icd10)), '.', ''), 1) = 'C' OR LEFT(REPLACE(UPPER(TRIM(rd.icd10)), '.', ''), 3) IN ('D00', 'D01', 'D02', 'D03', 'D04', 'D05', 'D06', 'D07', 'D08', 'D09') OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') IN ('Z510', 'Z511'))
              )
            )
        ))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
((LEFT(REPLACE(UPPER(TRIM(pdx)), '.', ''), 1) = 'C' OR LEFT(REPLACE(UPPER(TRIM(pdx)), '.', ''), 3) IN ('D00', 'D01', 'D02', 'D03', 'D04', 'D05', 'D06', 'D07', 'D08', 'D09') OR REPLACE(UPPER(TRIM(pdx)), '.', '') IN ('Z510', 'Z511')) OR EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND (LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 1) = 'C' OR LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('D00', 'D01', 'D02', 'D03', 'D04', 'D05', 'D06', 'D07', 'D08', 'D09') OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('Z510', 'Z511'))
        ))
```

- Measures percent of cancer inpatient episodes (pdx or sdx malignant neoplasm C00 to C97, in situ D00 to D09, or Z510 Z511) that are readmissions within 28 days after a previous cancer discharge of the same patient. The printed definition counts unplanned returns BEFORE the booked appointment date, which HOSxP does not store. Confirm with the hospital owner the appointment date source and the planned versus unplanned flag; until then 28 days is the documented proxy used across this repo.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: e56ec0a202724ec0f765f31d488b47d74dc110c3554584326828d9d7e629ad0d

## DC0403

PDF physical 118; printed 109 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของผู้ป่วย Liver cancer ที่จำหน่ายด้วยการเสียชีวิต ใน 1 เดือน

ตัวหาร / population: b = จำนวนครั้งของผู้ป่วย Liver cancer ที่จำหน่ายทุกสถานะ (ในเดือนเดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE died)
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
((LEFT(pdx, 3) IN ('C220', 'C222', 'C223', 'C224', 'C225', 'C226', 'C227', 'C228', 'C229')) OR EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('C220', 'C222', 'C223', 'C224', 'C225', 'C226', 'C227', 'C228', 'C229')
        ))
```

- Measures percent of liver cancer inpatient episodes (pdx or sdx in C220, C222 to C229 per the thipKpiRules token list) discharged dead, all causes. The printed definition mixes death from any cause with death caused by liver cancer. Confirm whether C221 (intrahepatic bile duct carcinoma) belongs in the cohort, and whether deaths shortly after discharge should be attributed back to the admission.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: d74c9b29ec53aec8570f793c8bf34d60d3d9c8cbf269654f662d2d99e5f6d29d

## DC0501

PDF physical 119; printed 110, 111 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยโรคไตเรื้อรัง (CKD) ระยะที่ 3-4 สัญชาติไทยที่มารับบริการที่แผนกผู้ป่วย นอกของโรงพยาบาล และได้รับการตรวจ Serum creatinine โดยมีผล eGFR เกินกว่า 2 ค่า ในช่วงเวลาที่ต่างกันของปีที่เก็บข้อมูล, และ มีค่าเฉลี่ยการเปลี่ยนแปลง ลดลง <4 ml/min/1.73 m2/Yr

ตัวหาร / population: b = จำนวนผู้ป่วยโรคไตเรื้อรัง (CKD) ระยะที่ 3-4 สัญชาติไทยที่มารับบริการที่แผนกผู้ป่วย นอกของโรงพยาบาล และได้รับการตรวจ Serum Creatinine โดยมีผล eGFR เกินกว่า 2 ค่า ในช่วงเวลาที่ต่างกันของปีที่เก็บข้อมูล

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: lab_order.lab_order_number, lab_head.lab_order_number, lab_items.lab_items_code, lab_order.lab_items_code. Date candidates: clinicmember.dchdate, clinicmember.last_bp_date, clinicmember.last_hba1c_date, clinicmember.regdate, lab_head.order_date.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT clinicmember_id) FILTER (WHERE egfr.first_val - egfr.last_val < 4)
-- denominator (count)
COUNT(DISTINCT clinicmember_id)
-- outer FROM / source
chronic_periodized
      LEFT JOIN LATERAL (
      SELECT
        COUNT(CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END) AS n,
        (array_agg(CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END ORDER BY lh.order_date))[1] AS first_val,
        (array_agg(CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END ORDER BY lh.order_date DESC))[1] AS last_val
      FROM lab_head lh
      JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
      JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
      WHERE lh.hn = chronic_periodized.hn
        AND (li.lab_items_name ILIKE '%egfr%' OR li.lab_items_name ILIKE '%gfr%')
        AND lh.order_date >= chronic_periodized.regdate - INTERVAL '12 months'
        AND lh.order_date <= chronic_periodized.regdate
    ) egfr ON TRUE
-- outer cohort predicate
EXISTS (
      SELECT 1
      FROM clinic_ckd_member ck
      WHERE ck.clinicmember_id = chronic_periodized.clinicmember_id
    )
    AND egfr.n >= 2
    AND egfr.first_val IS NOT NULL
    AND egfr.last_val IS NOT NULL
    AND egfr.first_val >= 15
    AND egfr.first_val < 60
```

- Measures CKD registry members (clinic_ckd_member) with at least two numeric eGFR lab results in the trailing 12 months and baseline eGFR between 15 and 59 (stages 3-4) whose first-to-last decline is below 4. The PDF wants the mean annual change in ml per min per 1.73 m2 below 4; the branch approximates the annual slope with first minus last over a 12-month window, so the owner must confirm the eGFR item set, the stage boundary values and the slope convention.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: clinic_ckd_member, clinicmember, lab_head, lab_items, lab_order. SQL SHA256: 0a6a24099712f5c35a6da0abfce5642d4e76551187ecebd59bdebc7b10623691

## DC0502

PDF physical 121; printed 112, 113 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยโรคไตเรื้อรัง (CKD) ระยะที่ 1-4 สัญชาติไทย ที่มารับบริการที่แผนกผู้ป่วย นอกของโรงพยาบาล และได้รับการตรวจ Serum creatinine โดยมีค่า eGFR ≥15 ml/min/1.73 m2/Yr, และ ได้รับการรักษาด้วยยา ACEi หรือ ARB

ตัวหาร / population: b = จำนวนผู้ป่วยโรคไตเรื้อรัง (CKD) ระยะที่ 1-4 สัญชาติไทย ที่มารับบริการที่แผนก ผู้ป่วยนอกของโรงพยาบาล และได้รับการตรวจ Serum creatinine โดยมีค่า eGFR ≥15 ml/min/1.73 m2/Yr

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: lab_order.lab_order_number, lab_head.lab_order_number, lab_items.lab_items_code, lab_order.lab_items_code, drugitems.icode, opitemrece.icode. Date candidates: clinicmember.dchdate, clinicmember.last_bp_date, clinicmember.last_hba1c_date, clinicmember.regdate, lab_head.order_date, opitemrece.vstdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT clinicmember_id) FILTER (WHERE ace_arb.flagged)
-- denominator (count)
COUNT(DISTINCT clinicmember_id)
-- outer FROM / source
chronic_periodized
      LEFT JOIN LATERAL (
      SELECT
        COUNT(CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END) AS n,
        (array_agg(CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END ORDER BY lh.order_date))[1] AS first_val,
        (array_agg(CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END ORDER BY lh.order_date DESC))[1] AS last_val
      FROM lab_head lh
      JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
      JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
      WHERE lh.hn = chronic_periodized.hn
        AND (li.lab_items_name ILIKE '%egfr%' OR li.lab_items_name ILIKE '%gfr%')
        AND lh.order_date >= chronic_periodized.regdate - INTERVAL '6 months'
        AND lh.order_date <= chronic_periodized.regdate
    ) egfr ON TRUE
    LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.hn = chronic_periodized.hn
          AND (di.name ILIKE '%enalapril%' OR di.name ILIKE '%captopril%' OR di.name ILIKE '%lisinopril%' OR di.name ILIKE '%ramipril%' OR di.name ILIKE '%perindopril%' OR di.name ILIKE '%fosinopril%' OR di.name ILIKE '%benazepril%' OR di.name ILIKE '%imidapril%' OR di.name ILIKE '%losartan%' OR di.name ILIKE '%valsartan%' OR di.name ILIKE '%candesartan%' OR di.name ILIKE '%irbesartan%' OR di.name ILIKE '%telmisartan%' OR di.name ILIKE '%olmesartan%')
          AND oi.vstdate >= chronic_periodized.regdate - INTERVAL '6 months'
          AND oi.vstdate <= chronic_periodized.regdate
      ) AS flagged
    ) ace_arb ON TRUE
-- outer cohort predicate
EXISTS (
      SELECT 1
      FROM clinic_ckd_member ck
      WHERE ck.clinicmember_id = chronic_periodized.clinicmember_id
    )
    AND egfr.n >= 1
    AND egfr.last_val IS NOT NULL
    AND egfr.last_val >= 15
```

- Measures CKD registry members with a last eGFR of at least 15 (stages 1-4) in the trailing 6 months who collected an ACE inhibitor or ARB (drugitems name set) in the same window. The PDF wants current use of ACEi or ARB among CKD stages 1-4; the owner must confirm the antihypertensive name list against the local formulary and the eGFR item set.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: clinic_ckd_member, clinicmember, drugitems, lab_head, lab_items, lab_order, opitemrece. SQL SHA256: c4963cfb831bea924aab62e705407dd03ccb02792047fbe606866026e3ddf882

## DE0101

PDF physical 139; printed 130 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: A= จำนวนวัน รอตรวจกับศัลยแพทย์เต้านมรวม ของผู้ป่วย BI-RADS 4 ขึ้นไปทั้งหมด (หน่วย = วัน)

ตัวหาร / population: B= จำนวนผู้ป่วย BI-RADS 4 ขึ้นไปทั้งหมด (หน่วย = ราย)

Grain: visit/event at ovst VN (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: จำนวนวัน; formula: a/b. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (sum)
SUM((
          SELECT MIN(pcr.patient_cancer_first_meet_doctor_date - bc.screen_date)
          FROM person pp
          JOIN person_bc_screen bc ON bc.person_id = pp.person_id
          JOIN patient_cancer_registeration pcr ON pcr.hn = pp.patient_hn
          WHERE pp.patient_hn = opd_periodized.hn
            AND bc.screen_date = opd_periodized.event_date
            AND COALESCE(bc.mamogram_birads_result_integer, 0) >= 4
            AND pcr.patient_cancer_first_meet_doctor_date IS NOT NULL
            AND pcr.patient_cancer_first_meet_doctor_date >= bc.screen_date
        ))
-- denominator (count)
COUNT(*)
-- outer FROM / source
opd_periodized
-- outer cohort predicate
(
          SELECT MIN(pcr.patient_cancer_first_meet_doctor_date - bc.screen_date)
          FROM person pp
          JOIN person_bc_screen bc ON bc.person_id = pp.person_id
          JOIN patient_cancer_registeration pcr ON pcr.hn = pp.patient_hn
          WHERE pp.patient_hn = opd_periodized.hn
            AND bc.screen_date = opd_periodized.event_date
            AND COALESCE(bc.mamogram_birads_result_integer, 0) >= 4
            AND pcr.patient_cancer_first_meet_doctor_date IS NOT NULL
            AND pcr.patient_cancer_first_meet_doctor_date >= bc.screen_date
        ) IS NOT NULL
```

- Measures mean waiting days from a BI-RADS 4 or higher mammogram (person_bc_screen.screen_date with mamogram_birads_result_integer at least 4) to the first doctor consultation date on patient_cancer_registeration, computed over screening visits whose consultation completed. The printed clock runs from the radiologist report time to the breast surgeon appointment and also counts BI-RADS 4 or higher patients whose biopsy was benign and who never reach a cancer registration. Confirm the BI-RADS integer coding, that patient_cancer_first_meet_doctor_date is the breast surgeon consultation, and where mammogram report timestamps live.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: er_regist, ovst, ovstdiag, patient, patient_cancer_registeration, person, person_bc_screen. SQL SHA256: c6159947eb35338f25c7ad75e63c5117169c3e6e348d56e7b6a5fe7c92905756

## DE0103

PDF physical 140; printed 131 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยรายใหม่ได้รับการวินิจฉัยในสถานพยาบาลนั้นว่าเป็นมะเร็งเต้านมระยะที่ 1 หรือ ระยะที่ 2 ในรอบปี

ตัวหาร / population: B = จำนวนผู้ป่วยมะเร็งเต้านมรายใหม่ที่ได้รับวินิจฉัยในสถาบันนั้นทั้งหมดในรอบปี

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: รอตรวจ SQL. Date candidates: clinicmember.dchdate, clinicmember.last_bp_date, clinicmember.last_hba1c_date, clinicmember.regdate.

Unit: ร้อยละ; formula: (a/b) ข 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM patient_cancer_registeration pcr
          WHERE pcr.clinicmember_id = chronic_periodized.clinicmember_id
            AND COALESCE(pcr.m_value, 0) = 0
            AND COALESCE(pcr.n_value, 99) <= 1
            AND COALESCE(pcr.t_value, 99) <= 2
        ))
-- denominator (count)
COUNT(*)
-- outer FROM / source
chronic_periodized
-- outer cohort predicate
EXISTS (
          SELECT 1
          FROM clinicmember_cancer cc
          WHERE cc.clinicmember_id = chronic_periodized.clinicmember_id
            AND LEFT(REPLACE(UPPER(TRIM(COALESCE(cc.f53_topography, ''))), '.', ''), 3) = 'C50'
        )
```

- Measures percent of new breast cancer clinic registrations (clinicmember regdate inside the year with clinicmember_cancer.f53_topography starting C50) whose patient_cancer_registeration TNM values give an early stage reading (t_value at most 2, n_value at most 1, m_value 0 or null). The printed stage groups 1 and 2 per AJCC are broader (for example T3 N0 stage 2B) and the registry may encode the group directly in cancer_stage2_id or f53_cm_stage_code instead of TNM numbers. Confirm the TNM column coding and which field carries the final stage group at diagnosis.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: clinicmember, clinicmember_cancer, patient_cancer_registeration. SQL SHA256: 7cf6baf997b748c493fdc03438c60ef34c6e58e2ec98880cbabd2774db4c57b1

## DE0501

PDF physical 141; printed 132 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยที่เข้ารับการรักษาด้วยการปลูกถ่ายไขกระดูกที่มีผลของการปลูกถ่ายติด (engraftment) ภายใน 45 วัน

ตัวหาร / population: b = จำนวนผู้ป่วยที่เข้ารับการรักษาด้วยการปลูกถ่ายไขกระดูกทั้งหมด

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) ข 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM operation_list ol
          JOIN operation_detail od ON od.operation_id = ol.operation_id
          LEFT JOIN operation_item oi ON oi.operation_item_id = od.operation_item_id
          WHERE ol.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(COALESCE(od.icdcode, oi.icd9, ''))), '.', ''), 3) = '410'
            AND EXISTS (
              SELECT 1
              FROM lab_head lh
              JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
              JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
              WHERE lh.hn = ol.hn
                AND li.lab_items_name ILIKE '%neutrophil%'
                AND lh.order_date IS NOT NULL
                AND ol.operation_date IS NOT NULL
                AND lh.order_date >= ol.operation_date
                AND lh.order_date <= ol.operation_date + INTERVAL '45 days'
                AND REPLACE(COALESCE(lo.lab_order_result, ''), ',', '') ~ '^[0-9]+(\.[0-9]+)?$'
                AND REPLACE(COALESCE(lo.lab_order_result, ''), ',', '')::numeric >= 500
            )
        ))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
EXISTS (
          SELECT 1
          FROM operation_list ol
          JOIN operation_detail od ON od.operation_id = ol.operation_id
          LEFT JOIN operation_item oi ON oi.operation_item_id = od.operation_item_id
          WHERE ol.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(COALESCE(od.icdcode, oi.icd9, ''))), '.', ''), 3) = '410'
        )
```

- Measures percent of stem cell or bone marrow transplant admissions (operation_detail.icdcode ICD-9 41.0x) showing an engraftment proxy within 45 days of the operation: a neutrophil lab item (name matching neutrophil) with numeric result at least 500. The printed definition needs true engraftment (ANC at least 500 for 3 consecutive days) and graft failure counting from a transplant registry that HOSxP lacks. Confirm the local lab item names for absolute neutrophil count, the value unit, and the procedure codes booked for transplants.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, lab_head, lab_items, lab_order, operation_detail, operation_item, operation_list. SQL SHA256: bedfb3e75c22f8dfcb59be26ab640883ba426e892eaf4005fd367808d0ac8032

## DE0801

PDF physical 142; printed 133 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย TDT ที่อายุมากกว่า 2 ปี และถึง 15 ปี มีภาวะธาตุเหล็กเกินได้รับยาขับ ธาตุเหล็ก

ตัวหาร / population: b = จำนวนผู้ป่วย TDT ที่อายุมากกว่า 2 ปี และถึง 15 ปี มีภาวะธาตุเหล็กเกินทั้งหมด ในช่วงระยะเวลาเดียวกัน

Grain: distinct HN within reporting window (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: ร้อยละ; formula: (a/b) ข 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ovst v2
          JOIN opitemrece oi ON oi.vn = v2.vn
          JOIN drugitems di ON di.icode = oi.icode
          WHERE v2.hn = opd_periodized.hn
            AND v2.vstdate >= opd_periodized.period_start
            AND v2.vstdate < opd_periodized.period_start + INTERVAL '1 month'
            AND (
              di.name ILIKE '%deferasirox%'
              OR di.name ILIKE '%deferoxamine%'
              OR di.name ILIKE '%deferiprone%'
            )
        ))
-- denominator (count)
COUNT(DISTINCT opd_periodized.hn)
-- outer FROM / source
opd_periodized
-- outer cohort predicate
age_y > 2 AND age_y <= 15 AND (LEFT(pdx, 3) = 'D56' OR EXISTS (
          SELECT 1
          FROM ovstdiag sd
          WHERE sd.vn = opd_periodized.vn
            AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'D56'
        )) AND EXISTS (
          SELECT 1
          FROM lab_head lh
          JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = opd_periodized.hn
            AND lh.order_date >= opd_periodized.period_start
            AND lh.order_date < opd_periodized.period_start + INTERVAL '1 month'
            AND li.lab_items_name ILIKE '%ferritin%'
            AND REPLACE(COALESCE(lo.lab_order_result, ''), ',', '') ~ '^[0-9]+(\.[0-9]+)?$'
            AND REPLACE(COALESCE(lo.lab_order_result, ''), ',', '')::numeric > 1000
        )
```

- Measures percent of thalassemia patients older than 2 and up to 15 years with serum ferritin over 1000 in the month (lab item name matching ferritin with a numeric result) who received an iron chelator (deferasirox, deferoxamine or deferiprone in drugitems.name) within the same month, counted once per patient per month. The printed definition requires confirmed transfusion dependent thalassemia rather than any D56 code and an exact serum ferritin unit rule. Confirm the TDT cohort marking (clinic or registry) and the local chelator drug names.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: drugitems, er_regist, lab_head, lab_items, lab_order, opitemrece, ovst, ovstdiag, patient. SQL SHA256: d09d16d67fc8c0fe4980c7f7bf361b765c7a605996d82a0c578664493a1bf495

## DE1201

PDF physical 143; printed 134 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย Cleft lip ที่เข้ารับการผ่าตัดช่วงอายุไม่เกิน 6 เดือน

ตัวหาร / population: b = จำนวนผู้ป่วย Cleft lip ที่เข้ารับการผ่าตัดทั้งหมดในช่วงเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b)x100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT periodized.hn) FILTER (WHERE EXISTS (
          SELECT 1
          FROM operation_list ol
          JOIN operation_detail od ON od.operation_id = ol.operation_id
          LEFT JOIN operation_item oi ON oi.operation_item_id = od.operation_item_id
          JOIN patient pd ON pd.hn = ol.hn
          WHERE ol.an = periodized.an
            AND ((LEFT(REPLACE(UPPER(TRIM(COALESCE(od.icdcode, oi.icd9, ''))), '.', ''), 3) = '304') OR (oi.name ILIKE '%cleft lip%' OR oi.name ILIKE '%ปากแหว่ง%'))
            AND ol.operation_date IS NOT NULL
            AND pd.birthday IS NOT NULL
            AND ol.operation_date >= pd.birthday
            AND ol.operation_date <= pd.birthday + INTERVAL '6 months'
        ))
-- denominator (count)
COUNT(DISTINCT periodized.hn)
-- outer FROM / source
periodized
-- outer cohort predicate
(LEFT(pdx, 3) IN ('Q35', 'Q36', 'Q37') OR EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('Q35', 'Q36', 'Q37')
        )) AND EXISTS (
          SELECT 1
          FROM operation_list ol
          JOIN operation_detail od ON od.operation_id = ol.operation_id
          LEFT JOIN operation_item oi ON oi.operation_item_id = od.operation_item_id

          WHERE ol.an = periodized.an
            AND ((LEFT(REPLACE(UPPER(TRIM(COALESCE(od.icdcode, oi.icd9, ''))), '.', ''), 3) = '304') OR (oi.name ILIKE '%cleft lip%' OR oi.name ILIKE '%ปากแหว่ง%'))
        )
```

- Measures percent of patients with ICD-10 Q35 to Q37 (pdx or sdx) whose cleft lip repair on operation_list and operation_detail (ICD-9 30.4x or an operation_item name matching cleft lip or the Thai term) happened at age 6 months or younger (operation_date versus patient.birthday), counted once per patient per quarter. The printed cohort also includes pre surgical alveolar moulding cases and referred in children born outside the district. Confirm the local procedure item names and icdcode values for cleft repair and how referred in cases are booked.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, operation_detail, operation_item, operation_list, patient. SQL SHA256: 5551c9ce179048dab3d32dab2219b7c8b7aa14b3d325eab63b890fbf19c3e311

## DE1202

PDF physical 144; printed 135 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย Cleft palate ที่เข้ารับการผ่าตัดเพดานโหว่ภายในช่วงอายุไม่เกิน 18 เดือน

ตัวหาร / population: b = จำนวนผู้ป่วย Cleft palate ที่เข้ารับการผ่าตัดทั้งหมดในช่วงเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b)x100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT periodized.hn) FILTER (WHERE EXISTS (
          SELECT 1
          FROM operation_list ol
          JOIN operation_detail od ON od.operation_id = ol.operation_id
          LEFT JOIN operation_item oi ON oi.operation_item_id = od.operation_item_id
          JOIN patient pd ON pd.hn = ol.hn
          WHERE ol.an = periodized.an
            AND ((REPLACE(UPPER(TRIM(COALESCE(od.icdcode, oi.icd9, ''))), '.', '') IN ('2754')) OR (oi.name ILIKE '%cleft palate%' OR oi.name ILIKE '%เพดานโหว่%'))
            AND ol.operation_date IS NOT NULL
            AND pd.birthday IS NOT NULL
            AND ol.operation_date >= pd.birthday
            AND ol.operation_date <= pd.birthday + INTERVAL '18 months'
        ))
-- denominator (count)
COUNT(DISTINCT periodized.hn)
-- outer FROM / source
periodized
-- outer cohort predicate
(LEFT(pdx, 3) IN ('Q35', 'Q36', 'Q37') OR EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('Q35', 'Q36', 'Q37')
        )) AND EXISTS (
          SELECT 1
          FROM operation_list ol
          JOIN operation_detail od ON od.operation_id = ol.operation_id
          LEFT JOIN operation_item oi ON oi.operation_item_id = od.operation_item_id

          WHERE ol.an = periodized.an
            AND ((REPLACE(UPPER(TRIM(COALESCE(od.icdcode, oi.icd9, ''))), '.', '') IN ('2754')) OR (oi.name ILIKE '%cleft palate%' OR oi.name ILIKE '%เพดานโหว่%'))
        )
```

- Measures percent of patients with ICD-10 Q35 to Q37 (pdx or sdx) whose cleft palate repair on operation_list and operation_detail (ICD-9 2754 or an operation_item name matching cleft palate or the Thai term) happened at age 18 months or younger, counted once per patient per quarter. The printed cohort counts complete and incomplete unilateral and bilateral cleft lip palate and excludes late presenters only from review, not from the denominator. Confirm the local procedure item names and icdcode values for palatoplasty.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, operation_detail, operation_item, operation_list, patient. SQL SHA256: c755c790ea5a26b727598b5442bb219f5bd5ca7ec1568bf369861285c28d06b6

## DE1301

PDF physical 145; printed 136 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนสตรีผู้รับบริการที่ได้รับการยืนยันการตั้งครรภ์ (กลุ่มอายุน้อยกว่า 34 ปี) ที่มี การเต้นของหัวใจทารก จากการตรวจด้วยเครื่องความถี่สูง จากการใส่ตัวอ่อนรอบสด ในช่วงระยะเวลาหนึ่งปี

ตัวหาร / population: b = จำนวนครั้งของการใส่ตัวอ่อนของผู้รับบริการทำเด็กหลอดแก้วและย้ายตัวอ่อน รอบสดทั้งหมด (กลุ่มอายุน้อยกว่า 34 ปี) ในช่วงเวลาเดียวกัน

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) ข 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'DE1301'
```

- External branch: fresh embryo transfer cycles and clinical pregnancy confirmations live in the IVF clinic system, not HOSxP (no embryo, fertilisation or transfer tables exist). Staging requirement: one reporting.thip_external_facts row per fiscal year anchor (period_start equal to the first day of October of the fiscal year) with indicator_code DE1301, numerator equal to women under 34 years with clinical pregnancy (fetal heartbeat at 6 to 8 weeks) after a fresh embryo transfer, denominator equal to fresh embryo transfer cycles in the same age band, value equal to numerator times 100 over denominator, and source_system naming the IVF system. Confirm the age cut off (strictly under 34) and that one denominator row means one transfer cycle.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 9192ed2dc61529a0cf8f446b7fb9ae812c20fca6cdb22596357b835a1e1d2f8c

## DE1302

PDF physical 146; printed 137 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนสตรีผู้รับบริการที่ได้รับการยืนยันการตั้งครรภ์ (กลุ่มอายุ 34 - 39 ปี) ที่มีการ เต้นของหัวใจทารก จากการตรวจด้วยเครื่องความถี่สูง จากการใส่ตัวอ่อนรอบสด ในช่วง ระยะเวลาหนึ่งปี

ตัวหาร / population: b = จำนวนครั้งของการใส่ตัวอ่อนของผู้รับบริการทำเด็กหลอดแก้วและย้ายตัวอ่อนรอบสด ทั้งหมด (กลุ่มอายุ 34-39 ปี) ในช่วงเวลาเดียวกัน

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) ข 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'DE1302'
```

- External branch: IVF or ICSI fresh embryo transfer cycles for the 34 to 39 year band are not in HOSxP. Staging requirement: one reporting.thip_external_facts row per fiscal year anchor (period_start equal to the first day of October of the fiscal year) with indicator_code DE1302, numerator equal to women aged 34 to 39 with clinical pregnancy after a fresh embryo transfer, denominator equal to fresh transfer cycles in the same band, value equal to numerator times 100 over denominator, and source_system naming the IVF system. Confirm the age band boundaries and the clinical pregnancy (fetal heartbeat) rule.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: e9347f1f1482adedcd164edda0334bcaa3f58333bc0d0c88d83fa683d4a11c31

## DE1303

PDF physical 147; printed 138 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนสตรีผู้รับบริการที่ได้รับการยืนยันการตั้งครรภ์ (กลุ่มอายุ 40 ปีขึ้นไป) ที่มีการ เต้นของหัวใจทารก จากการตรวจด้วยเครื่องความถี่สูง จากการใส่ตัวอ่อนรอบสด ในช่วง ระยะเวลาหนึ่งปี

ตัวหาร / population: b = จำนวนครั้งของการใส่ตัวอ่อนของผู้รับบริการทำเด็กหลอดแก้วและย้ายตัวอ่อนรอบสด ทั้งหมด (กลุ่มอายุ 40 ปีขึ้นไป) ในช่วงเวลาเดียวกัน

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) ข 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'DE1303'
```

- External branch: IVF or ICSI fresh embryo transfer cycles for the 40 years and older band are not in HOSxP. Staging requirement: one reporting.thip_external_facts row per fiscal year anchor (period_start equal to the first day of October of the fiscal year) with indicator_code DE1303, numerator equal to women aged 40 or more with clinical pregnancy after a fresh embryo transfer, denominator equal to fresh transfer cycles in the same band, value equal to numerator times 100 over denominator, and source_system naming the IVF system. Confirm the age rule (age at oocyte retrieval versus transfer) with the IVF team.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: eef4eb30575b708bdbfea92c3f061c5b6b8dafa8d7e802a471b5c6dc882347a7

## DE1304

PDF physical 148; printed 139 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนสตรีผู้รับบริการที่ได้รับการยืนยันการตั้งครรภ์ (กลุ่มอายุน้อยกว่า 34 ปี) ที่มี การเต้นของหัวใจทารก จากการตรวจด้วยเครื่องความถี่สูง จากการใส่ตัวอ่อนรอบแช่แข็ง ในช่วงระยะเวลาหนึ่งปี

ตัวหาร / population: b = จำนวนครั้งของการใส่ตัวอ่อนของผู้รับบริการทำเด็กหลอดแก้วและย้ายตัวอ่อน รอบแช่แข็งทั้งหมด (กลุ่มอายุน้อยกว่า 34 ปี) ในช่วงเวลาเดียวกัน

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) ข 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'DE1304'
```

- External branch: frozen thawed embryo transfer cycles (age under 34) are not in HOSxP. Staging requirement: one reporting.thip_external_facts row per fiscal year anchor (period_start equal to the first day of October of the fiscal year) with indicator_code DE1304, numerator equal to women under 34 with clinical pregnancy after a frozen embryo transfer, denominator equal to frozen transfer cycles in the same band, value equal to numerator times 100 over denominator, and source_system naming the IVF system. Confirm that thawed and cultured after thaw transfers both count as frozen cycles.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 954a5db474deefa75d54f3d6359c37ef276a803084d82304231c913111e98f3f

## DE1305

PDF physical 149; printed 140 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนสตรีผู้รับบริการที่ได้รับการยืนยันการตั้งครรภ์ (กลุ่มอายุ 34 - 39 ปี) ที่มีการ เต้นของหัวใจทารก จากการตรวจด้วยเครื่องความถี่สูง จากการใส่ตัวอ่อนรอบแช่แข็งในช่วง ระยะเวลาหนึ่งปี

ตัวหาร / population: b = จำนวนครั้งของการใส่ตัวอ่อนของผู้รับบริการทำเด็กหลอดแก้วและย้ายตัวอ่อน รอบแช่แข็งทั้งหมด (กลุ่มอายุ 34 - 39 ปี) ในช่วงเวลาเดียวกัน

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) ข 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'DE1305'
```

- External branch: frozen thawed embryo transfer cycles (age 34 to 39) are not in HOSxP. Staging requirement: one reporting.thip_external_facts row per fiscal year anchor (period_start equal to the first day of October of the fiscal year) with indicator_code DE1305, numerator equal to women aged 34 to 39 with clinical pregnancy after a frozen embryo transfer, denominator equal to frozen transfer cycles in the same band, value equal to numerator times 100 over denominator, and source_system naming the IVF system. Confirm the age band boundaries and the pregnancy confirmation window.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: f4f08e862056f4c7634c1d423a0635212e8d725941e951e9b44ca044dcfd3e0c

## DE1306

PDF physical 150; printed 141 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนสตรีผู้รับบริการที่ได้รับการยืนยันการตั้งครรภ์ (กลุ่มอายุ 40 ปีขึ้นไป) ที่มีการ เต้นของหัวใจทารก จากการตรวจด้วยเครื่องความถี่สูง จากการใส่ตัวอ่อนรอบแช่แข็งในช่วง ระยะเวลาหนึ่งปี

ตัวหาร / population: b = จำนวนครั้งของการใส่ตัวอ่อนของผู้รับบริการทำเด็กหลอดแก้วและย้ายตัวอ่อน รอบแช่แข็งทั้งหมด (กลุ่มอายุ 40 ปีขึ้นไป) ในช่วงเวลาเดียวกัน

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) ข 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'DE1306'
```

- External branch: frozen thawed embryo transfer cycles (age 40 and over) are not in HOSxP. Staging requirement: one reporting.thip_external_facts row per fiscal year anchor (period_start equal to the first day of October of the fiscal year) with indicator_code DE1306, numerator equal to women aged 40 or more with clinical pregnancy after a frozen embryo transfer, denominator equal to frozen transfer cycles in the same band, value equal to numerator times 100 over denominator, and source_system naming the IVF system. Confirm the age rule and that cancelled or thaw failed cycles are excluded from the denominator.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 5c9189eb401040bcbdd772f4151450f8194b968f5e7d3edc098bd9008cc46b27

## DE1401

PDF physical 151; printed 142 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยUGIH ได้รับการส่องกล้องทางเดินอาหารส่วนต้นภายใน 24 ชั่วโมงในช่วง1 เดือน

ตัวหาร / population: b = จำนวนผู้ป่วย UGIH ทั้งหมด ในช่วงเวลาเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
            AND (o.opdate::timestamp + COALESCE(o.optime, TIME '00:00:00')) >= (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00'))
            AND (o.opdate::timestamp + COALESCE(o.optime, TIME '00:00:00')) <= (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00')) + INTERVAL '24 hours'))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND pdx IN ('K250', 'K251', 'K252', 'K254', 'K255', 'K256', 'K260', 'K261', 'K262', 'K264', 'K265', 'K266', 'K270', 'K271', 'K272', 'K274', 'K275', 'K276', 'K280', 'K281', 'K282', 'K284', 'K285', 'K286', 'K290', 'K920', 'K921', 'K922')
```

- Counts UGIH admissions (Pdx K250 to K286, K290, K920, K921, K922 families) with an upper endoscopy (iptoprt icd9 4513 to 4516) performed within 24 hours of the admit timestamp (opdate and optime). The PDF times from admission or symptom onset to esophagogastroduodenoscopy; the local EGD icd9 coding and whether optime is maintained need owner confirmation.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, iptoprt. SQL SHA256: f9ff40abe6f01ca7c739025d48d92a3332d93e440a08d46e31c655ced1dc7467

## DE1402

PDF physical 152; printed 143, 144 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย UGIH กลุ่ม high risk ได้รับการส่องกล้องทางเดินอาหารส่วนต้น ภายใน 24 ชั่วโมง ในช่วง 1 เดือน

ตัวหาร / population: b = จำนวนผู้ป่วย UGIH กลุ่ม high risk ที่จำหน่ายออกจากโรงพยาบาลทั้งหมด ในช่วงเวลาเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
            AND (o.opdate::timestamp + COALESCE(o.optime, TIME '00:00:00')) >= (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00'))
            AND (o.opdate::timestamp + COALESCE(o.optime, TIME '00:00:00')) <= (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00')) + INTERVAL '24 hours'))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND pdx IN ('K250', 'K251', 'K252', 'K254', 'K255', 'K256', 'K260', 'K261', 'K262', 'K264', 'K265', 'K266', 'K270', 'K271', 'K272', 'K274', 'K275', 'K276', 'K280', 'K281', 'K282', 'K284', 'K285', 'K286', 'K290', 'K920', 'K921', 'K922') AND (
          age_y >= 60
          OR EXISTS (
            SELECT 1
            FROM iptdiag sd
            WHERE sd.an = periodized.an
              AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('N18', 'K74', 'I50', 'I25', 'J43', 'J44')
          )
          OR EXISTS (
            SELECT 1
            FROM lab_order lo
            JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
            JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
            WHERE lh.hn = periodized.hn
              AND lh.order_date >= periodized.regdate
              AND lh.order_date <= periodized.dchdate
              AND (
                li.lab_items_name ILIKE '%hemoglobin%'
                OR li.lab_items_name ILIKE '%hb%'
              )
              AND li.lab_items_name NOT ILIKE '%hba1c%'
              AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END <= 8
          )
        ) AND NOT died
```

- High risk UGIH branch: same cohort plus a high risk flag (age 60 or over, or comorbidity secondary diagnosis N18, K74, I50, I25, J43, J44, or a hemoglobin lab result of 8 or lower from lab_order, lab_head and lab_items with a safe numeric cast of lab_order_result), denominator restricted to live discharges, numerator with EGD within 24 hours as in DE1401. The PDF high risk list also includes fresh blood from a nasogastric tube, shock signs and a 2 g per dl hemoglobin drop, which are not structured, and the hemoglobin threshold assumes the site stores grams per dl. Owner must confirm the high risk definition mapping and the lab unit.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, iptoprt, lab_head, lab_items, lab_order. SQL SHA256: d36ae84f83857c1f078064b776d236779566e17110f4f752892b77854cbcce50

## DE1403

PDF physical 154; printed 145, 146 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยที่มีแผลในระบบทางเดินอาหารส่วนต้น (Non-variceal UGIH) ที่ สามารถหยุดเลือดด้วยวิธีการส่องกล้องสำเร็จ ในช่วง 1 เดือน

ตัวหาร / population: b = จำนวนผู้ป่วยที่มีแผลในระบบทางเดินอาหารส่วนต้น (Non-variceal UGIH) ที่ได้รับ การหยุดเลือดด้วยวิธีการส่องกล้อง ในช่วงเวลาเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE (
          EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516'))
          AND (
            EXISTS (
              SELECT 1
              FROM iptoprt o2
              WHERE o2.an = periodized.an
                AND REPLACE(UPPER(TRIM(o2.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
                AND (
                  o2.oper_note_text ILIKE '%hemoclip%'
                  OR o2.oper_note_text ILIKE '%clip%'
                  OR o2.oper_note_text ILIKE '%heater%'
                  OR o2.oper_note_text ILIKE '%probe%'
                  OR o2.oper_note_text ILIKE '%argon%'
                  OR o2.oper_note_text ILIKE '%band%'
                  OR o2.oper_note_text ILIKE '%histoacryl%'
                )
            )
            OR EXISTS (
              SELECT 1
              FROM opitemrece oi
              JOIN drugitems di ON di.icode = oi.icode
              WHERE oi.an = periodized.an
                AND (
                  di.name ILIKE '%adrenaline%'
                  OR di.name ILIKE '%epinephrine%'
                  OR di.name ILIKE '%histoacryl%'
                  OR di.name ILIKE '%thrombin%'
                )
            )
          )
        ) AND NOT (
          EXISTS (
            SELECT 1
            FROM iptoprt o3
            WHERE o3.an = periodized.an
              AND REPLACE(UPPER(TRIM(o3.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
              AND o3.opdate >= periodized.regdate + INTERVAL '2 days'
          )
          OR EXISTS (
            SELECT 1
            FROM opitemrece oi
            JOIN drugitems di ON di.icode = oi.icode
            WHERE oi.an = periodized.an
              AND oi.rxdate > periodized.regdate
              AND (di.name ILIKE '%packed red%' OR di.name ILIKE '%red cell%' OR di.name ILIKE '%prbc%')
          )
        ))
-- denominator (count)
COUNT(*) FILTER (WHERE (
          EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516'))
          AND (
            EXISTS (
              SELECT 1
              FROM iptoprt o2
              WHERE o2.an = periodized.an
                AND REPLACE(UPPER(TRIM(o2.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
                AND (
                  o2.oper_note_text ILIKE '%hemoclip%'
                  OR o2.oper_note_text ILIKE '%clip%'
                  OR o2.oper_note_text ILIKE '%heater%'
                  OR o2.oper_note_text ILIKE '%probe%'
                  OR o2.oper_note_text ILIKE '%argon%'
                  OR o2.oper_note_text ILIKE '%band%'
                  OR o2.oper_note_text ILIKE '%histoacryl%'
                )
            )
            OR EXISTS (
              SELECT 1
              FROM opitemrece oi
              JOIN drugitems di ON di.icode = oi.icode
              WHERE oi.an = periodized.an
                AND (
                  di.name ILIKE '%adrenaline%'
                  OR di.name ILIKE '%epinephrine%'
                  OR di.name ILIKE '%histoacryl%'
                  OR di.name ILIKE '%thrombin%'
                )
            )
          )
        ))
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND pdx IN ('K250', 'K251', 'K252', 'K254', 'K255', 'K256', 'K260', 'K261', 'K262', 'K264', 'K265', 'K266', 'K270', 'K271', 'K272', 'K274', 'K275', 'K276', 'K280', 'K281', 'K282', 'K284', 'K285', 'K286', 'K290')
```

- Non-variceal UGIH (Pdx K250 to K286 and K290 families) with endoscopic hemostasis (EGD plus a hemostasis adjunct: hemoclip, heater probe, bipolar or argon coagulation, band ligation or histoacryl evidenced by iptoprt oper_note_text, or an adrenaline, epinephrine, histoacryl or thrombin item in opitemrece) as the denominator; numerator excludes cases with early rebleeding evidence (repeat upper endoscopy from admission day 2 onward or a red cell transfusion after admission). The PDF success judgement comes from the endoscopy report (Forrest class, visible vessel, successful hemostasis), which HOSxP does not store. Owner must confirm how hemostasis modalities are charted or load the endoscopy registry aggregates into reporting.thip_external_facts.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, drugitems, ipt, iptdiag, iptoprt, opitemrece. SQL SHA256: 4ce78c0d9ab8bf88c9c515b1818338d25d02ff1f9b6ba9720659c04c25c170fe

## DE1404

PDF physical 156; printed 147, 148 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยที่เกิดภาวะเลือดออกซ้ำจากแผลในระบบทางเดินอาหารส่วนต้นภายหลัง จากการหยุดเลือดด้วยการส่องกล้องสำเร็จ b = จำนวนผู้ป่วยที่มีแผลในระบบทางเดินอาหารส่วนต้นที่ได้รับการหยุดเลือดสำเร็จด้วย

ตัวหาร / population: การส่องกล้อง

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE (
          EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516'))
          AND (
            EXISTS (
              SELECT 1
              FROM iptoprt o2
              WHERE o2.an = periodized.an
                AND REPLACE(UPPER(TRIM(o2.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
                AND (
                  o2.oper_note_text ILIKE '%hemoclip%'
                  OR o2.oper_note_text ILIKE '%clip%'
                  OR o2.oper_note_text ILIKE '%heater%'
                  OR o2.oper_note_text ILIKE '%probe%'
                  OR o2.oper_note_text ILIKE '%argon%'
                  OR o2.oper_note_text ILIKE '%band%'
                  OR o2.oper_note_text ILIKE '%histoacryl%'
                )
            )
            OR EXISTS (
              SELECT 1
              FROM opitemrece oi
              JOIN drugitems di ON di.icode = oi.icode
              WHERE oi.an = periodized.an
                AND (
                  di.name ILIKE '%adrenaline%'
                  OR di.name ILIKE '%epinephrine%'
                  OR di.name ILIKE '%histoacryl%'
                  OR di.name ILIKE '%thrombin%'
                )
            )
          )
        ) AND (
          EXISTS (
            SELECT 1
            FROM iptoprt o3
            WHERE o3.an = periodized.an
              AND REPLACE(UPPER(TRIM(o3.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
              AND o3.opdate >= periodized.regdate + INTERVAL '2 days'
          )
          OR EXISTS (
            SELECT 1
            FROM opitemrece oi
            JOIN drugitems di ON di.icode = oi.icode
            WHERE oi.an = periodized.an
              AND oi.rxdate > periodized.regdate
              AND (di.name ILIKE '%packed red%' OR di.name ILIKE '%red cell%' OR di.name ILIKE '%prbc%')
          )
        ))
-- denominator (count)
COUNT(*) FILTER (WHERE (
          EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516'))
          AND (
            EXISTS (
              SELECT 1
              FROM iptoprt o2
              WHERE o2.an = periodized.an
                AND REPLACE(UPPER(TRIM(o2.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')
                AND (
                  o2.oper_note_text ILIKE '%hemoclip%'
                  OR o2.oper_note_text ILIKE '%clip%'
                  OR o2.oper_note_text ILIKE '%heater%'
                  OR o2.oper_note_text ILIKE '%probe%'
                  OR o2.oper_note_text ILIKE '%argon%'
                  OR o2.oper_note_text ILIKE '%band%'
                  OR o2.oper_note_text ILIKE '%histoacryl%'
                )
            )
            OR EXISTS (
              SELECT 1
              FROM opitemrece oi
              JOIN drugitems di ON di.icode = oi.icode
              WHERE oi.an = periodized.an
                AND (
                  di.name ILIKE '%adrenaline%'
                  OR di.name ILIKE '%epinephrine%'
                  OR di.name ILIKE '%histoacryl%'
                  OR di.name ILIKE '%thrombin%'
                )
            )
          )
        ))
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND pdx IN ('K250', 'K251', 'K252', 'K254', 'K255', 'K256', 'K260', 'K261', 'K262', 'K264', 'K265', 'K266', 'K270', 'K271', 'K272', 'K274', 'K275', 'K276', 'K280', 'K281', 'K282', 'K284', 'K285', 'K286', 'K290')
```

- Rebleeding rate after endoscopic hemostasis: non-variceal UGIH with endoscopic hemostasis (as in DE1403) as the denominator and rebleeding evidence (repeat upper endoscopy from admission day 2 onward or red cell transfusion after admission) as the numerator. The PDF defines rebleeding by hematemesis or melena with shock or a hemoglobin drop after initial hemostasis success; those events are not structured so the proxy may over count (transfusions given for initial resuscitation) or under count (rebleeding managed without repeat endoscopy). Owner must confirm the rebleeding evidence convention.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, drugitems, ipt, iptdiag, iptoprt, opitemrece. SQL SHA256: a2efb2df9a5ad3b98e9cae34c20a9cbc841f4679d562b54d4a767a6f312eec58

## DE1405

PDF physical 158; printed 149 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยที่มีภาวะแทรกซ้อนจากการส่องกล้องทางเดินอาหารส่วนต้นเพื่อรักษา UGIH

ตัวหาร / population: b = จำนวนผู้ป่วย UGIH ทั้งหมดที่ได้รับการส่องกล้องในช่วงเวลาเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')) AND EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('T810', 'T811', 'T812', 'T813', 'T814', 'T815', 'T816', 'T818', 'T819', 'K631', 'J690')
        ))
-- denominator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('4513', '4514', '4515', '4516')))
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND pdx IN ('K250', 'K251', 'K252', 'K254', 'K255', 'K256', 'K260', 'K261', 'K262', 'K264', 'K265', 'K266', 'K270', 'K271', 'K272', 'K274', 'K275', 'K276', 'K280', 'K281', 'K282', 'K284', 'K285', 'K286', 'K290', 'K920', 'K921', 'K922')
```

- Complication rate of upper endoscopy for UGIH: UGIH admissions with an EGD as the denominator and a procedural complication secondary diagnosis (T810 to T819 family, K631 perforation of intestine, or J690 aspiration pneumonitis) during the stay as the numerator. The PDF lists perforation, bleeding, sedation complications and aspiration within the endoscopy episode; HOSxP relies on the coder adding the complication diagnosis. Owner must confirm the complication code list and the observation window.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, iptoprt. SQL SHA256: 5bcf9308fea7b8c92828a9ae38c5f21a52a2b213a6b2f11dd831da9df0747b06

## DE1601

PDF physical 159; printed 150 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนทารกแรกเกิดมีชีพทั้งหมดที่ได้รับการตรวจการได้ยิน ภายใน 30 วัน

ตัวหาร / population: b = จำนวนทารกแรกเกิดมีชีพทั้งหมด (ในปีเดียวกัน)

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) ข 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'DE1601'
```

- External branch: HOSxP has no OAE or AABR newborn hearing screening table (ckup_ear_* holds school audiometry only). Staging requirement: one reporting.thip_external_facts row per fiscal year anchor (period_start equal to the first day of October of the fiscal year) with indicator_code DE1601, numerator equal to live newborns of gestational age 28 weeks or more screened by OAE or AABR within 30 days of birth, denominator equal to all live newborns in that fiscal year, value equal to numerator times 100 over denominator, and source_system naming the hearing screening system. Confirm the screening register, the 30 day window rule and the exclusion of infants transferred out before screening.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 368d9fe8d03520ef958e87a117834477e98e75b149345afb6c98c8c701be08d7

## DG0101

PDF physical 129; printed 120 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย Upper GI hemorrhage ที่ต้องรับกลับเข้าโรงพยาบาลโดยไม่ได้วางแผน ภายใน 28 วัน หลังออกจาก รพ.

ตัวหาร / population: b = จำนวนผู้ป่วย Upper GI hemorrhage ที่จำหน่าย ในเดือนก่อนหน้านั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        ))
-- denominator (count)
COUNT(*) FILTER (WHERE NOT died)
-- outer FROM / source
periodized
-- outer cohort predicate
pdx IN ('K250', 'K251', 'K252', 'K254', 'K255', 'K256', 'K260', 'K261', 'K262', 'K264', 'K265', 'K266', 'K270', 'K271', 'K272', 'K274', 'K275', 'K276', 'K280', 'K281', 'K282', 'K284', 'K285', 'K286', 'K290', 'K920', 'K921', 'K922')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: 816a9b04f8126be3f7cdc03fc5a974c03020143e89ccdf75f631afba12dceab9

## DG0102

PDF physical 130; printed 121 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = ผลรวมระยะเวลาวันนอนของผู้ป่วย Upper GI hemorrhage

ตัวหาร / population: b = จำนวนผู้ป่วย Upper GI Hemorrhage ที่จำหน่าย ในช่วงเวลานั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: วัน; formula: a/b. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (sum)
ROUND(SUM(los)::numeric, 2)
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
pdx IN ('K250', 'K251', 'K252', 'K254', 'K255', 'K256', 'K260', 'K261', 'K262', 'K264', 'K265', 'K266', 'K270', 'K271', 'K272', 'K274', 'K275', 'K276', 'K280', 'K281', 'K282', 'K284', 'K285', 'K286', 'K290', 'K920', 'K921', 'K922')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: cb0c3e753cd0fab044eb3d0c1147667d14dcb78691d71cb3d3491a1c5833adab

## DG0201

PDF physical 131; printed 122 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยโรคไส้ติ่งทะลุ ที่รับไว้รักษาในโรงพยาบาล ในเดือนนั้น

ตัวหาร / population: b = จำนวนผู้ป่วยโรคไส้ติ่งอักเสบเฉียบพลัน ที่รับไว้รักษาในโรงพยาบาลทั้งหมด (ในเดือน เดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE pdx = 'K352')
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
pdx IN ('K35', 'K352', 'K353', 'K358')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: a4ea606002599caa20593399b99fe8191e39b3a405e7330fbfde60ef960dfd47

## DG0202

PDF physical 132; printed 123 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของผู้ป่วยไส้ติ่งอักเสบเฉียบพลัน ที่จำหน่ายด้วยการเสียชีวิต ในเดือนนั้น

ตัวหาร / population: b = จำนวนครั้งของผู้ป่วยไส้ติ่งอักเสบเฉียบพลัน ที่จำหน่ายทุกสถานะ (ในเดือนเดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE died)
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
LEFT(pdx, 3) = 'K35'
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: 4aedc48469e3fbbbe8405a02e9a06a62ed8aa2f08b7c1413e375e375b647df24

## DH0101

PDF physical 48; printed 39 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการจำหน่ายด้วยการเสียชีวิตของผู้ป่วย ACS จากทุกหอผู้ป่วยในเดือนนั้น

ตัวหาร / population: b = จำนวนครั้งของการจำหน่ายทุกสถานะของผู้ป่วย ACS จากทุกหอผู้ป่วยในช่วงเดือน เดียวกันนั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: null; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE (pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') AND died) OR (has_acs_sdx AND died_from_acs))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND (pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') OR has_acs_sdx)
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ตัวตั้งครั้งจำหน่าย ACS ที่ตาย / ตัวหารครั้งจำหน่าย ACS ทุกสถานะ; ต้องยืนยัน I21/secondary ACS และ cause-of-death proxy ไม่ใช่จำนวน HN ทั้งทะเบียน
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: 7bf0a04444e09e155f61a3267036139c6251e7894cad35fb62f5ca47d150e7e4

## DH0101.1

PDF physical 49; printed 40 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการจำหน่ายด้วยการเสียชีวิตของผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ชนิด ST segment ยกขึ้น (STEMI) จากทุกหอผู้ป่วยในเดือนนั้น

ตัวหาร / population: b = จำนวนครั้งของการจำหน่ายทุกสถานะของผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) จากทุกหอผู้ป่วยในช่วงเดือนเดียวกันนั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: null; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE (pdx IN ('I210', 'I211', 'I212', 'I213') AND died) OR (has_stemi_sdx AND died_from_stemi))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND (pdx IN ('I210', 'I211', 'I212', 'I213') OR has_stemi_sdx)
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: 0ce260a7029d448432e9b83a103bbe962f101ec067d9acdbd386eb29a6ae5a8a

## DH0101.2

PDF physical 50; printed 41 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการจำหน่ายด้วยการเสียชีวิตของผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน ชนิด ST segment ไม่ยกขึ้น (NSTE-ACS) จากทุกหอผู้ป่วยในเดือนนั้น

ตัวหาร / population: b = จำนวนครั้งของการจำหน่ายทุกสถานะของผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ไม่ยกขึ้น (NSTE-ACS) จากทุกหอผู้ป่วยในช่วงเดือนเดียวกันนั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: null; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE (pdx IN ('I214', 'I219') AND died) OR (has_nste_sdx AND died_from_nste))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND (pdx IN ('I214', 'I219') OR has_nste_sdx)
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: bc7a4c323088a7627c2941c9a164cc1ac028199e102bd2a27563b597b0ad37f1

## DH0102

PDF physical 51; printed 42 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันที่ได้รับ Aspirin ภายใน 24 ชั่วโมง เมื่อมาถึง โรงพยาบาลในเดือนนั้น

ตัวหาร / population: b = จำนวนผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันที่รับเข้ารักษาในโรงพยาบาล ในเดือน เดียวกันนั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND di.name ILIKE '%aspirin%'
            AND EXTRACT(EPOCH FROM (oi.vstdate::timestamp + COALESCE(oi.vsttime, TIME '00:00:00') - (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00')))) <= 86400))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, drugitems, ipt, iptdiag, opitemrece. SQL SHA256: 67c87fe2bbffae1e9756ce40326e76c1851212d2145f936a39af2c439a3ad0f0

## DH0103

PDF physical 52; printed 43 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) ที่ได้รับการสั่งยา Aspirin เมื่อจำหน่าย ออกจากโรงพยาบาล ในเดือนนั้น

ตัวหาร / population: b = จำนวนผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) ทื่จำหน่ายออกจากโรงพยาบาล โดยนับเฉพาะการจำหน่ายมีชีวิตด้วยสถานะการอนุญาตให้กลับบ้าน ในเดือนเดียวกันนั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%aspirin%' OR di.name ILIKE '%acetylsalicylic%')
            AND oi.rxdate >= periodized.dchdate - INTERVAL '1 day' AND oi.rxdate <= periodized.dchdate))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') AND NOT died
```

- Counts ACS admissions (Pdx I210-I219, age 18 or over) discharged alive whose opitemrece holds an aspirin item on the discharge day or the day before (drugitems.name like aspirin). The PDF asks for aspirin prescribed at discharge with a live home discharge status and an absent contraindication (aspirin allergy, active bleeding); HOSxP does not code the contraindication and dchstts home status is approximated as alive discharge (no death record). Owner must confirm the local aspirin item names and the discharge prescription window.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, drugitems, ipt, iptdiag, opitemrece. SQL SHA256: 49892003e7b5e2ed9d36b3320f92a15e849e4c1777a5650ac85702446fb18b68

## DH0104

PDF physical 53; printed 44, 45 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) ที่มี LVSD และได้รับยาACE inhibitors หรือARB ทั้งหมดในเดือนนั้น

ตัวหาร / population: b = จำนวนผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) ที่มี LVSD ทั้งหมด ในเดือน เดียวกันนั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%enalapril%' OR di.name ILIKE '%captopril%' OR di.name ILIKE '%lisinopril%' OR di.name ILIKE '%ramipril%' OR di.name ILIKE '%perindopril%' OR di.name ILIKE '%fosinopril%' OR di.name ILIKE '%benazepril%' OR di.name ILIKE '%quinapril%' OR di.name ILIKE '%trandolapril%' OR di.name ILIKE '%losartan%' OR di.name ILIKE '%valsartan%' OR di.name ILIKE '%candesartan%' OR di.name ILIKE '%irbesartan%' OR di.name ILIKE '%telmisartan%' OR di.name ILIKE '%olmesartan%' OR di.name ILIKE '%azilsartan%')))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') AND EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('I502', 'I504')
        )
```

- Counts ACS admissions with an LVSD proxy (secondary diagnosis I502 or I504, systolic or combined heart failure) that received an ACE inhibitor or ARB during the stay (drugitems.name match). The PDF needs echocardiographic ejection fraction 40 percent or lower to define LVSD; ejection fraction is not stored in HOSxP structured tables. Owner must confirm the heart failure code proxy or load the echo-confirmed cohort aggregates into reporting.thip_external_facts.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, drugitems, ipt, iptdiag, opitemrece. SQL SHA256: 756f37011e556b06fde04e4b2f96a1c899937ba5ec29370c93f041c23f623a01

## DH0105

PDF physical 55; printed 46 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) ที่สูบบุหรี่และที่ได้รับการแนะนำให้ งดบุหรี่ระหว่างการอยู่โรงพยาบาลในเดือนนั้น

ตัวหาร / population: b = จำนวนผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) ที่สูบบุหรี่ทั้งหมดที่รับไว้ใน โรงพยาบาล ในเดือนเดียวกันนั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE (
          EXISTS (
            SELECT 1
            FROM iptdiag sd
            WHERE sd.an = periodized.an
              AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen scr
            JOIN ovst v ON v.vn = scr.vn
            WHERE v.an = periodized.an
              AND (
                scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
                OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
                OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
                OR scr.advice7_note ILIKE '%smoke%'
                OR scr.advice7_note ILIKE '%สูบ%'
              )
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen_advice adv
            JOIN opdscreen_advice_item itm ON itm.opdscreen_advice_item_id = adv.opdscreen_advice_item_id
            JOIN ovst v ON v.vn = adv.vn
            WHERE v.an = periodized.an
              AND (
                itm.opdscreen_advice_item_name ILIKE '%smoke%'
                OR itm.opdscreen_advice_item_name ILIKE '%บุหรี่%'
              )
          )
        ))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') AND (
          EXISTS (
            SELECT 1
            FROM iptdiag sd
            WHERE sd.an = periodized.an
              AND (
                LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
                OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
              )
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen scr
            JOIN ovst v ON v.vn = scr.vn
            WHERE v.an = periodized.an
              AND scr.smoking_type_id IN (2, 3)
          )
        )
```

- Counts ACS admissions of smokers (secondary diagnosis F17 or Z720, or opdscreen smoking_type_id 2 or 3 on a linked visit) whose chart shows cessation advice (secondary diagnosis Z716, opdscreen advice flags, advice7_note text, or an opdscreen_advice item naming tobacco). The PDF needs documented advice given during the admission for every smoker with no contraindication exclusion; documentation completeness depends on local nursing entry habits. Owner must confirm the smoking status and advice item mappings.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, opdscreen, opdscreen_advice, opdscreen_advice_item, ovst. SQL SHA256: c6b748460cedc9d1329f1aaa363a418d2ea5937bf6780be8b5462a9233b626c0

## DH0106

PDF physical 56; printed 47 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) ที่ไม่มีข้อห้ามของการให้ยา และ ได้รับ Beta-blocker ระหว่างรับไว้รักษาในโรงพยาบาลในเดือนนั้น

ตัวหาร / population: b = จำนวนผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) ที่ไม่มีข้อห้ามของการให้ยานี้ ที่เข้า รับการรักษาในโรงพยาบาลในเดือนเดียวกันนั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%metoprolol%' OR di.name ILIKE '%atenolol%' OR di.name ILIKE '%bisoprolol%' OR di.name ILIKE '%carvedilol%' OR di.name ILIKE '%propranolol%' OR di.name ILIKE '%labetalol%' OR di.name ILIKE '%nebivolol%' OR di.name ILIKE '%sotalol%')))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') AND NOT EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J45', 'J46')
              OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('R000', 'R001', 'I440', 'I441', 'I442', 'I495', 'I951')
            )
        )
```

- Counts ACS admissions without coded beta blocker contraindications (no asthma J45 or J46 and no bradycardia or block codes R000, R001, I440, I441, I442, I495, I951 as secondary diagnoses) that received a beta blocker drug during the stay. The PDF excludes clinical contraindications (hypotension, decompensated heart failure, severe asthma) that are not coded in HOSxP, so the denominator is broader than the printed one. Owner must confirm the contraindication list and local beta blocker item names.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, drugitems, ipt, iptdiag, opitemrece. SQL SHA256: afc9992132a763e908ee46ac2bd2fbdff6ebbc9a8146a31af84c5c6797e6199d

## DH0107

PDF physical 57; printed 48 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) ที่ไม่มีข้อห้ามของการให้ยา ที่ จำหน่ายออกจากโรงพยาบาล และ ได้รับยา Beta-blocker เมื่อจำหน่าย ในเดือนนั้น

ตัวหาร / population: b = จำนวนผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) ที่ไม่มีข้อห้ามของการให้ยานี้ ที่ จำหน่ายออกจากโรงพยาบาลโดยนับเฉพาะการจำหน่ายมีชีวิตด้วยสถานะการอนุญาตให้ กลับบ้าน ในเดือนเดียวกันนั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%metoprolol%' OR di.name ILIKE '%atenolol%' OR di.name ILIKE '%bisoprolol%' OR di.name ILIKE '%carvedilol%' OR di.name ILIKE '%propranolol%' OR di.name ILIKE '%labetalol%' OR di.name ILIKE '%nebivolol%' OR di.name ILIKE '%sotalol%')
            AND oi.rxdate >= periodized.dchdate - INTERVAL '1 day' AND oi.rxdate <= periodized.dchdate))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') AND NOT EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J45', 'J46')
              OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('R000', 'R001', 'I440', 'I441', 'I442', 'I495', 'I951')
            )
        ) AND NOT died
```

- Same cohort as DH0106, restricted to live discharges, with a beta blocker drug item ordered on the discharge day or the day before (take home prescription). The PDF asks for beta blocker prescribed at discharge for patients without contraindications and discharged alive with home status; home discharge status is approximated as alive discharge and contraindications are approximated by the coded list. Owner must confirm the discharge prescription window.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, drugitems, ipt, iptdiag, opitemrece. SQL SHA256: 86430dee1b1cd06c942bbd82e94e9114b77f5725f9ab6fdae8b9e41adf330baf

## DH0108

PDF physical 58; printed 49 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = ระยะเวลารวม (นาที) ที่ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) ได้รับการทำ EKG เมื่อมาถึงโรงพยาบาลทุกราย ในเดือนนั้น

ตัวหาร / population: b = จำนวน (คน) ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) ที่มาโรงพยาบาล และได้รับ การทำ EKG ทั้งหมด ในเดือนเดียวกันนั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: นาที; formula: a/b. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (sum)
SUM((
          SELECT EXTRACT(EPOCH FROM ((er.vstdate + ero.begin_time) - er.enter_er_time)) / NULLIF(60, 0)
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          JOIN er_regist_oper ero ON ero.vn = v.vn
          JOIN er_oper_code eoc ON eoc.er_oper_code = ero.er_oper_code
          WHERE v.an = periodized.an
            AND er.enter_er_time IS NOT NULL
            AND ero.begin_time IS NOT NULL
            AND (er.vstdate + ero.begin_time) >= er.enter_er_time
            AND (
              eoc.name ILIKE '%ekg%'
              OR eoc.name ILIKE '%ecg%'
              OR REPLACE(UPPER(TRIM(eoc.icd9cm)), '.', '') = '8952'
            )
          ORDER BY ero.begin_time
          LIMIT 1))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') AND ((
          SELECT EXTRACT(EPOCH FROM ((er.vstdate + ero.begin_time) - er.enter_er_time)) / NULLIF(60, 0)
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          JOIN er_regist_oper ero ON ero.vn = v.vn
          JOIN er_oper_code eoc ON eoc.er_oper_code = ero.er_oper_code
          WHERE v.an = periodized.an
            AND er.enter_er_time IS NOT NULL
            AND ero.begin_time IS NOT NULL
            AND (er.vstdate + ero.begin_time) >= er.enter_er_time
            AND (
              eoc.name ILIKE '%ekg%'
              OR eoc.name ILIKE '%ecg%'
              OR REPLACE(UPPER(TRIM(eoc.icd9cm)), '.', '') = '8952'
            )
          ORDER BY ero.begin_time
          LIMIT 1)) IS NOT NULL
```

- Average door to EKG minutes for ACS admissions with an ER arrival timestamp and an EKG event: the EKG time is the earliest er_regist_oper begin_time for an ER operation whose er_oper_code name matches EKG or ECG, or whose icd9cm normalizes to 8952, measured from er_regist enter_er_time. The PDF wants the average time from arrival to first EKG over all ACS arrivals; HOSxP stores no dedicated EKG event, so the event source and code naming must be confirmed by the owner (or the average loaded into reporting.thip_external_facts).
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, er_oper_code, er_regist, er_regist_oper, ipt, iptdiag, ovst. SQL SHA256: e4647b6e6f7b501788a874f7b067a25c1fb61e7b1797261fb46d816f97503734

## DH0109

PDF physical 59; printed 50 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = ระยะเวลารวม (นาที) ที่ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) มาถึงโรงพยาบาล จนได้รับการส่งต่อทุกราย ในเดือนนั้น

ตัวหาร / population: b = จำนวน (คน) ผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน (ACS) ที่มาโรงพยาบาล และได้รับ การส่งต่อทั้งหมด ในเดือนเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: นาที; formula: a/b. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (sum)
SUM((
          SELECT EXTRACT(EPOCH FROM (ro.refer_begin_time - er.enter_er_time)) / NULLIF(60, 0)
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          JOIN referout ro ON ro.vn = v.vn
          WHERE v.an = periodized.an
            AND er.enter_er_time IS NOT NULL
            AND ro.refer_begin_time IS NOT NULL
            AND ro.refer_begin_time >= er.enter_er_time
          ORDER BY ro.refer_begin_time
          LIMIT 1))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219') AND ((
          SELECT EXTRACT(EPOCH FROM (ro.refer_begin_time - er.enter_er_time)) / NULLIF(60, 0)
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          JOIN referout ro ON ro.vn = v.vn
          WHERE v.an = periodized.an
            AND er.enter_er_time IS NOT NULL
            AND ro.refer_begin_time IS NOT NULL
            AND ro.refer_begin_time >= er.enter_er_time
          ORDER BY ro.refer_begin_time
          LIMIT 1)) IS NOT NULL
```

- Average door to referral minutes for ACS admissions referred out: from er_regist enter_er_time to referout refer_begin_time for the earliest referral of the linked visit. The PDF wants the average arrival-to-referral time over all referred ACS patients; cases without ER clock or refer timestamps are dropped. Owner must confirm refer_begin_time is maintained at referral decision time.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, er_regist, ipt, iptdiag, ovst, referout. SQL SHA256: ed9fdf58ba56520ba90d65af44abcf8228968fedecb3a6c28d3613c5a58dab9e

## DH0110

PDF physical 60; printed 51, 52 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) ที่ไม่มี ข้อจำกัดของการทำ PPCI หรือไม่มีข้อห้ามของการให้ Thrombolytic agent ในการรักษา ที่รับไว้ในโรงพยาบาล ที่ได้รับ PPCI ภายใน 120 นาที หรือ Fibrinolytic agent ภายใน 30 นาทีเมื่อแรกรับ ในช่วงไตรมาส (3 เดือน) นั้น

ตัวหาร / population: b = จำนวนผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) ที่ไม่มี ข้อจำกัดของการทำ PPCI หรือไม่มีข้อห้ามของการให้ Thrombolytic agent ในการรักษา ที่รับไว้ในโรงพยาบาลทั้งหมด ในไตรมาสเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          WHERE v.an = periodized.an
            AND er.do_stemi_balloon = 'Y'
            AND er.enter_er_time IS NOT NULL
            AND er.stemi_balloon_datetime IS NOT NULL
            AND er.stemi_balloon_datetime >= er.enter_er_time
            AND EXTRACT(EPOCH FROM (er.stemi_balloon_datetime - er.enter_er_time)) <= 7200) OR EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%streptokinase%' OR di.name ILIKE '%alteplase%' OR di.name ILIKE '%tenecteplase%' OR di.name ILIKE '%reteplase%' OR di.name ILIKE '%urokinase%')
            AND EXISTS (
              SELECT 1
              FROM ovst v
              JOIN er_regist er ON er.vn = v.vn
              WHERE v.an = periodized.an
                AND er.enter_er_time IS NOT NULL
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) >= er.enter_er_time
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) <= er.enter_er_time + INTERVAL '30 minutes'
            )))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213')
```

- Counts STEMI admissions (Pdx I210-I213) whose reperfusion clock meets the target: primary PCI proxy is er_regist do_stemi_balloon with stemi_balloon_datetime within 7200 seconds of enter_er_time, or a fibrinolytic drug (drugitems name match) given within 30 minutes of ER arrival (opitemrece rxdate and rxtime). The PDF denominator excludes patients with PPCI limitations or thrombolytic contraindications and its PPCI clock is puncture or device time, not balloon time; both exclusions and the event choice need owner confirmation.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, drugitems, er_regist, ipt, iptdiag, opitemrece, ovst. SQL SHA256: 3b009dfadae4f4e899200c6f7999461e830f4c835806d5b092280ec10aa93fce

## DH0111

PDF physical 62; printed 53 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันที่มีการรับกลับเข้าโรงพยาบาลหลัง จำหน่ายภายใน 28 วัน โดยไม่ได้วางแผน ในเดือนนั้น

ตัวหาร / population: b = จำนวนผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันที่จำหน่ายด้วยสถานะการอนุญาตให้กลับ บ้าน (Status=improve) ในเดือนก่อนหน้านั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        ))
-- denominator (count)
COUNT(*) FILTER (WHERE NOT died)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: 9fd85638a2946fcf0a4488c9484063e5234960a277864066a159d5bfff0737ac

## DH0112

PDF physical 63; printed 54 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = ผลรวมระยะเวลาวันนอนของผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันทุกรายที่จำหน่ายใน เดือนนั้น

ตัวหาร / population: b = จำนวนผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันที่จำหน่ายในเดือนนั้น (คน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: วัน; formula: (a/b). Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (sum)
ROUND(SUM(los)::numeric, 2)
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213', 'I214', 'I219')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ตัวตั้งผลรวมวันนอน / ตัวหาร COUNT admission ACS ที่จำหน่าย; dictionary ใช้คำว่าคน ต้องยืนยัน episode เทียบ distinct HN; ไม่เปลี่ยนเป็น COUNT HN โดยเดา
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: f633ec4768802767cb66cbefa1e2abc1ce02a1666c420c265ce229d50f0ec4e4

## DH0113

PDF physical 64; printed 55, 56 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) ที่ไม่มี ข้อห้ามของการให้ Thrombolytic agent ในการรักษา ที่รับไว้ในโรงพยาบาล ที่ได้รับยา Fibrinolytic agent ภายใน 30 นาทีเมื่อแรกรับในเดือนนั้น

ตัวหาร / population: b = จำนวนผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลันชนิด ST segment ยกขึ้น (STEMI) ที่ไม่มี ข้อห้ามของการให้ Thrombolytic agent ในการรักษา ที่รับไว้ในโรงพยาบาลทั้งหมด ใน เดือนเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%streptokinase%' OR di.name ILIKE '%alteplase%' OR di.name ILIKE '%tenecteplase%' OR di.name ILIKE '%reteplase%' OR di.name ILIKE '%urokinase%')
            AND EXISTS (
              SELECT 1
              FROM ovst v
              JOIN er_regist er ON er.vn = v.vn
              WHERE v.an = periodized.an
                AND er.enter_er_time IS NOT NULL
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) >= er.enter_er_time
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) <= er.enter_er_time + INTERVAL '30 minutes'
            )))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND pdx IN ('I210', 'I211', 'I212', 'I213')
```

- Counts STEMI admissions receiving a fibrinolytic agent (streptokinase, alteplase, tenecteplase, reteplase, urokinase by drugitems name) within 30 minutes of ER arrival over all STEMI admissions. The PDF denominator excludes thrombolytic contraindications (recent stroke or bleeding) and counts time from first medical contact; HOSxP codes neither, so the denominator is broader and the clock starts at hospital arrival. Owner must confirm the fibrinolytic item names.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, drugitems, er_regist, ipt, iptdiag, opitemrece, ovst. SQL SHA256: 6bc170e9b2df8c93a4a081de3f2ee5697f8969e33ca108d6a53bc5742ad3306d

## DH0201

PDF physical 66; printed 57 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยที่ทำ CABG แล้วเสียชีวิต

ตัวหาร / population: b = จำนวนผู้ป่วยที่ทำ CABG แล้วจำหน่ายทั้งหมดในช่วงเวลาเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE died)
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('3610', '3611', '3612', '3613', '3614', '3615', '3616', '3617', '3618', '3619')
    )
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, iptoprt. SQL SHA256: 175dbe916536fdadee362331a41a895bd5b1b3d4322f4fd423a12dfe8bb626cd

## DH0202

PDF physical 67; printed 58 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการผ่าตัด CABG ที่ได้รับ prophylactic antibiotic ภายใน 1 ชั่วโมง ก่อนลงมีดผ่าตัดในเดือนนั้น

ตัวหาร / population: b = จำนวนครั้งของการผ่าตัด CABG ทั้งหมดในเดือนเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          JOIN opitemrece oi ON oi.an = o.an
          JOIN drugitems di ON di.icode = oi.icode
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('3610', '3611', '3612', '3613', '3614', '3615', '3616', '3617', '3618', '3619')
            AND (di.antibiotic = 'Y' OR di.drugcategory ILIKE '%antibio%')
            AND EXTRACT(EPOCH FROM (
              (o.opdate + COALESCE(o.optime, TIME '00:00:00')) -
              (oi.vstdate + COALESCE(oi.vsttime, TIME '00:00:00'))
            )) BETWEEN 0 AND 3600))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('3610', '3611', '3612', '3613', '3614', '3615', '3616', '3617', '3618', '3619')
    )
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, drugitems, ipt, iptdiag, iptoprt, opitemrece. SQL SHA256: d0ca24d013f5909075a6d181bb96fc3f6faae955044a5f6f498fdb7ccb70805b

## DH0203

PDF physical 68; printed 59 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการติดเชื้อแผลผ่าตัด CABG ในเดือนนั้น

ตัวหาร / population: b = จำนวนครั้งของการผ่าตัด CABG ทั้งหมด ในเดือนเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('T814', 'T826', 'T827')
          UNION
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          LEFT JOIN iptdiag rd ON rd.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '30 days'
            AND (
              REPLACE(UPPER(TRIM(rs.pdx)), '.', '') IN ('T814', 'T826', 'T827')
              OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') IN ('T814', 'T826', 'T827')
            )))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('3610', '3611', '3612', '3613', '3614', '3615', '3616', '3617', '3618', '3619')
    )
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, iptoprt. SQL SHA256: 106b7c06f9eee23e1285fcf9603d67d5e5cbb0f234ae3b5a0a937d3cb02542ac

## DH0204

PDF physical 69; printed 60 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยที่ทำ CABG ที่เสียชีวิตจากทุกสาเหตุภายในระยะเวลา 30 วัน ทั้งขณะรับการรักษาในโรงพยาบาลและหลังจากจำหน่ายออกจากโรงพยาบาล (ยกเว้นเป็นการเสียชีวิตจากสาเหตุที่เกิดจากอุบัติเหตุ) นับจากวันที่เข้ารับการรักษา แบบผู้ป่วยในวันแรก ในเดือนนั้น

ตัวหาร / population: b = จำนวนผู้ป่วยที่ทำ CABG ทั้งหมดในช่วงเดือนเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (
        WHERE died OR EXISTS (
          SELECT 1
          FROM death d
          WHERE (d.an = periodized.an OR d.hn = periodized.hn)
            AND d.death_date IS NOT NULL
            AND (d.death_date + COALESCE(d.death_time, TIME '23:59:59')) >=
              (periodized.regdate + COALESCE(periodized.regtime, TIME '00:00:00'))
            AND (d.death_date + COALESCE(d.death_time, TIME '23:59:59')) <=
              (periodized.regdate + COALESCE(periodized.regtime, TIME '00:00:00')) + INTERVAL '30 days'
            AND NOT (
              LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_diag_icd10, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
              OR LEFT(REPLACE(UPPER(TRIM(COALESCE(d.death_cause, ''))), '.', ''), 1) IN ('V', 'W', 'X', 'Y')
            )
        )
      )
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('3610', '3611', '3612', '3613', '3614', '3615', '3616', '3617', '3618', '3619')
    )
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, iptoprt. SQL SHA256: 9769adb6be0e5fd88c1eb82fc46ace4991598b8d3c127e800bef88ac48c77512

## DH0301

PDF physical 70; printed 61, 62 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย HFREF ที่ได้รับยา ACE inhibitors หรือ ARBs หรือ MRA ในเดือนนั้น

ตัวหาร / population: b = จำนวนผู้ป่วย HFREF ที่ไม่มีข้อห้าม หรือข้อจำกัดในการให้ยานี้ ในเดือนเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (
              di.name ILIKE '%enalapril%' OR di.name ILIKE '%captopril%' OR di.name ILIKE '%lisinopril%'
              OR di.name ILIKE '%ramipril%' OR di.name ILIKE '%perindopril%' OR di.name ILIKE '%fosinopril%'
              OR di.name ILIKE '%losartan%' OR di.name ILIKE '%valsartan%' OR di.name ILIKE '%candesartan%'
              OR di.name ILIKE '%irbesartan%' OR di.name ILIKE '%telmisartan%' OR di.name ILIKE '%olmesartan%'
              OR di.name ILIKE '%spironolactone%' OR di.name ILIKE '%eplerenone%'
            )))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND LEFT(pdx, 3) = 'I50' AND NOT EXISTS (SELECT 1 FROM iptdiag sd WHERE sd.an = periodized.an AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J45', 'J46'))
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, drugitems, ipt, iptdiag, opitemrece. SQL SHA256: 4a7788220dfec92a153fcdd48214e64ca070ab3a08d07b57fa3c63585e9f26d3

## DH0302

PDF physical 72; printed 63 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย Heart failure ที่สูบบุหรี่ที่ได้รับการแนะนำให้งดบุหรี่ระหว่างการอยู่ โรงพยาบาล ในเดือนนั้น

ตัวหาร / population: b = จำนวนผู้ป่วย Heart failure ที่สูบบุหรี่ทั้งหมดที่รับไว้ในโรงพยาบาล ในเดือนเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
          UNION
          SELECT 1
          FROM opdscreen scr
          JOIN ovst v ON v.vn = scr.vn
          WHERE v.an = periodized.an
            AND (
              scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
              OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
              OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
              OR scr.advice7_note ILIKE '%smoke%' OR scr.advice7_note ILIKE '%สูบ%'
            )))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
LEFT(pdx, 3) = 'I50'
      AND (
        EXISTS (
          SELECT 1 FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND (LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17' OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720')
        )
        OR EXISTS (
          SELECT 1 FROM opdscreen scr
          JOIN ovst v ON v.vn = scr.vn
          WHERE v.an = periodized.an
            AND scr.smoking_type_id IN (2, 3)
        )
      )
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, opdscreen, ovst. SQL SHA256: 8dd153bdce6df81880cef337cce170a7ffe2128eba15260afbbfa2a2f5387398

## DH0401

PDF physical 73; printed 64, 65 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย Atrial fibrillation ที่ไม่มีข้อห้ามหรือข้อจำกัดของการให้ยานี้ และได้รับยา Warfarin ที่มารับการรักษา และ มีค่า INR ระดับเป้าหมายในทุกครั้งของการ ตรวจรักษาในไตรมาสนั้น

ตัวหาร / population: b = จำนวนผู้ป่วย Atrial fibrillation ที่ไม่มีข้อห้ามหรือข้อจำกัดของการให้ยานี้ และได้รับยา Warfarin ที่มารับการรักษาทั้งหมดในไตรมาสเดียวกัน

Grain: visit/event at ovst VN (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: ร้อยละ; formula: (a/b) x100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM opdscreen sc WHERE sc.vn = opd_periodized.vn AND sc.inr IS NOT NULL AND sc.inr >= 2.0 AND sc.inr <= 3.0))
-- denominator (count)
COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM opdscreen sc WHERE sc.vn = opd_periodized.vn AND sc.inr IS NOT NULL))
-- outer FROM / source
opd_periodized
-- outer cohort predicate
age_y >= 18 AND (
          LEFT(pdx, 3) = 'I48'
          OR EXISTS (
            SELECT 1
            FROM ovstdiag sd
            WHERE sd.vn = opd_periodized.vn
              AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'I48'
          )
        ) AND EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.vn = opd_periodized.vn
            AND (di.name ILIKE '%warfarin%'))
```

- Visit-grain branch over OPD follow-up visits: atrial fibrillation or flutter (Pdx or secondary I48) with a warfarin item on the visit and an INR recorded in opdscreen; numerator is visits with INR between 2.0 and 3.0. The PDF wants AF patients on warfarin whose INR was at target at every visit of the quarter; per patient all-visit compliance and quarterly windowing are not computable in one pass over visits. Owner must confirm the target range for their warfarin clinic (for example 2.0 to 3.0) or load quarterly patient aggregates into reporting.thip_external_facts.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: drugitems, er_regist, opdscreen, opitemrece, ovst, ovstdiag, patient. SQL SHA256: e7e2d5f4528be7c48ef649caf3abdd500922491fc63f4cbcce71ab7d367fe5fe

## DH0402

PDF physical 75; printed 66 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย Atrial fibrillation ที่ไม่มีข้อห้ามหรือข้อจำกัดของการให้ยานี้และได้รับ ยา Warfarin ที่เกิด adverse event ในไตรมาสนั้น

ตัวหาร / population: b = จำนวนผู้ป่วย Atrial fibrillation ที่ไม่มีข้อห้ามหรือข้อจำกัดของการให้ยานี้และได้รับ ยา Warfarin ในการรักษาทั้งหมด ในช่วงไตรมาสเดียวกัน

Grain: visit/event at ovst VN (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ipt i2
          JOIN an_stat s2 ON s2.an = i2.an
          WHERE i2.hn = opd_periodized.hn
            AND LEFT(REPLACE(UPPER(TRIM(s2.pdx)), '.', ''), 3) IN ('I60', 'I61', 'I62')
            AND i2.regdate <= opd_periodized.event_date
            AND i2.regdate >= opd_periodized.event_date - INTERVAL '90 days'
        ))
-- denominator (count)
COUNT(*)
-- outer FROM / source
opd_periodized
-- outer cohort predicate
age_y >= 18 AND (
          LEFT(pdx, 3) = 'I48'
          OR EXISTS (
            SELECT 1
            FROM ovstdiag sd
            WHERE sd.vn = opd_periodized.vn
              AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'I48'
          )
        ) AND EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.vn = opd_periodized.vn
            AND (di.name ILIKE '%warfarin%'))
```

- Visit-grain branch over AF warfarin follow-up visits (same cohort as DH0401 without the INR requirement); numerator is visits of patients with a non-traumatic intracranial hemorrhage admission (an_stat Pdx I60, I61 or I62) within the 90 days before the visit. The PDF wants quarterly major bleeding (intracranial hemorrhage) incidence among warfarin treated AF patients, including GI bleeding events; the lookback window and visit grain are approximations. Owner must confirm the incidence window or load quarterly aggregates into reporting.thip_external_facts.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: an_stat, drugitems, er_regist, ipt, opitemrece, ovst, ovstdiag, patient. SQL SHA256: 9a72c0c718ad11740cca54c51354b8bf6a4ee864b80af16970f616a4f3639214

## DM0101

PDF physical 160; printed 151 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนเด็กพัฒนาการช้ารอบด้าน (GDD) มีพัฒนาการดีขึ้นภายใน 6 เดือน หลังรับการ รักษา (คน)

ตัวหาร / population: b = จํานวนเด็กพัฒนาการล่าช้ารอบด้าน (GDD) ที่ได้รับการประเมินพัฒนาการ (คน)

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: psych_assess_child.psych_assess_head_id, psych_assess_head.psych_assess_head_id, psych_assess_head.hn. Date candidates: clinicmember.dchdate, clinicmember.last_bp_date, clinicmember.last_hba1c_date, clinicmember.regdate, psych_assess_head.date_assessment.

Unit: ร้อยละ; formula: (a/b) ข 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT clinicmember_id) FILTER (WHERE imp.flagged)
-- denominator (count)
COUNT(DISTINCT clinicmember_id)
-- outer FROM / source
chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM psych_assess_head h1
        JOIN psych_assess_child c1 ON c1.psych_assess_head_id = h1.psych_assess_head_id

        JOIN psych_assess_head h2 ON h2.hn = h1.hn
          AND h2.date_assessment > h1.date_assessment
          AND h2.date_assessment <= h1.date_assessment + INTERVAL '6 months'
        JOIN psych_assess_child c2 ON c2.psych_assess_head_id = h2.psych_assess_head_id

        WHERE h1.hn = chronic_periodized.hn
          AND h1.date_assessment >= chronic_periodized.regdate - INTERVAL '6 months'
          AND h1.date_assessment <= chronic_periodized.regdate
          AND ((((c2.psych_assess_child_gm_year * 12 + c2.psych_assess_child_gm_month) > (c1.psych_assess_child_gm_year * 12 + c1.psych_assess_child_gm_month) OR (c2.psych_assess_child_fm_year * 12 + c2.psych_assess_child_fm_month) > (c1.psych_assess_child_fm_year * 12 + c1.psych_assess_child_fm_month) OR (c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) > (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) OR (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) > (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month) OR (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) > (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month)) AND ((c2.psych_assess_child_gm_year * 12 + c2.psych_assess_child_gm_month) >= (c1.psych_assess_child_gm_year * 12 + c1.psych_assess_child_gm_month) AND (c2.psych_assess_child_fm_year * 12 + c2.psych_assess_child_fm_month) >= (c1.psych_assess_child_fm_year * 12 + c1.psych_assess_child_fm_month) AND (c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) >= (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) AND (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) >= (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month) AND (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) >= (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month))))
      ) AS flagged
    ) imp ON TRUE
-- outer cohort predicate
chronic_periodized.age_y <= 6
    AND EXISTS (
      SELECT 1
      FROM ovstdiag sdg
      WHERE sdg.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdg.icd10)), '.', ''), 3) IN ('F83', 'R62'))
    )
    AND EXISTS (
      SELECT 1
      FROM psych_assess_head ha
      JOIN psych_assess_child ca ON ca.psych_assess_head_id = ha.psych_assess_head_id
      WHERE ha.hn = chronic_periodized.hn
        AND ha.date_assessment >= chronic_periodized.regdate - INTERVAL '6 months'
        AND ha.date_assessment <= chronic_periodized.regdate
    )
```

- Measures members aged 6 or under with GDD (F83, R62) who had a developmental assessment in the trailing 6 months (denominator) and whose paired psych_assess_child records one to six months apart improve at least one of the five developmental-age domains with none worse (numerator). The PDF leaves the improvement instrument to context and needs clinical judgement over 6 months of treatment; the domain-month comparison is the closest structured aggregate, so the owner must confirm the domain columns and the pair window.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: clinicmember, ovstdiag, psych_assess_child, psych_assess_head. SQL SHA256: 3db5be89e7cb8387e30e5da7580fe2b6a645bf40a46a53fdbd501cb220d8407c

## DM0102

PDF physical 161; printed 152 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนเด็กพัฒนาการช้ารอบด้าน (GDD) มีพัฒนาการดีขึ้นภายใน 6 เดือน หลังรับการ รักษา (คน)

ตัวหาร / population: b = จํานวนเด็กพัฒนาการล่าช้ารอบด้าน (GDD) ที่ได้รับการประเมินพัฒนาการ (คน)

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: psych_assess_child.psych_assess_head_id, psych_assess_head.psych_assess_head_id, psych_assess_topic.psych_assess_topic_id, psych_assess_head.psych_assess_topic_id, psych_assess_head.hn. Date candidates: clinicmember.dchdate, clinicmember.last_bp_date, clinicmember.last_hba1c_date, clinicmember.regdate, psych_assess_head.date_assessment.

Unit: ร้อยละ; formula: (a/b) ข 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT clinicmember_id) FILTER (WHERE imp.flagged)
-- denominator (count)
COUNT(DISTINCT clinicmember_id)
-- outer FROM / source
chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM psych_assess_head h1
        JOIN psych_assess_child c1 ON c1.psych_assess_head_id = h1.psych_assess_head_id
        JOIN psych_assess_topic tpa ON tpa.psych_assess_topic_id = h1.psych_assess_topic_id AND tpa.psych_assess_topic_name ILIKE '%teda%'
        JOIN psych_assess_head h2 ON h2.hn = h1.hn
          AND h2.date_assessment > h1.date_assessment
          AND h2.date_assessment <= h1.date_assessment + INTERVAL '6 months'
        JOIN psych_assess_child c2 ON c2.psych_assess_head_id = h2.psych_assess_head_id
        JOIN psych_assess_topic tpb ON tpb.psych_assess_topic_id = h2.psych_assess_topic_id AND tpb.psych_assess_topic_name ILIKE '%teda%'
        WHERE h1.hn = chronic_periodized.hn
          AND h1.date_assessment >= chronic_periodized.regdate - INTERVAL '6 months'
          AND h1.date_assessment <= chronic_periodized.regdate
          AND ((((c2.psych_assess_child_gm_year * 12 + c2.psych_assess_child_gm_month) > (c1.psych_assess_child_gm_year * 12 + c1.psych_assess_child_gm_month) OR (c2.psych_assess_child_fm_year * 12 + c2.psych_assess_child_fm_month) > (c1.psych_assess_child_fm_year * 12 + c1.psych_assess_child_fm_month) OR (c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) > (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) OR (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) > (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month) OR (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) > (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month)) AND ((c2.psych_assess_child_gm_year * 12 + c2.psych_assess_child_gm_month) >= (c1.psych_assess_child_gm_year * 12 + c1.psych_assess_child_gm_month) AND (c2.psych_assess_child_fm_year * 12 + c2.psych_assess_child_fm_month) >= (c1.psych_assess_child_fm_year * 12 + c1.psych_assess_child_fm_month) AND (c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) >= (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) AND (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) >= (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month) AND (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) >= (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month))))
      ) AS flagged
    ) imp ON TRUE
-- outer cohort predicate
chronic_periodized.age_y <= 6
    AND EXISTS (
      SELECT 1
      FROM ovstdiag sdg
      WHERE sdg.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdg.icd10)), '.', ''), 3) IN ('F83', 'R62'))
    )
    AND EXISTS (
      SELECT 1
      FROM psych_assess_head ha
      JOIN psych_assess_child ca ON ca.psych_assess_head_id = ha.psych_assess_head_id
      WHERE ha.hn = chronic_periodized.hn
        AND ha.date_assessment >= chronic_periodized.regdate - INTERVAL '6 months'
        AND ha.date_assessment <= chronic_periodized.regdate
        AND ha.psych_assess_topic_id IN (SELECT tpx.psych_assess_topic_id FROM psych_assess_topic tpx WHERE tpx.psych_assess_topic_name ILIKE '%teda%')
    )
```

- Same cohort and domain-pair rule as DM0101 but both assessments must sit under a psych_assess_topic named for TEDA4I. The PDF requires the TEDA4I instrument specifically; topic-name matching is the only instrument binding in HOSxP, so the owner must confirm the TEDA4I topic naming in psych_assess_topic.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: clinicmember, ovstdiag, psych_assess_child, psych_assess_head, psych_assess_topic. SQL SHA256: 1a9d70c325639c5cc771113beb5ad4ba761edbb4f2c0d648f41401b320642d4f

## DM0103

PDF physical 162; printed 153 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนเด็กพัฒนาการล่าช้ารอบด้าน (GDD) คงอยู่ในระบบการศึกษาได้ อย่างน้อย 1 ปี (คน)

ตัวหาร / population: b = จํานวนเด็กพัฒนาการล่าช้ารอบด้าน (GDD) ที่ส่งเข้าระบบการศึกษา (คน)

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) ข 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'DM0103'
```

- GDD school retention for at least one year is school-system data, absent from HOSxP. Branch is branchExternal: the hospital must load one row per reporting-period anchor into reporting.thip_external_facts with numerator, denominator, value and source_system, for example sourced from the education referral follow-up register.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: cbcd92756d199e0beb4d9c736595d866db6a09745abe66913ac3d9c3a33ae2be

## DM0201

PDF physical 163; printed 154 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนเด็กออทิสติกที่ได้รับการวินิจฉัยและบำบัดรักษาตามโปรแกรมของหน่วยงาน แล้วมีพัฒนาการด้านการเข้าใจภาษาหรือด้านการใช้ภาษา ร่วมกับด้านการช่วยเหลือตัวเอง และสังคมดีขึ้นภายใน 6 เดือน (คน)

ตัวหาร / population: b = จํานวนเด็กออทิสติกทั้งหมดที่ได้รับการวินิจฉัยและบำบัดรักษาตามโปรแกรมของ หน่วยงาน (คน)

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: psych_assess_child.psych_assess_head_id, psych_assess_head.psych_assess_head_id, psych_assess_head.hn, ovst.vn, psych_therapy.vn_an. Date candidates: clinicmember.dchdate, clinicmember.last_bp_date, clinicmember.last_hba1c_date, clinicmember.regdate, ovst.vstdate, psych_assess_head.date_assessment, psych_plan.psych_plan_date, psych_therapy.psych_therapy_date.

Unit: ร้อยละ; formula: (a/b) ข 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT clinicmember_id) FILTER (WHERE imp.flagged)
-- denominator (count)
COUNT(DISTINCT clinicmember_id)
-- outer FROM / source
chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM psych_assess_head h1
        JOIN psych_assess_child c1 ON c1.psych_assess_head_id = h1.psych_assess_head_id

        JOIN psych_assess_head h2 ON h2.hn = h1.hn
          AND h2.date_assessment > h1.date_assessment
          AND h2.date_assessment <= h1.date_assessment + INTERVAL '6 months'
        JOIN psych_assess_child c2 ON c2.psych_assess_head_id = h2.psych_assess_head_id

        WHERE h1.hn = chronic_periodized.hn
          AND h1.date_assessment >= chronic_periodized.regdate - INTERVAL '6 months'
          AND h1.date_assessment <= chronic_periodized.regdate
          AND (((((c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) > (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) OR (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) > (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month)) AND (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) > (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month)) AND ((c2.psych_assess_child_gm_year * 12 + c2.psych_assess_child_gm_month) >= (c1.psych_assess_child_gm_year * 12 + c1.psych_assess_child_gm_month) AND (c2.psych_assess_child_fm_year * 12 + c2.psych_assess_child_fm_month) >= (c1.psych_assess_child_fm_year * 12 + c1.psych_assess_child_fm_month) AND (c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) >= (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) AND (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) >= (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month) AND (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) >= (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month))))
      ) AS flagged
    ) imp ON TRUE
-- outer cohort predicate
EXISTS (
      SELECT 1
      FROM ovstdiag sda
      WHERE sda.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sda.icd10)), '.', ''), 3) IN ('F84'))
    )
    AND (EXISTS (
      SELECT 1
      FROM psych_therapy th
      JOIN ovst tv ON tv.vn = th.vn_an
      WHERE tv.hn = chronic_periodized.hn
        AND th.psych_therapy_date >= chronic_periodized.regdate - INTERVAL '6 months'
        AND th.psych_therapy_date <= chronic_periodized.regdate
    ) OR EXISTS (
      SELECT 1
      FROM psych_plan pp
      WHERE pp.hn = chronic_periodized.hn
        AND pp.psych_plan_date >= chronic_periodized.regdate - INTERVAL '6 months'
        AND pp.psych_plan_date <= chronic_periodized.regdate
    ))
```

- Measures members with ASD (F84) in treatment per programme (psych_therapy or psych_plan in the trailing 6 months, denominator) whose paired psych_assess_child records improve receptive or expressive language together with personal and social, with no domain worse (numerator). The PDF wants clinician-judged social and communication improvement over 6 months; the owner must confirm the domain mapping and the treatment-programme evidence.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: clinicmember, ovst, ovstdiag, psych_assess_child, psych_assess_head, psych_plan, psych_therapy. SQL SHA256: 5a1d7af8b9b2f31c550c3d81a058f810a8088d4a94e756be84f06c7d0d2b9a09

## DM0202

PDF physical 164; printed 155 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนเด็กออทิสติกที่ได้รับการวินิจฉัยและบำบัดรักษาตามโปรแกรมของหน่วยงาน แล้วมีพัฒนาการด้านการเข้าใจภาษาหรือด้านการใช้ภาษา ร่วมกับด้านการช่วยเหลือตัวเอง และสังคมดีขึ้นภายใน 6 เดือน (คน)

ตัวหาร / population: b = จํานวนเด็กออทิสติกทั้งหมดที่ได้รับการวินิจฉัยและบำบัดรักษาตามโปรแกรมของ หน่วยงาน (คน)

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: psych_assess_child.psych_assess_head_id, psych_assess_head.psych_assess_head_id, psych_assess_topic.psych_assess_topic_id, psych_assess_head.psych_assess_topic_id, psych_assess_head.hn, ovst.vn, psych_therapy.vn_an. Date candidates: clinicmember.dchdate, clinicmember.last_bp_date, clinicmember.last_hba1c_date, clinicmember.regdate, ovst.vstdate, psych_assess_head.date_assessment, psych_plan.psych_plan_date, psych_therapy.psych_therapy_date.

Unit: ร้อยละ; formula: (a/b) ข 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT clinicmember_id) FILTER (WHERE imp.flagged)
-- denominator (count)
COUNT(DISTINCT clinicmember_id)
-- outer FROM / source
chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM psych_assess_head h1
        JOIN psych_assess_child c1 ON c1.psych_assess_head_id = h1.psych_assess_head_id
        JOIN psych_assess_topic tpa ON tpa.psych_assess_topic_id = h1.psych_assess_topic_id AND tpa.psych_assess_topic_name ILIKE '%teda%'
        JOIN psych_assess_head h2 ON h2.hn = h1.hn
          AND h2.date_assessment > h1.date_assessment
          AND h2.date_assessment <= h1.date_assessment + INTERVAL '6 months'
        JOIN psych_assess_child c2 ON c2.psych_assess_head_id = h2.psych_assess_head_id
        JOIN psych_assess_topic tpb ON tpb.psych_assess_topic_id = h2.psych_assess_topic_id AND tpb.psych_assess_topic_name ILIKE '%teda%'
        WHERE h1.hn = chronic_periodized.hn
          AND h1.date_assessment >= chronic_periodized.regdate - INTERVAL '6 months'
          AND h1.date_assessment <= chronic_periodized.regdate
          AND (((((c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) > (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) OR (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) > (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month)) AND (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) > (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month)) AND ((c2.psych_assess_child_gm_year * 12 + c2.psych_assess_child_gm_month) >= (c1.psych_assess_child_gm_year * 12 + c1.psych_assess_child_gm_month) AND (c2.psych_assess_child_fm_year * 12 + c2.psych_assess_child_fm_month) >= (c1.psych_assess_child_fm_year * 12 + c1.psych_assess_child_fm_month) AND (c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) >= (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) AND (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) >= (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month) AND (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) >= (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month))))
      ) AS flagged
    ) imp ON TRUE
-- outer cohort predicate
EXISTS (
      SELECT 1
      FROM ovstdiag sda
      WHERE sda.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sda.icd10)), '.', ''), 3) IN ('F84'))
    )
    AND (EXISTS (
      SELECT 1
      FROM psych_therapy th
      JOIN ovst tv ON tv.vn = th.vn_an
      WHERE tv.hn = chronic_periodized.hn
        AND th.psych_therapy_date >= chronic_periodized.regdate - INTERVAL '6 months'
        AND th.psych_therapy_date <= chronic_periodized.regdate
    ) OR EXISTS (
      SELECT 1
      FROM psych_plan pp
      WHERE pp.hn = chronic_periodized.hn
        AND pp.psych_plan_date >= chronic_periodized.regdate - INTERVAL '6 months'
        AND pp.psych_plan_date <= chronic_periodized.regdate
    ))
```

- Same cohort and language-plus-social pair rule as DM0201 but both assessments must sit under a psych_assess_topic named for TEDA4I. The TEDA4I binding is topic-name matching only, so the owner must confirm the TEDA4I topic naming in psych_assess_topic.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: clinicmember, ovst, ovstdiag, psych_assess_child, psych_assess_head, psych_assess_topic, psych_plan, psych_therapy. SQL SHA256: 3cb954626999a5301314d9baecf7575f0ace91601daf45b93bf471d2de6f5cab

## DM0203

PDF physical 165; printed 156 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนเด็กออทิสติกที่คงอยู่ในระบบการศึกษาได้อย่างน้อย 1 ปี (คน)

ตัวหาร / population: b = จํานวนเด็กออทิสติกทั้งหมดที่รับการรักษาที่ส่งเข้าระบบการศึกษาภายใน ปีงบประมาณ (คน)

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) ข 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'DM0203'
```

- ASD school retention for at least one year is school-system data, absent from HOSxP (person_wbc keeps only child health book growth and vaccine fields). Branch is branchExternal: the hospital must load one row per reporting-period anchor into reporting.thip_external_facts with numerator, denominator, value and source_system, for example sourced from the education referral follow-up register.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 1b98e3e8c5944a72a5f6a01dd4612222412e184e6d54c5e41bce9e2bfa3045c4

## DM0301

PDF physical 166; printed 157 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยเด็กสมองพิการที่มีพัฒนาการดีขึ้นภายใน 6 เดือน (คน)

ตัวหาร / population: b = จำนวนผู้ป่วยเด็กสมองพิการทั้งหมดที่รับการรักษา (คน)

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: psych_assess_child.psych_assess_head_id, psych_assess_head.psych_assess_head_id, psych_assess_head.hn, ovst.vn, psych_therapy.vn_an. Date candidates: clinicmember.dchdate, clinicmember.last_bp_date, clinicmember.last_hba1c_date, clinicmember.regdate, ovst.vstdate, psych_assess_head.date_assessment, psych_plan.psych_plan_date, psych_therapy.psych_therapy_date.

Unit: ร้อยละ; formula: (a/b) ข 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT clinicmember_id) FILTER (WHERE imp.flagged)
-- denominator (count)
COUNT(DISTINCT clinicmember_id)
-- outer FROM / source
chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM psych_assess_head h1
        JOIN psych_assess_child c1 ON c1.psych_assess_head_id = h1.psych_assess_head_id

        JOIN psych_assess_head h2 ON h2.hn = h1.hn
          AND h2.date_assessment > h1.date_assessment
          AND h2.date_assessment <= h1.date_assessment + INTERVAL '6 months'
        JOIN psych_assess_child c2 ON c2.psych_assess_head_id = h2.psych_assess_head_id

        WHERE h1.hn = chronic_periodized.hn
          AND h1.date_assessment >= chronic_periodized.regdate - INTERVAL '6 months'
          AND h1.date_assessment <= chronic_periodized.regdate
          AND ((((c2.psych_assess_child_gm_year * 12 + c2.psych_assess_child_gm_month) > (c1.psych_assess_child_gm_year * 12 + c1.psych_assess_child_gm_month) OR (c2.psych_assess_child_fm_year * 12 + c2.psych_assess_child_fm_month) > (c1.psych_assess_child_fm_year * 12 + c1.psych_assess_child_fm_month) OR (c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) > (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) OR (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) > (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month) OR (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) > (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month)) AND ((c2.psych_assess_child_gm_year * 12 + c2.psych_assess_child_gm_month) >= (c1.psych_assess_child_gm_year * 12 + c1.psych_assess_child_gm_month) AND (c2.psych_assess_child_fm_year * 12 + c2.psych_assess_child_fm_month) >= (c1.psych_assess_child_fm_year * 12 + c1.psych_assess_child_fm_month) AND (c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) >= (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) AND (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) >= (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month) AND (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) >= (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month))))
      ) AS flagged
    ) imp ON TRUE
-- outer cohort predicate
chronic_periodized.age_y <= 18
    AND EXISTS (
      SELECT 1
      FROM ovstdiag sdp
      WHERE sdp.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdp.icd10)), '.', ''), 3) IN ('G80'))
    )
    AND (EXISTS (
      SELECT 1
      FROM psych_therapy th
      JOIN ovst tv ON tv.vn = th.vn_an
      WHERE tv.hn = chronic_periodized.hn
        AND th.psych_therapy_date >= chronic_periodized.regdate - INTERVAL '6 months'
        AND th.psych_therapy_date <= chronic_periodized.regdate
    ) OR EXISTS (
      SELECT 1
      FROM psych_plan pp
      WHERE pp.hn = chronic_periodized.hn
        AND pp.psych_plan_date >= chronic_periodized.regdate - INTERVAL '6 months'
        AND pp.psych_plan_date <= chronic_periodized.regdate
    ))
```

- Measures members aged 18 or under with cerebral palsy (G80) in treatment per programme (psych_therapy or psych_plan in the trailing 6 months, denominator) whose paired psych_assess_child records improve at least one of the five domains with none worse (numerator). The PDF leaves the instrument to context and spans 6 months of treatment; the owner must confirm the domain mapping and the treatment-programme evidence.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: clinicmember, ovst, ovstdiag, psych_assess_child, psych_assess_head, psych_plan, psych_therapy. SQL SHA256: fe9f085d1e080d6872104abb77e4ec1d8f259be824db57c4379ac66d2ebbb5cd

## DM0302

PDF physical 167; printed 158 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยเด็กสมองพิการที่มีพัฒนาการดีขึ้นภายใน 6 เดือน (คน)

ตัวหาร / population: b = จำนวนผู้ป่วยเด็กสมองพิการทั้งหมดที่รับการรักษา (คน)

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: psych_assess_child.psych_assess_head_id, psych_assess_head.psych_assess_head_id, psych_assess_topic.psych_assess_topic_id, psych_assess_head.psych_assess_topic_id, psych_assess_head.hn, ovst.vn, psych_therapy.vn_an. Date candidates: clinicmember.dchdate, clinicmember.last_bp_date, clinicmember.last_hba1c_date, clinicmember.regdate, ovst.vstdate, psych_assess_head.date_assessment, psych_plan.psych_plan_date, psych_therapy.psych_therapy_date.

Unit: ร้อยละ; formula: (a/b) ข 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT clinicmember_id) FILTER (WHERE imp.flagged)
-- denominator (count)
COUNT(DISTINCT clinicmember_id)
-- outer FROM / source
chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM psych_assess_head h1
        JOIN psych_assess_child c1 ON c1.psych_assess_head_id = h1.psych_assess_head_id
        JOIN psych_assess_topic tpa ON tpa.psych_assess_topic_id = h1.psych_assess_topic_id AND tpa.psych_assess_topic_name ILIKE '%teda%'
        JOIN psych_assess_head h2 ON h2.hn = h1.hn
          AND h2.date_assessment > h1.date_assessment
          AND h2.date_assessment <= h1.date_assessment + INTERVAL '6 months'
        JOIN psych_assess_child c2 ON c2.psych_assess_head_id = h2.psych_assess_head_id
        JOIN psych_assess_topic tpb ON tpb.psych_assess_topic_id = h2.psych_assess_topic_id AND tpb.psych_assess_topic_name ILIKE '%teda%'
        WHERE h1.hn = chronic_periodized.hn
          AND h1.date_assessment >= chronic_periodized.regdate - INTERVAL '6 months'
          AND h1.date_assessment <= chronic_periodized.regdate
          AND ((((c2.psych_assess_child_gm_year * 12 + c2.psych_assess_child_gm_month) > (c1.psych_assess_child_gm_year * 12 + c1.psych_assess_child_gm_month) OR (c2.psych_assess_child_fm_year * 12 + c2.psych_assess_child_fm_month) > (c1.psych_assess_child_fm_year * 12 + c1.psych_assess_child_fm_month) OR (c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) > (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) OR (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) > (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month) OR (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) > (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month)) AND ((c2.psych_assess_child_gm_year * 12 + c2.psych_assess_child_gm_month) >= (c1.psych_assess_child_gm_year * 12 + c1.psych_assess_child_gm_month) AND (c2.psych_assess_child_fm_year * 12 + c2.psych_assess_child_fm_month) >= (c1.psych_assess_child_fm_year * 12 + c1.psych_assess_child_fm_month) AND (c2.psych_assess_child_rl_year * 12 + c2.psych_assess_child_rl_month) >= (c1.psych_assess_child_rl_year * 12 + c1.psych_assess_child_rl_month) AND (c2.psych_assess_child_el_year * 12 + c2.psych_assess_child_el_month) >= (c1.psych_assess_child_el_year * 12 + c1.psych_assess_child_el_month) AND (c2.psych_assess_child_ps_year * 12 + c2.psych_assess_child_ps_month) >= (c1.psych_assess_child_ps_year * 12 + c1.psych_assess_child_ps_month))))
      ) AS flagged
    ) imp ON TRUE
-- outer cohort predicate
chronic_periodized.age_y <= 18
    AND EXISTS (
      SELECT 1
      FROM ovstdiag sdp
      WHERE sdp.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdp.icd10)), '.', ''), 3) IN ('G80'))
    )
    AND (EXISTS (
      SELECT 1
      FROM psych_therapy th
      JOIN ovst tv ON tv.vn = th.vn_an
      WHERE tv.hn = chronic_periodized.hn
        AND th.psych_therapy_date >= chronic_periodized.regdate - INTERVAL '6 months'
        AND th.psych_therapy_date <= chronic_periodized.regdate
    ) OR EXISTS (
      SELECT 1
      FROM psych_plan pp
      WHERE pp.hn = chronic_periodized.hn
        AND pp.psych_plan_date >= chronic_periodized.regdate - INTERVAL '6 months'
        AND pp.psych_plan_date <= chronic_periodized.regdate
    ))
```

- Same cohort and domain-pair rule as DM0301 but both assessments must sit under a psych_assess_topic named for TEDA4I. The TEDA4I binding is topic-name matching only, so the owner must confirm the TEDA4I topic naming in psych_assess_topic.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: clinicmember, ovst, ovstdiag, psych_assess_child, psych_assess_head, psych_assess_topic, psych_plan, psych_therapy. SQL SHA256: a690cd0eb1ca6ac1c94952cc68aaac109b13b2901f6603cf2bf8ca84232c3696

## DM0401

PDF physical 168; printed 159 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จํานวนผู้ป่วยเด็กสมาธิสั้น อายุ 6-14 ปี 11 เดือน 29 วัน ที่มารับการรักษาทั้งหมด ในช่วง 6 เดือนและมีคะแนน SNAP-IV ลดลงจากการประเมินโดยผู้ปกครอง (คน)

ตัวหาร / population: b = จํานวนผู้ป่วยเด็กสมาธิสั้น อายุ 6-14 ปี 11 เดือน 29 วัน ที่มารับการรักษาทั้งหมด ในช่วง 6 เดือน (คน)

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) ข 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'DM0401'
```

- ADHD improvement needs a parent SNAP-IV score pair; HOSxP psych_assess stores only question and answer references with no verified SNAP-IV binding (psych_assess_list.psych_assess_evalueate is ambiguous). Branch is branchExternal: the hospital must load one row per reporting-period anchor into reporting.thip_external_facts with numerator, denominator, value and source_system, computed from the SNAP-IV parent questionnaires.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: eb85739e41d0a4c221f6c4da0d03279234af56027a127a08cdbcbe6d467aac52

## DM0402

PDF physical 169; printed 160 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จํานวนผู้ป่วยเด็กและวัยรุ่นโรคซึมเศร้าที่อาการสงบหรือ คะแนน CDI น้อยกว่าหรือเท่ากับ 15 คะแนน (คน)

ตัวหาร / population: b = จํานวนผู้ป่วยเด็กและวัยรุ่นที่ได้รับการวินิจฉัยเป็นโรคซึมเศร้า ทั้งหมด ทั้งวินิจฉัยหลักและวินิจฉัยรอง (คน)

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) ข 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'DM0402'
```

- MDD remission needs the CDI score at 6 months or a documented clinical remission; psych_assess_cdi stores answer-type references only and depression_screen holds the 9Q score, a different instrument. Branch is branchExternal: the hospital must load one row per reporting-period anchor into reporting.thip_external_facts with numerator, denominator, value and source_system, computed from CDI follow-up scores or the clinic remission register.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: b7388742c6defa031df1961440ad1760a33d2e15169713310feeeb5b44883aa3

## DN0101

PDF physical 76; printed 67 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการจำหน่ายด้วยการเสียชีวิต ของผู้ป่วย Stroke จากทุกหอผู้ป่วยใน เดือนนั้น

ตัวหาร / population: b = จำนวนครั้งของการจำหน่ายทุกสถานะ ของผู้ป่วย Stroke จากทุกหอผู้ป่วยในช่วง เดือนเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE died)
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
LEFT(pdx, 3) IN ('I60', 'I61', 'I62', 'I63', 'I64', 'I65', 'I66', 'I67')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: c69516d5e7947f16c27bbee4817329cae4800caa32d21eeae214407e3edb5446

## DN0102

PDF physical 77; printed 68 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย Ischemic Stroke ที่ได้รับยาต้านเกล็ดเลือด ภายใน 48 ชั่วโมงหลังเกิด อาการ ในเดือนนั้น

ตัวหาร / population: b = จำนวนผู้ป่วย Ischemic Stroke ทั้งหมดที่รับไว้ในโรงพยาบาล ในช่วงเดือนเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%aspirin%' OR di.name ILIKE '%acetylsalicylic%' OR di.name ILIKE '%clopidogrel%' OR di.name ILIKE '%ticagrelor%' OR di.name ILIKE '%prasugrel%' OR di.name ILIKE '%dipyridamole%' OR di.name ILIKE '%cilostazol%')
            AND oi.rxdate >= periodized.regdate AND oi.rxdate <= periodized.regdate + INTERVAL '2 days'))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND LEFT(pdx, 3) = 'I63'
```

- Counts ischemic stroke admissions (Pdx I63, age 18 or over) with an antiplatelet drug item (aspirin, clopidogrel, ticagrelor, prasugrel, dipyridamole, cilostazol) ordered between admission day and admission day plus 2 days. The PDF times the dose from symptom onset within 48 hours; symptom onset time is not stored, so admission time is the clock start. Owner must confirm the antiplatelet item names.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, drugitems, ipt, iptdiag, opitemrece. SQL SHA256: 116b70b05e6f8cf418aa9ccfe83464aae29e22f8012af66423795399d68a915f

## DN0103

PDF physical 78; printed 69 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย Ischemic stroke ที่ได้รับ Antithrombotic drugs ขณะจำหน่ายออก จากโรงพยาบาล ในช่วงเดือนนั้น

ตัวหาร / population: b = จำนวนผู้ป่วย Ischemic stroke ที่จำหน่ายออกจากโรงพยาบาล ในช่วงเดือนเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%aspirin%' OR di.name ILIKE '%acetylsalicylic%' OR di.name ILIKE '%clopidogrel%' OR di.name ILIKE '%ticagrelor%' OR di.name ILIKE '%prasugrel%' OR di.name ILIKE '%dipyridamole%' OR di.name ILIKE '%cilostazol%' OR di.name ILIKE '%warfarin%' OR di.name ILIKE '%heparin%' OR di.name ILIKE '%enoxaparin%' OR di.name ILIKE '%dalteparin%' OR di.name ILIKE '%fondaparinux%' OR di.name ILIKE '%dabigatran%' OR di.name ILIKE '%rivaroxaban%' OR di.name ILIKE '%apixaban%' OR di.name ILIKE '%edoxaban%')
            AND oi.rxdate >= periodized.dchdate - INTERVAL '1 day' AND oi.rxdate <= periodized.dchdate))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND LEFT(pdx, 3) = 'I63' AND NOT died
```

- Counts ischemic stroke admissions discharged alive whose discharge day or day before prescription contains an antiplatelet or anticoagulant item (drugitems name match over both drug groups). The PDF asks for antithrombotic therapy at discharge after live home discharge; home status is approximated as alive discharge. Owner must confirm the antithrombotic item names and discharge window.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, drugitems, ipt, iptdiag, opitemrece. SQL SHA256: df66144bfffec80133787f7d63711fdd88e1d7d482d5da97a85e948258ba7dff

## DN0104

PDF physical 79; printed 70 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย Stroke ที่มีภาวะ AF or A-flutter และได้รับการบำบัดด้วย Anticoagulant ในช่วงเดือนนั้น

ตัวหาร / population: b = จำนวนผู้ป่วย Stroke ที่มีภาวะ AF or A-flutter ที่จำหน่ายออกจากโรงพยาบาล ในช่วงเดือนเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%warfarin%' OR di.name ILIKE '%heparin%' OR di.name ILIKE '%enoxaparin%' OR di.name ILIKE '%dalteparin%' OR di.name ILIKE '%fondaparinux%' OR di.name ILIKE '%dabigatran%' OR di.name ILIKE '%rivaroxaban%' OR di.name ILIKE '%apixaban%' OR di.name ILIKE '%edoxaban%')))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND LEFT(pdx, 3) IN ('I60', 'I61', 'I62', 'I63', 'I64') AND EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'I48'
        ) AND NOT died
```

- Counts stroke admissions (Pdx I60 to I64) with atrial fibrillation or flutter (secondary diagnosis I48) discharged alive that received an anticoagulant (warfarin, heparins, fondaparinux, or a direct oral anticoagulant) at any point in the stay. The PDF restricts to stays of 120 days or less, excludes palliative care and contraindicated patients, and prefers discharge therapy; those flags are not coded. Owner must confirm the anticoagulant item names and whether discharge-only therapy is required.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, drugitems, ipt, iptdiag, opitemrece. SQL SHA256: e70615d32e59be61006c6a096f00ca397c1ce523d1d66c335af59cdee5b797dc

## DN0105

PDF physical 80; printed 71 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย Stroke ที่จำหน่ายออกจากโรงพยาบาลในช่วงเดือนนั้น ที่ได้รับความรู้ ขณะอยู่ในโรงพยาบาล

ตัวหาร / population: b = จำนวนผู้ป่วย Stroke ที่จำหน่ายออกจากโรงพยาบาล ในช่วงเดือนเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE (
          EXISTS (
            SELECT 1
            FROM iptdiag sd
            WHERE sd.an = periodized.an
              AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('Z716', 'Z719', 'V6541', 'V6549')
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen scr
            JOIN ovst v ON v.vn = scr.vn
            WHERE v.an = periodized.an
              AND (
                scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
                OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
                OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
              )
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen_advice adv
            JOIN ovst v ON v.vn = adv.vn
            WHERE v.an = periodized.an
          )
        ))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND LEFT(pdx, 3) IN ('I60', 'I61', 'I62', 'I63', 'I64') AND NOT died
```

- Counts stroke admissions discharged alive with a health education proxy: counseling secondary diagnosis (Z716, Z719, V6541, V6549), opdscreen advice flags set on a linked visit, or any opdscreen_advice record. The PDF needs stroke-specific education (emergency activation, follow-up, risk factor and medication counselling) documented for the patient or caregiver; HOSxP has no stroke education checklist, so documentation proxies may over or under count. Owner must confirm which local documentation of stroke education to treat as evidence.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, opdscreen, opdscreen_advice, ovst. SQL SHA256: 90e6218e367c22230d2448cae1ed59d6518f462182a9f2ff77f7766e473e414d

## DN0106

PDF physical 81; printed 72 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยStroke ที่จำหน่ายออกจากโรงพยาบาลและการประเมินด้านเวชศาสตร์ฟื้นฟูเพื่อ ฟื้นฟูสมรรถภาพและได้รับการรักษาทางเวชศาสตร์ฟื้นฟู ภายใน72 ชั่วโมงหลังรับไว้ในโรงพยาบาล

ตัวหาร / population: b = จำนวนผู้ป่วย Stroke ที่จำหน่ายออกจากโรงพยาบาล ในเดือนเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ovst_rehab rb
          WHERE rb.an = periodized.an
            AND rb.service_date >= periodized.regdate
            AND rb.service_date::timestamp <= (periodized.regdate::timestamp + COALESCE(periodized.regtime, TIME '00:00:00') + INTERVAL '72 hours')
        ))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND LEFT(pdx, 3) IN ('I60', 'I61', 'I62', 'I63', 'I64') AND NOT died
```

- Counts stroke admissions discharged alive with a rehabilitation record (ovst_rehab on the admission) whose service_date falls within 72 hours of the admit timestamp. The PDF wants physiotherapy or rehabilitation assessment and treatment started within 72 hours once the patient is stable; stability and the assessment text are not structured and ovst_rehab keeps date granularity only. Owner must confirm ovst_rehab is the inpatient rehab register and the local timing convention.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, ovst_rehab. SQL SHA256: bc5cd99b95f44ab2db0151c124e69e5ce4db2f235891d01d43f189cd730147df

## DN0107

PDF physical 82; printed 73 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย Stroke ที่ต้องรับกลับเข้าโรงพยาบาลด้วยโรคหลอดเลือดสมองเดิม โดย ไม่ได้วางแผน ภายใน 28 วันหลังออกจากโรงพยาบาล

ตัวหาร / population: b = จำนวนผู้ป่วย Stroke ที่จำหน่ายออกจากโรงพยาบาล ในเดือนก่อนหน้านั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        ))
-- denominator (count)
COUNT(*) FILTER (WHERE NOT died)
-- outer FROM / source
periodized
-- outer cohort predicate
LEFT(pdx, 3) IN ('I60', 'I61', 'I62', 'I63', 'I64', 'I65', 'I66', 'I67')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: 58ebfaed0fc1c9f8a93ae6c576d5d25a5f89b5a53056b34ce654ad49f1b3799f

## DN0109

PDF physical 83; printed 74 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = ผลรวมระยะเวลาวันนอนของผู้ป่วย Stroke ทุกรายที่จำหน่ายในเดือนนั้น

ตัวหาร / population: b = จำนวน (คน) ผู้ป่วย Stroke ที่จำหน่ายในเดือนเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: วัน; formula: a/b. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (sum)
ROUND(SUM(los)::numeric, 2)
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
LEFT(pdx, 3) IN ('I60', 'I61', 'I62', 'I63', 'I64', 'I65', 'I66', 'I67')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: 181073a4ed52b15fdec56800d19579e8561a81e48aeb4460d0e464645d140b28

## DN0110

PDF physical 84; printed 75 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย Ischemic stroke ที่ได้รับ Thrombolytic agents ภายใน 60 นาที หลังมาถึงโรงพยาบาลแต่ละครั้ง ในช่วงเดือนนั้น

ตัวหาร / population: b = จำนวนผู้ป่วย Ischemic stroke ที่ได้รับ Thrombolytic agents ที่รับเข้ารักษาใน โรงพยาบาลในช่วงเดือนเดียวกันนั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          WHERE v.an = periodized.an
            AND er.do_stroke_needle = 'Y'
            AND er.enter_er_time IS NOT NULL
            AND er.stroke_needle_datetime IS NOT NULL
            AND er.stroke_needle_datetime >= er.enter_er_time
            AND EXTRACT(EPOCH FROM (er.stroke_needle_datetime - er.enter_er_time)) <= 3600) OR EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%streptokinase%' OR di.name ILIKE '%alteplase%' OR di.name ILIKE '%tenecteplase%' OR di.name ILIKE '%reteplase%' OR di.name ILIKE '%urokinase%')
            AND EXISTS (
              SELECT 1
              FROM ovst v
              JOIN er_regist er ON er.vn = v.vn
              WHERE v.an = periodized.an
                AND er.enter_er_time IS NOT NULL
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) >= er.enter_er_time
                AND (oi.rxdate::timestamp + COALESCE(oi.rxtime, TIME '00:00:00')) <= er.enter_er_time + INTERVAL '60 minutes'
            )))
-- denominator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM ovst v
          JOIN er_regist er ON er.vn = v.vn
          WHERE v.an = periodized.an
            AND er.do_stroke_needle = 'Y') OR EXISTS (
          SELECT 1
          FROM opitemrece oi
          JOIN drugitems di ON di.icode = oi.icode
          WHERE oi.an = periodized.an
            AND (di.name ILIKE '%streptokinase%' OR di.name ILIKE '%alteplase%' OR di.name ILIKE '%tenecteplase%' OR di.name ILIKE '%reteplase%' OR di.name ILIKE '%urokinase%')))
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND LEFT(pdx, 3) = 'I63'
```

- Counts ischemic stroke admissions receiving thrombolysis within 60 minutes of arrival (er_regist do_stroke_needle with stroke_needle_datetime within 3600 seconds of enter_er_time, or a fibrinolytic drug item given within 60 minutes of arrival) over admissions that received thrombolysis at all (do_stroke_needle or a fibrinolytic item). The PDF excludes thrombolytic contraindications and counts from arrival to needle for every treated patient; the contraindication exclusion is not coded. Owner must confirm which clock field (door_to_needle_second or the timestamps) is maintained.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, drugitems, er_regist, ipt, iptdiag, opitemrece, ovst. SQL SHA256: a1dab3b563230a40b9fecb93c25d6b8f1f8992b3eff2041c79da60042e60fdbe

## DN0301

PDF physical 85; printed 76 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยที่ทำ Craniotomy ที่ต้องรับกลับเข้าโรงพยาบาลโดยไม่ได้วางแผน ภายใน 28 วัน หลังออกจากโรงพยาบาล

ตัวหาร / population: b = จำนวนผู้ป่วยที่ทำ Craniotomy ที่จำหน่ายออกจากโรงพยาบาล ในเดือนก่อนหน้านั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        ))
-- denominator (count)
COUNT(*) FILTER (WHERE NOT died)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND LEFT(pdx, 3) IN ('S02', 'S06') AND EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(o.icd9)), '.', ''), 3) IN ('012', '013', '014', '015', '016')
        )
```

- Counts head injury admissions (Pdx S02 or S06, age 18 or over) with a craniotomy procedure (iptoprt icd9 in the 012 to 016 families) discharged alive and not readmitted within 28 days of discharge (any later ipt admission of the same hn) as the denominator; the numerator is those with such a readmission. The PDF denominator is the previous month discharge cohort and counts unplanned readmissions only (elective and planned returns excluded); HOSxP has no planned readmission flag and this branch buckets both counts by the discharge month of the craniotomy episode. Owner must confirm the craniotomy icd9 list and the unplanned convention.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, iptoprt. SQL SHA256: d7d3ddb876f58a44c7a108fcf8309ae0b6de2d66fd6b148057d5fe7ba5a1beac

## DN0302

PDF physical 86; printed 77 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของผู้ป่วยบาดเจ็บที่ศีรษะ ที่จำหน่ายด้วยการเสียชีวิต ภายใน 48 ชั่วโมง ในช่วงเดือนนั้น

ตัวหาร / population: b = จำนวนครั้งของผู้ป่วยบาดเจ็บที่ศีรษะ ที่จำหน่ายทุกสถานะ ในช่วงเดือนเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE died_within_48h)
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
pdx IN ('S060', 'S061', 'S062', 'S063', 'S064', 'S065', 'S066', 'S067', 'S068', 'S069')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: a780a82f9fce7a28bd50faec5165a1d79e0cc95869455e8bf8fc3b9fa9d56525

## DN0303

PDF physical 87; printed 78 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการผ่าตัดสมองในผู้ป่วยบาดเจ็บที่ศีรษะที่มี Intracranial injury ใน เดือนนั้น

ตัวหาร / population: b = จำนวนผู้ป่วยบาดเจ็บที่ศีรษะที่มี Intracranial injury ในช่วงเดือนเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          WHERE o.an = periodized.an
            AND LEFT(REPLACE(UPPER(TRIM(o.icd9)), '.', ''), 3) IN ('012', '013', '014', '015', '016')
        ))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND LEFT(pdx, 3) = 'S06'
```

- Counts intracranial injury admissions (Pdx S06, age 18 or over) that had at least one craniotomy (iptoprt icd9 012 to 016) over all such admissions. The PDF numerator is the number of craniotomy operations (multiple operations per patient each count) while one episode is counted once here, per the one row per episode grain. Owner must confirm the craniotomy icd9 list and whether operation counts are needed (they can be staged into reporting.thip_external_facts).
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, iptoprt. SQL SHA256: 720dd9f3fb06af01d347a6a24c5a28c60fb0e66324889f5f8097c3c5f4e25f94

## DO0202

PDF physical 123; printed 114 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการผ่าตัดเปลี่ยนข้อสะโพกที่ได้รับ prophylactic antibiotic ภายใน 1 ชั่วโมง ก่อนลงมีดผ่าตัด ใน 1เดือน

ตัวหาร / population: b = จำนวนครั้งของการผ่าตัดเปลี่ยนข้อสะโพกทั้งหมดในเดือนเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          JOIN opitemrece oi ON oi.an = o.an
          JOIN drugitems di ON di.icode = oi.icode
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8151', '8152', '8153')
            AND (di.antibiotic = 'Y' OR di.drugcategory ILIKE '%antibio%')
            AND EXTRACT(EPOCH FROM (
              (o.opdate + COALESCE(o.optime, TIME '00:00:00')) -
              (oi.vstdate + COALESCE(oi.vsttime, TIME '00:00:00'))
            )) BETWEEN 0 AND 3600))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8151', '8152', '8153')
    )
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, drugitems, ipt, iptdiag, iptoprt, opitemrece. SQL SHA256: 13a69a41becd79f7db468cbca20eee222e5ce93557303f811aa14a06a1db61fd

## DO0204

PDF physical 124; printed 115 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการติดเชื้อในข้อสะโพกหลังการผ่าตัดเปลี่ยนข้อสะโพก

ตัวหาร / population: b = จำนวนครั้งของการผ่าตัดเปลี่ยนข้อสะโพกทั้งหมดในเดือนเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'T845'
          UNION
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          LEFT JOIN iptdiag rd ON rd.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '365 days'
            AND (
              REPLACE(UPPER(TRIM(rs.pdx)), '.', '') = 'T845'
              OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') = 'T845'
            )))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8151', '8152', '8153')
    )
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, iptoprt. SQL SHA256: dc6a5de520661f6fc2702fb83ec7ed4b30b7355ffd4c266cb577f2ca52ec6aaf

## DO0205

PDF physical 125; printed 116 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการติดเชื้อในข้อสะโพกหลังการผ่าตัดเปลี่ยนข้อสะโพก

ตัวหาร / population: b = จำนวนครั้งของการผ่าตัดเปลี่ยนข้อสะโพกทั้งหมดในเดือนเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('T845', 'T814')
          UNION
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          LEFT JOIN iptdiag rd ON rd.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '90 days'
            AND (
              REPLACE(UPPER(TRIM(rs.pdx)), '.', '') IN ('T845', 'T814')
              OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') IN ('T845', 'T814')
            )))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8151', '8152', '8153')
    )
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, iptoprt. SQL SHA256: 2b823bd7b0dc1fb9260bba656d4ceba29ad84ea8c53f3fb0406f36859f53b7dd

## DO0302

PDF physical 126; printed 117 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการผ่าตัดเปลี่ยนข้อเข่าที่ได้รับ prophylactic antibiotic ภายใน 1 ชั่วโมง ก่อนลงมีดผ่าตัด ใน 1เดือน

ตัวหาร / population: b = จำนวนครั้งของการผ่าตัดเปลี่ยนข้อเข่าทั้งหมดในเดือนเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptoprt o
          JOIN opitemrece oi ON oi.an = o.an
          JOIN drugitems di ON di.icode = oi.icode
          WHERE o.an = periodized.an
            AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8154', '8155')
            AND (di.antibiotic = 'Y' OR di.drugcategory ILIKE '%antibio%')
            AND EXTRACT(EPOCH FROM (
              (o.opdate + COALESCE(o.optime, TIME '00:00:00')) -
              (oi.vstdate + COALESCE(oi.vsttime, TIME '00:00:00'))
            )) BETWEEN 0 AND 3600))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8154', '8155')
    )
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, drugitems, ipt, iptdiag, iptoprt, opitemrece. SQL SHA256: b6e0cbd54310b5293d876861d1a079f139062af96e70f6c27e490c2a493ba30c

## DO0303

PDF physical 127; printed 118 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการติดเชื้อในข้อเข่าหลังการผ่าตัดเปลี่ยนข้อเข่า

ตัวหาร / population: b = จำนวนครั้งของการผ่าตัดเปลี่ยนข้อเข่าทั้งหมด

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'T845'
          UNION
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          LEFT JOIN iptdiag rd ON rd.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '365 days'
            AND (
              REPLACE(UPPER(TRIM(rs.pdx)), '.', '') = 'T845'
              OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') = 'T845'
            )))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8154', '8155')
    )
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, iptoprt. SQL SHA256: 1792c52158ee5fe8cc1c7380c872568eca3db5993224378f2ce0de3380c6976e

## DO0304

PDF physical 128; printed 119 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการติดเชื้อในข้อเข่าหลังการผ่าตัดเปลี่ยนข้อเข่า

ตัวหาร / population: b = จำนวนครั้งของการผ่าตัดเปลี่ยนข้อเข่าทั้งหมด

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('T845', 'T814')
          UNION
          SELECT 1
          FROM ipt r
          JOIN an_stat rs ON rs.an = r.an
          LEFT JOIN iptdiag rd ON rd.an = r.an
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '90 days'
            AND (
              REPLACE(UPPER(TRIM(rs.pdx)), '.', '') IN ('T845', 'T814')
              OR REPLACE(UPPER(TRIM(rd.icd10)), '.', '') IN ('T845', 'T814')
            )))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
EXISTS (
      SELECT 1 FROM iptoprt o
      WHERE o.an = periodized.an
        AND REPLACE(UPPER(TRIM(o.icd9)), '.', '') IN ('8154', '8155')
    )
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, iptoprt. SQL SHA256: 6eea37f7683256fc93e1754d6ee7771345c42089d904cfea019589e3cb15a1ec

## DP0101

PDF physical 133; printed 124, 125 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยเบาหวานเบาหวานชนิดที่ 1 ในเด็กและวัยรุ่นที่อายุน้อยกว่า 18 ปี ที่ ควบคุมระดับน้ำตาลในเลือดได้ดีตามเกณฑ์ที่กำหนด ในช่วงเวลาหนึ่งปี

ตัวหาร / population: b = จำนวนผู้ป่วยเบาหวานเบาหวานชนิดที่ 1 ในเด็กและวัยรุ่นที่อายุน้อยกว่า 18 ปี ที่ขึ้น ทะเบียนรับการรักษากับโรงพยาบาลและมารับบริการทั้งหมดในช่วงปีเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (
        WHERE EXISTS (
          SELECT 1 FROM lab_order lo
          JOIN lab_head lh ON lh.lab_order_number = lo.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = periodized.hn
            AND li.lab_items_name ILIKE '%hba1c%'
            AND lh.order_date >= :start_date AND lh.order_date < :end_date
            AND CASE WHEN REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') ~ '^[0-9]*[.]?[0-9]+$' THEN CAST(REGEXP_REPLACE(lo.lab_order_result, '[^0-9.]', '', 'g') AS numeric) ELSE NULL END < 7.5
        )
      )
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y < 18 AND (LEFT(pdx, 3) = 'E10' OR pdx IN ('E891', 'P702'))
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, lab_head, lab_items, lab_order. SQL SHA256: 3858e284491fd99de4624a920b5af40735a1efc6a00647f74b9a8539059d6651

## DR0101

PDF physical 88; printed 79 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งการจำหน่ายด้วยการเสียชีวิตของผู้ป่วยโรคปอดบวม จากทุกหอผู้ป่วย

ตัวหาร / population: b = จำนวนครั้งของการจำหน่ายทุกสถานะของผู้ป่วยโรคปอดบวม (ในเดือนเดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE (LEFT(pdx, 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851') OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')) AND died OR (has_pneumonia_sdx AND died_from_pneumonia))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
LEFT(pdx, 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851') OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18') OR has_pneumonia_sdx
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: 2fe7085cc41268b29eee66797d41c9578e5ba62be4e6401b0d900f06edc1c4ac

## DR0102

PDF physical 89; printed 80 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยโรคปอดบวมที่มีการรับกลับเข้าโรงพยาบาลหลังจำหน่ายภายใน 28 วัน โดยไม่ได้วางแผน ในเดือนนั้น

ตัวหาร / population: b = จำนวนผู้ป่วยโรคปอดบวมที่จำหน่ายด้วยสถานะการอนุญาตให้กลับบ้าน (Status=improve) ในเดือนก่อนหน้านั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        ))
-- denominator (count)
COUNT(*) FILTER (WHERE NOT died)
-- outer FROM / source
periodized
-- outer cohort predicate
LEFT(pdx, 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851') OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18') OR has_pneumonia_sdx
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: 29344aec0e0b9ea365ad63bd61848a34487c16e81826239e8621026869a89c63

## DR0103

PDF physical 90; printed 81 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยโรคปอดบวมที่สูบบุหรี่ได้รับการแนะนำให้อดหรือเลิกบุหรี่

ตัวหาร / population: b = จำนวนผู้ป่วยโรคปอดบวมที่สูบบุหรี่ทั้งหมด (ในเดือนเดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE (
          EXISTS (
            SELECT 1
            FROM iptdiag sd
            WHERE sd.an = periodized.an
              AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen scr
            JOIN ovst v ON v.vn = scr.vn
            WHERE v.an = periodized.an
              AND (
                scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
                OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
                OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
                OR scr.advice7_note ILIKE '%smoke%'
                OR scr.advice7_note ILIKE '%สูบ%'
              )
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen_advice adv
            JOIN opdscreen_advice_item itm ON itm.opdscreen_advice_item_id = adv.opdscreen_advice_item_id
            JOIN ovst v ON v.vn = adv.vn
            WHERE v.an = periodized.an
              AND (
                itm.opdscreen_advice_item_name ILIKE '%smoke%'
                OR itm.opdscreen_advice_item_name ILIKE '%บุหรี่%'
              )
          )
        ))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
(LEFT(pdx, 4) IN ('J100', 'J110', 'J170', 'J171', 'J172', 'J173', 'J178', 'J850', 'J851') OR LEFT(pdx, 3) IN ('J12', 'J13', 'J14', 'J15', 'J16', 'J18')) AND (
          EXISTS (
            SELECT 1
            FROM iptdiag sd
            WHERE sd.an = periodized.an
              AND (
                LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
                OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
              )
          )
          OR EXISTS (
            SELECT 1
            FROM opdscreen scr
            JOIN ovst v ON v.vn = scr.vn
            WHERE v.an = periodized.an
              AND scr.smoking_type_id IN (2, 3)
          )
        )
```

- Counts pneumonia admissions of smokers (secondary diagnosis F17 or Z720, or opdscreen smoking_type_id 2 or 3) with documented cessation advice (Z716 secondary diagnosis, opdscreen advice flags or advice note text, or an opdscreen_advice item naming tobacco) over all smoking pneumonia admissions. The PDF needs advice documented for every smoker with pneumonia and lists no age limit; documentation evidence quality is local. Owner must confirm the smoking and advice mappings.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, opdscreen, opdscreen_advice, opdscreen_advice_item, ovst. SQL SHA256: 4f9c816c13fa1ded90cb5b7446630544815b1327c07f75ad71c09c5ff444ae3a

## DR0201

PDF physical 91; printed 82 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยวัณโรคปอดระยะแพร่เชื้อรายใหม่ที่เสียชีวิตในระหว่างการรักษาในช่วง 12 เดือน

ตัวหาร / population: b = จำนวนผู้ป่วยวัณโรคปอดเสมหะพบเชื้อรายใหม่ที่ขึ้นทะเบียนรักษา (ในรอบ ปีงบประมาณเดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE died)
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
pdx IN ('A15', 'A16')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: 1b1bbd4f09bea3f18e72e75a4d8b165e4b51b1dc69c9bf079ab4ae530e9c263e

## DR0202

PDF physical 92; printed 83 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย/ ผู้ติดเชื้อเอชไอวีที่ได้รับการคัดกรองวัณโรคปอด อย่างน้อย 1 ครั้ง ใน รอบปีงบประมาณ

ตัวหาร / population: b = จำนวนผู้ป่วย/ ผู้ติดเชื้อเอชไอวีและไม่อยู่ในระหว่างการรักษาวัณโรค (ในรอบ ปีงบประมาณเดียวกัน)

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: ovst.vn, clinic_visit.vn. Date candidates: clinicmember.dchdate, clinicmember.last_bp_date, clinicmember.last_hba1c_date, clinicmember.regdate, ovst.vstdate, tb_lab_examination_sputum.tb_lab_examination_sputum_date, tb_register.tb_register_date, tb_register.tb_register_receive_recomment_tb_date.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT clinicmember_id) FILTER (WHERE tb_scr.flagged)
-- denominator (count)
COUNT(DISTINCT clinicmember_id)
-- outer FROM / source
chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM tb_lab_examination_sputum ts
        WHERE ts.tb_register_id IN (
            SELECT tbrs.tb_register_id FROM tb_register tbrs WHERE tbrs.hn = chronic_periodized.hn
          )
          AND ts.tb_lab_examination_sputum_date >= chronic_periodized.regdate - INTERVAL '12 months'
          AND ts.tb_lab_examination_sputum_date <= chronic_periodized.regdate
      ) OR EXISTS (
        SELECT 1
        FROM clinic_visit cv
        JOIN ovst cvv ON cvv.vn = cv.vn
        WHERE cv.hn = chronic_periodized.hn
          AND cv.afb_check = 'Y'
          AND cvv.vstdate >= chronic_periodized.regdate - INTERVAL '12 months'
          AND cvv.vstdate <= chronic_periodized.regdate
      ) OR EXISTS (
        SELECT 1
        FROM tb_register tbr2
        WHERE tbr2.hn = chronic_periodized.hn
          AND tbr2.tb_register_receive_recomment_tb_date >= chronic_periodized.regdate - INTERVAL '12 months'
          AND tbr2.tb_register_receive_recomment_tb_date <= chronic_periodized.regdate
      ) AS flagged
    ) tb_scr ON TRUE
-- outer cohort predicate
(EXISTS (
      SELECT 1
      FROM arv_tx axh
      WHERE axh.hn = chronic_periodized.hn
    ) OR EXISTS (
      SELECT 1
      FROM ovstdiag sdh
      WHERE sdh.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdh.icd10)), '.', ''), 3) IN ('B20', 'B21', 'B22', 'B23', 'B24') OR REPLACE(UPPER(TRIM(sdh.icd10)), '.', '') IN ('Z21'))
    ))
    AND NOT EXISTS (
      SELECT 1
      FROM tb_register tba
      WHERE tba.hn = chronic_periodized.hn
        AND tba.tb_register_date >= chronic_periodized.regdate - INTERVAL '12 months'
        AND tba.tb_register_date <= chronic_periodized.regdate + INTERVAL '6 months'
    )
```

- Measures PLHIV without recent TB treatment whose TB screening is on file in the trailing 12 months, where screening is an AFB sputum examination, an afb_check clinic visit or the tb_register TB-screening advice date. The PDF also accepts symptom history and CXR which are not separately structured; the owner must confirm those screening channels or accept the recorded subset.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: arv_tx, clinic_visit, clinicmember, ovst, ovstdiag, tb_lab_examination_sputum, tb_register. SQL SHA256: e95e9596aa91ffa4b463a05aa54c038ed91a2c25e7b22aabee505e36589bdde6

## DR0203

PDF physical 93; printed 84 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยวัณโรคปอดพบเชื้อรายใหม่ที่ได้รับการรักษาหายรวมกับการรักษาครบ

ตัวหาร / population: b = จำนวนผู้ป่วยวัณโรคปอดพบเขื้อรายใหม่ที่ขึ้นทะเบียนรักษา (ในรอบปีงบประมาณเดียวกัน)

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: รอตรวจ SQL. Date candidates: clinicmember.dchdate, clinicmember.last_bp_date, clinicmember.last_hba1c_date, clinicmember.regdate, tb_register.tb_register_date, tb_register.tb_register_receive_recomment_hiv_date, tb_register.tb_register_start_date_treatment.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT clinicmember_id) FILTER (WHERE tdt.tb_discharge_type_name ILIKE '%หาย%' OR tdt.tb_discharge_type_name ILIKE '%ครบ%' OR tdt.tb_discharge_type_name ILIKE '%cure%' OR tdt.tb_discharge_type_name ILIKE '%complete%')
-- denominator (count)
COUNT(DISTINCT clinicmember_id)
-- outer FROM / source
chronic_periodized
      LEFT JOIN LATERAL (
      SELECT
        tbr.tb_register_id,
        tbr.tb_register_date,
        tbr.tb_register_start_date_treatment,
        tbr.tb_discharge_type_id,
        tbr.clinicmember_tb_patient_type_id,
        tbr.tb_result_sputum_id,
        tbr.tb_register_receive_recomment_hiv_date
      FROM tb_register tbr
      WHERE tbr.hn = chronic_periodized.hn
        AND tbr.tb_register_date >= chronic_periodized.regdate - INTERVAL '3 months'
        AND tbr.tb_register_date <= chronic_periodized.regdate + INTERVAL '3 months'
      ORDER BY ABS(tbr.tb_register_date - chronic_periodized.regdate)
      LIMIT 1
    ) tbr ON TRUE
    LEFT JOIN clinicmember_tb_patient_type tpt
      ON tpt.clinicmember_tb_patient_type_id = tbr.clinicmember_tb_patient_type_id
    LEFT JOIN tb_result_sputum trs
      ON trs.tb_result_sputum_id = tbr.tb_result_sputum_id
    LEFT JOIN tb_discharge_type tdt
      ON tdt.tb_discharge_type_id = tbr.tb_discharge_type_id
-- outer cohort predicate
tbr.tb_register_id IS NOT NULL
    AND (tpt.clinicmember_tb_patient_type_name ILIKE '%ใหม่%' OR tpt.clinicmember_tb_patient_type_name ILIKE '%new%')
    AND (trs.tb_result_sputum_name ILIKE '%บวก%' OR trs.tb_result_sputum_name ILIKE '%pos%')
```

- Measures TB registrations whose nearest tb_register episode within 3 months of the clinic registration is a new case (patient type name) with a positive sputum result at registration and whose discharge type name signals cure or completion. The PDF evaluates treatment outcomes 12 months back and the anchor is the clinicmember registration date rather than tb_register_date; the owner must confirm the patient-type and outcome name matching in clinicmember_tb_patient_type, tb_result_sputum and tb_discharge_type.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: clinicmember, clinicmember_tb_patient_type, tb_discharge_type, tb_register, tb_result_sputum. SQL SHA256: 50d45d35abd44088658011d20c69b254b3386577356dd143be9cb5795fb95686

## DR0204

PDF physical 94; printed 85 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยวัณโรคปอดที่ได้รับการคัดกรอง HIV ทั้งโดยวิธี VCT, DCT, PICT

ตัวหาร / population: b = จำนวนผู้ป่วยวัณโรคปอดทั้งหมด (ในรอบปีงบประมาณเดียวกัน)

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: lab_order.lab_order_number, lab_head.lab_order_number, lab_items.lab_items_code, lab_order.lab_items_code. Date candidates: clinicmember.dchdate, clinicmember.last_bp_date, clinicmember.last_hba1c_date, clinicmember.regdate, lab_head.order_date, tb_register.tb_register_date, tb_register.tb_register_receive_recomment_hiv_date, tb_register.tb_register_start_date_treatment.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT clinicmember_id) FILTER (WHERE hiv_scr.flagged)
-- denominator (count)
COUNT(DISTINCT clinicmember_id)
-- outer FROM / source
chronic_periodized
      LEFT JOIN LATERAL (
      SELECT
        tbr.tb_register_id,
        tbr.tb_register_date,
        tbr.tb_register_start_date_treatment,
        tbr.tb_discharge_type_id,
        tbr.clinicmember_tb_patient_type_id,
        tbr.tb_result_sputum_id,
        tbr.tb_register_receive_recomment_hiv_date
      FROM tb_register tbr
      WHERE tbr.hn = chronic_periodized.hn
        AND tbr.tb_register_date >= chronic_periodized.regdate - INTERVAL '3 months'
        AND tbr.tb_register_date <= chronic_periodized.regdate + INTERVAL '3 months'
      ORDER BY ABS(tbr.tb_register_date - chronic_periodized.regdate)
      LIMIT 1
    ) tbr ON TRUE
    LEFT JOIN clinicmember_tb_patient_type tpt
      ON tpt.clinicmember_tb_patient_type_id = tbr.clinicmember_tb_patient_type_id
    LEFT JOIN tb_result_sputum trs
      ON trs.tb_result_sputum_id = tbr.tb_result_sputum_id
    LEFT JOIN tb_discharge_type tdt
      ON tdt.tb_discharge_type_id = tbr.tb_discharge_type_id
    LEFT JOIN LATERAL (
      SELECT
        (tbr.tb_register_receive_recomment_hiv_date IS NOT NULL) OR EXISTS (
          SELECT 1
          FROM lab_head lh
          JOIN lab_order lo ON lo.lab_order_number = lh.lab_order_number
          JOIN lab_items li ON li.lab_items_code = lo.lab_items_code
          WHERE lh.hn = chronic_periodized.hn
            AND (li.lab_items_name ILIKE '%hiv%' OR li.lab_items_name ILIKE '%เอชไอวี%')
            AND lh.order_date >= chronic_periodized.regdate - INTERVAL '12 months'
            AND lh.order_date <= chronic_periodized.regdate
        ) AS flagged
    ) hiv_scr ON TRUE
-- outer cohort predicate
tbr.tb_register_id IS NOT NULL
```

- Measures TB registrations whose tb_register episode records an HIV screening signal: the receive_recomment_hiv_date column or an HIV lab item in the trailing 12 months. The PDF counts VCT, DCT and PICT counselling channels which may not reach the lab or that date column, so the owner must confirm the counselling record source (for example arv_counselling).
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: clinicmember, clinicmember_tb_patient_type, lab_head, lab_items, lab_order, tb_discharge_type, tb_register, tb_result_sputum. SQL SHA256: 57dbcd471e111eacb6ea2e7a5fa20a2af7f3f9468e54180f53d528c2e918676b

## DR0205

PDF physical 95; printed 86 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยวัณโรคปอดที่มีผลเลือดเอชไอวีบวกได้รับการรักษาด้วยยาต้านไวรัส

ตัวหาร / population: b = จำนวนผู้ป่วยวัณโรคปอดที่มีผลเลือดเอชไอวีบวกทั้งหมด (ในรอบปีงบประมาณ เดียวกัน)

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: รอตรวจ SQL. Date candidates: arv_tx.date_entry, clinicmember.dchdate, clinicmember.last_bp_date, clinicmember.last_hba1c_date, clinicmember.regdate, tb_register.tb_register_date, tb_register.tb_register_receive_recomment_hiv_date, tb_register.tb_register_start_date_treatment.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT clinicmember_id) FILTER (WHERE art_started.flagged)
-- denominator (count)
COUNT(DISTINCT clinicmember_id)
-- outer FROM / source
chronic_periodized
      LEFT JOIN LATERAL (
      SELECT
        tbr.tb_register_id,
        tbr.tb_register_date,
        tbr.tb_register_start_date_treatment,
        tbr.tb_discharge_type_id,
        tbr.clinicmember_tb_patient_type_id,
        tbr.tb_result_sputum_id,
        tbr.tb_register_receive_recomment_hiv_date
      FROM tb_register tbr
      WHERE tbr.hn = chronic_periodized.hn
        AND tbr.tb_register_date >= chronic_periodized.regdate - INTERVAL '3 months'
        AND tbr.tb_register_date <= chronic_periodized.regdate + INTERVAL '3 months'
      ORDER BY ABS(tbr.tb_register_date - chronic_periodized.regdate)
      LIMIT 1
    ) tbr ON TRUE
    LEFT JOIN clinicmember_tb_patient_type tpt
      ON tpt.clinicmember_tb_patient_type_id = tbr.clinicmember_tb_patient_type_id
    LEFT JOIN tb_result_sputum trs
      ON trs.tb_result_sputum_id = tbr.tb_result_sputum_id
    LEFT JOIN tb_discharge_type tdt
      ON tdt.tb_discharge_type_id = tbr.tb_discharge_type_id
    LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM arv_tx ax
        WHERE ax.hn = chronic_periodized.hn
          AND ax.date_entry <= chronic_periodized.regdate + INTERVAL '6 months'
      ) AS flagged
    ) art_started ON TRUE
-- outer cohort predicate
tbr.tb_register_id IS NOT NULL
    AND (EXISTS (
      SELECT 1
      FROM arv_tx axh
      WHERE axh.hn = chronic_periodized.hn
    ) OR EXISTS (
      SELECT 1
      FROM ovstdiag sdh
      WHERE sdh.hn = chronic_periodized.hn
        AND (LEFT(REPLACE(UPPER(TRIM(sdh.icd10)), '.', ''), 3) IN ('B20', 'B21', 'B22', 'B23', 'B24') OR REPLACE(UPPER(TRIM(sdh.icd10)), '.', '') IN ('Z21'))
    ))
```

- Measures HIV-positive TB registrations (tb_register episode plus HIV cohort evidence) with an arv_tx record starting within 6 months after registration. The PDF wants ART started within 6 months of TB treatment and sustained more than 6 months; the branch only sees the ARV record start, so the owner must confirm arv_tx.date_entry semantics and the TB-to-ART clock start.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: arv_tx, clinicmember, clinicmember_tb_patient_type, ovstdiag, tb_discharge_type, tb_register, tb_result_sputum. SQL SHA256: 774d7349622f7895ca4a8167407b060736386f5834e111560ba5c9cf42460189

## DR0301

PDF physical 96; printed 87 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย Asthma ที่ต้องรับกลับเข้าโรงพยาบาลโดยไม่ได้วางแผน ภายใน 28 วัน หลังออกจากโรงพยาบาล ในเดือนนั้น

ตัวหาร / population: b = จำนวนผู้ป่วย Asthma ที่จำหน่ายด้วยสถานะการอนุญาตให้กลับบ้าน ในเดือนก่อน หน้านั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        ))
-- denominator (count)
COUNT(*) FILTER (WHERE NOT died)
-- outer FROM / source
periodized
-- outer cohort predicate
LEFT(pdx, 3) IN ('J45', 'J46')
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: 3371cc4c4ef8dd449bcf278173c83837210bc3a0d45189990230d81d37aff782

## DR0302

PDF physical 97; printed 88 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย Asthma ที่สูบบุหรี่ได้รับการแนะนำให้อดหรือเลิกบุหรี่

ตัวหาร / population: b = จำนวนผู้ป่วย Asthma ที่สูบบุหรี่ทั้งหมด (ในเดือนเดียวกัน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
          UNION
          SELECT 1
          FROM opdscreen scr
          JOIN ovst v ON v.vn = scr.vn
          WHERE v.an = periodized.an
            AND (
              scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
              OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
              OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
              OR scr.advice7_note ILIKE '%smoke%' OR scr.advice7_note ILIKE '%สูบ%'
            )))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
LEFT(pdx, 3) IN ('J45', 'J46')
      AND (
        EXISTS (
          SELECT 1 FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND (LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17' OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720')
        )
        OR EXISTS (
          SELECT 1 FROM opdscreen scr
          JOIN ovst v ON v.vn = scr.vn
          WHERE v.an = periodized.an
            AND scr.smoking_type_id IN (2, 3)
        )
      )
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, opdscreen, ovst. SQL SHA256: cc58223558005a20d1a4690be22a07b560eb15935603d546851a807c0446eb42

## DR0401

PDF physical 98; printed 89 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วย COPD ที่ต้องรับกลับเข้าโรงพยาบาลโดยไม่ได้วางแผน ภายใน 28 วัน หลังออกจากโรงพยาบาล

ตัวหาร / population: b = จำนวนผู้ป่วย COPD ที่จำหน่ายด้วยสถานะการอนุญาตให้กลับบ้าน ในเดือนก่อนหน้า นั้น

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE NOT died AND EXISTS (
          SELECT 1
          FROM ipt r
          WHERE r.hn = periodized.hn
            AND r.an <> periodized.an
            AND r.regdate > periodized.dchdate
            AND r.regdate <= periodized.dchdate + INTERVAL '28 days'
        ))
-- denominator (count)
COUNT(*) FILTER (WHERE NOT died)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND LEFT(pdx, 3) = 'J44'
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: 0a7261db0fd276025c15420aca94a190b34062379193867cfcb839bb96e09de4

## DR0403

PDF physical 99; printed 90 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการจำหน่ายด้วยการเสียชีวิตของผู้ป่วย COPD จากทุกหอผู้ป่วย

ตัวหาร / population: b = จำนวนครั้งของการจำหน่ายทุกสถานะของผู้ป่วย COPD จากทุกหอผู้ป่วยในช่วงเวลา เดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE died)
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND LEFT(pdx, 3) = 'J44'
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag. SQL SHA256: a5b29405b1ac83e809e8338d3a9a618ae129a56403835835d834ff4541a1d6fd

## DR0404

PDF physical 100; printed 91 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยโรคปอดอุดกั้นเรื้อรัง ที่มารับบริการแบบผู้ป่วยนอกของโรงพยาบาล ที่ยัง สูบบุหรี่อยู่ หรือ เลิกบุหรี่ต่อเนื่องมาเป็นระยะเวลาไม่เกิน 12 เดือน (คน)

ตัวหาร / population: b = จำนวนผู้ป่วยโรคปอดอุดกั้นเรื้อรัง ที่มารับบริการแบบผู้ป่วยนอกของโรงพยาบาล ทั้งหมด (คน)

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
          SELECT 1
          FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
          UNION
          SELECT 1
          FROM opdscreen scr
          JOIN ovst v ON v.vn = scr.vn
          WHERE v.an = periodized.an
            AND (
              scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
              OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
              OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
              OR scr.advice7_note ILIKE '%smoke%' OR scr.advice7_note ILIKE '%สูบ%'
            )))
-- denominator (count)
COUNT(*)
-- outer FROM / source
periodized
-- outer cohort predicate
age_y >= 18 AND LEFT(pdx, 3) = 'J44'
      AND (
        EXISTS (
          SELECT 1 FROM iptdiag sd
          WHERE sd.an = periodized.an
            AND (LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17' OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720')
        )
        OR EXISTS (
          SELECT 1 FROM opdscreen scr
          JOIN ovst v ON v.vn = scr.vn
          WHERE v.an = periodized.an
            AND scr.smoking_type_id IN (2, 3)
        )
      )
```

- ต้องยืนยันนิยามและ local workflow กับโรงพยาบาล
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, opdscreen, ovst. SQL SHA256: 7beb66217f216f94ea4fe8241e4c5f945a38e3e82cf024af78e5895184b1b4c2

## DS0101

PDF physical 135; printed 126 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ติดยาเสพติดกลุ่ม Methamphetamine ที่หยุดเสพต่อเนื่อง 3 เดือนหลัง จำหน่ายจากการบำบัดรักษา

ตัวหาร / population: b = จำนวนผู้ติดยาเสพติดกลุ่ม Methamphetamine ที่เข้ารับการบำบัดรักษาในระบบ สมัครใจ แบบผู้ป่วยนอก ที่จำหน่ายจากการบำบัดรักษาทั้งหมดในไตรมาสก่อนหน้า

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'DS0101'
```

- Methamphetamine three-month abstinence after discharge is a verdict from the national addiction programme follow-up forms, not a structured HOSxP fact (psych_screen_addict holds screening, not the follow-up abstinence verdict). Branch is branchExternal: the hospital must load one row per reporting-period anchor into reporting.thip_external_facts with numerator, denominator, value and source_system, from the addiction treatment database follow-up outcomes.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 47bf4d3ad1d4c225788f3c3c92d4073bd36716f8dfe1331f8b26c049d25e0a4d

## DS0201

PDF physical 136; printed 127 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ติดสุราที่เข้ารับการบำบัดรักษาแบบผู้ป่วยนอก ที่หยุดเสพต่อเนื่อง 3 เดือน หลังจำหน่ายจากการบำบัดรักษา

ตัวหาร / population: b = จำนวนผู้ติดสุราที่เข้ารับการบำบัดรักษาแบบผู้ป่วยนอก ที่จำหน่ายจากการบำบัดรักษา ทั้งหมดในไตรมาสก่อนหน้า

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'DS0201'
```

- Alcohol three-month abstinence after discharge is a follow-up verdict outside HOSxP, same gap as DS0101. Branch is branchExternal: the hospital must load one row per reporting-period anchor into reporting.thip_external_facts with numerator, denominator, value and source_system, from the addiction treatment database follow-up outcomes.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 66716b7c6a15d4e1a530c58c16ddf5a033f8d4d9e0818bbcc8de4551c29c00e4

## DS0301

PDF physical 137; printed 128 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ติดยาสูบที่เข้ารับการบำบัดรักษาแบบผู้ป่วยนอก หยุดเสพต่อเนื่อง 3 เดือน หลังจำหน่ายจากการบำบัดรักษา

ตัวหาร / population: b = จำนวนผู้ติดยาสูบที่เข้ารับการบำบัดรักษาแบบผู้ป่วยนอก ที่จำหน่ายจากการ บำบัดรักษาทั้งหมดในไตรมาสก่อนหน้า

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'DS0301'
```

- Tobacco three-month abstinence after discharge is a follow-up verdict outside HOSxP, same gap as DS0101. Branch is branchExternal: the hospital must load one row per reporting-period anchor into reporting.thip_external_facts with numerator, denominator, value and source_system, from the addiction treatment database follow-up outcomes.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: c8c342815303f0b77c9272c96f3c1fec6decf3ef2a28e415fd8990a1598f843e

## DS0401

PDF physical 138; printed 129 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยนอก ระบบสมัครใจที่เริ่มบำบัดรักษาในแต่ละไตรมาสของปีงบประมาณที่ ผ่านมา ได้รับการบำบัดรักษาด้วยเมทาโดนระยะยาว และคงอยู่ในการรักษาจนครบ 1 ปี ขึ้นไป ในแต่ละไตรมาสของปีงบประมาณปัจจุบัน

ตัวหาร / population: b = จำนวนผู้ป่วยนอก ระบบสมัครใจที่เริ่มการบำบัดรักษาในแต่ละไตรมาสของ ปีงบประมาณที่ผ่านมา ได้รับการบำบัดรักษาด้วยเมทาโดนระยะยาวทั้งหมด

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: drugitems.icode, opitemrece.icode. Date candidates: clinicmember.dchdate, clinicmember.last_bp_date, clinicmember.last_hba1c_date, clinicmember.regdate, opitemrece.vstdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT clinicmember_id) FILTER (WHERE mmt_retained.flagged)
-- denominator (count)
COUNT(DISTINCT clinicmember_id)
-- outer FROM / source
chronic_periodized
      LEFT JOIN LATERAL (
      SELECT EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.hn = chronic_periodized.hn
          AND (di.name ILIKE '%methadone%')
          AND oi.vstdate >= chronic_periodized.regdate + INTERVAL '11 months'
          AND oi.vstdate <= chronic_periodized.regdate + INTERVAL '15 months'
      ) AS flagged
    ) mmt_retained ON TRUE
-- outer cohort predicate
EXISTS (
      SELECT 1
      FROM opitemrece oi0
      JOIN drugitems di0 ON di0.icode = oi0.icode
      WHERE oi0.hn = chronic_periodized.hn
        AND di0.name ILIKE '%methadone%'
        AND oi0.vstdate >= chronic_periodized.regdate - INTERVAL '3 months'
        AND oi0.vstdate <= chronic_periodized.regdate + INTERVAL '3 months'
    )
```

- Measures members whose first methadone dispensing (opitemrece plus drugitems name match) falls within 3 months of the clinic registration (denominator: MMT starts) and who collect methadone again 11 to 15 months later (numerator: retained at one year). The PDF counts voluntary-system outpatients started in the previous fiscal year quarters, requires no gap longer than 1 month and excludes arrest, death and transfer; the branch cannot verify the gap rule or those exclusions, so the owner must confirm the methadone item set, the MMT start anchor and accept the retention proxy or stage the programme outcomes.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: clinicmember, drugitems, opitemrece. SQL SHA256: 672de1d37d87157ac12f3da260f28066d111cf50218792010d69135d7572bcb8

## HC0101

PDF physical 279; printed 270 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของผู้ป่วยโรค Asthma ที่มารับการรักษาที่ ER ในรอบ 1 ปี

ตัวหาร / population: b = จำนวนผู้ป่วยโรค Asthma ทั้งหมดที่มารับการรักษาที่ OPD อย่างต่อเนื่องอย่างน้อย 2 ครั้ง/ปี ในรอบปีเดียวกัน

Grain: distinct HN within reporting window (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: อัตรา (ครั้ง : คน); formula: a/b. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE opd_periodized.enter_er_time IS NOT NULL)
-- denominator (count)
COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      SELECT COUNT(DISTINCT v2.vn)
      FROM ovst v2
      JOIN ovstdiag sd2 ON sd2.vn = v2.vn
      WHERE v2.hn = opd_periodized.hn
        AND v2.vstdate >= :start_date
        AND v2.vstdate < :end_date
        AND LEFT(REPLACE(UPPER(TRIM(sd2.icd10)), '.', ''), 3) IN ('J45', 'J46')
    ) >= 2)
-- outer FROM / source
opd_periodized
-- outer cohort predicate
(
      LEFT(pdx, 3) IN ('J45', 'J46')
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J45', 'J46')
      )
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J45', 'J46')
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN ('J45', 'J46')
      )
    )
```

- Per fiscal year: numerator = ER attendances (er_regist clock present on the ovst visit) of asthma patients (J45, J46 on the visit or anywhere in the reporting range, OPD or IPD); denominator = distinct asthma patients with at least 2 asthma-coded OPD visits in the reporting range. Value is a plain a over b (no x100 per thipKpiRules). The printed title is about self-care ability of patients or relatives while the printed numerator and denominator measure ER reliance versus continuous OPD follow-up; the hospital owner must confirm which reading governs and how continuous care (at least 2 visits per year) is certified locally. Person counts use the reporting-range params, so run one reporting period per execution for exact person denominators.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: er_regist, ipt, iptdiag, ovst, ovstdiag, patient. SQL SHA256: 8a369149434d82d8e17d1de2b8ce5223bdb361b874268a293b88db5139b74e50

## HC0102

PDF physical 280; printed 271 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยโรค COPD ที่มารับการรักษาที่ ER มากกว่าหรือเท่ากับ 3 ครั้งต่อปี

ตัวหาร / population: b = จำนวนผู้ป่วยโรค COPD ทั้งหมดที่มารับการรักษาอย่างต่อเนื่องอย่างน้อย 2 ครั้งต่อปี

Grain: distinct HN within reporting window (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      SELECT COUNT(DISTINCT v3.vn)
      FROM ovst v3
      JOIN er_regist er3 ON er3.vn = v3.vn
      WHERE v3.hn = opd_periodized.hn
        AND v3.vstdate >= :start_date
        AND v3.vstdate < :end_date
    ) >= 3)
-- denominator (count)
COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      SELECT COUNT(DISTINCT v4.vn)
      FROM ovst v4
      JOIN ovstdiag sd4 ON sd4.vn = v4.vn
      WHERE v4.hn = opd_periodized.hn
        AND v4.vstdate >= :start_date
        AND v4.vstdate < :end_date
        AND LEFT(REPLACE(UPPER(TRIM(sd4.icd10)), '.', ''), 3) = 'J44'
    ) >= 2)
-- outer FROM / source
opd_periodized
-- outer cohort predicate
(
      LEFT(pdx, 3) IN ('J44')
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J44')
      )
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J44')
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN ('J44')
      )
    )
```

- Per fiscal year: numerator = distinct COPD patients (J44) with at least 3 ER visits in the reporting range; denominator = distinct COPD patients with at least 2 COPD-coded OPD visits in the reporting range. Same title-versus-definition gap as HC0101 (self-care ability) and the same one-reporting-period execution caveat for person counts.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: er_regist, ipt, iptdiag, ovst, ovstdiag, patient. SQL SHA256: 9eb79a729e001d491c8546724746b8ee43a93145722f03d841ad11c6ff055359

## HE0101

PDF physical 273; printed 264 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนบุคลากรได้รับการตรวจร่างกายประจำปี

ตัวหาร / population: b = จำนวนบุคลากรทั้งหมด

Grain: staff / month aggregate (candidate). Key candidates: emp.emp_id, emp.emp_cid. Date candidates: emp.emp_work_begindate, emp.emp_resign_enddate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.had_checkup)
-- denominator (count)
COUNT(DISTINCT hr.staff_key)
-- outer FROM / source
(
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (EXISTS (
            SELECT 1
            FROM patient pp
            JOIN opdscreen scr ON scr.hn = pp.hn
            WHERE pp.cid = e.emp_cid
              AND scr.vstdate >= months.work_month
              AND scr.vstdate < months.work_month + INTERVAL '1 month'
              AND scr.checkup = '1'
          )) AS had_checkup
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
        WHERE e.emp_work_begindate IS NULL OR e.emp_resign_enddate IS NULL
          OR e.emp_resign_enddate >= e.emp_work_begindate
      ) hr
-- outer cohort predicate
TRUE
```

- Measures: Employees active in the fiscal year with at least one linked screening visit flagged as a health check (opdscreen.checkup) in that month, over all employees active in the fiscal year (one row per employee per active month, COUNT(DISTINCT staff_key)). PDF beyond the branch: the printed entitlement split (civil servants and permanent staff under the Ministry of Finance entitlement, temporary staff under the organization policy) and the exact annual check-up items. that opdscreen.checkup = 1 marks the annual health check-up (otherwise point the numerator at the health-check clinic or visit type) and whether checks done under the Ministry of Finance entitlement are captured in HOSxP at all. Confirm with the hospital owner: the employee to visit linkage runs emp.emp_cid = patient.cid and then patient.hn to the clinical rows; employees whose citizen id is missing or differs from their patient record are invisible to the numerator (they still count in b), and screening recorded outside the HOSxP visit flow is missed. If the linkage is not reliable in local data, stage the indicator from the employee health-check register into reporting.thip_external_facts instead (one row per annual reporting anchor with period_start, numerator, denominator, value, source_system).
- ทะเบียน emp เป็น candidate; CID ใช้เชื่อมเหตุการณ์ด้วย EXISTS ไม่ตัดเจ้าหน้าที่ CID ว่างออกจากทะเบียนหลัก; checkup=1 ยังเป็น local proxy; วันที่สิ้นสุดก่อนเริ่มงานไม่สร้าง employee-month ต้องตรวจทะเบียนกับ HR
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- วันเริ่ม/สิ้นสุดงานว่างยังใช้ fallback ในสูตรเดิม; ยอดฐานแยก unknown temporal; สิ้นสุดก่อนเริ่มงานถูกตัดจาก employee-month; ขอบเขตวันสิ้นสุดและทะเบียนครบต้องยืนยัน HR

Source tables: emp, emp_position_main, opdscreen, patient. SQL SHA256: 26ddf4c9f3145f37f2cd62e31edd41ead56608f4bd3b25200935c8053b5824d9

## HE0102

PDF physical 274; printed 265 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนบุคลากรที่มี BMI เกินเกณฑ์มาตรฐาน

ตัวหาร / population: b = จำนวนบุคลากรที่ได้รับการตรวจประเมินหาค่าดัชนีมวลกายทั้งหมด

Grain: staff / month aggregate (candidate). Key candidates: emp.emp_id, emp.emp_cid. Date candidates: emp.emp_work_begindate, emp.emp_resign_enddate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.bmi_over)
-- denominator (count)
COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.bmi_measured)
-- outer FROM / source
(
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (EXISTS (
            SELECT 1
            FROM patient pp
            JOIN opdscreen scr ON scr.hn = pp.hn
            WHERE pp.cid = e.emp_cid
              AND scr.vstdate >= months.work_month
              AND scr.vstdate < months.work_month + INTERVAL '1 month'
              AND scr.bmi IS NOT NULL
          )) AS bmi_measured,
          (EXISTS (
            SELECT 1
            FROM patient pp
            JOIN opdscreen scr ON scr.hn = pp.hn
            WHERE pp.cid = e.emp_cid
              AND scr.vstdate >= months.work_month
              AND scr.vstdate < months.work_month + INTERVAL '1 month'
              AND scr.bmi >= 23
          )) AS bmi_over
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
        WHERE e.emp_work_begindate IS NULL OR e.emp_resign_enddate IS NULL
          OR e.emp_resign_enddate >= e.emp_work_begindate
      ) hr
-- outer cohort predicate
TRUE
```

- Measures: Employees with at least one linked screening visit carrying opdscreen.bmi at or above 23.0, over employees with at least one linked BMI measurement, in the fiscal year. PDF beyond the branch: BMI measured together with the annual health check-up from weight and height, per the printed assessment protocol. that opdscreen.bmi is maintained for employee check-ups (or that height and weight are, so the ratio can be derived) and that the check-up window matches the annual campaign. Confirm with the hospital owner: the employee to visit linkage runs emp.emp_cid = patient.cid and then patient.hn to the clinical rows; employees whose citizen id is missing or differs from their patient record are invisible to the numerator (they still count in b), and screening recorded outside the HOSxP visit flow is missed. If the linkage is not reliable in local data, stage the indicator from the employee health-check register into reporting.thip_external_facts instead (one row per annual reporting anchor with period_start, numerator, denominator, value, source_system).
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- วันเริ่ม/สิ้นสุดงานว่างยังใช้ fallback ในสูตรเดิม; ยอดฐานแยก unknown temporal; สิ้นสุดก่อนเริ่มงานถูกตัดจาก employee-month; ขอบเขตวันสิ้นสุดและทะเบียนครบต้องยืนยัน HR

Source tables: emp, emp_position_main, opdscreen, patient. SQL SHA256: 8de2491f2f99a1b5e66ccc66ebbf7d02052f69a166e0649b96062bb3d422d665

## HE0103

PDF physical 275; printed 266 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนบุคลากรที่มีพฤติกรรมการสูบบุหรี่

ตัวหาร / population: b = จำนวนบุคลากรทั้งหมด

Grain: staff / month aggregate (candidate). Key candidates: emp.emp_id, emp.emp_cid. Date candidates: emp.emp_work_begindate, emp.emp_resign_enddate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.smoker)
-- denominator (count)
COUNT(DISTINCT hr.staff_key)
-- outer FROM / source
(
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (EXISTS (
            SELECT 1
            FROM patient pp
            JOIN opdscreen scr ON scr.hn = pp.hn
            WHERE pp.cid = e.emp_cid
              AND scr.vstdate >= months.work_month
              AND scr.vstdate < months.work_month + INTERVAL '1 month'
              AND scr.smoking_type_id IN (2, 3)
          )) AS smoker
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
        WHERE e.emp_work_begindate IS NULL OR e.emp_resign_enddate IS NULL
          OR e.emp_resign_enddate >= e.emp_work_begindate
      ) hr
-- outer cohort predicate
TRUE
```

- Measures: Employees with at least one linked screening visit whose opdscreen.smoking_type_id marks a current smoker (the same smoking predicate as the registered query library), over all employees active in the fiscal year. PDF beyond the branch: smoking behavior as assessed in the annual health check-up questionnaire. the installed smoking_type_id dictionary (the branch assumes 2 and 3 are current-smoker values) and that the annual check-up records it. Confirm with the hospital owner: the employee to visit linkage runs emp.emp_cid = patient.cid and then patient.hn to the clinical rows; employees whose citizen id is missing or differs from their patient record are invisible to the numerator (they still count in b), and screening recorded outside the HOSxP visit flow is missed. If the linkage is not reliable in local data, stage the indicator from the employee health-check register into reporting.thip_external_facts instead (one row per annual reporting anchor with period_start, numerator, denominator, value, source_system).
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- วันเริ่ม/สิ้นสุดงานว่างยังใช้ fallback ในสูตรเดิม; ยอดฐานแยก unknown temporal; สิ้นสุดก่อนเริ่มงานถูกตัดจาก employee-month; ขอบเขตวันสิ้นสุดและทะเบียนครบต้องยืนยัน HR

Source tables: emp, emp_position_main, opdscreen, patient. SQL SHA256: 8b89f77d15a3329fbbd1c0ef37cbed002c9bae8198073e432fa5352097e2345f

## HE0104

PDF physical 276; printed 267 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนบุคลากรเพศชายที่ได้รับการวัดรอบเอวและมีค่ารอบเอวมากกว่า 90 เซนติเมตร

ตัวหาร / population: b = จำนวนบุคลากรเพศชายที่ได้รับการวัดรอบเอวทั้งหมด

Grain: staff / month aggregate (candidate). Key candidates: emp.emp_id, emp.emp_cid. Date candidates: emp.emp_work_begindate, emp.emp_resign_enddate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.waist_over_male)
-- denominator (count)
COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.waist_measured_male)
-- outer FROM / source
(
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (COALESCE(sx.emp_sex_name, '') ILIKE '%ชาย%' AND EXISTS (
            SELECT 1
            FROM patient pp
            JOIN opdscreen scr ON scr.hn = pp.hn
            WHERE pp.cid = e.emp_cid
              AND scr.vstdate >= months.work_month
              AND scr.vstdate < months.work_month + INTERVAL '1 month'
              AND scr.waist IS NOT NULL
          )) AS waist_measured_male,
          (COALESCE(sx.emp_sex_name, '') ILIKE '%ชาย%' AND EXISTS (
            SELECT 1
            FROM patient pp
            JOIN opdscreen scr ON scr.hn = pp.hn
            WHERE pp.cid = e.emp_cid
              AND scr.vstdate >= months.work_month
              AND scr.vstdate < months.work_month + INTERVAL '1 month'
              AND scr.waist > 90
          )) AS waist_over_male
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        LEFT JOIN emp_sex sx ON sx.emp_sex_id = e.emp_sex_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
        WHERE e.emp_work_begindate IS NULL OR e.emp_resign_enddate IS NULL
          OR e.emp_resign_enddate >= e.emp_work_begindate
      ) hr
-- outer cohort predicate
TRUE
```

- Measures: Male employees (emp_sex_name male token) with at least one linked screening visit carrying opdscreen.waist above 90 centimeters, over male employees with at least one linked waist measurement, in the fiscal year. PDF beyond the branch: waist measured at the navel at end-expiration with the printed technique, over male staff measured during the annual check-up. the emp_sex dictionary, that opdscreen.waist is centimeters measured at the navel, and that male staff waist is captured for the check-up cohort. Confirm with the hospital owner: the employee to visit linkage runs emp.emp_cid = patient.cid and then patient.hn to the clinical rows; employees whose citizen id is missing or differs from their patient record are invisible to the numerator (they still count in b), and screening recorded outside the HOSxP visit flow is missed. If the linkage is not reliable in local data, stage the indicator from the employee health-check register into reporting.thip_external_facts instead (one row per annual reporting anchor with period_start, numerator, denominator, value, source_system).
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- วันเริ่ม/สิ้นสุดงานว่างยังใช้ fallback ในสูตรเดิม; ยอดฐานแยก unknown temporal; สิ้นสุดก่อนเริ่มงานถูกตัดจาก employee-month; ขอบเขตวันสิ้นสุดและทะเบียนครบต้องยืนยัน HR

Source tables: emp, emp_position_main, emp_sex, opdscreen, patient. SQL SHA256: e3058c79967915f6d513135942225d41dc9de7e954d6ec6e00ddcb346c283860

## HE0105

PDF physical 277; printed 268 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนบุคลากรเพศหญิงที่ได้รับการวัดรอบเอว และมีค่ารอบเอวมากกว่า 80 เซนติเมตร

ตัวหาร / population: b = จำนวนบุคลากรเพศหญิงที่ได้รับการวัดรอบเอวทั้งหมด

Grain: staff / month aggregate (candidate). Key candidates: emp.emp_id, emp.emp_cid. Date candidates: emp.emp_work_begindate, emp.emp_resign_enddate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.waist_over_female)
-- denominator (count)
COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.waist_measured_female)
-- outer FROM / source
(
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (COALESCE(sx.emp_sex_name, '') ILIKE '%หญิง%' AND EXISTS (
            SELECT 1
            FROM patient pp
            JOIN opdscreen scr ON scr.hn = pp.hn
            WHERE pp.cid = e.emp_cid
              AND scr.vstdate >= months.work_month
              AND scr.vstdate < months.work_month + INTERVAL '1 month'
              AND scr.waist IS NOT NULL
          )) AS waist_measured_female,
          (COALESCE(sx.emp_sex_name, '') ILIKE '%หญิง%' AND EXISTS (
            SELECT 1
            FROM patient pp
            JOIN opdscreen scr ON scr.hn = pp.hn
            WHERE pp.cid = e.emp_cid
              AND scr.vstdate >= months.work_month
              AND scr.vstdate < months.work_month + INTERVAL '1 month'
              AND scr.waist > 80
          )) AS waist_over_female
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        LEFT JOIN emp_sex sx ON sx.emp_sex_id = e.emp_sex_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
        WHERE e.emp_work_begindate IS NULL OR e.emp_resign_enddate IS NULL
          OR e.emp_resign_enddate >= e.emp_work_begindate
      ) hr
-- outer cohort predicate
TRUE
```

- Measures: Female employees (emp_sex_name female token) with at least one linked screening visit carrying opdscreen.waist above 80 centimeters, over female employees with at least one linked waist measurement, in the fiscal year. PDF beyond the branch: waist measured at the navel at end-expiration with the printed technique, over female staff measured during the annual check-up. the emp_sex dictionary, that opdscreen.waist is centimeters measured at the navel, and that female staff waist is captured for the check-up cohort. Confirm with the hospital owner: the employee to visit linkage runs emp.emp_cid = patient.cid and then patient.hn to the clinical rows; employees whose citizen id is missing or differs from their patient record are invisible to the numerator (they still count in b), and screening recorded outside the HOSxP visit flow is missed. If the linkage is not reliable in local data, stage the indicator from the employee health-check register into reporting.thip_external_facts instead (one row per annual reporting anchor with period_start, numerator, denominator, value, source_system).
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- วันเริ่ม/สิ้นสุดงานว่างยังใช้ fallback ในสูตรเดิม; ยอดฐานแยก unknown temporal; สิ้นสุดก่อนเริ่มงานถูกตัดจาก employee-month; ขอบเขตวันสิ้นสุดและทะเบียนครบต้องยืนยัน HR

Source tables: emp, emp_position_main, emp_sex, opdscreen, patient. SQL SHA256: 9cde27f79897afd2749ce0ecee8a252fd27d28f7d1e3263f7c64be04ea30b163

## HE0106

PDF physical 278; printed 269 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนบุคลากรที่ได้รับการฉีดวัคซีนไข้หวัดใหญ่ตามฤดูกาล

ตัวหาร / population: b = จำนวนบุคลากรทั้งหมด (1 มิถุนายน สิ้นสุด 30 กันยายน ของทุกปี)

Grain: staff / month aggregate (candidate). Key candidates: emp.emp_id, emp.emp_cid. Date candidates: emp.emp_work_begindate, emp.emp_resign_enddate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.got_influenza_vaccine)
-- denominator (count)
COUNT(DISTINCT hr.staff_key)
-- outer FROM / source
(
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (EXISTS (
            SELECT 1
            FROM patient pp
            JOIN ovst vv ON vv.hn = pp.hn
            JOIN ovst_vaccine ovv ON ovv.vn = vv.vn
            JOIN person_vaccine pv ON pv.person_vaccine_id = ovv.person_vaccine_id
            WHERE pp.cid = e.emp_cid
              AND vv.vstdate >= months.work_month
              AND vv.vstdate < months.work_month + INTERVAL '1 month'
              AND (pv.vaccine_name ILIKE '%ไข้หวัดใหญ่%' OR pv.vaccine_name ILIKE '%influenza%')
          )) AS got_influenza_vaccine
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
        WHERE e.emp_work_begindate IS NULL OR e.emp_resign_enddate IS NULL
          OR e.emp_resign_enddate >= e.emp_work_begindate
      ) hr
-- outer cohort predicate
TRUE
```

- Measures: Employees with at least one linked visit carrying a seasonal influenza vaccination in the visit immunization register (ovst_vaccine joined to person_vaccine.vaccine_name), over all employees active in the fiscal year. PDF beyond the branch: seasonal influenza vaccination of employees during the printed campaign period, per the organization policy. The printed denominator covers the vaccination campaign from 1 June to 30 September; the branch buckets to the annual anchor, so a fiscal-year run reports the whole-year staff count against vaccinations given in the campaign window recorded inside the reporting window. Doses recorded only in the MoPH immunization registry or given outside the hospital are missed; confirm the person_vaccine catalog names for influenza (vaccine_name tokens) and stage the campaign result if doses are recorded elsewhere. Confirm with the hospital owner: the employee to visit linkage runs emp.emp_cid = patient.cid and then patient.hn to the clinical rows; employees whose citizen id is missing or differs from their patient record are invisible to the numerator (they still count in b), and screening recorded outside the HOSxP visit flow is missed. If the linkage is not reliable in local data, stage the indicator from the employee health-check register into reporting.thip_external_facts instead (one row per annual reporting anchor with period_start, numerator, denominator, value, source_system).
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- วันเริ่ม/สิ้นสุดงานว่างยังใช้ fallback ในสูตรเดิม; ยอดฐานแยก unknown temporal; สิ้นสุดก่อนเริ่มงานถูกตัดจาก employee-month; ขอบเขตวันสิ้นสุดและทะเบียนครบต้องยืนยัน HR

Source tables: emp, emp_position_main, ovst, ovst_vaccine, patient, person_vaccine. SQL SHA256: 0316740e30477a3c0f26be51d930b25f1c64319db173d8bff07636278acbb3e3

## HH0101.1

PDF physical 281; printed 272 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้รับบริการของสถานพยาบาลที่มีอายุ 15 ปีขึ้นไปที่มาใช้บริการผู้ป่วยนอกของ สถานพยาบาล และได้รับการคัดกรองสถานะการบริโภคยาสูบ ในช่วงเวลา 3 เดือน

ตัวหาร / population: b = จำนวนผู้รับบริการของสถานพยาบาลที่มีอายุ 15 ปีขึ้นไปทั้งหมดที่มาใช้ บริการผู้ป่วยนอกของสถานพยาบาล ในช่วงเวลาเดียวกัน

Grain: distinct HN within reporting window (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND scr.smoking_type_id IS NOT NULL
      ))
-- denominator (count)
COUNT(DISTINCT opd_periodized.hn)
-- outer FROM / source
opd_periodized
-- outer cohort predicate
opd_periodized.age_y >= 15
```

- Quarterly percent of distinct OPD recipients aged 15+ with at least one visit screen recording smoking status (opdscreen.smoking_type_id IS NOT NULL). Screening is per visit but the printed definition counts recipients; ER visits registered through ovst are also OPD rows here. Confirm the local smoking_type_id semantics (2, 3 = current smoker) and whether ER visits belong in the OPD service denominator.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: er_regist, opdscreen, ovst, ovstdiag, patient. SQL SHA256: 2961594ccea674faa2c446ac1850a9366f8285476dee443195d83ac795fa9391

## HH0101.2

PDF physical 282; printed 273 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้รับบริการของสถานพยาบาลที่มีอายุ 15 ปีขึ้นไปที่มาใช้บริการผู้ป่วยในของ สถานพยาบาล และได้รับการคัดกรองสถานะการบริโภคยาสูบ ในช่วงเวลา 3 เดือน

ตัวหาร / population: b = จำนวนผู้รับบริการของสถานพยาบาลที่มีอายุ 15 ปีขึ้นไปทั้งหมดที่มาใช้ บริการผู้ป่วยในของสถานพยาบาล ในช่วงเวลาเดียวกัน

Grain: admission at ipt AN (candidate). Key candidates: ipt.an, ipt.hn, an_stat.an. Date candidates: ipt.dchdate, ipt.regdate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT periodized.hn) FILTER (WHERE EXISTS (
        SELECT 1
        FROM ovst v
        JOIN opdscreen scr ON scr.vn = v.vn
        WHERE v.an = periodized.an
          AND scr.smoking_type_id IS NOT NULL
      ))
-- denominator (count)
COUNT(DISTINCT periodized.hn)
-- outer FROM / source
periodized
-- outer cohort predicate
periodized.age_y >= 15
```

- Quarterly percent of distinct inpatients aged 15+ whose admission has a smoking-status screen via the admitting ovst visit (ovst.an = periodized.an joined to opdscreen). HOSxP keeps no separate IPD smoking-screen table; the hospital owner must confirm the admitting visit screen is the official inpatient screening record.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: an_stat, death, ipt, iptdiag, opdscreen, ovst. SQL SHA256: 9b972c2d0edd2ed59823dd9be7cfde09cccf8f227d7cc3db20963c900a168985

## HH0102

PDF physical 283; printed 274 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้รับบริการในสถานพยาบาลที่มีอายุ 15 ปีขึ้นไป ที่ได้รับการวินิจฉัยภาวะติด นิโคติน และได้รับบริการบำบัดภาวะติดนิโคติน

ตัวหาร / population: b = จำนวนผู้รับบริการในสถานพยาบาลที่มีอายุ 15 ปีขึ้นไป ที่ได้รับการวินิจฉัยภาวะติด นิโคตินทั้งหมดในช่วงเวลาเดียวกัน

Grain: distinct HN within reporting window (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ))
-- denominator (count)
COUNT(DISTINCT opd_periodized.hn)
-- outer FROM / source
opd_periodized
-- outer cohort predicate
opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND 1 = 1
```

- Semiannual percent of distinct patients aged 15+ with a nicotine-dependence diagnosis (F17 or Z720 on Pdx, ovstdiag or iptdiag of the visit) who received treatment: Z716 counseling diagnosis, any opdscreen advice flag (advice1..advice8 or advice7_note smoke text), or a bupropion, varenicline or nicotine item on the visit. The printed definition needs a certified nicotine-dependence diagnosis and a treatment program per the hospital cessation guideline; Z720 and advice flags are proxies the owner must confirm.
- DISTINCT HN เป็น proxy ผู้สูบบุหรี่/รับคำแนะนำ; ต้องยืนยัน F17/Z720 และรหัสคำแนะนำ/ยา; distinct ข้ามเดือนต้องคำนวณเต็มช่วง
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: drugitems, er_regist, iptdiag, opdscreen, opitemrece, ovst, ovstdiag, patient. SQL SHA256: c452824fa693a84cc787c23899be716ca1a829aee433286349c6f5d70b4b1644

## HH0103.1

PDF physical 284; printed 275 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้รับบริการกลุ่มโรคเบาหวานในสถานพยาบาลที่มีอายุ 15 ปีขึ้นไป ที่ได้รับการ วินิจฉัยภาวะติดนิโคติน และได้รับบริการบำบัดภาวะติดนิโคติน

ตัวหาร / population: b = จำนวนผู้รับบริการกลุ่มโรคเบาหวานในสถานพยาบาลที่มีอายุ 15 ปีขึ้นไป ที่ได้รับการ วินิจฉัยภาวะติดนิโคตินทั้งหมดในช่วงเวลาเดียวกัน

Grain: distinct HN within reporting window (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ))
-- denominator (count)
COUNT(DISTINCT opd_periodized.hn)
-- outer FROM / source
opd_periodized
-- outer cohort predicate
opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
      )
    )
```

- HH0102 restricted to the diabetes group (E10-E14 diagnosis anywhere in the reporting range, OPD or IPD). Group membership is diagnosis-based; the owner must confirm whether clinicmember DM registration should define the group instead.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: drugitems, er_regist, ipt, iptdiag, opdscreen, opitemrece, ovst, ovstdiag, patient. SQL SHA256: 31b1943dddcf39501d906a6e0a72f8a1a68e30c92f11039035322ef1ce4962ca

## HH0103.2

PDF physical 285; printed 276 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้รับบริการกลุ่มโรคความดันโลหิตสูงในสถานพยาบาลที่มีอายุ 15 ปีขึ้นไป ที่ ได้รับการวินิจฉัยภาวะติดนิโคติน และได้รับบริการบำบัดภาวะติดนิโคติน

ตัวหาร / population: b = จำนวนผู้รับบริการกลุ่มโรคความดันโลหิตสูงในสถานพยาบาลที่มีอายุ 15 ปีขึ้นไป ที่ ได้รับการวินิจฉัยภาวะติดนิโคตินทั้งหมดในช่วงเวลาเดียวกัน

Grain: distinct HN within reporting window (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ))
-- denominator (count)
COUNT(DISTINCT opd_periodized.hn)
-- outer FROM / source
opd_periodized
-- outer cohort predicate
opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('I10', 'I11', 'I12', 'I13', 'I14', 'I15')
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN ('I10', 'I11', 'I12', 'I13', 'I14', 'I15')
      )
    )
```

- HH0102 restricted to the hypertension group (I10-I15 diagnosis anywhere in the reporting range). Same group-membership confirmation as HH0103.1.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: drugitems, er_regist, ipt, iptdiag, opdscreen, opitemrece, ovst, ovstdiag, patient. SQL SHA256: 2ed7f6dee1df0644ede5fdf6c75cc62d847c0e896c72a6c335e1e21fe6d6e38b

## HH0103.3

PDF physical 286; printed 277 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้รับบริการกลุ่มโรคหืดในสถานพยาบาลที่มีอายุ 15 ปีขึ้นไป ที่ได้รับการวินิจฉัย ภาวะติดนิโคติน และได้รับบริการบำบัดภาวะติดนิโคติน

ตัวหาร / population: b = จำนวนผู้รับบริการกลุ่มโรคหืดในสถานพยาบาลที่มีอายุ 15 ปีขึ้นไป ที่ได้รับการวินิจฉัย ภาวะติดนิโคตินทั้งหมดในช่วงเวลาเดียวกัน

Grain: distinct HN within reporting window (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ))
-- denominator (count)
COUNT(DISTINCT opd_periodized.hn)
-- outer FROM / source
opd_periodized
-- outer cohort predicate
opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J45', 'J46')
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN ('J45', 'J46')
      )
    )
```

- HH0102 restricted to the asthma group (J45, J46 diagnosis anywhere in the reporting range).
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: drugitems, er_regist, ipt, iptdiag, opdscreen, opitemrece, ovst, ovstdiag, patient. SQL SHA256: f1f0033789fe942071149404851c871d0e102274d4667dbcae5fd8491e97e0ce

## HH0103.4

PDF physical 287; printed 278 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้รับบริการกลุ่มโรคถุงลมโป่งพองในสถานพยาบาลที่มีอายุ 15 ปีขึ้นไป ที่ได้รับ การวินิจฉัยภาวะติดนิโคติน และได้รับบริการบำบัดภาวะติดนิโคติน

ตัวหาร / population: b = จำนวนผู้รับบริการกลุ่มโรคถุงลมโป่งพองในสถานพยาบาลที่มีอายุ 15 ปีขึ้นไป ที่ได้รับ การวินิจฉัยภาวะติดนิโคตินทั้งหมดในช่วงเวลาเดียวกัน

Grain: distinct HN within reporting window (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ))
-- denominator (count)
COUNT(DISTINCT opd_periodized.hn)
-- outer FROM / source
opd_periodized
-- outer cohort predicate
opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J44')
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN ('J44')
      )
    )
```

- HH0102 restricted to the COPD group (J44 diagnosis anywhere in the reporting range).
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: drugitems, er_regist, ipt, iptdiag, opdscreen, opitemrece, ovst, ovstdiag, patient. SQL SHA256: 72604480ad3547ca1ada5e4b909ba94acfe835922a5bf09d906d65e35b3ac067

## HH0103.5

PDF physical 288; printed 279 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้รับบริการกลุ่มหญิงตั้งครรภ์ในสถานพยาบาลที่มีอายุ 15 ปีขึ้นไป ที่ได้รับการ วินิจฉัยภาวะติดนิโคติน และได้รับบริการบำบัดภาวะติดนิโคติน

ตัวหาร / population: b = จำนวนผู้รับบริการกลุ่มหญิงตั้งครรภ์ในสถานพยาบาลที่มีอายุ 15 ปีขึ้นไป ที่ได้รับการ วินิจฉัยภาวะติดนิโคตินทั้งหมดในช่วงเวลาเดียวกัน

Grain: distinct HN within reporting window (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ))
-- denominator (count)
COUNT(DISTINCT opd_periodized.hn)
-- outer FROM / source
opd_periodized
-- outer cohort predicate
opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND (
      EXISTS (
        SELECT 1
        FROM opdscreen pg
        WHERE pg.vn = opd_periodized.vn
          AND pg.pregnancy = 'Y'
      )
      OR EXISTS (
        SELECT 1
        FROM opdscreen_pregnancy pg2
        WHERE pg2.vn = opd_periodized.vn
      )
      OR EXISTS (
          SELECT 1
          FROM ipt_pregnancy ipg
          WHERE ipg.an = opd_periodized.an
        )
      OR EXISTS (
        SELECT 1
        FROM clinicmember cm
        WHERE cm.hn = opd_periodized.hn
          AND cm.with_pregnancy = 'Y'
      )
    )
```

- HH0102 restricted to the pregnant group (opdscreen.pregnancy = Y or opdscreen_pregnancy row on the visit, ipt_pregnancy on the admission, or clinicmember.with_pregnancy = Y). person_anc-based ANC registration was not wired (person-to-hn linkage unverified); the owner must confirm how pregnancy status is recorded for smokers.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: clinicmember, drugitems, er_regist, ipt_pregnancy, iptdiag, opdscreen, opdscreen_pregnancy, opitemrece, ovst, ovstdiag, patient. SQL SHA256: 27eb0edab8c7e96f6a57e0e2c72d14734e4ef21ce8c77b0830a30f6be40673de

## HH0103.6

PDF physical 289; printed 280 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้รับบริการกลุ่มโรคถุงลมโป่งพองในสถานพยาบาลที่มีอายุ 15 ปีขึ้นไป ที่ได้รับ การวินิจฉัยภาวะติดนิโคติน และได้รับบริการบำบัดภาวะติดนิโคติน

ตัวหาร / population: b = จำนวนผู้รับบริการกลุ่มโรคถุงลมโป่งพองในสถานพยาบาลที่มีอายุ 15 ปีขึ้นไป ที่ได้รับ การวินิจฉัยภาวะติดนิโคตินทั้งหมดในช่วงเวลาเดียวกัน

Grain: distinct HN within reporting window (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ))
-- denominator (count)
COUNT(DISTINCT opd_periodized.hn)
-- outer FROM / source
opd_periodized
-- outer cohort predicate
opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J44')
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN ('J44')
      )
    )
```

- Implemented as the COPD group (same predicate as HH0103.4) because the Thai definition and title of HH0103.6 both say ถุงลมโป่งพอง (COPD) while its English title says Asthma and the PDF repeats the COPD group; the hospital owner must confirm which group HH0103.6 really covers before publication.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: drugitems, er_regist, ipt, iptdiag, opdscreen, opitemrece, ovst, ovstdiag, patient. SQL SHA256: 53c9fb4c0690601fe2f1e93c058d89b75135dcefc4f1b0f7211fab49a4066220

## HH0104.1

PDF physical 290; printed 281 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยกลุ่มโรคเบาหวาน ที่มีอายุ 15 ปีขึ้นไป ที่เข้ารับบริการบำบัดรักษาภาวะติด นิโคตินและสามารถหยุดบริโภคยาสูบได้สำเร็จต่อเนื่อง 6 เดือนหลังจำหน่ายจากการ บำบัดรักษา

ตัวหาร / population: b = จำนวนผู้ป่วยกลุ่มโรคเบาหวาน ที่มีอายุ 15 ปีขึ้นไปที่เข้ารับบริการบำบัดรักษาภาวะ ติดนิโคติน

Grain: distinct HN within reporting window (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovst fv
        JOIN opdscreen fs ON fs.vn = fv.vn
        WHERE fv.hn = opd_periodized.hn
          AND fv.vstdate >= opd_periodized.event_date + INTERVAL '180 days'
          AND fv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND COALESCE(fs.smoking_type_id, 0) NOT IN (2, 3)
      )
      AND NOT EXISTS (
        SELECT 1
        FROM ovst rv
        JOIN opdscreen rs ON rs.vn = rv.vn
        WHERE rv.hn = opd_periodized.hn
          AND rv.vstdate > opd_periodized.event_date
          AND rv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND rs.smoking_type_id IN (2, 3)
      )
    ))
-- denominator (count)
COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ))
-- outer FROM / source
opd_periodized
-- outer cohort predicate
opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN ('E10', 'E11', 'E12', 'E13', 'E14')
      )
    )
```

- Annual percent of the treated diabetes-group nicotine-dependence cohort (HH0103.1 numerator grain) whose follow-up screens support 6-month abstinence: at least one screen 180-270 days after the treatment visit showing non-smoker (smoking_type_id not in 2, 3) and no screen in the 270-day window showing relapse (smoking_type_id in 2, 3). Continuous abstinence per the printed definition requires a certified cessation-program follow-up record that HOSxP does not hold; the window and self-report screens are an approximation the owner must confirm.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: drugitems, er_regist, ipt, iptdiag, opdscreen, opitemrece, ovst, ovstdiag, patient. SQL SHA256: a16c43fd18e84780de766cae0a9625d64b22eae18ad5e37aafbc19cb9a49e0a6

## HH0104.2

PDF physical 291; printed 282 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยกลุ่มโรคความดันโลหิตสูง ที่มีอายุ 15 ปีขึ้นไป ที่เข้ารับบริการบำบัดรักษา ภาวะติดนิโคตินและสามารถหยุดบริโภคยาสูบได้สำเร็จต่อเนื่อง 6 เดือนหลังจำหน่ายจากการ บำบัดรักษา

ตัวหาร / population: b = จำนวนผู้ป่วยกลุ่มโรคความดันโลหิตสูง ที่มีอายุ 15 ปีขึ้นไปที่เข้ารับบริการบำบัดรักษา ภาวะติดนิโคติน

Grain: distinct HN within reporting window (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovst fv
        JOIN opdscreen fs ON fs.vn = fv.vn
        WHERE fv.hn = opd_periodized.hn
          AND fv.vstdate >= opd_periodized.event_date + INTERVAL '180 days'
          AND fv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND COALESCE(fs.smoking_type_id, 0) NOT IN (2, 3)
      )
      AND NOT EXISTS (
        SELECT 1
        FROM ovst rv
        JOIN opdscreen rs ON rs.vn = rv.vn
        WHERE rv.hn = opd_periodized.hn
          AND rv.vstdate > opd_periodized.event_date
          AND rv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND rs.smoking_type_id IN (2, 3)
      )
    ))
-- denominator (count)
COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ))
-- outer FROM / source
opd_periodized
-- outer cohort predicate
opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('I10', 'I11', 'I12', 'I13', 'I14', 'I15')
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN ('I10', 'I11', 'I12', 'I13', 'I14', 'I15')
      )
    )
```

- HH0104.1 abstinence rule applied to the hypertension group (HH0103.2 cohort). Same follow-up-window approximation.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: drugitems, er_regist, ipt, iptdiag, opdscreen, opitemrece, ovst, ovstdiag, patient. SQL SHA256: e5a9ba57b062915b40feccc57359e11ee040380dd646db5c4e5afc6be72f1332

## HH0104.3

PDF physical 292; printed 283 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยกลุ่มโรคหืด ที่มีอายุ 15 ปีขึ้นไป ที่เข้ารับบริการบำบัดรักษาภาวะติด นิโคตินและสามารถหยุดบริโภคยาสูบได้สำเร็จต่อเนื่อง 6 เดือนหลังจำหน่ายจากการ บำบัดรักษา

ตัวหาร / population: b = จำนวนผู้ป่วยกลุ่มโรคหืด ที่มีอายุ 15 ปีขึ้นไปที่เข้ารับบริการบำบัดรักษาภาวะติด นิโคติน

Grain: distinct HN within reporting window (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovst fv
        JOIN opdscreen fs ON fs.vn = fv.vn
        WHERE fv.hn = opd_periodized.hn
          AND fv.vstdate >= opd_periodized.event_date + INTERVAL '180 days'
          AND fv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND COALESCE(fs.smoking_type_id, 0) NOT IN (2, 3)
      )
      AND NOT EXISTS (
        SELECT 1
        FROM ovst rv
        JOIN opdscreen rs ON rs.vn = rv.vn
        WHERE rv.hn = opd_periodized.hn
          AND rv.vstdate > opd_periodized.event_date
          AND rv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND rs.smoking_type_id IN (2, 3)
      )
    ))
-- denominator (count)
COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ))
-- outer FROM / source
opd_periodized
-- outer cohort predicate
opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J45', 'J46')
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN ('J45', 'J46')
      )
    )
```

- HH0104.1 abstinence rule applied to the asthma group (HH0103.3 cohort). Same follow-up-window approximation.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: drugitems, er_regist, ipt, iptdiag, opdscreen, opitemrece, ovst, ovstdiag, patient. SQL SHA256: c07f74f4dc5742dc48b82e8752f5ae36ae5b52286a19115fe992eeb3df38905e

## HH0104.4

PDF physical 293; printed 284 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยกลุ่มโรคถุงลมโป่งพอง ที่มีอายุ 15 ปีขึ้นไป ที่เข้ารับบริการบำบัดรักษา ภาวะติดนิโคตินและสามารถหยุดบริโภคยาสูบได้สำเร็จต่อเนื่อง 6 เดือนหลังจำหน่ายจากการ บำบัดรักษา

ตัวหาร / population: b = จำนวนผู้ป่วยกลุ่มโรคถุงลมโป่งพอง ที่มีอายุ 15 ปีขึ้นไปที่เข้ารับบริการบำบัดรักษา ภาวะติดนิโคติน

Grain: distinct HN within reporting window (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovst fv
        JOIN opdscreen fs ON fs.vn = fv.vn
        WHERE fv.hn = opd_periodized.hn
          AND fv.vstdate >= opd_periodized.event_date + INTERVAL '180 days'
          AND fv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND COALESCE(fs.smoking_type_id, 0) NOT IN (2, 3)
      )
      AND NOT EXISTS (
        SELECT 1
        FROM ovst rv
        JOIN opdscreen rs ON rs.vn = rv.vn
        WHERE rv.hn = opd_periodized.hn
          AND rv.vstdate > opd_periodized.event_date
          AND rv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND rs.smoking_type_id IN (2, 3)
      )
    ))
-- denominator (count)
COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ))
-- outer FROM / source
opd_periodized
-- outer cohort predicate
opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        JOIN ovst v ON v.vn = sd.vn
        WHERE v.hn = opd_periodized.hn
          AND v.vstdate >= :start_date
          AND v.vstdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) IN ('J44')
      )
      OR EXISTS (
        SELECT 1
        FROM iptdiag idg
        JOIN ipt i ON i.an = idg.an
        WHERE i.hn = opd_periodized.hn
          AND i.dchdate >= :start_date
          AND i.dchdate < :end_date
          AND LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) IN ('J44')
      )
    )
```

- HH0104.1 abstinence rule applied to the COPD group (HH0103.4 cohort). Same follow-up-window approximation.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: drugitems, er_regist, ipt, iptdiag, opdscreen, opitemrece, ovst, ovstdiag, patient. SQL SHA256: 83f8e67b7bf3f46baa3ec91e4105b9ab07fecdff1b8ed517a09d223cb76c1059

## HH0104.5

PDF physical 294; printed 285 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ป่วยกลุ่มหญิงตั้งครรภ์ ที่มีอายุ 15 ปีขึ้นไป ที่เข้ารับบริการบำบัดรักษาภาวะติด นิโคตินและสามารถหยุดบริโภคยาสูบได้สำเร็จต่อเนื่อง 6 เดือนหลังจำหน่ายจากการ บำบัดรักษา

ตัวหาร / population: b = จำนวนผู้ป่วยกลุ่มหญิงตั้งครรภ์ ที่มีอายุ 15 ปีขึ้นไปที่เข้ารับบริการบำบัดรักษาภาวะ ติดนิโคติน

Grain: distinct HN within reporting window (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ) AND (
      EXISTS (
        SELECT 1
        FROM ovst fv
        JOIN opdscreen fs ON fs.vn = fv.vn
        WHERE fv.hn = opd_periodized.hn
          AND fv.vstdate >= opd_periodized.event_date + INTERVAL '180 days'
          AND fv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND COALESCE(fs.smoking_type_id, 0) NOT IN (2, 3)
      )
      AND NOT EXISTS (
        SELECT 1
        FROM ovst rv
        JOIN opdscreen rs ON rs.vn = rv.vn
        WHERE rv.hn = opd_periodized.hn
          AND rv.vstdate > opd_periodized.event_date
          AND rv.vstdate <= opd_periodized.event_date + INTERVAL '270 days'
          AND rs.smoking_type_id IN (2, 3)
      )
    ))
-- denominator (count)
COUNT(DISTINCT opd_periodized.hn) FILTER (WHERE (
      EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z716'
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z716'
        )
      OR EXISTS (
        SELECT 1
        FROM opdscreen scr
        WHERE scr.vn = opd_periodized.vn
          AND (
            scr.advice1 = 'Y' OR scr.advice2 = 'Y' OR scr.advice3 = 'Y'
            OR scr.advice4 = 'Y' OR scr.advice5 = 'Y' OR scr.advice6 = 'Y'
            OR scr.advice7 = 'Y' OR scr.advice8 = 'Y'
            OR scr.advice7_note ILIKE '%smoke%'
            OR scr.advice7_note ILIKE '%สูบ%'
          )
      )
      OR EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (
            di.name ILIKE '%bupropion%'
            OR di.name ILIKE '%varenicline%'
            OR di.name ILIKE '%nicotine%'
          )
      )
    ))
-- outer FROM / source
opd_periodized
-- outer cohort predicate
opd_periodized.age_y >= 15 AND (
      LEFT(pdx, 3) = 'F17'
      OR pdx = 'Z720'
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'F17'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') = 'Z720'
          )
      )
      OR EXISTS (
          SELECT 1
          FROM iptdiag idg
          WHERE idg.an = opd_periodized.an
            AND (
              LEFT(REPLACE(UPPER(TRIM(idg.icd10)), '.', ''), 3) = 'F17'
              OR REPLACE(UPPER(TRIM(idg.icd10)), '.', '') = 'Z720'
            )
        )
    ) AND (
      EXISTS (
        SELECT 1
        FROM opdscreen pg
        WHERE pg.vn = opd_periodized.vn
          AND pg.pregnancy = 'Y'
      )
      OR EXISTS (
        SELECT 1
        FROM opdscreen_pregnancy pg2
        WHERE pg2.vn = opd_periodized.vn
      )
      OR EXISTS (
          SELECT 1
          FROM ipt_pregnancy ipg
          WHERE ipg.an = opd_periodized.an
        )
      OR EXISTS (
        SELECT 1
        FROM clinicmember cm
        WHERE cm.hn = opd_periodized.hn
          AND cm.with_pregnancy = 'Y'
      )
    )
```

- HH0104.1 abstinence rule applied to the pregnant group (HH0103.5 cohort). Same follow-up-window approximation; confirm how pregnancy is tracked over the 6-month window.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: clinicmember, drugitems, er_regist, ipt_pregnancy, iptdiag, opdscreen, opdscreen_pregnancy, opitemrece, ovst, ovstdiag, patient. SQL SHA256: eb9e0cd240051167a8ecec87abfa51df0148accda4d9c966c91325019e565a56

## SC0101

PDF physical 259; printed 250 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: A = จำนวนผู้ตอบแบบสอบถามที่มีระดับความพึงพอใจระดับ 4 และ 5

ตัวหาร / population: b = จำนวนผู้ตอบแบบสอบถามทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SC0101'
```

- Measures: Percent of outpatient satisfaction (overall): share of OPD questionnaire respondents selecting satisfaction level 4 or 5 on the overall question (THIP page 259). The branch is branchExternal over reporting.thip_external_facts. PDF beyond the branch: the sampled OPD respondents of the printed OPD satisfaction questionnaire with the overall-satisfaction item scored on the confirmed 5-level scale where only levels 4 and 5 count as satisfied. Confirm with the hospital owner: which installed questionnaire version is the printed OPD instrument, that choice_no 4 and choice_no 5 are the two highest satisfaction levels, and that the tally covers respondents sampled across the whole OPD service process. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): Anchor rows: one row per semiannual reporting anchor with period_start 2025-10-01 and 2026-04-01 (fiscal months 1 and 7 of fiscal year 2026; anchors are always 1 October and 1 April). numerator (a) = count of sampled OPD respondents with overall satisfaction level 4 or 5.  denominator (b) = count of all sampled OPD respondents in the period.  value = ROUND(a * 100.0 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100. source_system = 'thip-survey-opd'. Source check: the HOSxP survey tables were verified column by column and cannot confirm the printed instrument or score scale. survey_satisfy_head_pcu (survey_satisfy_head_id, survey_satisfy_age, survey_satisfy_suggest, survey_satisfy_date, survey_satisfy_sum_1 to survey_satisfy_sum_5, hos_guid) has no visit, patient, service-point or questionnaire-version column, so OPD respondents cannot be separated from IPD respondents and the unconfirmed semantics of survey_satisfy_sum_1 to survey_satisfy_sum_5 cannot define the printed 5-level scale. survey_satisfy_screen_pcu (survey_satisfy_screen_id, survey_satisfy_head_id, survey_satisfy_id, survey_satisfy_choice_id) and survey_satisfy_choice_pcu (survey_satisfy_choice_id, survey_satisfy_id, survey_satisfy_choice_no, survey_satisfy_choice_name, survey_satisfy_choice_code) only record one chosen choice per question of the local survey_satisfy_pcu master (survey_satisfy_id, survey_satisfy_name, survey_satisfy_part), whose installed wording version is unverifiable local data. dis_satisfied (dis_satisfied_id, drug_information_service_id, dis_satisfied_topic_id, dis_satisfied_result_id, note), dis_satisfied_result and dis_satisfied_topic belong to the drug information service instrument, not to the printed patient satisfaction questionnaire.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: d5f3c97410feebe33bf271a354c7b38026eb059637e8b1ab67bec2139e55e4c5

## SC0102

PDF physical 260; printed 251 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: A = จำนวนผู้ตอบแบบสอบถามที่มีระดับความพึงพอใจระดับ 4 และ 5

ตัวหาร / population: b = จำนวนผู้ตอบแบบสอบถามทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SC0102'
```

- Measures: Percent of inpatient satisfaction (overall): share of IPD questionnaire respondents selecting satisfaction level 4 or 5 on the overall question, sampled from admissions with length of stay more than 3 days (THIP page 260). The branch is branchExternal over reporting.thip_external_facts. PDF beyond the branch: the sampled IPD respondents of the printed IPD satisfaction questionnaire, restricted to admissions with more than 3 inpatient days, with the overall item scored on the confirmed 5-level scale where only levels 4 and 5 count as satisfied. Confirm with the hospital owner: which installed questionnaire version is the printed IPD instrument, that choice_no 4 and choice_no 5 are the two highest satisfaction levels, and that the respondent sample is restricted to stays of more than 3 days. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): Anchor rows: one row per semiannual reporting anchor with period_start 2025-10-01 and 2026-04-01 (fiscal months 1 and 7 of fiscal year 2026; anchors are always 1 October and 1 April). numerator (a) = count of sampled IPD respondents with overall satisfaction level 4 or 5 (stays over 3 days).  denominator (b) = count of all sampled IPD respondents in the period (stays over 3 days).  value = ROUND(a * 100.0 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100. source_system = 'thip-survey-ipd'. Source check: the HOSxP survey tables were verified column by column and cannot confirm the printed instrument or score scale. survey_satisfy_head_pcu (survey_satisfy_head_id, survey_satisfy_age, survey_satisfy_suggest, survey_satisfy_date, survey_satisfy_sum_1 to survey_satisfy_sum_5, hos_guid) has no visit, patient, service-point or questionnaire-version column, so OPD respondents cannot be separated from IPD respondents and the unconfirmed semantics of survey_satisfy_sum_1 to survey_satisfy_sum_5 cannot define the printed 5-level scale. survey_satisfy_screen_pcu (survey_satisfy_screen_id, survey_satisfy_head_id, survey_satisfy_id, survey_satisfy_choice_id) and survey_satisfy_choice_pcu (survey_satisfy_choice_id, survey_satisfy_id, survey_satisfy_choice_no, survey_satisfy_choice_name, survey_satisfy_choice_code) only record one chosen choice per question of the local survey_satisfy_pcu master (survey_satisfy_id, survey_satisfy_name, survey_satisfy_part), whose installed wording version is unverifiable local data. dis_satisfied (dis_satisfied_id, drug_information_service_id, dis_satisfied_topic_id, dis_satisfied_result_id, note), dis_satisfied_result and dis_satisfied_topic belong to the drug information service instrument, not to the printed patient satisfaction questionnaire.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 65789fd4b1cc6da862c07594d137cea6b42b5ccb2fa181905844c6d40884f5bc

## SC0103

PDF physical 261; printed 252 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ตอบแบบสอบถามประมาณ 20% ของจำนวนผู้ป่วยนอกที่มารับบริการตรวจ รักษาในช่วงเวลานั้นที่ตอบว่าจะกลับมารักษาในครั้งต่อไป

ตัวหาร / population: b = จำนวนผู้ตอบแบบสอบถามประมาณ 20% ของจำนวนผู้ป่วยนอกที่มารับบริการตรวจ รักษาในช่วงเวลานั้นที่ตอบแบบสอบถามทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SC0103'
```

- Measures: Percent of outpatients who return to receive care: share of OPD questionnaire respondents answering yes (come) to the question asking whether they would choose this hospital again (THIP page 261). The branch is branchExternal over reporting.thip_external_facts. PDF beyond the branch: the binary return-intention item of the printed OPD questionnaire (answers come or not come), answered by roughly 20 percent of the OPD volume of the period. Confirm with the hospital owner: which installed question of the OPD instrument is the printed return-intention item, that its positive answer is the come option, and that the sample is roughly 20 percent of OPD visits in the period. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): Anchor rows: one row per semiannual reporting anchor with period_start 2025-10-01 and 2026-04-01 (fiscal months 1 and 7 of fiscal year 2026; anchors are always 1 October and 1 April). numerator (a) = count of sampled OPD respondents answering they would come back.  denominator (b) = count of all sampled OPD respondents answering the questionnaire in the period.  value = ROUND(a * 100.0 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100. source_system = 'thip-survey-opd'. Source check: the HOSxP survey tables were verified column by column and cannot confirm the printed instrument or score scale. survey_satisfy_head_pcu (survey_satisfy_head_id, survey_satisfy_age, survey_satisfy_suggest, survey_satisfy_date, survey_satisfy_sum_1 to survey_satisfy_sum_5, hos_guid) has no visit, patient, service-point or questionnaire-version column, so OPD respondents cannot be separated from IPD respondents and the unconfirmed semantics of survey_satisfy_sum_1 to survey_satisfy_sum_5 cannot define the printed 5-level scale. survey_satisfy_screen_pcu (survey_satisfy_screen_id, survey_satisfy_head_id, survey_satisfy_id, survey_satisfy_choice_id) and survey_satisfy_choice_pcu (survey_satisfy_choice_id, survey_satisfy_id, survey_satisfy_choice_no, survey_satisfy_choice_name, survey_satisfy_choice_code) only record one chosen choice per question of the local survey_satisfy_pcu master (survey_satisfy_id, survey_satisfy_name, survey_satisfy_part), whose installed wording version is unverifiable local data. dis_satisfied (dis_satisfied_id, drug_information_service_id, dis_satisfied_topic_id, dis_satisfied_result_id, note), dis_satisfied_result and dis_satisfied_topic belong to the drug information service instrument, not to the printed patient satisfaction questionnaire.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 312385043073fad555858955d6306b81df25182ad5ab9c710f57c44aad8db27b

## SC0104

PDF physical 262; printed 253 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ตอบแบบสอบถามประมาณ 20% ของจำนวนผู้ป่วยที่เข้ารับการตรวจรักษาใน โรงพยาบาลที่ตอบว่าจะกลับมารักษาในครั้งต่อไป

ตัวหาร / population: b = จำนวนผู้ตอบแบบสอบถามประมาณ 20% ของจำนวนผู้ป่วยที่เข้ารับการตรวจรักษา ในโรงพยาบาลที่ตอบแบบสอบถามทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SC0104'
```

- Measures: Percent of inpatients who return to receive care: share of IPD questionnaire respondents answering yes (come) to the question asking whether they would choose this hospital again (THIP page 262). The branch is branchExternal over reporting.thip_external_facts. PDF beyond the branch: the binary return-intention item of the printed IPD questionnaire (answers come or not come), answered by roughly 20 percent of the inpatient volume of the period. Confirm with the hospital owner: which installed question of the IPD instrument is the printed return-intention item, that its positive answer is the come option, and that the sample is roughly 20 percent of inpatient admissions in the period. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): Anchor rows: one row per semiannual reporting anchor with period_start 2025-10-01 and 2026-04-01 (fiscal months 1 and 7 of fiscal year 2026; anchors are always 1 October and 1 April). numerator (a) = count of sampled IPD respondents answering they would come back.  denominator (b) = count of all sampled IPD respondents answering the questionnaire in the period.  value = ROUND(a * 100.0 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100. source_system = 'thip-survey-ipd'. Source check: the HOSxP survey tables were verified column by column and cannot confirm the printed instrument or score scale. survey_satisfy_head_pcu (survey_satisfy_head_id, survey_satisfy_age, survey_satisfy_suggest, survey_satisfy_date, survey_satisfy_sum_1 to survey_satisfy_sum_5, hos_guid) has no visit, patient, service-point or questionnaire-version column, so OPD respondents cannot be separated from IPD respondents and the unconfirmed semantics of survey_satisfy_sum_1 to survey_satisfy_sum_5 cannot define the printed 5-level scale. survey_satisfy_screen_pcu (survey_satisfy_screen_id, survey_satisfy_head_id, survey_satisfy_id, survey_satisfy_choice_id) and survey_satisfy_choice_pcu (survey_satisfy_choice_id, survey_satisfy_id, survey_satisfy_choice_no, survey_satisfy_choice_name, survey_satisfy_choice_code) only record one chosen choice per question of the local survey_satisfy_pcu master (survey_satisfy_id, survey_satisfy_name, survey_satisfy_part), whose installed wording version is unverifiable local data. dis_satisfied (dis_satisfied_id, drug_information_service_id, dis_satisfied_topic_id, dis_satisfied_result_id, note), dis_satisfied_result and dis_satisfied_topic belong to the drug information service instrument, not to the printed patient satisfaction questionnaire.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 352c2900b8f89fe865cc564b5cd6284a710ac15ee4c8d2a7b6bee9cdc2d01191

## SC0105

PDF physical 263; printed 254 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ตอบแบบสอบถามที่เลือกแนะนําญาติหรือคนรู้จักมาใช้บริการ

ตัวหาร / population: b = จํานวนผู้ตอบแบบสอบถามทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SC0105'
```

- Measures: Percent of outpatients who would recommend friends or family: share of OPD questionnaire respondents answering yes (recommend) to the question asking whether they would recommend others to this hospital (THIP page 263). The branch is branchExternal over reporting.thip_external_facts. PDF beyond the branch: the binary recommend item of the printed OPD questionnaire (answers recommend or not recommend), answered across the OPD service process sample. Confirm with the hospital owner: which installed question of the OPD instrument is the printed recommend item and that its positive answer is the recommend option. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): Anchor rows: one row per semiannual reporting anchor with period_start 2025-10-01 and 2026-04-01 (fiscal months 1 and 7 of fiscal year 2026; anchors are always 1 October and 1 April). numerator (a) = count of sampled OPD respondents choosing the recommend answer.  denominator (b) = count of all sampled OPD respondents in the period.  value = ROUND(a * 100.0 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100. source_system = 'thip-survey-opd'. Source check: the HOSxP survey tables were verified column by column and cannot confirm the printed instrument or score scale. survey_satisfy_head_pcu (survey_satisfy_head_id, survey_satisfy_age, survey_satisfy_suggest, survey_satisfy_date, survey_satisfy_sum_1 to survey_satisfy_sum_5, hos_guid) has no visit, patient, service-point or questionnaire-version column, so OPD respondents cannot be separated from IPD respondents and the unconfirmed semantics of survey_satisfy_sum_1 to survey_satisfy_sum_5 cannot define the printed 5-level scale. survey_satisfy_screen_pcu (survey_satisfy_screen_id, survey_satisfy_head_id, survey_satisfy_id, survey_satisfy_choice_id) and survey_satisfy_choice_pcu (survey_satisfy_choice_id, survey_satisfy_id, survey_satisfy_choice_no, survey_satisfy_choice_name, survey_satisfy_choice_code) only record one chosen choice per question of the local survey_satisfy_pcu master (survey_satisfy_id, survey_satisfy_name, survey_satisfy_part), whose installed wording version is unverifiable local data. dis_satisfied (dis_satisfied_id, drug_information_service_id, dis_satisfied_topic_id, dis_satisfied_result_id, note), dis_satisfied_result and dis_satisfied_topic belong to the drug information service instrument, not to the printed patient satisfaction questionnaire.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: ca95e931f5202edf2687595e9f0559d3b1c71d31846b8c1dd58fb081c3ca1a06

## SC0106

PDF physical 264; printed 255 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนผู้ตอบแบบสอบถาม (ผู้ป่วยใน/ญาติ) ว่าจะแนะนำผู้อื่นมารักษาที่โรงพยาบาล จำแนกตามกลุ่มผู้รับบริการ

ตัวหาร / population: b = จำนวนผู้ตอบแบบสอบถาม (ผู้ป่วยใน/ญาติ) ทั้งหมดตามกลุ่มผู้รับบริการนั้น ๆ

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SC0106'
```

- Measures: Percent of inpatients who would recommend friends or family: share of IPD questionnaire respondents (patient or relative) answering yes (recommend) to the question asking whether they would recommend others to this hospital, counted per respondent group (THIP page 264). The branch is branchExternal over reporting.thip_external_facts. PDF beyond the branch: the binary recommend item of the printed IPD questionnaire answered by patients or relatives, tallied per respondent group, with a sample of roughly 20 percent of inpatient admissions. Confirm with the hospital owner: which installed question of the IPD instrument is the printed recommend item, which respondent groups (patient versus relative) are reported separately, and that the sample is roughly 20 percent of inpatient admissions. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): Anchor rows: one row per semiannual reporting anchor with period_start 2025-10-01 and 2026-04-01 (fiscal months 1 and 7 of fiscal year 2026; anchors are always 1 October and 1 April). numerator (a) = count of sampled IPD respondents (patient or relative) answering they would recommend others, per respondent group.  denominator (b) = count of all sampled IPD respondents in that respondent group in the period.  value = ROUND(a * 100.0 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100. source_system = 'thip-survey-ipd'. Source check: the HOSxP survey tables were verified column by column and cannot confirm the printed instrument or score scale. survey_satisfy_head_pcu (survey_satisfy_head_id, survey_satisfy_age, survey_satisfy_suggest, survey_satisfy_date, survey_satisfy_sum_1 to survey_satisfy_sum_5, hos_guid) has no visit, patient, service-point or questionnaire-version column, so OPD respondents cannot be separated from IPD respondents and the unconfirmed semantics of survey_satisfy_sum_1 to survey_satisfy_sum_5 cannot define the printed 5-level scale. survey_satisfy_screen_pcu (survey_satisfy_screen_id, survey_satisfy_head_id, survey_satisfy_id, survey_satisfy_choice_id) and survey_satisfy_choice_pcu (survey_satisfy_choice_id, survey_satisfy_id, survey_satisfy_choice_no, survey_satisfy_choice_name, survey_satisfy_choice_code) only record one chosen choice per question of the local survey_satisfy_pcu master (survey_satisfy_id, survey_satisfy_name, survey_satisfy_part), whose installed wording version is unverifiable local data. dis_satisfied (dis_satisfied_id, drug_information_service_id, dis_satisfied_topic_id, dis_satisfied_result_id, note), dis_satisfied_result and dis_satisfied_topic belong to the drug information service instrument, not to the printed patient satisfaction questionnaire.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 74507b35636f404bc6d1d17009ab090183987c4ded6a95f2a82753d5728dc77a

## SF0101

PDF physical 253; printed 244 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนสินทรัพย์หมุนเวียน

ตัวหาร / population: b = จำนวนหนี้สินหมุนเวียน

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: เท่า; formula: a/b. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SF0101'
```

- Measures: Current ratio: liquidity of the hospital as current assets over current liabilities (THIP page 253). The branch is branchExternal over reporting.thip_external_facts because the audited financial statements of the hospital are outside HOSxP (the stock_item and stock_trancation candidates only hold consumable stock card quantities and money flows, never balance sheet or income statement items). PDF beyond the branch: the a and b amounts of the printed definition taken from the audited financial statements of the fiscal year. Confirm with the hospital owner: the finance office account mapping of current assets and current liabilities, and that the figures come from the audited statements of the reported fiscal year (a value under 1 signals short-term liquidity strain). Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): Anchor rows: one row per annual reporting anchor with period_start 2025-10-01 (fiscal month 1 of fiscal year 2026; the anchor is always 1 October). numerator (a) = current assets in THB per the audited financial statements of the fiscal year (cash, bank deposits, short-term investments, trade receivables, notes receivable, inventory, other receivables, accrued income, prepaid expenses, supplies).  denominator (b) = current liabilities in THB per the same statements (bank overdrafts, short-term bank loans, trade payables, notes payable, advances received, accrued expenses, other payables).  value = ROUND(a * 1.0 divided by NULLIF(b, 0), 2) per formulaScale a over b. source_system = 'thip-finance-audited'.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 797e8c2e1621d82958a5597d1c79d8242fa0f4c3d36eb6f2a87be5c980f29501

## SF0102

PDF physical 254; printed 245 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนสินทรัพย์สภาพคล่อง

ตัวหาร / population: b = จำนวนหนี้สินหมุนเวียน

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: เท่า; formula: a/b. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SF0102'
```

- Measures: Quick ratio (liquid asset ratio): immediate solvency as liquid assets over current liabilities, excluding inventory (THIP page 254). The branch is branchExternal over reporting.thip_external_facts because the audited financial statements of the hospital are outside HOSxP (the stock_item and stock_trancation candidates only hold consumable stock card quantities and money flows, never balance sheet or income statement items). PDF beyond the branch: the a and b amounts of the printed definition taken from the audited financial statements of the fiscal year. Confirm with the hospital owner: the finance office definition of liquid assets (which receivables and marketable instruments qualify) and that inventory is excluded from a. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): Anchor rows: one row per annual reporting anchor with period_start 2025-10-01 (fiscal month 1 of fiscal year 2026; the anchor is always 1 October). numerator (a) = liquid assets in THB per the audited financial statements (current assets excluding inventory: cash, bank deposits, short-term investments, trade receivables, notes receivable, marketable assets).  denominator (b) = current liabilities in THB per the same statements (same items as SF0101 b).  value = ROUND(a * 1.0 divided by NULLIF(b, 0), 2) per formulaScale a over b. source_system = 'thip-finance-audited'.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 4ab98583c7081aebd021784e32727c48ad394c39175cc7165a9ab4d995890e76

## SF0103

PDF physical 255; printed 246 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = ยอดขายสุทธิ จากงบการเงินในรอบการประเมินของปีงบประมาณ

ตัวหาร / population: b = สินทรัพย์ถาวร จากงบการเงินในรอบการประเมินของปีงบประมาณเดียวกัน

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: เท่า; formula: a/b. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SF0103'
```

- Measures: Fixed asset turnover: how productively tangible long-life assets generate service revenue (THIP page 255). The branch is branchExternal over reporting.thip_external_facts because the audited financial statements of the hospital are outside HOSxP (the stock_item and stock_trancation candidates only hold consumable stock card quantities and money flows, never balance sheet or income statement items). PDF beyond the branch: the a and b amounts of the printed definition taken from the audited financial statements of the fiscal year. Confirm with the hospital owner: the finance office mapping of net sales and fixed assets, and that both amounts cover the same fiscal-year evaluation round. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): Anchor rows: one row per annual reporting anchor with period_start 2025-10-01 (fiscal month 1 of fiscal year 2026; the anchor is always 1 October). numerator (a) = net sales (service operating revenue) of the fiscal year per the audited financial statements.  denominator (b) = fixed assets in THB per the same statements (tangible assets with useful life over one year held to produce services).  value = ROUND(a * 1.0 divided by NULLIF(b, 0), 2) per formulaScale a over b. source_system = 'thip-finance-audited'.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: b0994ca5309fdf10f7b44c4a0e9091f5e87fe17b687170e688f68394e48ae9c1

## SF0104

PDF physical 256; printed 247 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = ยอดลูกหนี้สุทธิ ณ วันสิ้นปี

ตัวหาร / population: b = ยอดขายเชื่อเฉลี่ยต่อวัน

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: วัน; formula: a/b. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SF0104'
```

- Measures: Average collection period of net medical receivables, in days (THIP page 256; lower is better). The branch is branchExternal over reporting.thip_external_facts because the audited financial statements of the hospital are outside HOSxP (the stock_item and stock_trancation candidates only hold consumable stock card quantities and money flows, never balance sheet or income statement items). PDF beyond the branch: the a and b amounts of the printed definition taken from the audited financial statements of the fiscal year. Confirm with the hospital owner: the finance office computation of average credit sales per day and that the receivable balance is the year-end net figure; the resulting value is a day count, not a percent. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): Anchor rows: one row per annual reporting anchor with period_start 2025-10-01 (fiscal month 1 of fiscal year 2026; the anchor is always 1 October). numerator (a) = net accounts receivable in THB at the end of the fiscal year.  denominator (b) = average credit sales per day in THB (net credit sales of the fiscal year prorated to one day by the finance office before loading).  value = ROUND(a * 1.0 divided by NULLIF(b, 0), 2) per formulaScale a over b (unit: days). source_system = 'thip-finance-audited'.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 58401b5a21dbd75a188a3f5692bd6316ce5469e87dfdd0f0967dde30baaa96c4

## SF0105

PDF physical 257; printed 248 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = กำไรสุทธิ

ตัวหาร / population: b = ยอดขายสุทธิ

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SF0105'
```

- Measures: Net profit margin: net profit over net sales in percent (THIP page 257; higher is better). The branch is branchExternal over reporting.thip_external_facts because the audited financial statements of the hospital are outside HOSxP (the stock_item and stock_trancation candidates only hold consumable stock card quantities and money flows, never balance sheet or income statement items). PDF beyond the branch: the a and b amounts of the printed definition taken from the audited financial statements of the fiscal year. Confirm with the hospital owner: the finance office mapping of net profit and net sales, in particular that b counts service revenue only while a includes other income. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): Anchor rows: one row per annual reporting anchor with period_start 2025-10-01 (fiscal month 1 of fiscal year 2026; the anchor is always 1 October). numerator (a) = net profit in THB (total income including service and other income minus expenses, depreciation and costs).  denominator (b) = net sales in THB (service revenue only).  value = ROUND(a * 100.0 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100. source_system = 'thip-finance-audited'.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 274d4ce1574dc3631c7c8904200e32b5353adb44a6dc41310df1531ad39bbeaa

## SF0106

PDF physical 258; printed 249 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = ยอดกำไรสุทธิ (net profit)

ตัวหาร / population: b = ยอดสินทรัพย์รวม (total assets)

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SF0106'
```

- Measures: Return on assets (ROA): net profit over total assets in percent (THIP page 258; higher is better). The branch is branchExternal over reporting.thip_external_facts because the audited financial statements of the hospital are outside HOSxP (the stock_item and stock_trancation candidates only hold consumable stock card quantities and money flows, never balance sheet or income statement items). PDF beyond the branch: the a and b amounts of the printed definition taken from the audited financial statements of the fiscal year. Confirm with the hospital owner: the finance office mapping of net profit and total assets and that both amounts come from the same audited fiscal-year statements. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): Anchor rows: one row per annual reporting anchor with period_start 2025-10-01 (fiscal month 1 of fiscal year 2026; the anchor is always 1 October). numerator (a) = net profit in THB per the audited financial statements of the fiscal year.  denominator (b) = total assets in THB per the same statements.  value = ROUND(a * 100.0 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100. source_system = 'thip-finance-audited'.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 05ecd5d3880d88363d36d45532c009319d7f32e8f16b1e21c26f03f3618733b8

## SG0104

PDF physical 265; printed 256 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = น้ำหนักของขยะรีไซเคิลของเดือนนี้ (กิโลกรัม)

ตัวหาร / population: b = น้ำหนักของขยะรีไซเคิลในเดือนที่ผ่านมา (กิโลกรัม)

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: เท่า; formula: a/b. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SG0104'
```

- Measures: Percent of recycled waste: month-over-month ratio of recycled-waste weight (THIP page 265), a = weight of recycled waste of the month in kilograms, b = weight of recycled waste of the previous month in kilograms. The branch is branchExternal over reporting.thip_external_facts because no HOSxP table records waste weights. PDF beyond the branch: the monthly kilogram weights of waste classified as recyclable (waste that can be reprocessed in the industrial system), including the previous month weight that the printed b definition needs. Confirm with the hospital owner: that the hospital environment office waste log measures kilograms, which waste streams count as recycled waste, and that month-over-month comparison against the previous month weight is the intended denominator. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): Anchor rows: one row per monthly reporting anchor with period_start = first day of each calendar month (for example 2025-10-01, 2025-11-01). numerator (a) = weight of recycled waste of that month in kilograms. denominator (b) = weight of recycled waste of the immediately previous month in kilograms (the first loaded month needs its predecessor weight from the waste log). value = ROUND(a * 1.0 divided by NULLIF(b, 0), 2) per formulaScale a over b. source_system = 'thip-environment-waste-log'. Source check: stock_item and stock_trancation track consumable stock cards (item_id, transaction_date, in_qty, out_qty, unit quantities and money columns) with no waste weights or waste-type registry; supply_sterile and supply_sterile_item track sterile supply processing counts (supply_sterile_item_qty); house_survey_garbage, provis_garbage, village_garbage_place and village_recycle_tank are village health survey lookup lists without weights or dates.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 97ae74b7e28d04b619c13c20d6f338a646720fc00fc8781c4bf35b073384c1d2

## SH0101

PDF physical 221; printed 212 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = ค่าเฉลี่ยของจำนวนบุคลากรที่ลาออกในรอบปีงบประมาณ

ตัวหาร / population: b = ค่าเฉลี่ยของจำนวนบุคลากร ณ วันแรก และวันสุดท้ายของปีงบประมาณเดียวกัน

Grain: staff / month aggregate (candidate). Key candidates: emp.emp_id, emp.emp_cid. Date candidates: emp.emp_work_begindate, emp.emp_resign_enddate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (sum)
SUM(hr.voluntary_resign_cnt) / NULLIF(12, 0)
-- denominator (count)
(COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_fy_start) + COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_fy_end)) / NULLIF(2.0, 0)
-- outer FROM / source
(
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COUNT(*)
            FROM emp_resign rr
            LEFT JOIN emp_resign_type rt ON rt.emp_resign_type_id = rr.emp_resign_type_id
            WHERE rr.emp_id = e.emp_id
              AND rr.emp_resign_date >= months.work_month
              AND rr.emp_resign_date < months.work_month + INTERVAL '1 month'
              AND (rt.emp_resign_type_name IS NULL OR rt.emp_resign_type_name NOT ILIKE ANY (ARRAY['%ให้ออก%', '%ไล่ออก%', '%ปลด%', '%เกษียณ%', '%เสียชีวิต%', '%ถึงแก่กรรม%', '%โอน%', '%ย้าย%', '%ตาย%']))) AS voluntary_resign_cnt,
          ((e.emp_work_begindate IS NULL OR e.emp_work_begindate <= CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END) AND (e.emp_resign_enddate IS NULL OR e.emp_resign_enddate >= CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END)) AS active_at_fy_start,
          ((e.emp_work_begindate IS NULL OR e.emp_work_begindate <= (CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END + INTERVAL '1 year' - INTERVAL '1 day')) AND (e.emp_resign_enddate IS NULL OR e.emp_resign_enddate >= (CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END + INTERVAL '1 year' - INTERVAL '1 day'))) AS active_at_fy_end
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
        WHERE e.emp_work_begindate IS NULL OR e.emp_resign_enddate IS NULL
          OR e.emp_resign_enddate >= e.emp_work_begindate
      ) hr
-- outer cohort predicate
TRUE
```

- Measures: Voluntary turnover rate of all personnel over the fiscal year (annual anchor). numerator (a) = voluntary resignation events of the fiscal year (emp_resign, monthly counts summed) divided by 12 per the printed average definition (written as SUM over NULLIF(12, 0)) denominator (b) = the average of the staff employed on the first and on the last day of the fiscal year (active_at_fy_start and active_at_fy_end from emp_work_begindate and emp_resign_enddate against the fiscal-year boundaries of the row month) divided by 2 (written as the sum over NULLIF(2, 0)) value = ROUND(a times 100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100. Voluntary resignation is emp_resign rows whose emp_resign_type_name does not mark given-out, dismissed, discharged, retired, early-retired, deceased or transferred staff (name keywords). Confirm the installed emp_resign_type dictionary so only the voluntary group is counted. PDF beyond the branch: the printed definition needs the exact a and b counts certified by the human resources office for the reporting period. Confirm with the hospital owner: the resignation-type dictionary, and that emp_work_begindate and emp_resign_enddate are complete for active and resigned staff so the boundary headcounts are exact.
- รายปีใช้ค่าเฉลี่ยจำนวนลาออกสมัครใจรายเดือนกับค่าเฉลี่ย headcount ต้น/ปลายปีตาม dictionary; SUM(bigint) ใน PostgreSQL เป็น numeric; ห้ามแบ่ง annual turnover เป็น 12 ค่าเดือนโดยปริยาย
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- วันเริ่ม/สิ้นสุดงานว่างยังใช้ fallback ในสูตรเดิม; ยอดฐานแยก unknown temporal; สิ้นสุดก่อนเริ่มงานถูกตัดจาก employee-month; ขอบเขตวันสิ้นสุดและทะเบียนครบต้องยืนยัน HR

Source tables: emp, emp_position_main, emp_resign, emp_resign_type. SQL SHA256: 484ea7f75678b62ac6f9b065a053d9ac98e255584d9086f0525d4b4b27cf3bbd

## SH0102

PDF physical 222; printed 213 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการบาดเจ็บจากการทำงาน

ตัวหาร / population: b = จำนวนบุคลากรเฉลี่ยปีงบประมาณ

Grain: staff / month aggregate (candidate). Key candidates: emp.emp_id, emp.emp_cid. Date candidates: emp.emp_work_begindate, emp.emp_resign_enddate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (sum)
SUM(hr.work_injury_event_cnt)
-- denominator (count)
(COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_fy_start) + COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_fy_end)) / NULLIF(2.0, 0)
-- outer FROM / source
(
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COUNT(*)
            FROM emp_work_sick es
            JOIN emp_work_sick_type st ON st.emp_work_sick_type_id = es.emp_work_sick_type_id
            WHERE es.emp_id = e.emp_id
              AND es.emp_work_sick_sdatetime >= months.work_month
              AND es.emp_work_sick_sdatetime < months.work_month + INTERVAL '1 month'
              AND (st.emp_work_sick_type_name ILIKE '%อันตราย%' OR st.emp_work_sick_type_name ILIKE '%บาดเจ็บ%' OR st.emp_work_sick_type_name ILIKE '%อุบัติเหตุ%')) AS work_injury_event_cnt,
          ((e.emp_work_begindate IS NULL OR e.emp_work_begindate <= CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END) AND (e.emp_resign_enddate IS NULL OR e.emp_resign_enddate >= CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END)) AS active_at_fy_start,
          ((e.emp_work_begindate IS NULL OR e.emp_work_begindate <= (CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END + INTERVAL '1 year' - INTERVAL '1 day')) AND (e.emp_resign_enddate IS NULL OR e.emp_resign_enddate >= (CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END + INTERVAL '1 year' - INTERVAL '1 day'))) AS active_at_fy_end
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
        WHERE e.emp_work_begindate IS NULL OR e.emp_resign_enddate IS NULL
          OR e.emp_resign_enddate >= e.emp_work_begindate
      ) hr
-- outer cohort predicate
TRUE
```

- Measures: Work-related injury events per average fiscal-year headcount (annual anchor). numerator (a) = emp_work_sick events whose type marks an accident, injury or danger event, summed over the fiscal year denominator (b) = the average of the staff employed on the first and on the last day of the fiscal year, divided by 2 (sum over NULLIF(2, 0)) value = ROUND(a times 100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100. Work-related injury and illness events are emp_work_sick rows classified through emp_work_sick_type_name keywords (injury: accident, injury or danger tokens; illness: illness, back-pain, stress or work-disease tokens). HOSxP carries no work-relatedness flag in emp_work_sick, so ordinary sick leave whose type name matches the keywords is over-counted and work-related cases filed under an untyped reason are missed; the social-security work-related registry (emp_social_sick) only covers reported cases and is not joined. PDF beyond the branch: the printed definition needs the exact a and b counts certified by the human resources office for the reporting period. Confirm with the hospital owner: the emp_work_sick_type dictionary and how work-relatedness (a clear accident mechanism) is flagged locally; stage from the occupational health registry if injuries are recorded outside emp_work_sick.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- วันเริ่ม/สิ้นสุดงานว่างยังใช้ fallback ในสูตรเดิม; ยอดฐานแยก unknown temporal; สิ้นสุดก่อนเริ่มงานถูกตัดจาก employee-month; ขอบเขตวันสิ้นสุดและทะเบียนครบต้องยืนยัน HR

Source tables: emp, emp_position_main, emp_work_sick, emp_work_sick_type. SQL SHA256: 68dc2897b53babb91e1d1d0dfe490620e29e9b695516d59378e050c08e54a4fd

## SH0103

PDF physical 223; printed 214 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการเจ็บป่วยจากการทำงาน

ตัวหาร / population: b = จำนวนบุคลากรเฉลี่ยปีงบประมาณ

Grain: staff / month aggregate (candidate). Key candidates: emp.emp_id, emp.emp_cid. Date candidates: emp.emp_work_begindate, emp.emp_resign_enddate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (sum)
SUM(hr.work_illness_event_cnt)
-- denominator (count)
(COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_fy_start) + COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_fy_end)) / NULLIF(2.0, 0)
-- outer FROM / source
(
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COUNT(*)
            FROM emp_work_sick es
            JOIN emp_work_sick_type st ON st.emp_work_sick_type_id = es.emp_work_sick_type_id
            WHERE es.emp_id = e.emp_id
              AND es.emp_work_sick_sdatetime >= months.work_month
              AND es.emp_work_sick_sdatetime < months.work_month + INTERVAL '1 month'
              AND (st.emp_work_sick_type_name ILIKE '%เจ็บป่วย%' OR st.emp_work_sick_type_name ILIKE '%ปวดหลัง%' OR st.emp_work_sick_type_name ILIKE '%เครียด%' OR st.emp_work_sick_type_name ILIKE '%โรคจากการทำงาน%')) AS work_illness_event_cnt,
          ((e.emp_work_begindate IS NULL OR e.emp_work_begindate <= CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END) AND (e.emp_resign_enddate IS NULL OR e.emp_resign_enddate >= CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END)) AS active_at_fy_start,
          ((e.emp_work_begindate IS NULL OR e.emp_work_begindate <= (CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END + INTERVAL '1 year' - INTERVAL '1 day')) AND (e.emp_resign_enddate IS NULL OR e.emp_resign_enddate >= (CASE WHEN EXTRACT(MONTH FROM months.work_month) >= 10 THEN DATE_TRUNC('year', months.work_month)::date + INTERVAL '9 months' ELSE DATE_TRUNC('year', months.work_month)::date - INTERVAL '3 months' END + INTERVAL '1 year' - INTERVAL '1 day'))) AS active_at_fy_end
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
        WHERE e.emp_work_begindate IS NULL OR e.emp_resign_enddate IS NULL
          OR e.emp_resign_enddate >= e.emp_work_begindate
      ) hr
-- outer cohort predicate
TRUE
```

- Measures: Work-related illness events per average fiscal-year headcount (annual anchor). numerator (a) = emp_work_sick events whose type marks illness, back pain, work stress or occupational disease, summed over the fiscal year denominator (b) = the average of the staff employed on the first and on the last day of the fiscal year, divided by 2 (sum over NULLIF(2, 0)) value = ROUND(a times 100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100. Work-related injury and illness events are emp_work_sick rows classified through emp_work_sick_type_name keywords (injury: accident, injury or danger tokens; illness: illness, back-pain, stress or work-disease tokens). HOSxP carries no work-relatedness flag in emp_work_sick, so ordinary sick leave whose type name matches the keywords is over-counted and work-related cases filed under an untyped reason are missed; the social-security work-related registry (emp_social_sick) only covers reported cases and is not joined. PDF beyond the branch: the printed definition needs the exact a and b counts certified by the human resources office for the reporting period. Confirm with the hospital owner: the emp_work_sick_type dictionary and how work-aggravated illness (back pain, work stress) is flagged locally; stage from the occupational health registry if such cases are recorded outside emp_work_sick.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- วันเริ่ม/สิ้นสุดงานว่างยังใช้ fallback ในสูตรเดิม; ยอดฐานแยก unknown temporal; สิ้นสุดก่อนเริ่มงานถูกตัดจาก employee-month; ขอบเขตวันสิ้นสุดและทะเบียนครบต้องยืนยัน HR

Source tables: emp, emp_position_main, emp_work_sick, emp_work_sick_type. SQL SHA256: cfd1535f216daf3d4a1ce201bab878d3465e8db7a6f60130ca6c3fbde4b4d2fc

## SH0104

PDF physical 224; printed 215 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนแพทย์/ทันตแพทย์ที่ลาออกในแต่ละไตรมาส

ตัวหาร / population: b = จำนวนแพทย์/ทันตแพทย์ทั้งหมด ณ วันสุดท้ายของไตรมาสนั้น

Grain: staff / month aggregate (candidate). Key candidates: emp.emp_id, emp.emp_cid. Date candidates: emp.emp_work_begindate, emp.emp_resign_enddate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (sum)
SUM(hr.voluntary_resign_cnt)
-- denominator (count)
COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_period_end)
-- outer FROM / source
(
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COUNT(*)
            FROM emp_resign rr
            LEFT JOIN emp_resign_type rt ON rt.emp_resign_type_id = rr.emp_resign_type_id
            WHERE rr.emp_id = e.emp_id
              AND rr.emp_resign_date >= months.work_month
              AND rr.emp_resign_date < months.work_month + INTERVAL '1 month'
              AND (rt.emp_resign_type_name IS NULL OR rt.emp_resign_type_name NOT ILIKE ANY (ARRAY['%ให้ออก%', '%ไล่ออก%', '%ปลด%', '%เกษียณ%', '%เสียชีวิต%', '%ถึงแก่กรรม%', '%โอน%', '%ย้าย%', '%ตาย%']))) AS voluntary_resign_cnt,
          ((e.emp_work_begindate IS NULL OR e.emp_work_begindate <= (DATE_TRUNC('quarter', months.work_month) + INTERVAL '3 months' - INTERVAL '1 day')) AND (e.emp_resign_enddate IS NULL OR e.emp_resign_enddate >= (DATE_TRUNC('quarter', months.work_month) + INTERVAL '3 months' - INTERVAL '1 day'))) AS active_at_period_end,
          ((COALESCE(pm.emp_position_main_name, '') ILIKE '%แพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%เทคนิคการแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วยแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%แพทย์แผน%')) AS is_physician
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
        WHERE e.emp_work_begindate IS NULL OR e.emp_resign_enddate IS NULL
          OR e.emp_resign_enddate >= e.emp_work_begindate
      ) hr
-- outer cohort predicate
hr.is_physician
```

- Measures: Quarterly voluntary turnover rate of physicians and dentists (quarterly anchor). numerator (a) = voluntary resignation events of physicians and dentists during the quarter denominator (b) = physicians and dentists employed on the last day of the quarter (active_at_period_end against the quarter boundary of the row month; fiscal quarters coincide with calendar quarters) value = ROUND(a times 100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100. Voluntary resignation is emp_resign rows whose emp_resign_type_name does not mark given-out, dismissed, discharged, retired, early-retired, deceased or transferred staff (name keywords). Confirm the installed emp_resign_type dictionary so only the voluntary group is counted. The job-group split (physician and dentist, professional nurse, allied health, back office) is a keyword mapping over emp_position_main.emp_position_main_name: physician and dentist = name contains the physician token minus technician, assistant and Thai-traditional-medicine names; professional nurse = name contains the professional-nurse token minus assistant and employee-nurse names; allied health = the remaining direct-contact occupations named in the printed definition (midwifery, pharmacy, physician assistant, occupational health and environment, physical therapy, nutrition, communication sciences, optometry, occupational therapy, medical technologist and pathology laboratory, pharmacy assistant, prosthetic and orthotic, nursing employee, dental assistant and dental therapist, health records, community health, optical dispensing, physical therapy assistant, occupational health inspector, ambulance worker, central supply and central pharmacy); back office = every remaining position. Confirm the exact installed position names so the mapping reproduces the printed professional and non-professional groups. PDF beyond the branch: the printed definition needs the exact a and b counts certified by the human resources office for the reporting period. Confirm with the hospital owner: the resignation-type and position-name mapping for the physician and dentist group.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- วันเริ่ม/สิ้นสุดงานว่างยังใช้ fallback ในสูตรเดิม; ยอดฐานแยก unknown temporal; สิ้นสุดก่อนเริ่มงานถูกตัดจาก employee-month; ขอบเขตวันสิ้นสุดและทะเบียนครบต้องยืนยัน HR

Source tables: emp, emp_position_main, emp_resign, emp_resign_type. SQL SHA256: c669edd388d5fdc20a2be3e5c076244df23a0cc41afb125e94ba6d4dd3fb7070

## SH0105

PDF physical 225; printed 216 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนพยาบาลวิชาชีพที่ลาออกในแต่ละไตรมาส

ตัวหาร / population: b = จำนวนพยาบาลวิชาชีพทั้งหมด ณ วันสุดท้ายของไตรมาสนั้น

Grain: staff / month aggregate (candidate). Key candidates: emp.emp_id, emp.emp_cid. Date candidates: emp.emp_work_begindate, emp.emp_resign_enddate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (sum)
SUM(hr.voluntary_resign_cnt)
-- denominator (count)
COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_period_end)
-- outer FROM / source
(
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COUNT(*)
            FROM emp_resign rr
            LEFT JOIN emp_resign_type rt ON rt.emp_resign_type_id = rr.emp_resign_type_id
            WHERE rr.emp_id = e.emp_id
              AND rr.emp_resign_date >= months.work_month
              AND rr.emp_resign_date < months.work_month + INTERVAL '1 month'
              AND (rt.emp_resign_type_name IS NULL OR rt.emp_resign_type_name NOT ILIKE ANY (ARRAY['%ให้ออก%', '%ไล่ออก%', '%ปลด%', '%เกษียณ%', '%เสียชีวิต%', '%ถึงแก่กรรม%', '%โอน%', '%ย้าย%', '%ตาย%']))) AS voluntary_resign_cnt,
          ((e.emp_work_begindate IS NULL OR e.emp_work_begindate <= (DATE_TRUNC('quarter', months.work_month) + INTERVAL '3 months' - INTERVAL '1 day')) AND (e.emp_resign_enddate IS NULL OR e.emp_resign_enddate >= (DATE_TRUNC('quarter', months.work_month) + INTERVAL '3 months' - INTERVAL '1 day'))) AS active_at_period_end,
          ((COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาลวิชาชีพ%' OR (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาล%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วย%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%พนักงาน%'))) AS is_nurse
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
        WHERE e.emp_work_begindate IS NULL OR e.emp_resign_enddate IS NULL
          OR e.emp_resign_enddate >= e.emp_work_begindate
      ) hr
-- outer cohort predicate
hr.is_nurse
```

- Measures: Quarterly voluntary turnover rate of professional nurses (quarterly anchor). numerator (a) = voluntary resignation events of professional nurses during the quarter denominator (b) = professional nurses employed on the last day of the quarter (active_at_period_end against the quarter boundary of the row month) value = ROUND(a times 100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100. Voluntary resignation is emp_resign rows whose emp_resign_type_name does not mark given-out, dismissed, discharged, retired, early-retired, deceased or transferred staff (name keywords). Confirm the installed emp_resign_type dictionary so only the voluntary group is counted. The job-group split (physician and dentist, professional nurse, allied health, back office) is a keyword mapping over emp_position_main.emp_position_main_name: physician and dentist = name contains the physician token minus technician, assistant and Thai-traditional-medicine names; professional nurse = name contains the professional-nurse token minus assistant and employee-nurse names; allied health = the remaining direct-contact occupations named in the printed definition (midwifery, pharmacy, physician assistant, occupational health and environment, physical therapy, nutrition, communication sciences, optometry, occupational therapy, medical technologist and pathology laboratory, pharmacy assistant, prosthetic and orthotic, nursing employee, dental assistant and dental therapist, health records, community health, optical dispensing, physical therapy assistant, occupational health inspector, ambulance worker, central supply and central pharmacy); back office = every remaining position. Confirm the exact installed position names so the mapping reproduces the printed professional and non-professional groups. PDF beyond the branch: the printed definition needs the exact a and b counts certified by the human resources office for the reporting period. Confirm with the hospital owner: the resignation-type and position-name mapping for the professional nurse group.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- วันเริ่ม/สิ้นสุดงานว่างยังใช้ fallback ในสูตรเดิม; ยอดฐานแยก unknown temporal; สิ้นสุดก่อนเริ่มงานถูกตัดจาก employee-month; ขอบเขตวันสิ้นสุดและทะเบียนครบต้องยืนยัน HR

Source tables: emp, emp_position_main, emp_resign, emp_resign_type. SQL SHA256: 00a2cc902e048e031fbf0f262f9efaf925ebdc0af47f06c62a7293ed5ba5989d

## SH0106

PDF physical 226; printed 217 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนบุคลากรสาย allied health ที่ลาออกในแต่ละไตรมาส

ตัวหาร / population: b = จำนวนบุคลากรสาย allied health ทั้งหมด ณ วันสุดท้ายของไตรมาสนั้น

Grain: staff / month aggregate (candidate). Key candidates: emp.emp_id, emp.emp_cid. Date candidates: emp.emp_work_begindate, emp.emp_resign_enddate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (sum)
SUM(hr.voluntary_resign_cnt)
-- denominator (count)
COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_period_end)
-- outer FROM / source
(
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COUNT(*)
            FROM emp_resign rr
            LEFT JOIN emp_resign_type rt ON rt.emp_resign_type_id = rr.emp_resign_type_id
            WHERE rr.emp_id = e.emp_id
              AND rr.emp_resign_date >= months.work_month
              AND rr.emp_resign_date < months.work_month + INTERVAL '1 month'
              AND (rt.emp_resign_type_name IS NULL OR rt.emp_resign_type_name NOT ILIKE ANY (ARRAY['%ให้ออก%', '%ไล่ออก%', '%ปลด%', '%เกษียณ%', '%เสียชีวิต%', '%ถึงแก่กรรม%', '%โอน%', '%ย้าย%', '%ตาย%']))) AS voluntary_resign_cnt,
          ((e.emp_work_begindate IS NULL OR e.emp_work_begindate <= (DATE_TRUNC('quarter', months.work_month) + INTERVAL '3 months' - INTERVAL '1 day')) AND (e.emp_resign_enddate IS NULL OR e.emp_resign_enddate >= (DATE_TRUNC('quarter', months.work_month) + INTERVAL '3 months' - INTERVAL '1 day'))) AS active_at_period_end,
          (((NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%แพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%เทคนิคการแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วยแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%แพทย์แผน%')) AND (NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาลวิชาชีพ%' OR (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาล%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วย%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%พนักงาน%'))) AND (COALESCE(pm.emp_position_main_name, '') ILIKE ANY (ARRAY['%ผดุงครรภ์%', '%เภสัช%', '%ผู้ช่วยแพทย์%', '%อาชีวอนามัย%', '%สิ่งแวดล้อม%', '%กายภาพ%', '%โภชนา%', '%สื่อความหมาย%', '%ทัศนมาตร%', '%อาชีวบำบัด%', '%กิจกรรมบำบัด%', '%เทคนิคการแพทย์%', '%เทคนิคพยาธิ%', '%พยาธิ%', '%ผู้ช่วยเภสัช%', '%อุปกรณ์การแพทย์เทียม%', '%พนักงานการพยาบาล%', '%ผู้ช่วยทันต%', '%ทันตภิบาล%', '%เวชระเบียน%', '%สุขภาพชุมชน%', '%ประกอบแว่น%', '%ผู้ช่วยนักกายภาพ%', '%ผู้ตรวจสอบ%', '%รถพยาบาล%', '%จ่ายกลาง%', '%เวชภัณฑ์กลาง%', '%แพทย์แผน%'])))) AS is_allied_health
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
        WHERE e.emp_work_begindate IS NULL OR e.emp_resign_enddate IS NULL
          OR e.emp_resign_enddate >= e.emp_work_begindate
      ) hr
-- outer cohort predicate
hr.is_allied_health
```

- Measures: Quarterly voluntary turnover rate of allied health personnel (quarterly anchor). numerator (a) = voluntary resignation events of allied health personnel during the quarter denominator (b) = allied health personnel employed on the last day of the quarter (active_at_period_end against the quarter boundary of the row month) value = ROUND(a times 100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100. Voluntary resignation is emp_resign rows whose emp_resign_type_name does not mark given-out, dismissed, discharged, retired, early-retired, deceased or transferred staff (name keywords). Confirm the installed emp_resign_type dictionary so only the voluntary group is counted. The job-group split (physician and dentist, professional nurse, allied health, back office) is a keyword mapping over emp_position_main.emp_position_main_name: physician and dentist = name contains the physician token minus technician, assistant and Thai-traditional-medicine names; professional nurse = name contains the professional-nurse token minus assistant and employee-nurse names; allied health = the remaining direct-contact occupations named in the printed definition (midwifery, pharmacy, physician assistant, occupational health and environment, physical therapy, nutrition, communication sciences, optometry, occupational therapy, medical technologist and pathology laboratory, pharmacy assistant, prosthetic and orthotic, nursing employee, dental assistant and dental therapist, health records, community health, optical dispensing, physical therapy assistant, occupational health inspector, ambulance worker, central supply and central pharmacy); back office = every remaining position. Confirm the exact installed position names so the mapping reproduces the printed professional and non-professional groups. PDF beyond the branch: the printed definition needs the exact a and b counts certified by the human resources office for the reporting period. Confirm with the hospital owner: the resignation-type and position-name mapping for the allied health group.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- วันเริ่ม/สิ้นสุดงานว่างยังใช้ fallback ในสูตรเดิม; ยอดฐานแยก unknown temporal; สิ้นสุดก่อนเริ่มงานถูกตัดจาก employee-month; ขอบเขตวันสิ้นสุดและทะเบียนครบต้องยืนยัน HR

Source tables: emp, emp_position_main, emp_resign, emp_resign_type. SQL SHA256: e94f42448dc21d04c504b63cae7f78d2caace839ef52626271b350db44f2ec5d

## SH0107

PDF physical 227; printed 218 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนบุคลากรสายสนับสนุนที่ลาออกในแต่ละไตรมาส

ตัวหาร / population: b = จำนวนบุคลากรสายสนับสนุนทั้งหมด ณ วันสุดท้ายของไตรมาสนั้น

Grain: staff / month aggregate (candidate). Key candidates: emp.emp_id, emp.emp_cid. Date candidates: emp.emp_work_begindate, emp.emp_resign_enddate.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (sum)
SUM(hr.voluntary_resign_cnt)
-- denominator (count)
COUNT(DISTINCT hr.staff_key) FILTER (WHERE hr.active_at_period_end)
-- outer FROM / source
(
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COUNT(*)
            FROM emp_resign rr
            LEFT JOIN emp_resign_type rt ON rt.emp_resign_type_id = rr.emp_resign_type_id
            WHERE rr.emp_id = e.emp_id
              AND rr.emp_resign_date >= months.work_month
              AND rr.emp_resign_date < months.work_month + INTERVAL '1 month'
              AND (rt.emp_resign_type_name IS NULL OR rt.emp_resign_type_name NOT ILIKE ANY (ARRAY['%ให้ออก%', '%ไล่ออก%', '%ปลด%', '%เกษียณ%', '%เสียชีวิต%', '%ถึงแก่กรรม%', '%โอน%', '%ย้าย%', '%ตาย%']))) AS voluntary_resign_cnt,
          ((e.emp_work_begindate IS NULL OR e.emp_work_begindate <= (DATE_TRUNC('quarter', months.work_month) + INTERVAL '3 months' - INTERVAL '1 day')) AND (e.emp_resign_enddate IS NULL OR e.emp_resign_enddate >= (DATE_TRUNC('quarter', months.work_month) + INTERVAL '3 months' - INTERVAL '1 day'))) AS active_at_period_end,
          (((NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%แพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%เทคนิคการแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วยแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%แพทย์แผน%')) AND (NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาลวิชาชีพ%' OR (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาล%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วย%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%พนักงาน%'))) AND (NOT (COALESCE(pm.emp_position_main_name, '') ILIKE ANY (ARRAY['%ผดุงครรภ์%', '%เภสัช%', '%ผู้ช่วยแพทย์%', '%อาชีวอนามัย%', '%สิ่งแวดล้อม%', '%กายภาพ%', '%โภชนา%', '%สื่อความหมาย%', '%ทัศนมาตร%', '%อาชีวบำบัด%', '%กิจกรรมบำบัด%', '%เทคนิคการแพทย์%', '%เทคนิคพยาธิ%', '%พยาธิ%', '%ผู้ช่วยเภสัช%', '%อุปกรณ์การแพทย์เทียม%', '%พนักงานการพยาบาล%', '%ผู้ช่วยทันต%', '%ทันตภิบาล%', '%เวชระเบียน%', '%สุขภาพชุมชน%', '%ประกอบแว่น%', '%ผู้ช่วยนักกายภาพ%', '%ผู้ตรวจสอบ%', '%รถพยาบาล%', '%จ่ายกลาง%', '%เวชภัณฑ์กลาง%', '%แพทย์แผน%']))))) AS is_back_office
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
        WHERE e.emp_work_begindate IS NULL OR e.emp_resign_enddate IS NULL
          OR e.emp_resign_enddate >= e.emp_work_begindate
      ) hr
-- outer cohort predicate
hr.is_back_office
```

- Measures: Quarterly voluntary turnover rate of back office personnel (quarterly anchor). numerator (a) = voluntary resignation events of back office personnel during the quarter denominator (b) = back office personnel employed on the last day of the quarter (active_at_period_end against the quarter boundary of the row month) value = ROUND(a times 100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100. Voluntary resignation is emp_resign rows whose emp_resign_type_name does not mark given-out, dismissed, discharged, retired, early-retired, deceased or transferred staff (name keywords). Confirm the installed emp_resign_type dictionary so only the voluntary group is counted. The job-group split (physician and dentist, professional nurse, allied health, back office) is a keyword mapping over emp_position_main.emp_position_main_name: physician and dentist = name contains the physician token minus technician, assistant and Thai-traditional-medicine names; professional nurse = name contains the professional-nurse token minus assistant and employee-nurse names; allied health = the remaining direct-contact occupations named in the printed definition (midwifery, pharmacy, physician assistant, occupational health and environment, physical therapy, nutrition, communication sciences, optometry, occupational therapy, medical technologist and pathology laboratory, pharmacy assistant, prosthetic and orthotic, nursing employee, dental assistant and dental therapist, health records, community health, optical dispensing, physical therapy assistant, occupational health inspector, ambulance worker, central supply and central pharmacy); back office = every remaining position. Confirm the exact installed position names so the mapping reproduces the printed professional and non-professional groups. PDF beyond the branch: the printed definition needs the exact a and b counts certified by the human resources office for the reporting period. Confirm with the hospital owner: the resignation-type and position-name mapping for the back office group.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- วันเริ่ม/สิ้นสุดงานว่างยังใช้ fallback ในสูตรเดิม; ยอดฐานแยก unknown temporal; สิ้นสุดก่อนเริ่มงานถูกตัดจาก employee-month; ขอบเขตวันสิ้นสุดและทะเบียนครบต้องยืนยัน HR

Source tables: emp, emp_position_main, emp_resign, emp_resign_type. SQL SHA256: eaac4f30446c46f2634f3340d80705bf05147e84bcd615d6195d866bb28f4b4f

## SH0201

PDF physical 228; printed 219 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนแพทย์/ทันตแพทย์ ที่ตอบแบบสอบถามมีระดับความพึงพอใจในระดับ 4-5

ตัวหาร / population: b = จำนวนแพทย์/ทันตแพทย์ ที่ตอบแบบสอบถามทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SH0201'
```

- Measures: the level 4 to 5 share of overall organizational satisfaction among physicians and dentists, from the single five-level questionnaire item. The branch is branchExternal over reporting.thip_external_facts. PDF beyond the branch: the the level 4 to 5 share response counts of physicians and dentists from the employee satisfaction survey of the fiscal year. Confirm with the hospital owner: that the installed instrument is the printed single item with the five-level scale, and the response counts per job group. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): one row per annual reporting anchor with period_start = 1 October of the fiscal year (fiscal month 1), numerator = a, denominator = b, value = ROUND(a times 100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100, source_system = the employee satisfaction survey system. No HOSxP table holds the printed questionnaire: the item is the single question on overall organizational satisfaction answered on a five-level scale, and neither the instrument version nor the level semantics can be confirmed from the HOSxP survey tables (survey_satisfy_head_pcu, survey_satisfy_screen_pcu, survey_satisfy_choice_pcu and dis_satisfied belong to other, unversioned instruments). The survey result must therefore be aggregated by the hospital and loaded into reporting.thip_external_facts.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 765a34838cf47941b6b2b773117a9cd53016d0d6a68f35de8f4612a6bd6bf146

## SH0202

PDF physical 229; printed 220 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนพยาบาลวิชาชีพที่ตอบแบบสอบถามมีระดับความพึงพอใจในระดับ 4-5

ตัวหาร / population: b = จำนวนพยาบาลวิชาชีพที่ตอบแบบสอบถามทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SH0202'
```

- Measures: the level 4 to 5 share of overall organizational satisfaction among professional nurses, from the single five-level questionnaire item. The branch is branchExternal over reporting.thip_external_facts. PDF beyond the branch: the the level 4 to 5 share response counts of professional nurses from the employee satisfaction survey of the fiscal year. Confirm with the hospital owner: that the installed instrument is the printed single item with the five-level scale, and the response counts per job group. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): one row per annual reporting anchor with period_start = 1 October of the fiscal year (fiscal month 1), numerator = a, denominator = b, value = ROUND(a times 100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100, source_system = the employee satisfaction survey system. No HOSxP table holds the printed questionnaire: the item is the single question on overall organizational satisfaction answered on a five-level scale, and neither the instrument version nor the level semantics can be confirmed from the HOSxP survey tables (survey_satisfy_head_pcu, survey_satisfy_screen_pcu, survey_satisfy_choice_pcu and dis_satisfied belong to other, unversioned instruments). The survey result must therefore be aggregated by the hospital and loaded into reporting.thip_external_facts.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 6ec84de052ed81e9e65cfea908acf221ce0c05ea86d90d8b73cc25eb511221ff

## SH0203

PDF physical 230; printed 221 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนบุคลากรสาย allied health ที่ตอบแบบสอบถามมีระดับความพึงพอใจใน ระดับ 4-5

ตัวหาร / population: b = จำนวนบุคลากรสาย allied health ที่ตอบแบบสอบถามทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SH0203'
```

- Measures: the level 4 to 5 share of overall organizational satisfaction among allied health personnel, from the single five-level questionnaire item. The branch is branchExternal over reporting.thip_external_facts. PDF beyond the branch: the the level 4 to 5 share response counts of allied health personnel from the employee satisfaction survey of the fiscal year. Confirm with the hospital owner: that the installed instrument is the printed single item with the five-level scale, and the response counts per job group. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): one row per annual reporting anchor with period_start = 1 October of the fiscal year (fiscal month 1), numerator = a, denominator = b, value = ROUND(a times 100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100, source_system = the employee satisfaction survey system. No HOSxP table holds the printed questionnaire: the item is the single question on overall organizational satisfaction answered on a five-level scale, and neither the instrument version nor the level semantics can be confirmed from the HOSxP survey tables (survey_satisfy_head_pcu, survey_satisfy_screen_pcu, survey_satisfy_choice_pcu and dis_satisfied belong to other, unversioned instruments). The survey result must therefore be aggregated by the hospital and loaded into reporting.thip_external_facts.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: ff0cd4c31ec452d78990f052aa349d9e8f5f951dc2628c4474aaa2363c18dec8

## SH0204

PDF physical 231; printed 222 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนชั่วโมงของแพทย์/ ทันตแพทย์ที่ได้ฝึกอบรมเพื่อพัฒนาทักษะตามสายวิชาชีพ ของตน

ตัวหาร / population: b = จำนวนบุคลากรสายแพทย์/ทันตแพทย์ทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ชั่วโมง; formula: a/b. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SH0204'
```

- Measures: training hours per person per year of physicians and dentists (counted events: study, training, short research, observation visits, academic services, meetings, seminars with explicit schedules; one training day is six hours). The branch is branchExternal over reporting.thip_external_facts. PDF beyond the branch: total counted training hours and the staff count of physicians and dentists for the fiscal year. Confirm with the hospital owner: the counted-hour rules and the job-group roster used for the denominator. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): one row per annual reporting anchor with period_start = 1 October of the fiscal year (fiscal month 1), numerator = a (training hours), denominator = b (staff count of the group), value = ROUND(a times 1 divided by NULLIF(b, 0), 2) per formulaScale a over b, source_system = the human resources training register. No HOSxP table holds the staff training-hour register (the emp_work_study and emp_education tables hold leave-for-study records and education-level lookups, and emp_educate_child and emp_wf_edu_regis cover children and welfare education, not staff training events with hours). Training hours must be aggregated by the human resources office and loaded into reporting.thip_external_facts.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: dfa76090e0e0ae909c8cbd666efd67e188ef20586b23b4e4f02595ead371ac73

## SH0205

PDF physical 232; printed 223 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนชั่วโมงของพยาบาลวิชาชีพที่ได้ฝึกอบรมเพื่อพัฒนาทักษะตามสายวิชาชีพของ ตน

ตัวหาร / population: b = จำนวนบุคลากรพยาบาลวิชาชีพทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ชั่วโมง; formula: a/b. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SH0205'
```

- Measures: training hours per person per year of professional nurses (counted events: study, training, short research, observation visits, academic services, meetings, seminars with explicit schedules; one training day is six hours). The branch is branchExternal over reporting.thip_external_facts. PDF beyond the branch: total counted training hours and the staff count of professional nurses for the fiscal year. Confirm with the hospital owner: the counted-hour rules and the job-group roster used for the denominator. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): one row per annual reporting anchor with period_start = 1 October of the fiscal year (fiscal month 1), numerator = a (training hours), denominator = b (staff count of the group), value = ROUND(a times 1 divided by NULLIF(b, 0), 2) per formulaScale a over b, source_system = the human resources training register. No HOSxP table holds the staff training-hour register (the emp_work_study and emp_education tables hold leave-for-study records and education-level lookups, and emp_educate_child and emp_wf_edu_regis cover children and welfare education, not staff training events with hours). Training hours must be aggregated by the human resources office and loaded into reporting.thip_external_facts.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: c43589a78e4eaede54f6f2e997f801c1787fb6196e425635b4cd570aa00b0ed1

## SH0206

PDF physical 233; printed 224 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = ผลรวมคะแนนระดับความพึงพอใจของแพทย์/ทันตแพทย์ ที่ตอบแบบสอบถาม

ตัวหาร / population: b = คะแนนเต็มระดับความพึงพอใจของแพทย์/ทันตแพทย์ ที่ตอบแบบสอบถามทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SH0206'
```

- Measures: the average satisfaction share of overall organizational satisfaction among physicians and dentists, from the single five-level questionnaire item. The branch is branchExternal over reporting.thip_external_facts. PDF beyond the branch: the the average satisfaction share response counts of physicians and dentists from the employee satisfaction survey of the fiscal year. Confirm with the hospital owner: that the installed instrument is the printed single item with the five-level scale, and the response counts per job group. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): one row per annual reporting anchor with period_start = 1 October of the fiscal year (fiscal month 1), numerator = a, denominator = b, value = ROUND(a times 100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100, source_system = the employee satisfaction survey system. No HOSxP table holds the printed questionnaire: the item is the single question on overall organizational satisfaction answered on a five-level scale, and neither the instrument version nor the level semantics can be confirmed from the HOSxP survey tables (survey_satisfy_head_pcu, survey_satisfy_screen_pcu, survey_satisfy_choice_pcu and dis_satisfied belong to other, unversioned instruments). The survey result must therefore be aggregated by the hospital and loaded into reporting.thip_external_facts.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 6953ea04976e8db1a799cdda32ccb36aa03985a6007e5ae83420e69cb5cb447d

## SH0207

PDF physical 234; printed 225 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนแพทย์/ทันตแพทย์ที่ตอบแบบสอบถามมีระดับความพึงพอใจในระดับ 1-2

ตัวหาร / population: b = จำนวนแพทย์/ทันตแพทย์ที่ตอบแบบสอบถามทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SH0207'
```

- Measures: the level 1 to 2 share of overall organizational satisfaction among physicians and dentists, from the single five-level questionnaire item. The branch is branchExternal over reporting.thip_external_facts. PDF beyond the branch: the the level 1 to 2 share response counts of physicians and dentists from the employee satisfaction survey of the fiscal year. Confirm with the hospital owner: that the installed instrument is the printed single item with the five-level scale, and the response counts per job group. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): one row per annual reporting anchor with period_start = 1 October of the fiscal year (fiscal month 1), numerator = a, denominator = b, value = ROUND(a times 100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100, source_system = the employee satisfaction survey system. No HOSxP table holds the printed questionnaire: the item is the single question on overall organizational satisfaction answered on a five-level scale, and neither the instrument version nor the level semantics can be confirmed from the HOSxP survey tables (survey_satisfy_head_pcu, survey_satisfy_screen_pcu, survey_satisfy_choice_pcu and dis_satisfied belong to other, unversioned instruments). The survey result must therefore be aggregated by the hospital and loaded into reporting.thip_external_facts.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 84564da77457fb7c71781a9f3529ce21a52002e930fe378ce78884ce60f3020d

## SH0208

PDF physical 235; printed 226 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = ผลรวมคะแนนระดับความพึงพอใจของพยาบาลวิชาชีพที่ตอบแบบสอบถาม

ตัวหาร / population: b = คะแนนเต็มระดับความพึงพอใจของพยาบาลวิชาชีพที่ตอบแบบสอบถามทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SH0208'
```

- Measures: the average satisfaction share of overall organizational satisfaction among professional nurses, from the single five-level questionnaire item. The branch is branchExternal over reporting.thip_external_facts. PDF beyond the branch: the the average satisfaction share response counts of professional nurses from the employee satisfaction survey of the fiscal year. Confirm with the hospital owner: that the installed instrument is the printed single item with the five-level scale, and the response counts per job group. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): one row per annual reporting anchor with period_start = 1 October of the fiscal year (fiscal month 1), numerator = a, denominator = b, value = ROUND(a times 100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100, source_system = the employee satisfaction survey system. No HOSxP table holds the printed questionnaire: the item is the single question on overall organizational satisfaction answered on a five-level scale, and neither the instrument version nor the level semantics can be confirmed from the HOSxP survey tables (survey_satisfy_head_pcu, survey_satisfy_screen_pcu, survey_satisfy_choice_pcu and dis_satisfied belong to other, unversioned instruments). The survey result must therefore be aggregated by the hospital and loaded into reporting.thip_external_facts.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 7a3d4fd4e0163ba054198a95a0f7a9707b2e1cffac329b11f57cc6136281d2c0

## SH0209

PDF physical 236; printed 227 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนพยาบาลวิชาชีพที่ตอบแบบสอบถามมีระดับความพึงพอใจในระดับ 1-2

ตัวหาร / population: b = จำนวนพยาบาลวิชาชีพที่ตอบแบบสอบถามทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SH0209'
```

- Measures: the level 1 to 2 share of overall organizational satisfaction among professional nurses, from the single five-level questionnaire item. The branch is branchExternal over reporting.thip_external_facts. PDF beyond the branch: the the level 1 to 2 share response counts of professional nurses from the employee satisfaction survey of the fiscal year. Confirm with the hospital owner: that the installed instrument is the printed single item with the five-level scale, and the response counts per job group. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): one row per annual reporting anchor with period_start = 1 October of the fiscal year (fiscal month 1), numerator = a, denominator = b, value = ROUND(a times 100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100, source_system = the employee satisfaction survey system. No HOSxP table holds the printed questionnaire: the item is the single question on overall organizational satisfaction answered on a five-level scale, and neither the instrument version nor the level semantics can be confirmed from the HOSxP survey tables (survey_satisfy_head_pcu, survey_satisfy_screen_pcu, survey_satisfy_choice_pcu and dis_satisfied belong to other, unversioned instruments). The survey result must therefore be aggregated by the hospital and loaded into reporting.thip_external_facts.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: b8e3657a2d91b09a8d3d3716b2fe713c8666d081e9607db0bf7c4790b09c233c

## SH0210

PDF physical 237; printed 228 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = ผลรวมคะแนนระดับความพึงพอใจของบุคลากรสาย allied health ที่ตอบ แบบสอบถาม

ตัวหาร / population: b = คะแนนเต็มระดับความพึงพอใจของบุคลากรสาย allied health ที่ตอบแบบสอบถาม ทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SH0210'
```

- Measures: the average satisfaction share of overall organizational satisfaction among allied health personnel, from the single five-level questionnaire item. The branch is branchExternal over reporting.thip_external_facts. PDF beyond the branch: the the average satisfaction share response counts of allied health personnel from the employee satisfaction survey of the fiscal year. Confirm with the hospital owner: that the installed instrument is the printed single item with the five-level scale, and the response counts per job group. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): one row per annual reporting anchor with period_start = 1 October of the fiscal year (fiscal month 1), numerator = a, denominator = b, value = ROUND(a times 100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100, source_system = the employee satisfaction survey system. No HOSxP table holds the printed questionnaire: the item is the single question on overall organizational satisfaction answered on a five-level scale, and neither the instrument version nor the level semantics can be confirmed from the HOSxP survey tables (survey_satisfy_head_pcu, survey_satisfy_screen_pcu, survey_satisfy_choice_pcu and dis_satisfied belong to other, unversioned instruments). The survey result must therefore be aggregated by the hospital and loaded into reporting.thip_external_facts.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 1ffe42eda88b5d47a84e32e3f05a8c637776cabdfc8fdd8235960b81193b4a84

## SH0211

PDF physical 238; printed 229 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนบุคลากรสาย allied health ที่ตอบแบบสอบถามมีระดับความพึงพอใจใน ระดับ 1-2

ตัวหาร / population: b = จำนวนบุคลากรสาย allied health ที่ตอบแบบสอบถามทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SH0211'
```

- Measures: the level 1 to 2 share of overall organizational satisfaction among allied health personnel, from the single five-level questionnaire item. The branch is branchExternal over reporting.thip_external_facts. PDF beyond the branch: the the level 1 to 2 share response counts of allied health personnel from the employee satisfaction survey of the fiscal year. Confirm with the hospital owner: that the installed instrument is the printed single item with the five-level scale, and the response counts per job group. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): one row per annual reporting anchor with period_start = 1 October of the fiscal year (fiscal month 1), numerator = a, denominator = b, value = ROUND(a times 100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100, source_system = the employee satisfaction survey system. No HOSxP table holds the printed questionnaire: the item is the single question on overall organizational satisfaction answered on a five-level scale, and neither the instrument version nor the level semantics can be confirmed from the HOSxP survey tables (survey_satisfy_head_pcu, survey_satisfy_screen_pcu, survey_satisfy_choice_pcu and dis_satisfied belong to other, unversioned instruments). The survey result must therefore be aggregated by the hospital and loaded into reporting.thip_external_facts.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 728fd3886c7e3882a3b461cc4a4671aee2645efc8239843144f6442e6ed2c6d5

## SH0212

PDF physical 239; printed 230 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = ผลรวมคะแนนระดับความพึงพอใจของบุคลากรสายสนับสนุนที่ตอบแบบสอบถาม

ตัวหาร / population: b = คะแนนเต็มระดับความพึงพอใจของบุคลากรสายสนับสนุนที่ตอบแบบสอบถามทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SH0212'
```

- Measures: the average satisfaction share of overall organizational satisfaction among back office personnel, from the single five-level questionnaire item. The branch is branchExternal over reporting.thip_external_facts. PDF beyond the branch: the the average satisfaction share response counts of back office personnel from the employee satisfaction survey of the fiscal year. Confirm with the hospital owner: that the installed instrument is the printed single item with the five-level scale, and the response counts per job group. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): one row per annual reporting anchor with period_start = 1 October of the fiscal year (fiscal month 1), numerator = a, denominator = b, value = ROUND(a times 100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100, source_system = the employee satisfaction survey system. No HOSxP table holds the printed questionnaire: the item is the single question on overall organizational satisfaction answered on a five-level scale, and neither the instrument version nor the level semantics can be confirmed from the HOSxP survey tables (survey_satisfy_head_pcu, survey_satisfy_screen_pcu, survey_satisfy_choice_pcu and dis_satisfied belong to other, unversioned instruments). The survey result must therefore be aggregated by the hospital and loaded into reporting.thip_external_facts.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: daf8965af00e8b1e7c26ea9bb14cb23d29ade65361b1f7b158a00f55f9ce255a

## SH0213

PDF physical 240; printed 231 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนบุคลากรสายสนับสนุนที่ตอบแบบสอบถามมีระดับความพึงพอใจในระดับ 4-5

ตัวหาร / population: b = จำนวนบุคลากรสายสนับสนุนที่ตอบแบบสอบถามทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SH0213'
```

- Measures: the level 4 to 5 share of overall organizational satisfaction among back office personnel, from the single five-level questionnaire item. The branch is branchExternal over reporting.thip_external_facts. PDF beyond the branch: the the level 4 to 5 share response counts of back office personnel from the employee satisfaction survey of the fiscal year. Confirm with the hospital owner: that the installed instrument is the printed single item with the five-level scale, and the response counts per job group. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): one row per annual reporting anchor with period_start = 1 October of the fiscal year (fiscal month 1), numerator = a, denominator = b, value = ROUND(a times 100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100, source_system = the employee satisfaction survey system. No HOSxP table holds the printed questionnaire: the item is the single question on overall organizational satisfaction answered on a five-level scale, and neither the instrument version nor the level semantics can be confirmed from the HOSxP survey tables (survey_satisfy_head_pcu, survey_satisfy_screen_pcu, survey_satisfy_choice_pcu and dis_satisfied belong to other, unversioned instruments). The survey result must therefore be aggregated by the hospital and loaded into reporting.thip_external_facts.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 87f6cad4ccfe18a02acd06760a7c1d4a0996952b5974ca2b42192784a1f931c7

## SH0214

PDF physical 241; printed 232 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนบุคลากรสายสนับสนุนที่ตอบแบบสอบถามมีระดับความพึงพอใจในระดับ 1-2

ตัวหาร / population: b = จำนวนบุคลากรสายสนับสนุนที่ตอบแบบสอบถามทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SH0214'
```

- Measures: the level 1 to 2 share of overall organizational satisfaction among back office personnel, from the single five-level questionnaire item. The branch is branchExternal over reporting.thip_external_facts. PDF beyond the branch: the the level 1 to 2 share response counts of back office personnel from the employee satisfaction survey of the fiscal year. Confirm with the hospital owner: that the installed instrument is the printed single item with the five-level scale, and the response counts per job group. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): one row per annual reporting anchor with period_start = 1 October of the fiscal year (fiscal month 1), numerator = a, denominator = b, value = ROUND(a times 100 divided by NULLIF(b, 0), 2) per formulaScale a over b times 100, source_system = the employee satisfaction survey system. No HOSxP table holds the printed questionnaire: the item is the single question on overall organizational satisfaction answered on a five-level scale, and neither the instrument version nor the level semantics can be confirmed from the HOSxP survey tables (survey_satisfy_head_pcu, survey_satisfy_screen_pcu, survey_satisfy_choice_pcu and dis_satisfied belong to other, unversioned instruments). The survey result must therefore be aggregated by the hospital and loaded into reporting.thip_external_facts.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: c59f04d59ac70ac5a3666c0898f445626f69aba9f66ced52657ffc333464ed5b

## SH0215

PDF physical 242; printed 233 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนชั่วโมงของบุคลากรสาย allied health ที่ได้ฝึกอบรมเพื่อพัฒนาทักษะตามสาย วิชาชีพของตน

ตัวหาร / population: b = จำนวนบุคลากรสาย allied health ทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ชั่วโมง; formula: a/b. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SH0215'
```

- Measures: training hours per person per year of allied health personnel (counted events: study, training, short research, observation visits, academic services, meetings, seminars with explicit schedules; one training day is six hours). The branch is branchExternal over reporting.thip_external_facts. PDF beyond the branch: total counted training hours and the staff count of allied health personnel for the fiscal year. Confirm with the hospital owner: the counted-hour rules and the job-group roster used for the denominator. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): one row per annual reporting anchor with period_start = 1 October of the fiscal year (fiscal month 1), numerator = a (training hours), denominator = b (staff count of the group), value = ROUND(a times 1 divided by NULLIF(b, 0), 2) per formulaScale a over b, source_system = the human resources training register. No HOSxP table holds the staff training-hour register (the emp_work_study and emp_education tables hold leave-for-study records and education-level lookups, and emp_educate_child and emp_wf_edu_regis cover children and welfare education, not staff training events with hours). Training hours must be aggregated by the human resources office and loaded into reporting.thip_external_facts.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 20d90941c6e55fca7a9fa4d6e3ff9b345d75d84359fe7e6cda2858e15a9e537a

## SH0216

PDF physical 243; printed 234 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนชั่วโมงของบุคลากรสายสนับสนุนที่ได้ฝึกอบรมเพื่อพัฒนาทักษะตามสายวิชาชีพ ของตน

ตัวหาร / population: b = จำนวนบุคลากรสายสนับสนุนทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ชั่วโมง; formula: a/b. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SH0216'
```

- Measures: training hours per person per year of back office personnel (counted events: study, training, short research, observation visits, academic services, meetings, seminars with explicit schedules; one training day is six hours). The branch is branchExternal over reporting.thip_external_facts. PDF beyond the branch: total counted training hours and the staff count of back office personnel for the fiscal year. Confirm with the hospital owner: the counted-hour rules and the job-group roster used for the denominator. Staging rows for reporting.thip_external_facts (columns indicator_code, period_start, numerator, denominator, value, source_system): one row per annual reporting anchor with period_start = 1 October of the fiscal year (fiscal month 1), numerator = a (training hours), denominator = b (staff count of the group), value = ROUND(a times 1 divided by NULLIF(b, 0), 2) per formulaScale a over b, source_system = the human resources training register. No HOSxP table holds the staff training-hour register (the emp_work_study and emp_education tables hold leave-for-study records and education-level lookups, and emp_educate_child and emp_wf_edu_regis cover children and welfare education, not staff training events with hours). Training hours must be aggregated by the human resources office and loaded into reporting.thip_external_facts.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 028514b0af0b29ab324ad1166561251b0764429ed1a497f91cf6b2c4aa029eef

## SH0301

PDF physical 244; printed 235 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งที่บุคลากรได้รับบาดเจ็บ/เจ็บป่วย เนื่องจากการทำงานในช่วงเวลาที่กำหนด

ตัวหาร / population: b = จำนวนชั่วโมงการทำงานทั้งสิ้นของบุคลากรในองค์กรในช่วงเวลาเดียวกัน

Grain: staff / month aggregate (candidate). Key candidates: emp.emp_id, emp.emp_cid. Date candidates: emp.emp_work_begindate, emp.emp_resign_enddate.

Unit: ครั้งต่อล้านชั่วโมงการทำงาน; formula: (a/b) x 1,000,000. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (sum)
SUM(hr.work_injury_event_cnt) + SUM(hr.work_illness_event_cnt)
-- denominator (sum)
SUM(hr.work_hours)
-- outer FROM / source
(
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COUNT(*)
            FROM emp_work_sick es
            JOIN emp_work_sick_type st ON st.emp_work_sick_type_id = es.emp_work_sick_type_id
            WHERE es.emp_id = e.emp_id
              AND es.emp_work_sick_sdatetime >= months.work_month
              AND es.emp_work_sick_sdatetime < months.work_month + INTERVAL '1 month'
              AND (st.emp_work_sick_type_name ILIKE '%อันตราย%' OR st.emp_work_sick_type_name ILIKE '%บาดเจ็บ%' OR st.emp_work_sick_type_name ILIKE '%อุบัติเหตุ%')) AS work_injury_event_cnt,
          (SELECT COUNT(*)
            FROM emp_work_sick es
            JOIN emp_work_sick_type st ON st.emp_work_sick_type_id = es.emp_work_sick_type_id
            WHERE es.emp_id = e.emp_id
              AND es.emp_work_sick_sdatetime >= months.work_month
              AND es.emp_work_sick_sdatetime < months.work_month + INTERVAL '1 month'
              AND (st.emp_work_sick_type_name ILIKE '%เจ็บป่วย%' OR st.emp_work_sick_type_name ILIKE '%ปวดหลัง%' OR st.emp_work_sick_type_name ILIKE '%เครียด%' OR st.emp_work_sick_type_name ILIKE '%โรคจากการทำงาน%')) AS work_illness_event_cnt,
          ((SELECT COUNT(*)
            FROM emp_work_schedule wsc
            LEFT JOIN emp_work_status wst ON wst.emp_work_status_id = wsc.emp_work_status_id
            WHERE wsc.emp_id = e.emp_id
              AND wsc.emp_work_schedule_workdate >= months.work_month
              AND wsc.emp_work_schedule_workdate < months.work_month + INTERVAL '1 month'
              AND COALESCE(wst.emp_work_status_name, '') NOT ILIKE '%ลา%'
              AND COALESCE(wst.emp_work_status_name, '') NOT ILIKE '%หยุด%'
          ) * 8) AS work_hours
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
        WHERE e.emp_work_begindate IS NULL OR e.emp_resign_enddate IS NULL
          OR e.emp_resign_enddate >= e.emp_work_begindate
      ) hr
-- outer cohort predicate
TRUE
```

- Measures: Injury and illness frequency rate per one million work hours of all personnel (monthly anchor). numerator (a) = emp_work_sick injury and illness events of the month denominator (b) = work hours of the month (rostered shifts times 8 hours) of all personnel value = ROUND(a times 1000000 divided by NULLIF(b, 0), 2) per formulaScale a over b times 1000000. Work-related injury and illness events are emp_work_sick rows classified through emp_work_sick_type_name keywords (injury: accident, injury or danger tokens; illness: illness, back-pain, stress or work-disease tokens). HOSxP carries no work-relatedness flag in emp_work_sick, so ordinary sick leave whose type name matches the keywords is over-counted and work-related cases filed under an untyped reason are missed; the social-security work-related registry (emp_social_sick) only covers reported cases and is not joined. Work hours are the rostered shifts of emp_work_schedule per employee-month (rows whose emp_work_status_name marks leave or holiday are dropped) multiplied by eight hours per shift; the printed definition allows other shift lengths (eight or ten hours) and wants the real hours of each shift. If true shift lengths or clocked hours are maintained, stage the monthly work-hour totals instead. PDF beyond the branch: the printed definition needs the exact a and b counts certified by the human resources office for the reporting period. Confirm with the hospital owner: the emp_work_sick_type dictionary, the shift rostering convention and the hours per shift.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- วันเริ่ม/สิ้นสุดงานว่างยังใช้ fallback ในสูตรเดิม; ยอดฐานแยก unknown temporal; สิ้นสุดก่อนเริ่มงานถูกตัดจาก employee-month; ขอบเขตวันสิ้นสุดและทะเบียนครบต้องยืนยัน HR

Source tables: emp, emp_position_main, emp_work_schedule, emp_work_sick, emp_work_sick_type, emp_work_status. SQL SHA256: 96e38445b77a2ee663b8a844663b2d993217b0a6d63ad5e5de0dd364b4f3b5b5

## SH0302

PDF physical 245; printed 236, 237 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนวันที่บุคลากรกลุ่มสัมผัสผู้ป่วยโดยตรงทั้งหมดขององค์กรหยุดงานหรือสูญเสีย เนื่องจากการบาดเจ็บในช่วงเวลาที่กำหนด

ตัวหาร / population: b = จำนวนชั่วโมงการทำงานทั้งหมดของบุคลากรกลุ่มสัมผัสผู้ป่วยโดยตรงในองค์กร ในช่วง เวลาเดียวกัน

Grain: staff / month aggregate (candidate). Key candidates: emp.emp_id, emp.emp_cid. Date candidates: emp.emp_work_begindate, emp.emp_resign_enddate.

Unit: จำนวนวันที่หยุดงานหรือสูญเสียเนื่องจากการบาดเจ็บต่อหนึ่งล้านชั่วโมงการทำงาน; formula: (a/b) x 1,000,000. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (sum)
SUM(hr.injury_lost_days)
-- denominator (sum)
SUM(hr.work_hours)
-- outer FROM / source
(
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COALESCE(SUM(es.emp_work_sick_countday), 0)
            FROM emp_work_sick es
            JOIN emp_work_sick_type st ON st.emp_work_sick_type_id = es.emp_work_sick_type_id
            WHERE es.emp_id = e.emp_id
              AND es.emp_work_sick_sdatetime >= months.work_month
              AND es.emp_work_sick_sdatetime < months.work_month + INTERVAL '1 month'
              AND (st.emp_work_sick_type_name ILIKE '%อันตราย%' OR st.emp_work_sick_type_name ILIKE '%บาดเจ็บ%' OR st.emp_work_sick_type_name ILIKE '%อุบัติเหตุ%')) AS injury_lost_days,
          ((SELECT COUNT(*)
            FROM emp_work_schedule wsc
            LEFT JOIN emp_work_status wst ON wst.emp_work_status_id = wsc.emp_work_status_id
            WHERE wsc.emp_id = e.emp_id
              AND wsc.emp_work_schedule_workdate >= months.work_month
              AND wsc.emp_work_schedule_workdate < months.work_month + INTERVAL '1 month'
              AND COALESCE(wst.emp_work_status_name, '') NOT ILIKE '%ลา%'
              AND COALESCE(wst.emp_work_status_name, '') NOT ILIKE '%หยุด%'
          ) * 8) AS work_hours,
          (((COALESCE(pm.emp_position_main_name, '') ILIKE '%แพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%เทคนิคการแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วยแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%แพทย์แผน%') OR (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาลวิชาชีพ%' OR (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาล%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วย%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%พนักงาน%')) OR ((NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%แพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%เทคนิคการแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วยแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%แพทย์แผน%')) AND (NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาลวิชาชีพ%' OR (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาล%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วย%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%พนักงาน%'))) AND (COALESCE(pm.emp_position_main_name, '') ILIKE ANY (ARRAY['%ผดุงครรภ์%', '%เภสัช%', '%ผู้ช่วยแพทย์%', '%อาชีวอนามัย%', '%สิ่งแวดล้อม%', '%กายภาพ%', '%โภชนา%', '%สื่อความหมาย%', '%ทัศนมาตร%', '%อาชีวบำบัด%', '%กิจกรรมบำบัด%', '%เทคนิคการแพทย์%', '%เทคนิคพยาธิ%', '%พยาธิ%', '%ผู้ช่วยเภสัช%', '%อุปกรณ์การแพทย์เทียม%', '%พนักงานการพยาบาล%', '%ผู้ช่วยทันต%', '%ทันตภิบาล%', '%เวชระเบียน%', '%สุขภาพชุมชน%', '%ประกอบแว่น%', '%ผู้ช่วยนักกายภาพ%', '%ผู้ตรวจสอบ%', '%รถพยาบาล%', '%จ่ายกลาง%', '%เวชภัณฑ์กลาง%', '%แพทย์แผน%']))))) AS is_direct_contact
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
        WHERE e.emp_work_begindate IS NULL OR e.emp_resign_enddate IS NULL
          OR e.emp_resign_enddate >= e.emp_work_begindate
      ) hr
-- outer cohort predicate
hr.is_direct_contact
```

- Measures: Injury severity rate (lost workdays per one million work hours) of direct-contact personnel (monthly anchor). numerator (a) = lost workdays (emp_work_sick_countday) of injury events of direct-contact personnel in the month denominator (b) = work hours of the month of direct-contact personnel (rostered shifts times 8 hours) value = ROUND(a times 1000000 divided by NULLIF(b, 0), 2) per formulaScale a over b times 1000000. Work-related injury and illness events are emp_work_sick rows classified through emp_work_sick_type_name keywords (injury: accident, injury or danger tokens; illness: illness, back-pain, stress or work-disease tokens). HOSxP carries no work-relatedness flag in emp_work_sick, so ordinary sick leave whose type name matches the keywords is over-counted and work-related cases filed under an untyped reason are missed; the social-security work-related registry (emp_social_sick) only covers reported cases and is not joined. Work hours are the rostered shifts of emp_work_schedule per employee-month (rows whose emp_work_status_name marks leave or holiday are dropped) multiplied by eight hours per shift; the printed definition allows other shift lengths (eight or ten hours) and wants the real hours of each shift. If true shift lengths or clocked hours are maintained, stage the monthly work-hour totals instead. The job-group split (physician and dentist, professional nurse, allied health, back office) is a keyword mapping over emp_position_main.emp_position_main_name: physician and dentist = name contains the physician token minus technician, assistant and Thai-traditional-medicine names; professional nurse = name contains the professional-nurse token minus assistant and employee-nurse names; allied health = the remaining direct-contact occupations named in the printed definition (midwifery, pharmacy, physician assistant, occupational health and environment, physical therapy, nutrition, communication sciences, optometry, occupational therapy, medical technologist and pathology laboratory, pharmacy assistant, prosthetic and orthotic, nursing employee, dental assistant and dental therapist, health records, community health, optical dispensing, physical therapy assistant, occupational health inspector, ambulance worker, central supply and central pharmacy); back office = every remaining position. Confirm the exact installed position names so the mapping reproduces the printed professional and non-professional groups. The printed 8000-lost-hours rule for work-related death cannot be implemented (no work-death registry exists in HOSxP); such cases must be corrected in the staged hours. PDF beyond the branch: the printed definition needs the exact a and b counts certified by the human resources office for the reporting period. Confirm with the hospital owner: the emp_work_sick_type dictionary, the job-group mapping and the hours per shift.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- วันเริ่ม/สิ้นสุดงานว่างยังใช้ fallback ในสูตรเดิม; ยอดฐานแยก unknown temporal; สิ้นสุดก่อนเริ่มงานถูกตัดจาก employee-month; ขอบเขตวันสิ้นสุดและทะเบียนครบต้องยืนยัน HR

Source tables: emp, emp_position_main, emp_work_schedule, emp_work_sick, emp_work_sick_type, emp_work_status. SQL SHA256: e404ea65ca3191c298cedd8279f51984e3222f2732280c31c20c44396b564cd7

## SH0303

PDF physical 247; printed 238, 239 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนวันที่บุคลากรกลุ่มที่ไม่ได้สัมผัสผู้ป่วยโดยตรงทั้งหมดขององค์กรหยุดงานหรือ สูญเสียเนื่องจากการบาดเจ็บในช่วงเวลาที่กำหนด

ตัวหาร / population: b = จำนวนชั่วโมงการทำงานทั้งหมดของบุคลากรกลุ่มที่ไม่ได้สัมผัสผู้ป่วยโดยตรงในองค์กร ในช่วงเวลาเดียวกัน

Grain: staff / month aggregate (candidate). Key candidates: emp.emp_id, emp.emp_cid. Date candidates: emp.emp_work_begindate, emp.emp_resign_enddate.

Unit: จำนวนวันที่หยุดงานหรือสูญเสียเนื่องจากการบาดเจ็บต่อหนึ่งล้านชั่วโมงการทำงาน; formula: (a/b) x 1,000,000. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (sum)
SUM(hr.injury_lost_days)
-- denominator (sum)
SUM(hr.work_hours)
-- outer FROM / source
(
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COALESCE(SUM(es.emp_work_sick_countday), 0)
            FROM emp_work_sick es
            JOIN emp_work_sick_type st ON st.emp_work_sick_type_id = es.emp_work_sick_type_id
            WHERE es.emp_id = e.emp_id
              AND es.emp_work_sick_sdatetime >= months.work_month
              AND es.emp_work_sick_sdatetime < months.work_month + INTERVAL '1 month'
              AND (st.emp_work_sick_type_name ILIKE '%อันตราย%' OR st.emp_work_sick_type_name ILIKE '%บาดเจ็บ%' OR st.emp_work_sick_type_name ILIKE '%อุบัติเหตุ%')) AS injury_lost_days,
          ((SELECT COUNT(*)
            FROM emp_work_schedule wsc
            LEFT JOIN emp_work_status wst ON wst.emp_work_status_id = wsc.emp_work_status_id
            WHERE wsc.emp_id = e.emp_id
              AND wsc.emp_work_schedule_workdate >= months.work_month
              AND wsc.emp_work_schedule_workdate < months.work_month + INTERVAL '1 month'
              AND COALESCE(wst.emp_work_status_name, '') NOT ILIKE '%ลา%'
              AND COALESCE(wst.emp_work_status_name, '') NOT ILIKE '%หยุด%'
          ) * 8) AS work_hours,
          (((NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%แพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%เทคนิคการแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วยแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%แพทย์แผน%')) AND (NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาลวิชาชีพ%' OR (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาล%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วย%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%พนักงาน%'))) AND (NOT (COALESCE(pm.emp_position_main_name, '') ILIKE ANY (ARRAY['%ผดุงครรภ์%', '%เภสัช%', '%ผู้ช่วยแพทย์%', '%อาชีวอนามัย%', '%สิ่งแวดล้อม%', '%กายภาพ%', '%โภชนา%', '%สื่อความหมาย%', '%ทัศนมาตร%', '%อาชีวบำบัด%', '%กิจกรรมบำบัด%', '%เทคนิคการแพทย์%', '%เทคนิคพยาธิ%', '%พยาธิ%', '%ผู้ช่วยเภสัช%', '%อุปกรณ์การแพทย์เทียม%', '%พนักงานการพยาบาล%', '%ผู้ช่วยทันต%', '%ทันตภิบาล%', '%เวชระเบียน%', '%สุขภาพชุมชน%', '%ประกอบแว่น%', '%ผู้ช่วยนักกายภาพ%', '%ผู้ตรวจสอบ%', '%รถพยาบาล%', '%จ่ายกลาง%', '%เวชภัณฑ์กลาง%', '%แพทย์แผน%']))))) AS is_back_office
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
        WHERE e.emp_work_begindate IS NULL OR e.emp_resign_enddate IS NULL
          OR e.emp_resign_enddate >= e.emp_work_begindate
      ) hr
-- outer cohort predicate
hr.is_back_office
```

- Measures: Injury severity rate (lost workdays per one million work hours) of non-direct-contact personnel (monthly anchor). numerator (a) = lost workdays (emp_work_sick_countday) of injury events of back office personnel in the month denominator (b) = work hours of the month of back office personnel (rostered shifts times 8 hours) value = ROUND(a times 1000000 divided by NULLIF(b, 0), 2) per formulaScale a over b times 1000000. Work-related injury and illness events are emp_work_sick rows classified through emp_work_sick_type_name keywords (injury: accident, injury or danger tokens; illness: illness, back-pain, stress or work-disease tokens). HOSxP carries no work-relatedness flag in emp_work_sick, so ordinary sick leave whose type name matches the keywords is over-counted and work-related cases filed under an untyped reason are missed; the social-security work-related registry (emp_social_sick) only covers reported cases and is not joined. Work hours are the rostered shifts of emp_work_schedule per employee-month (rows whose emp_work_status_name marks leave or holiday are dropped) multiplied by eight hours per shift; the printed definition allows other shift lengths (eight or ten hours) and wants the real hours of each shift. If true shift lengths or clocked hours are maintained, stage the monthly work-hour totals instead. The job-group split (physician and dentist, professional nurse, allied health, back office) is a keyword mapping over emp_position_main.emp_position_main_name: physician and dentist = name contains the physician token minus technician, assistant and Thai-traditional-medicine names; professional nurse = name contains the professional-nurse token minus assistant and employee-nurse names; allied health = the remaining direct-contact occupations named in the printed definition (midwifery, pharmacy, physician assistant, occupational health and environment, physical therapy, nutrition, communication sciences, optometry, occupational therapy, medical technologist and pathology laboratory, pharmacy assistant, prosthetic and orthotic, nursing employee, dental assistant and dental therapist, health records, community health, optical dispensing, physical therapy assistant, occupational health inspector, ambulance worker, central supply and central pharmacy); back office = every remaining position. Confirm the exact installed position names so the mapping reproduces the printed professional and non-professional groups. The printed 8000-lost-hours rule for work-related death cannot be implemented (no work-death registry exists in HOSxP); such cases must be corrected in the staged hours. PDF beyond the branch: the printed definition needs the exact a and b counts certified by the human resources office for the reporting period. Confirm with the hospital owner: the emp_work_sick_type dictionary, the job-group mapping and the hours per shift.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- วันเริ่ม/สิ้นสุดงานว่างยังใช้ fallback ในสูตรเดิม; ยอดฐานแยก unknown temporal; สิ้นสุดก่อนเริ่มงานถูกตัดจาก employee-month; ขอบเขตวันสิ้นสุดและทะเบียนครบต้องยืนยัน HR

Source tables: emp, emp_position_main, emp_work_schedule, emp_work_sick, emp_work_sick_type, emp_work_status. SQL SHA256: 64c0bd0758642ffb0e62156996fb85173856681bae793c9309db6cd56be2f7d5

## SH0306

PDF physical 249; printed 240, 241 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งที่บุคลากรกลุ่มสัมผัสผู้ป่วยโดยตรงทั้งหมดขององค์กรได้รับบาดเจ็บ/ เจ็บป่วย เนื่องจากการทำงาน ในช่วงเวลาที่กำหนด

ตัวหาร / population: b = จำนวนชั่วโมงการทำงานทั้งหมดของบุคลากรกลุ่มสัมผัสผู้ป่วยโดยตรงในองค์กร ในช่วง เวลาเดียวกัน

Grain: staff / month aggregate (candidate). Key candidates: emp.emp_id, emp.emp_cid. Date candidates: emp.emp_work_begindate, emp.emp_resign_enddate.

Unit: ครั้งต่อหนึ่งล้านชั่วโมงการทำงาน; formula: (a/b) x 1,000,000. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (sum)
SUM(hr.work_injury_event_cnt) + SUM(hr.work_illness_event_cnt)
-- denominator (sum)
SUM(hr.work_hours)
-- outer FROM / source
(
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COUNT(*)
            FROM emp_work_sick es
            JOIN emp_work_sick_type st ON st.emp_work_sick_type_id = es.emp_work_sick_type_id
            WHERE es.emp_id = e.emp_id
              AND es.emp_work_sick_sdatetime >= months.work_month
              AND es.emp_work_sick_sdatetime < months.work_month + INTERVAL '1 month'
              AND (st.emp_work_sick_type_name ILIKE '%อันตราย%' OR st.emp_work_sick_type_name ILIKE '%บาดเจ็บ%' OR st.emp_work_sick_type_name ILIKE '%อุบัติเหตุ%')) AS work_injury_event_cnt,
          (SELECT COUNT(*)
            FROM emp_work_sick es
            JOIN emp_work_sick_type st ON st.emp_work_sick_type_id = es.emp_work_sick_type_id
            WHERE es.emp_id = e.emp_id
              AND es.emp_work_sick_sdatetime >= months.work_month
              AND es.emp_work_sick_sdatetime < months.work_month + INTERVAL '1 month'
              AND (st.emp_work_sick_type_name ILIKE '%เจ็บป่วย%' OR st.emp_work_sick_type_name ILIKE '%ปวดหลัง%' OR st.emp_work_sick_type_name ILIKE '%เครียด%' OR st.emp_work_sick_type_name ILIKE '%โรคจากการทำงาน%')) AS work_illness_event_cnt,
          ((SELECT COUNT(*)
            FROM emp_work_schedule wsc
            LEFT JOIN emp_work_status wst ON wst.emp_work_status_id = wsc.emp_work_status_id
            WHERE wsc.emp_id = e.emp_id
              AND wsc.emp_work_schedule_workdate >= months.work_month
              AND wsc.emp_work_schedule_workdate < months.work_month + INTERVAL '1 month'
              AND COALESCE(wst.emp_work_status_name, '') NOT ILIKE '%ลา%'
              AND COALESCE(wst.emp_work_status_name, '') NOT ILIKE '%หยุด%'
          ) * 8) AS work_hours,
          (((COALESCE(pm.emp_position_main_name, '') ILIKE '%แพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%เทคนิคการแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วยแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%แพทย์แผน%') OR (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาลวิชาชีพ%' OR (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาล%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วย%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%พนักงาน%')) OR ((NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%แพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%เทคนิคการแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วยแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%แพทย์แผน%')) AND (NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาลวิชาชีพ%' OR (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาล%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วย%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%พนักงาน%'))) AND (COALESCE(pm.emp_position_main_name, '') ILIKE ANY (ARRAY['%ผดุงครรภ์%', '%เภสัช%', '%ผู้ช่วยแพทย์%', '%อาชีวอนามัย%', '%สิ่งแวดล้อม%', '%กายภาพ%', '%โภชนา%', '%สื่อความหมาย%', '%ทัศนมาตร%', '%อาชีวบำบัด%', '%กิจกรรมบำบัด%', '%เทคนิคการแพทย์%', '%เทคนิคพยาธิ%', '%พยาธิ%', '%ผู้ช่วยเภสัช%', '%อุปกรณ์การแพทย์เทียม%', '%พนักงานการพยาบาล%', '%ผู้ช่วยทันต%', '%ทันตภิบาล%', '%เวชระเบียน%', '%สุขภาพชุมชน%', '%ประกอบแว่น%', '%ผู้ช่วยนักกายภาพ%', '%ผู้ตรวจสอบ%', '%รถพยาบาล%', '%จ่ายกลาง%', '%เวชภัณฑ์กลาง%', '%แพทย์แผน%']))))) AS is_direct_contact
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
        WHERE e.emp_work_begindate IS NULL OR e.emp_resign_enddate IS NULL
          OR e.emp_resign_enddate >= e.emp_work_begindate
      ) hr
-- outer cohort predicate
hr.is_direct_contact
```

- Measures: Injury and illness frequency rate per one million work hours of direct-contact personnel (monthly anchor). numerator (a) = emp_work_sick injury and illness events of direct-contact personnel in the month denominator (b) = work hours of the month of direct-contact personnel (rostered shifts times 8 hours) value = ROUND(a times 1000000 divided by NULLIF(b, 0), 2) per formulaScale a over b times 1000000. Work-related injury and illness events are emp_work_sick rows classified through emp_work_sick_type_name keywords (injury: accident, injury or danger tokens; illness: illness, back-pain, stress or work-disease tokens). HOSxP carries no work-relatedness flag in emp_work_sick, so ordinary sick leave whose type name matches the keywords is over-counted and work-related cases filed under an untyped reason are missed; the social-security work-related registry (emp_social_sick) only covers reported cases and is not joined. Work hours are the rostered shifts of emp_work_schedule per employee-month (rows whose emp_work_status_name marks leave or holiday are dropped) multiplied by eight hours per shift; the printed definition allows other shift lengths (eight or ten hours) and wants the real hours of each shift. If true shift lengths or clocked hours are maintained, stage the monthly work-hour totals instead. The job-group split (physician and dentist, professional nurse, allied health, back office) is a keyword mapping over emp_position_main.emp_position_main_name: physician and dentist = name contains the physician token minus technician, assistant and Thai-traditional-medicine names; professional nurse = name contains the professional-nurse token minus assistant and employee-nurse names; allied health = the remaining direct-contact occupations named in the printed definition (midwifery, pharmacy, physician assistant, occupational health and environment, physical therapy, nutrition, communication sciences, optometry, occupational therapy, medical technologist and pathology laboratory, pharmacy assistant, prosthetic and orthotic, nursing employee, dental assistant and dental therapist, health records, community health, optical dispensing, physical therapy assistant, occupational health inspector, ambulance worker, central supply and central pharmacy); back office = every remaining position. Confirm the exact installed position names so the mapping reproduces the printed professional and non-professional groups. PDF beyond the branch: the printed definition needs the exact a and b counts certified by the human resources office for the reporting period. Confirm with the hospital owner: the emp_work_sick_type dictionary, the job-group mapping and the hours per shift.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- วันเริ่ม/สิ้นสุดงานว่างยังใช้ fallback ในสูตรเดิม; ยอดฐานแยก unknown temporal; สิ้นสุดก่อนเริ่มงานถูกตัดจาก employee-month; ขอบเขตวันสิ้นสุดและทะเบียนครบต้องยืนยัน HR

Source tables: emp, emp_position_main, emp_work_schedule, emp_work_sick, emp_work_sick_type, emp_work_status. SQL SHA256: 9eeea77d820fa80002d1adb538b01d0ea18d64fe061ad4967aa7790b3684e152

## SH0307

PDF physical 251; printed 242, 243 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งที่บุคลากรกลุ่มที่ไม่ได้สัมผัสผู้ป่วยโดยตรงทั้งหมดขององค์กรได้รับบาดเจ็บ/ เจ็บป่วยเนื่องจากการทำงาน ในช่วงเวลาที่กำหนด

ตัวหาร / population: b = จำนวนชั่วโมงการทำงานทั้งหมดของบุคลากรกลุ่มที่ไม่ได้สัมผัสผู้ป่วยโดยตรงในองค์กร ในช่วงเวลาเดียวกัน

Grain: staff / month aggregate (candidate). Key candidates: emp.emp_id, emp.emp_cid. Date candidates: emp.emp_work_begindate, emp.emp_resign_enddate.

Unit: ครั้งต่อหนึ่งล้านชั่วโมงการทำงาน; formula: (a/b) x 1,000,000. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (sum)
SUM(hr.work_injury_event_cnt) + SUM(hr.work_illness_event_cnt)
-- denominator (sum)
SUM(hr.work_hours)
-- outer FROM / source
(
        SELECT
          e.emp_id AS staff_key,
          DATE_TRUNC('month', months.work_month)::date AS period_start,
          EXTRACT(MONTH FROM months.work_month)::integer AS calendar_month,
          (SELECT COUNT(*)
            FROM emp_work_sick es
            JOIN emp_work_sick_type st ON st.emp_work_sick_type_id = es.emp_work_sick_type_id
            WHERE es.emp_id = e.emp_id
              AND es.emp_work_sick_sdatetime >= months.work_month
              AND es.emp_work_sick_sdatetime < months.work_month + INTERVAL '1 month'
              AND (st.emp_work_sick_type_name ILIKE '%อันตราย%' OR st.emp_work_sick_type_name ILIKE '%บาดเจ็บ%' OR st.emp_work_sick_type_name ILIKE '%อุบัติเหตุ%')) AS work_injury_event_cnt,
          (SELECT COUNT(*)
            FROM emp_work_sick es
            JOIN emp_work_sick_type st ON st.emp_work_sick_type_id = es.emp_work_sick_type_id
            WHERE es.emp_id = e.emp_id
              AND es.emp_work_sick_sdatetime >= months.work_month
              AND es.emp_work_sick_sdatetime < months.work_month + INTERVAL '1 month'
              AND (st.emp_work_sick_type_name ILIKE '%เจ็บป่วย%' OR st.emp_work_sick_type_name ILIKE '%ปวดหลัง%' OR st.emp_work_sick_type_name ILIKE '%เครียด%' OR st.emp_work_sick_type_name ILIKE '%โรคจากการทำงาน%')) AS work_illness_event_cnt,
          ((SELECT COUNT(*)
            FROM emp_work_schedule wsc
            LEFT JOIN emp_work_status wst ON wst.emp_work_status_id = wsc.emp_work_status_id
            WHERE wsc.emp_id = e.emp_id
              AND wsc.emp_work_schedule_workdate >= months.work_month
              AND wsc.emp_work_schedule_workdate < months.work_month + INTERVAL '1 month'
              AND COALESCE(wst.emp_work_status_name, '') NOT ILIKE '%ลา%'
              AND COALESCE(wst.emp_work_status_name, '') NOT ILIKE '%หยุด%'
          ) * 8) AS work_hours,
          (((NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%แพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%เทคนิคการแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วยแพทย์%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%แพทย์แผน%')) AND (NOT (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาลวิชาชีพ%' OR (COALESCE(pm.emp_position_main_name, '') ILIKE '%พยาบาล%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%ผู้ช่วย%' AND COALESCE(pm.emp_position_main_name, '') NOT ILIKE '%พนักงาน%'))) AND (NOT (COALESCE(pm.emp_position_main_name, '') ILIKE ANY (ARRAY['%ผดุงครรภ์%', '%เภสัช%', '%ผู้ช่วยแพทย์%', '%อาชีวอนามัย%', '%สิ่งแวดล้อม%', '%กายภาพ%', '%โภชนา%', '%สื่อความหมาย%', '%ทัศนมาตร%', '%อาชีวบำบัด%', '%กิจกรรมบำบัด%', '%เทคนิคการแพทย์%', '%เทคนิคพยาธิ%', '%พยาธิ%', '%ผู้ช่วยเภสัช%', '%อุปกรณ์การแพทย์เทียม%', '%พนักงานการพยาบาล%', '%ผู้ช่วยทันต%', '%ทันตภิบาล%', '%เวชระเบียน%', '%สุขภาพชุมชน%', '%ประกอบแว่น%', '%ผู้ช่วยนักกายภาพ%', '%ผู้ตรวจสอบ%', '%รถพยาบาล%', '%จ่ายกลาง%', '%เวชภัณฑ์กลาง%', '%แพทย์แผน%']))))) AS is_back_office
        FROM emp e
        LEFT JOIN emp_position_main pm ON pm.emp_position_main_id = e.emp_position_main_id
        JOIN GENERATE_SERIES(
          DATE_TRUNC('month', GREATEST(COALESCE(e.emp_work_begindate, :start_date), :start_date)),
          DATE_TRUNC('month', LEAST(COALESCE(e.emp_resign_enddate, :end_date), :end_date) - INTERVAL '1 day'),
          INTERVAL '1 month'
        ) AS months(work_month) ON TRUE
        WHERE e.emp_work_begindate IS NULL OR e.emp_resign_enddate IS NULL
          OR e.emp_resign_enddate >= e.emp_work_begindate
      ) hr
-- outer cohort predicate
hr.is_back_office
```

- Measures: Injury and illness frequency rate per one million work hours of non-direct-contact personnel (monthly anchor). numerator (a) = emp_work_sick injury and illness events of back office personnel in the month denominator (b) = work hours of the month of back office personnel (rostered shifts times 8 hours) value = ROUND(a times 1000000 divided by NULLIF(b, 0), 2) per formulaScale a over b times 1000000. Work-related injury and illness events are emp_work_sick rows classified through emp_work_sick_type_name keywords (injury: accident, injury or danger tokens; illness: illness, back-pain, stress or work-disease tokens). HOSxP carries no work-relatedness flag in emp_work_sick, so ordinary sick leave whose type name matches the keywords is over-counted and work-related cases filed under an untyped reason are missed; the social-security work-related registry (emp_social_sick) only covers reported cases and is not joined. Work hours are the rostered shifts of emp_work_schedule per employee-month (rows whose emp_work_status_name marks leave or holiday are dropped) multiplied by eight hours per shift; the printed definition allows other shift lengths (eight or ten hours) and wants the real hours of each shift. If true shift lengths or clocked hours are maintained, stage the monthly work-hour totals instead. The job-group split (physician and dentist, professional nurse, allied health, back office) is a keyword mapping over emp_position_main.emp_position_main_name: physician and dentist = name contains the physician token minus technician, assistant and Thai-traditional-medicine names; professional nurse = name contains the professional-nurse token minus assistant and employee-nurse names; allied health = the remaining direct-contact occupations named in the printed definition (midwifery, pharmacy, physician assistant, occupational health and environment, physical therapy, nutrition, communication sciences, optometry, occupational therapy, medical technologist and pathology laboratory, pharmacy assistant, prosthetic and orthotic, nursing employee, dental assistant and dental therapist, health records, community health, optical dispensing, physical therapy assistant, occupational health inspector, ambulance worker, central supply and central pharmacy); back office = every remaining position. Confirm the exact installed position names so the mapping reproduces the printed professional and non-professional groups. PDF beyond the branch: the printed definition needs the exact a and b counts certified by the human resources office for the reporting period. Confirm with the hospital owner: the emp_work_sick_type dictionary, the job-group mapping and the hours per shift.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- วันเริ่ม/สิ้นสุดงานว่างยังใช้ fallback ในสูตรเดิม; ยอดฐานแยก unknown temporal; สิ้นสุดก่อนเริ่มงานถูกตัดจาก employee-month; ขอบเขตวันสิ้นสุดและทะเบียนครบต้องยืนยัน HR

Source tables: emp, emp_position_main, emp_work_schedule, emp_work_sick, emp_work_sick_type, emp_work_status. SQL SHA256: 9f3a7526e0704f68179e0d178f88ac1b6b7b7201000b557dd40680d3c6b716c5

## SI0101

PDF physical 211; printed 202 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการติดเชื้อปอดอักเสบจากการใช้เครื่องช่วยหายใจทั้งหมด

ตัวหาร / population: b = จำนวนวันนอนผู้ป่วยในที่ใช้เครื่องช่วยหายใจทั้งหมดในช่วงเวลาเดียวกัน

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ต่อ 1,000 วันนอนผู้ป่วยในที่ใช้เครื่องช่วยหายใจ; formula: (a/b) x 1,000. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SI0101'
```

- NOT in standard HOSxP: VAP needs NHSN device-days and surveillance-defined events. External staging: one monthly row per anchor (period_start = first day of the month) in reporting.thip_external_facts with indicator_code = SI0101, numerator = NHSN-defined VAP events in all wards (ICU plus non-ICU), denominator = total ventilator-days in all wards, value = ROUND(numerator * 1000 / NULLIF(denominator, 0), 2), source_system = icu_infection_surveillance. Confirm with the hospital owner: the infection-control registry that keeps ventilator-days and the NHSN case definition version in use.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 46834f2a0bade7cad9a14efff48fc666f9551f09d271e2619af5e7766863cf1c

## SI0102

PDF physical 212; printed 203 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการติดเชื้อปอดอักเสบจากการใช้เครื่องช่วยหายใจของผู้ป่วยใน ICU ทั้งหมด

ตัวหาร / population: b = จำนวนวันนอนผู้ป่วยในที่รักษาในห้อง ICU ที่ใช้เครื่องช่วยหายใจทั้งหมดในช่วงเวลา เดียวกัน

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ต่อ 1,000 วันนอนผู้ป่วยในที่ใช้เครื่องช่วยหายใจ; formula: (a/b) x 1,000. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SI0102'
```

- As SI0101 restricted to ICU patients. External staging: one monthly row with indicator_code = SI0102, numerator = NHSN-defined VAP events of ICU patients (all ICUs combined), denominator = ICU ventilator-days, value = ROUND(numerator * 1000 / NULLIF(denominator, 0), 2), source_system = icu_infection_surveillance. Confirm with the hospital owner: the list of wards counted as ICUs and that device-days are collected per ICU.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 735012ef915c3bd7f48306647a4513750792226a46b46ced5a22ac96c3e05cf3

## SI0103

PDF physical 213; printed 204 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการติดเชื้อปอดอักเสบจากการใช้เครื่องช่วยหายใจของผู้ป่วยที่รักษาอยู่ นอกห้อง ICU ทั้งหมด

ตัวหาร / population: b = จำนวนวันนอนผู้ป่วยในที่รักษาอยู่นอกห้อง ICU ที่ใช้เครื่องช่วยหายใจทั้งหมดใน ช่วงเวลาเดียวกัน

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ต่อ 1,000 วันนอนผู้ป่วยในที่ใช้เครื่องช่วยหายใจ; formula: (a/b) x 1,000. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SI0103'
```

- As SI0101 restricted to non-ICU wards. External staging: one monthly row with indicator_code = SI0103, numerator = NHSN-defined VAP events outside the ICUs, denominator = non-ICU ventilator-days, value = ROUND(numerator * 1000 / NULLIF(denominator, 0), 2), source_system = icu_infection_surveillance. Confirm with the hospital owner: ward classification of the ICU list.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 25535f8946077049faa715d733b325cb9fd119650d90402c92491bb0e9d40e58

## SI0201

PDF physical 214; printed 205 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการติดเชื้อในกระแสเลือดในผู้ป่วยใส่สาย central line ทั้งหมด

ตัวหาร / population: b = จำนวนวันรวมที่ผู้ป่วยใส่สาย central line ทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ต่อ 1,000วันที่คาสายสวนหลอดเลือดส่วนกลาง; formula: (a/b) x 1,000. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SI0201'
```

- NOT in standard HOSxP: CABSI needs central-line days and NHSN laboratory-confirmed bloodstream infection events. External staging: one monthly row with indicator_code = SI0201, numerator = NHSN-defined CABSI events in all wards, denominator = total central-line days, value = ROUND(numerator * 1000 / NULLIF(denominator, 0), 2), source_system = icu_infection_surveillance. Confirm with the hospital owner: where central-line insertion and removal dates are kept (ipd_nurse_note has no line-day fields) and the laboratory criteria used for the event definition.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: e21b127f1b1ff519825955dbce7c70cb50ba7334be62ab0699ee1da921d08687

## SI0202

PDF physical 215; printed 206 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการติดเชื้อในกระแสเลือดในผู้ป่วยใส่สาย central line ของผู้ป่วยที่ นอนใน ICU

ตัวหาร / population: b = จำนวนวันรวมที่ผู้ป่วยใน ICUที่ใส่สาย central line

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ต่อ 1,000 วันที่คาสายสวนหลอดเลือดส่วนกลาง; formula: (a/b) x 1,000. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SI0202'
```

- As SI0201 restricted to ICU patients. External staging: one monthly row with indicator_code = SI0202, numerator = NHSN-defined CABSI events of ICU patients (all ICUs combined), denominator = ICU central-line days, value = ROUND(numerator * 1000 / NULLIF(denominator, 0), 2), source_system = icu_infection_surveillance. Confirm with the hospital owner: the ICU ward list and per-ICU line-day collection.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 19b78794e79a255117a4025b5fd24502f22f61771184f5b1dd54aae372048bca

## SI0203

PDF physical 216; printed 207 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการติดเชื้อในกระแสเลือดในผู้ป่วยใส่สาย central ine ของผู้ป่วยที่ นอนนอกICU

ตัวหาร / population: b = จำนวนวันรวมที่ผู้ป่วยนอกICU ที่ใส่สาย central line

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ต่อ 1,000 วันที่คาสายสวนหลอดเลือดส่วนกลาง; formula: (a/b) x 1,000. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SI0203'
```

- As SI0201 restricted to non-ICU wards. External staging: one monthly row with indicator_code = SI0203, numerator = NHSN-defined CABSI events outside the ICUs, denominator = non-ICU central-line days, value = ROUND(numerator * 1000 / NULLIF(denominator, 0), 2), source_system = icu_infection_surveillance. Confirm with the hospital owner: ward classification of the ICU list.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 282c04d099fffea1515de390efd7603b119278d2f78a62ece276d34ef903cdff

## SI0301

PDF physical 217; printed 208 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการติดเชื้อระบบทางเดินปัสสาวะจากการคาสายสวนปัสสาวะทั้งหมด

ตัวหาร / population: b = จำนวนวันรวมที่ผู้ป่วยคาสายสวนปัสสาวะทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ต่อ 1,000 วันที่คาสายสวนปัสสาวะ; formula: (a/b) x 1,000. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SI0301'
```

- NOT in standard HOSxP: CAUTI needs urinary-catheter days and NHSN symptomatic urinary-tract infection events. External staging: one monthly row with indicator_code = SI0301, numerator = NHSN-defined CAUTI events in all wards, denominator = total urinary-catheter days, value = ROUND(numerator * 1000 / NULLIF(denominator, 0), 2), source_system = icu_infection_surveillance. Confirm with the hospital owner: where catheter insertion and removal dates are recorded and that asymptomatic bacteriuria cases are excluded per the definition.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 34470530a076f42cec005dffdc00b94e422bd46d35a1f4558740d31817ee338e

## SI0302

PDF physical 218; printed 209 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการติดเชื้อระบบทางเดินปัสสาวะจากการคาสายสวนปัสสาวะของ ผู้ป่วยที่นอนใน ICU

ตัวหาร / population: b = จำนวนวันรวมที่ผู้ป่วยใน ICU ที่คาสายสวนปัสสาวะทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ต่อ 1,000 วันที่คาสายสวนปัสสาวะ; formula: (a/b) x 1,000. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SI0302'
```

- As SI0301 restricted to ICU patients. External staging: one monthly row with indicator_code = SI0302, numerator = NHSN-defined CAUTI events of ICU patients (all ICUs combined), denominator = ICU urinary-catheter days, value = ROUND(numerator * 1000 / NULLIF(denominator, 0), 2), source_system = icu_infection_surveillance. Confirm with the hospital owner: the ICU ward list.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 20e8d77096ede9dfeb3ae40fecc702cec02aa41a49109c8af5d5dfa35355cc95

## SI0303

PDF physical 219; printed 210 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งของการติดเชื้อระบบทางเดินปัสสาวะจากการคาสายสวนปัสสาวะของ ผู้ป่วยที่นอนนอกห้อง ICU

ตัวหาร / population: b = จำนวนวันรวมที่ผู้ป่วยนอกห้อง ICU ที่คาสายสวนปัสสาวะทั้งหมด

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ต่อ 1,000 วันที่คาสายสวนปัสสาวะ; formula: (a/b) x 1,000. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SI0303'
```

- As SI0301 restricted to non-ICU wards. External staging: one monthly row with indicator_code = SI0303, numerator = NHSN-defined CAUTI events outside the ICUs, denominator = non-ICU urinary-catheter days, value = ROUND(numerator * 1000 / NULLIF(denominator, 0), 2), source_system = icu_infection_surveillance. Confirm with the hospital owner: ward classification of the ICU list.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 276a0b2ea19735246ab807c85299b203aa099a36c38be00e515fdf59bea88033

## SL0101

PDF physical 220; printed 211 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวน units ของโลหิตที่ทำการ crossmatch ในเดือนที่ทำการเก็บข้อมูลในกลุ่ม ผู้ป่วยผ่าตัดประเภทต่าง ๆ

ตัวหาร / population: b = จำนวน units ของโลหิตที่ถูกนำไป transfused ในเดือนที่ทำการเก็บข้อมูลในกลุ่ม ผู้ป่วยผ่าตัดประเภทต่าง ๆ

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: รอตรวจ SQL. Date candidates: blood_request.request_date, operation_list.operation_date.

Unit: อัตราส่วน; formula: C:T ratio = a/b. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (sum)
SUM(brd.request_qty)
-- denominator (sum)
SUM(brd.response_qty)
-- outer FROM / source
(
      SELECT
        br.blood_request_id,
        br.vn,
        br.hn,
        br.request_date,
        DATE_TRUNC('month', br.request_date)::date AS period_start,
        EXTRACT(MONTH FROM br.request_date)::integer AS calendar_month
      FROM blood_request br
      WHERE br.request_date >= :start_date
        AND br.request_date < :end_date
    ) blood_requests
      JOIN blood_request_detail brd ON brd.blood_request_id = blood_requests.blood_request_id
-- outer cohort predicate
EXISTS (
      SELECT 1
      FROM operation_list ol
      WHERE ol.vn = blood_requests.vn
         OR (
              ol.hn = blood_requests.hn
              AND ol.operation_date >= blood_requests.request_date - INTERVAL '7 days'
              AND ol.operation_date <= blood_requests.request_date + INTERVAL '7 days'
            )
    )
```

- Measures the C:T ratio for surgical cases from blood_request plus blood_request_detail: numerator is SUM(request_qty) (units crossmatch-requested) and denominator SUM(response_qty) (units issued) of blood requests tied to a surgical case (operation_list matched on vn, or on hn with an operation date within 7 days of the request). PDF needs: crossmatched units versus truly transfused units per month for elective surgery groups. Confirm with the hospital owner: whether response_qty equals transfused units, the correct patient-to-operation matching key (blood_request carries vn and hn but no an), and whether the blood-bank module (bb_ or blb_ tables) holds the authoritative crossmatch and transfusion unit counts that should be staged via branchExternal instead.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: blood_request, blood_request_detail, operation_list. SQL SHA256: ec92e2ee13184ab1975dfcc0fbff91e8c9f51db861b9954d5cdc3adc5b3f7569

## SM0102

PDF physical 269; printed 260 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนใบสั่งยาผู้ป่วย URI ที่ได้รับยาปฏิชีวนะ ในช่วง 6 เดือน

ตัวหาร / population: b = จำนวนใบสั่งยาผู้ป่วย URI ทั้งหมดในช่วงเวลาเดียวกัน

Grain: visit/event at ovst VN (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (di.antibiotic = 'Y' OR di.drugcategory ILIKE '%antibio%')
      ))
-- denominator (count)
COUNT(*)
-- outer FROM / source
opd_periodized
-- outer cohort predicate
(
      LEFT(pdx, 3) = 'J00'
      OR pdx IN ('B053', 'H650', 'H651', 'H659', 'H660', 'H664', 'H669', 'H670', 'H671', 'H678', 'H720', 'H722', 'H728', 'H729', 'J010', 'J014', 'J018', 'J019', 'J020', 'J029', 'J030', 'J038', 'J039', 'J040', 'J042', 'J050', 'J051', 'J060', 'J068', 'J069', 'J101', 'J111', 'J200', 'J209', 'J210', 'J218', 'J219')
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'J00'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('B053', 'H650', 'H651', 'H659', 'H660', 'H664', 'H669', 'H670', 'H671', 'H678', 'H720', 'H722', 'H728', 'H729', 'J010', 'J014', 'J018', 'J019', 'J020', 'J029', 'J030', 'J038', 'J039', 'J040', 'J042', 'J050', 'J051', 'J060', 'J068', 'J069', 'J101', 'J111', 'J200', 'J209', 'J210', 'J218', 'J219')
          )
      )
    )
```

- Percent of URI visits (Pdx or ovstdiag in the printed dotless token set from thipKpiRules: B053, H650-H678, H720-H729, J00, J010-J219 subset) that received at least one antibiotic item (drugitems.antibiotic = Y or drugcategory like antibio) on the same visit via opitemrece. One visit is treated as one prescription (ใบสั่งยา); a hospital issuing several prescription slips per visit must confirm the slip grain (e.g. via opitemreceh).
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: drugitems, er_regist, opitemrece, ovst, ovstdiag, patient. SQL SHA256: c316315af2b2aae4de6e575e3e6dc165b019e4dee0c8d427a7ece656e8db4224

## SM0103

PDF physical 270; printed 261 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนใบสั่งยาผู้ป่วย acute diarrhea ที่ได้รับยาปฏิชีวนะ ในช่วง 6 เดือน

ตัวหาร / population: b = จำนวนใบสั่งยาผู้ป่วย acute diarrhea ทั้งหมดในช่วงเวลาเดียวกัน

Grain: visit/event at ovst VN (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (WHERE EXISTS (
        SELECT 1
        FROM opitemrece oi
        JOIN drugitems di ON di.icode = oi.icode
        WHERE oi.vn = opd_periodized.vn
          AND (di.antibiotic = 'Y' OR di.drugcategory ILIKE '%antibio%')
      ))
-- denominator (count)
COUNT(*)
-- outer FROM / source
opd_periodized
-- outer cohort predicate
(
      LEFT(pdx, 3) = 'A09'
      OR pdx IN ('A000', 'A001', 'A009', 'A020', 'A030', 'A033', 'A038', 'A039', 'A040', 'A049', 'A050', 'A053', 'A054', 'A059', 'A080', 'A085', 'K521', 'K528', 'K529')
      OR EXISTS (
        SELECT 1
        FROM ovstdiag sd
        WHERE sd.vn = opd_periodized.vn
          AND (
            LEFT(REPLACE(UPPER(TRIM(sd.icd10)), '.', ''), 3) = 'A09'
            OR REPLACE(UPPER(TRIM(sd.icd10)), '.', '') IN ('A000', 'A001', 'A009', 'A020', 'A030', 'A033', 'A038', 'A039', 'A040', 'A049', 'A050', 'A053', 'A054', 'A059', 'A080', 'A085', 'K521', 'K528', 'K529')
          )
      )
    )
```

- Percent of acute-diarrhea visits (printed dotless token set A000-A085, A09x, K521, K528, K529) that received at least one antibiotic item on the same visit. Same prescription-grain approximation as SM0102.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: drugitems, er_regist, opitemrece, ovst, ovstdiag, patient. SQL SHA256: 7d7ca0b178eeefa56490219644d86ca45dfcafb2ec2546cc555e95a12d2ce46b

## SM0201

PDF physical 271; printed 262, 263 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = ปริมาณยาสำรองคงเหลือรวม(คลังยาและคลังยาย่อย) ณ สิ้นเดือน คูณด้วย ราคาทุนของยาสำรองคงเหลือที่คลัง

ตัวหาร / population: b = ปริมาณการจ่ายประจำเดือน คูณด้วย ราคาทุนของยาที่จ่ายออกจากคลัง

Grain: visit/event at ovst VN (candidate). Key candidates: ovst.vn, ovst.hn. Date candidates: ovst.vstdate, ovst.vsttime.

Unit: เดือน; formula: มูลค่ายาสำรองคงหลือรวม (คลังยาและคลังยาย่อย) ณ สิ้นเดือน (a) มูลค่ายารวมที่จ่ายไป ณ เดือนนั้น (b). Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (sum)
MAX((
        SELECT SUM(bal.left_value)
        FROM (
          SELECT DISTINCT ON (st.item_id) (st.left_qty * st.price) AS left_value
          FROM stock_trancation st
          WHERE st.transaction_date >= opd_periodized.period_start
            AND st.transaction_date < opd_periodized.period_start + INTERVAL '1 month'
          ORDER BY st.item_id, st.transaction_date DESC, st.stock_trancation_id DESC
        ) bal
      ))
-- denominator (sum)
MAX((
        SELECT SUM(st2.out_qty * st2.price)
        FROM stock_trancation st2
        WHERE st2.transaction_date >= opd_periodized.period_start
          AND st2.transaction_date < opd_periodized.period_start + INTERVAL '1 month'
          AND COALESCE(st2.out_qty, 0) > 0
      ))
-- outer FROM / source
opd_periodized
-- outer cohort predicate
opd_periodized.event_date IS NOT NULL
```

- Monthly inventory ratio a over b: a = month-end remaining stock value (last stock_trancation row per item in the month, left_qty times price, summed across main and sub warehouses); b = dispensed value of the month (out_qty times price on stock_trancation). The formula direction follows thipKpiRules formulaScale a over b (inventory turn); classic inventory turn is consumption over stock, so the hospital owner must confirm the PDF formula direction, that price is the cost price (drugitems.unitcost or stock_item.unit_cost may be authoritative), and which stock classes count as safety/reserve drugs (no ยาสำรอง flag is verified in stock_item). A month with stock activity but zero OPD visits emits no row.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target
- base LEFT JOIN patient.hn และ er_regist.vn อาจเพิ่มแถวถ้าคีย์ซ้ำ; principal diagnosis LIMIT 1 ยังต้องยืนยันลำดับ/ความครบ

Source tables: er_regist, ovst, ovstdiag, patient, stock_trancation. SQL SHA256: 82d305171d5f2503a8f4f66f7411bac8fbd68633e02bed20a3b39e4e295ff3ad

## SS0101

PDF physical 266; printed 257 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งการตรวจสอบประสิทธิภาพการทำปราศจากเชื้อผ่านเกณฑ์ใน 1 เดือน

ตัวหาร / population: b = จำนวนครั้งการตรวจสอบประสิทธิภาพการทำปราศจากเชื้อทั้งหมด ในเดือนเดียวกัน

Grain: hospital-supplied aggregate. Key candidates: reporting.thip_external_facts.indicator_code + fiscal_year + fiscal_month. Date candidates: reporting.thip_external_facts.period_start.

Unit: ร้อยละ; formula: (a/b) x 100. Window: hospital-provided cadence aggregate; window must be confirmed by source owner

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (external)
numerator
-- denominator (external)
denominator
-- outer FROM / source
external_facts
-- outer cohort predicate
indicator_code = 'SS0101'
```

- NOT in HOSxP: sterilization effectiveness checks (mechanical, chemical and biological spore-test indicators) are CSSD logbook events. External staging: one monthly row per anchor in reporting.thip_external_facts with indicator_code = SS0101, numerator = sterilization effectiveness checks passing all applicable indicators, denominator = all sterilization effectiveness checks in the month (steam and gas), value = ROUND(numerator * 100 / NULLIF(denominator, 0), 2), source_system = cssd_log. Confirm with the hospital owner: the check frequency policy (each load, weekly spore test) and who keeps the log.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: reporting.thip_external_facts. SQL SHA256: 3300aff6ac5dc1b23f5d9748dcde64f32bb8bd3baa57ff72acaa547f391caeaa

## SS0102

PDF physical 267; printed 258 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งการจัดเครื่องมืออุปกรณ์ทางการแพทย์ตามข้อตกลงถูกต้องครบถ้วน ในช่วงเวลา 1 เดือน

ตัวหาร / population: b = จำนวนครั้งการจัดเครื่องมือ วัสดุ อุปกรณ์ทางการแพทย์ทั้งหมด ในเดือนเดียวกัน

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: รอตรวจ SQL. Date candidates: supply_sterile.supply_sterile_date.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (
        WHERE sterile_batches.supply_sterile_complete = 'Y'
          AND sterile_batches.supply_sterile_confirm = 'Y'
          AND NOT EXISTS (
            SELECT 1
            FROM supply_sterile_list sl
            WHERE sl.supply_sterile_id = sterile_batches.supply_sterile_id
              AND COALESCE(sl.supply_sterile_list_complete, 'N') <> 'Y'
          )
      )
-- denominator (count)
COUNT(*)
-- outer FROM / source
(
      SELECT
        st.supply_sterile_id,
        st.supply_sterile_date,
        st.supply_sterile_confirm,
        st.supply_sterile_complete,
        DATE_TRUNC('month', st.supply_sterile_date)::date AS period_start,
        EXTRACT(MONTH FROM st.supply_sterile_date)::integer AS calendar_month
      FROM supply_sterile st
      WHERE st.supply_sterile_date >= :start_date
        AND st.supply_sterile_date < :end_date
    ) sterile_batches
-- outer cohort predicate
TRUE
```

- Measures the share of CSSD sterilization batches prepared correctly and completely: supply_sterile batches with supply_sterile_complete = Y and supply_sterile_confirm = Y and no supply_sterile_list line left incomplete. PDF needs: instrument sets assembled correctly for the specific procedure per the hospital committee agreement. Confirm with the hospital owner: that set-content correctness is verified against operation_set (operation_list.operation_set_id) or a paper checklist, and the Y convention of the supply_sterile flags; otherwise stage the audit counts via branchExternal.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: supply_sterile, supply_sterile_list. SQL SHA256: b033e0a7537194c6fff79be1d591b002f16b047270025a01a572d1e4c46ba04e

## SS0103

PDF physical 268; printed 259 · awaiting-hospital-confirmation · cohort-evidence/1

ตัวตั้ง: a = จำนวนครั้งการจ่ายอุปกรณ์เครื่องมือทางการแพทย์ถูกต้องครบถ้วนในช่วงเวลา 1 เดือน

ตัวหาร / population: b = จำนวนครั้งการจ่ายอุปกรณ์เครื่องมือทางการแพทย์ ทั้งหมด ในเดือนเดียวกัน

Grain: custom aggregate; inspect source SQL before confirming grain. Key candidates: รอตรวจ SQL. Date candidates: supply_sterile_receive.supply_sterile_receive_date.

Unit: ร้อยละ; formula: (a/b) x 100. Window: registered SELECT requested for full fiscal year (Oct–Sep), bucketed by native cadence; event/observation semantics remain unconfirmed

Inclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ. Exclusion: ยังไม่ structured — อ่าน definition ต้นฉบับ.

```sql
-- numerator (count)
COUNT(*) FILTER (
        WHERE sterile_receipts.supply_sterile_receive_status = 'Y'
          AND EXISTS (
            SELECT 1
            FROM supply_sterile st
            WHERE st.supply_sterile_id = sterile_receipts.supply_sterile_id
              AND st.supply_sterile_confirm = 'Y'
          )
      )
-- denominator (count)
COUNT(*)
-- outer FROM / source
(
      SELECT
        sr.supply_sterile_receive_id,
        sr.supply_sterile_id,
        sr.supply_sterile_receive_date,
        sr.supply_sterile_receive_status,
        DATE_TRUNC('month', sr.supply_sterile_receive_date)::date AS period_start,
        EXTRACT(MONTH FROM sr.supply_sterile_receive_date)::integer AS calendar_month
      FROM supply_sterile_receive sr
      WHERE sr.supply_sterile_receive_date >= :start_date
        AND sr.supply_sterile_receive_date < :end_date
    ) sterile_receipts
-- outer cohort predicate
TRUE
```

- Measures the share of CSSD distributions acknowledged as accurately provided: supply_sterile_receive rows with supply_sterile_receive_status = Y whose parent supply_sterile batch is confirmed. PDF needs: correct, complete and on-time provision of supplies to the requesting units as verified by the receiving unit. Confirm with the hospital owner: that supply_sterile_receive records the unit acknowledgement of an accurate delivery (including timeliness) and the status flag convention.
- ชื่อคอลัมน์และ primary key ไม่ยืนยัน join cardinality ของข้อมูลจริง; ยังไม่รับรองสูตร/หน่วย/วันที่/target

Source tables: supply_sterile, supply_sterile_receive. SQL SHA256: 5f2abb97a59d52910acc94e2e53c37af854894b42a3ab587dc96178d00c425ee
