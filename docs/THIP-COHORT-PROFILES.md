# ยอดฐานและคุณภาพการเชื่อมข้อมูล

เพิ่มในหน้า **ตรวจข้อมูลทีละ KPI** โดยเลือกปีจาก toolbar และเลือกเดือนสอบทานในส่วนยอดฐาน แล้วกด **โหลด/ใช้ cache ยอดฐาน** หรือ **อ่านยอดฐานใหม่**. ไม่โหลดอัตโนมัติพร้อมเข้าเว็บ. ทั้งหกชุดเป็น candidate เพื่อสอบทาน ไม่ใช้แทนตัวหารของทุก KPI และไม่เพิ่ม approved coverage.

## Measurement contract

| ชุด | หน่วยและช่วง | ข้อจำกัด |
|---|---|---|
| patient | แถว, HN/CID ไม่ซ้ำ/ว่าง/ซ้ำ ณ เวลาอ่าน | HN ไม่ใช่ PK ตาม snapshot; ยอดทะเบียนปัจจุบันไม่ใช่ population กลางปีหรือบริการย้อนหลัง |
| ovst | VN และ HN ตาม `vstdate >= start AND < end` | แยก VN ผูก/ไม่ผูก AN และ mixed VN; สองกลุ่มอาจซ้อนเมื่อข้อมูลขัดแย้ง ไม่เรียกทุก ovst เป็น OPD เฉพาะ |
| ipt | รับเข้าตาม regdate / จำหน่ายตาม dchdate; AN และ HN แยก | admission ข้ามเดือนอยู่ในคนละยอด; ห้ามบวก HN รายเดือนเป็น HN ทั้งปี |
| person | person_id, patient_hn–hn, CID agreement/conflict, ambiguous/unlinked | aggregate คู่เชื่อมให้หนึ่งแถวต่อ HN ก่อน JOIN เพื่อไม่เพิ่มแถว person; กลุ่มคุณภาพอาจซ้อน; ไม่ merge/fallback CID อัตโนมัติ |
| emp | emp_id/CID; วันที่ขาด/ผิด; candidate headcount วันสุดท้ายของเดือน | เริ่มงานไม่เกินสิ้นเดือน, end ว่างหรือไม่น้อยกว่าสิ้นเดือน; ไม่ตัด CID ว่าง. วันเริ่มว่าง/สิ้นสุดก่อนเริ่มแยก unknown. วันสิ้นสุดว่างอาจยังทำงาน; ต้องเทียบ HR ทุกกรณี |
| opduser | loginname/CID ณ เวลาอ่าน | จำนวนบัญชีแยกจากจำนวนบุคลากร; ไม่อ่าน password |

ทะเบียน patient/person/opduser แสดง **ทะเบียนปัจจุบัน ณ เวลาตรวจ — ไม่ใช่ยอดย้อนหลัง** ทุกปี/เดือนที่เลือก. emp แสดงทะเบียนปัจจุบันร่วมกับ headcount ย้อนช่วงแบบ candidate จากวันเริ่ม/สิ้นสุด ซึ่งไม่ยืนยันว่าทะเบียนยังเก็บพนักงานเก่าครบ. emp ว่างยังเป็น `unverified-source` ไม่ใช่บุคลากรศูนย์ที่รับรอง.

`CohortProfileResult` แยก series `cohort-profile`, FY/month, rule version, metrics, reason, observedAt/expiry, origin/latency และ approval `unapproved`. Pending/missing/future ใช้ NULL; empty episode ที่ query สำเร็จใช้ `zero-cohort`; empty registry และ emp ทุกผลยัง `unverified-source`. ไม่มีอัตราหรือ hospital target ถูกสร้างจากยอดฐาน.

## Query lane, session และ cache

Query ทั้งหกอยู่ใน `src/services/cohortProfiles.ts`; ใช้ `executeRegisteredQuery` ด้วย session/config เดิม. Outer projection มีเพียง `profile_key`, `metric_key`, `count_value`. Validator ปฏิเสธ identifier/คอลัมน์อื่น, metric ไม่ครบ/ซ้ำ/ผิดชุด และ count ที่ไม่ใช่ safe nonnegative integer. Array CID สำหรับตรวจคู่เชื่อมอยู่ภายใน SQL เท่านั้น ไม่ออกจากฐาน.

`AggregateQueryLane` ร่วมกับ Step KPI: FIFO, active request หนึ่งรายการ, เว้นอย่างน้อยหนึ่งวินาทีหลัง response จบ. Pause KPI ไม่หยุดงานยอดฐานที่ผู้ใช้กดแยก; ยกเลิกยอดฐานไม่ล้าง KPI ที่สำเร็จ. เปลี่ยนปี/session/เดือน/clear-all ยกเลิกงานยอดฐานและล้าง snapshot ก่อนแสดงช่วงใหม่. Session expiry/429 หยุด dispatch ทั้งสองทาง; สาม network/server failures ติดกันใน lane พักแหล่งข้อมูล; resume เป็น manual. HTTP 404 ระบุ route/config ไม่อ้าง budget โดยไม่มีหลักฐาน.

IndexedDB store เดิมเก็บคนละ namespace `cohort-profile` จาก `thip-report`. Key ผูก hashed endpoint/hospital/app/session capabilities, FY/month/profile, SQL fingerprint/rule/cache version. ไม่เก็บ token/session ID/raw response/error/identifier. อายุสูงสุด 24 ชั่วโมง และปีปัจจุบันไม่ข้ามขอบเดือน Bangkok. อ่านเมื่อไม่ใช่ source freshness. เปิด storage/เขียนไม่ได้ใช้ memory และป้ายเตือนเดิม; source ล้มเหลวไม่ cache.

**โหลดใหม่ทั้งคิว** ล้างเฉพาะ `thip-report` ของ context/FY; **อ่านยอดฐานใหม่** bypass profile cache และแทนที่เมื่อผ่าน validator. **ล้าง cache ทั้งหมด** ยกเลิกทั้งสองทาง ล้าง namespace ทั้งหมดของแอป; ต้องกดเริ่มโหลดใหม่. ข้อมูลคนละปี/เดือน/session ใช้แทนกันไม่ได้.

## Cohort evidence 232 รหัส

Machine mapping: `src/data/thipCohortEvidence.json`; human mapping: [THIP-COHORT-MAPPING.md](THIP-COHORT-MAPPING.md). อ่านนิยามตัวตั้ง/ตัวหารและหน่วยจาก dictionary, ดึง numerator/denominator/outer source/cohort จาก registered SQL ปัจจุบัน, ผูก PDF physical/printed page และ SQL SHA256. ในหน้าแต่ละ KPI มี **นิยามตัวตั้ง–ตัวหาร / วิธีนับ** แม้ยังไม่โหลดหรือรอ external source.

`CohortDefinition` เป็น evidence เชิงโครงสร้าง แยกจาก owner, clinical readiness และ publication approval. Grain/key/date เป็น candidate; inclusion/exclusion ที่ยังไม่ structured มีเหตุผลชัดและเก็บ full dictionary definition. ไม่ตีความช่องว่างว่าไม่มีข้อยกเว้น. All 232 ยัง `awaiting-hospital-confirmation`, `publicationApproval=unapproved`.

ใช้ JSON schema snapshot 6,109 ตาราง/56,891 คอลัมน์เป็นหลัก: patient PK hos_guid (HN ไม่ประกาศ unique), ovst PK hos_guid, ipt PK an, person PK person_id และ field patient_hn, emp PK emp_id/field emp_cid, opduser PK loginname. ไม่มี declared FK. Obsidian July snapshot 6,617 ตาราง/81,554 คอลัมน์เป็นหลักฐานประกอบคนละ snapshot ไม่ใช่หลักฐานข้อมูลจริงหรือ cardinality ปัจจุบัน. เก็บเฉพาะ schema/evidence ไม่เก็บ patient rows.

## สูตรที่ตรวจและแก้จากหลักฐาน

- CE0102/CE0103 จำกัดวันที่ 5, 15, 25 ตาม `enter_er_time` ใน dictionary; arrival proxy, triage level mapping, exclusions และ repeated ER records ยังต้องรับรอง.
- Employee-month ไม่สร้างแถวเมื่อ end date ก่อน start date; ยอดฐานยังนับเจ้าหน้าที่ในทะเบียนและแยก invalid/unknown. Missing dates ในสูตร KPI เดิมมี fallback ที่ต้องรับรอง HR; ไม่ตีความ headcount ว่ารับรองแล้ว.
- DH0101 นับครั้งจำหน่าย ACS ไม่ใช่ HN ทุกทะเบียน; DH0112 SUM LOS / COUNT admissions ต้องยืนยันคำว่า “คน” ใน dictionary กับ hospital episode interpretation. ไม่เปลี่ยนเป็น distinct HN โดยเดา.
- HH0102 ใช้ DISTINCT HN และ EXISTS diagnoses; proxy nicotine/advice/ยา, shared patient/ER joins และ local workflow ยังไม่รับรอง.
- HE0101 เก็บเจ้าหน้าที่ CID ว่างในตัวหาร; checkup=1 และ CID linkage ยังเป็น proxy.
- SH0101 คง annual dictionary average เดิม. Synthetic PostgreSQL ยืนยัน SUM(bigint) เป็น numeric จึงไม่ตัด 1/12 เป็นศูนย์; ห้ามสร้าง monthly turnover โดยแบ่งรายปี.
- AA0101–AA0105 patient registry ไม่ใช่ประชากรกลางปีอายุ 15–74 ในพื้นที่รับผิดชอบ; คง requirement ของ external population denominator.

ยังไม่แก้ patient.hn/ER.vn one-to-many โดยเลือกแถวหรือรวม CID อัตโนมัติ. เก็บความเสี่ยงไว้ใน evidence และ publication gate จนมีหลักฐาน cardinality/workflow โรงพยาบาล.

## Reproducible acceptance

```text
pnpm cohorts:build
pnpm cohorts:check
pnpm steps:check
pnpm sourceview:check
pnpm test
pnpm build
pnpm monitoring:release-check
python scripts/thip_source_audit.py --input test-fixtures/thip-kpi-complete-2026.json --fiscal-year 2026
python scripts/cohort_sql_smoke.py
THIP_STEP_SMOKE_URL=http://127.0.0.1:5183 python scripts/cohort_browser_smoke.py
```

SQL smoke ใช้ disposable PostgreSQL 16 image แบบ `--network none`, ไม่มี port/mount/host database URL. สร้างเฉพาะ synthetic tables แล้วทิ้ง container. ครอบคลุม HN หลาย VN/AN, duplicate diagnoses, visit ผูก admission, admission/discharge ข้ามเดือน, distinct ข้ามเดือน, CID ว่าง/ซ้ำ/ขัดแย้ง, one-to-many linkage, staff start/resign/invalid dates/missing CID, empty cohort และสูตรตัวแทนหกรหัส. Browser ใช้ intercepted mocked BMS บน desktop/mobile พร้อมจริง IndexedDB, queue gap/isolation, refresh/session,เดือน,clear-all,auth/429/failure/stale response และ keyboard details. ไม่มี hospital query หรือ publication certification.

THIP 232 codes / 1,552 reporting cells และ monitoring 2,784 cells คงเดิม. งานนี้ไม่เรียกฐานจริง ไม่แก้ข้อมูล HOSxP ไม่ deploy และไม่ commit/push.

ตรวจรับ local วันที่ 2026-10-01: suite 1,291 tests / 37 files, SQL smoke 16 checks, cohort browser 18 checks, Step browser 13 checks และ cache browser 13 checks ผ่าน. TypeScript/Vite build, source audit 1,552 cells, fixture audit, cohort/step/source-view generated checks และ production fixture exclusion ผ่าน. Build ยังมี warning ขนาด main bundle (3.09 MB / gzip 490 KB); งานแยก bundle อยู่ใน performance backlog ไม่ใช่ผลรับรองสูตร. รูป/ผลทดสอบอยู่ใน ignored tmp/cohort-browser, tmp/cohort-sql และ tmp/step-browser.
