# แผนให้ THIP ดึงข้อมูลผ่าน BMS ตามแนวทาง IPTImprove และ CMI-Dashboard

วันที่: 1 ตุลาคม 2569 · สถานะ: แผนเสนอพัฒนา ยังไม่ได้เปลี่ยน runtime หรือเปิดข้อมูลจริง

หลักฐานผล export ที่ผู้ใช้ส่งภายหลัง: [Excel aggregate FY2569](THIP-EXPORTED-AGGREGATE-REVIEW-2026-10-01.md) มี 177 รหัส / 1,353 cadence cells; 55 external codes ขาดตรง mapping. เพิ่มงานใน P0-C ให้รับ seven-column aggregate ใน candidate adapter, ตรวจ integer division/source-value discrepancy, และแยก 0/0 ที่ query เติมจาก zero cohort จริง. ไม่ใช้ workbook เป็น fixture production หรือหลักฐาน approval.

ผู้ใช้ระบุ SQL จาก Navicat เพิ่มเติมและพบ integer division ใน source ที่ตรงอาการ value ถูกตัดทศนิยม. เพิ่มงานก่อน pilot: แก้ numeric arithmetic ที่ต้นทาง/สร้าง generated queries ใหม่ และแยก registered SELECT ออกจากไฟล์รวมที่มี DDL/sample INSERT/refresh DELETE อยู่ด้วย. ไม่รันไฟล์รวมกับ HOSxP หรือส่งทั้งไฟล์เข้า API.

## ข้อสรุปและการตัดสินใจ

ให้ THIP มีเส้นทางอ่าน aggregate จาก HOSxP ผ่าน registered SQL โดยตรงเป็นเส้นทางเริ่มต้นสำหรับรหัสที่มี query และ schema เหมาะสม ใช้ session และ API ของ BMS เช่นเดียวกับ IPTImprove และ CMI-Dashboard ส่วน normalized source view เป็นทางเลือกสำหรับโรงพยาบาลที่มี reporting layer อยู่แล้ว ไม่ใช่ข้อบังคับสำหรับทุก KPI

ผู้ใช้เลือกให้มี **หน้าตรวจสอบ aggregate จริงที่ยังไม่รับรองแยกต่างหาก** หน้านี้แสดงหลักฐานเพื่อทดสอบและตรวจสูตร ไม่ถือเป็นผล THIP ที่รับรองแล้ว ไม่เพิ่ม measurement coverage ของผลเผยแพร่ และไม่ใช้ approval จำลองเพื่อเปิดข้อมูลจริง

คำแนะนำก่อนหน้านี้ว่าต้องสร้าง source view ก่อนจึงจะมีข้อมูลไม่ครอบคลุมทางเลือกทั้งหมด: THIP มี foundation query อยู่แล้ว แต่ default/configuration, monitoring provider และ publication gate ยังทำให้เส้นทางนี้ไม่ตอบโจทย์การเริ่มตรวจข้อมูลจริง การแก้เพียง environment variable หรือเพียงปลด approval จึงไม่เพียงพอ

## หลักฐานจากโปรเจ็คอ้างอิง

เป็นการอ่าน source ในเครื่อง ไม่ได้ทดสอบ connection สด และไม่ได้ยืนยันว่า local changes ตรงกับเวอร์ชันที่ใช้งานจริง ผู้ใช้ระบุว่าสองระบบนี้เคยดึงข้อมูลได้; ข้อค้นพบด้านล่างยืนยันรูปแบบ implementation ไม่ใช่ผลทดสอบ BMS ปัจจุบัน

| ประเด็น | IPTImprove | CMI-Dashboard | THIP ปัจจุบัน / สิ่งที่จะเปลี่ยน |
|---|---|---|---|
| ตำแหน่ง source | `C:/Users/KTLho/Documents/IPTImprove` | `C:/Users/KTLho/Documents/CMI-Dashboard/cmi-dashboard` | `C:/Users/KTLho/Documents/THIP-KPI-BMS` |
| รับ session | Launcher `bms-session-id`, alias `sessionId` และช่องกรอก session | Launcher และหน้าต่อ session/reconnect | THIP อ่าน launcher และเก็บใน memory แต่ไม่มีช่องกรอก/alias; เพิ่มช่องเชื่อมต่อและ reconnect |
| Handshake | PasteJSON → `result.user_info` | PasteJSON → `result.user_info` → database probe | ใช้ handshake เดิม พร้อมตรวจ response error และยกเลิก request เมื่อ reconnect |
| API config | `bms_url`, `bms_session_code` หรือ `result.key_value` | fields เดียวกัน; normalize URL | THIP ใช้ fields เดียวกัน; เพิ่ม URL validation/normalization กลาง |
| เรียก SQL | `POST /api/sql`, Bearer, body `{sql, app, params}` ผ่าน allowlisted registry | `POST /api/sql`, Bearer, `{sql, app, params}` และ optional `marketplace-token` ใน body | THIP มี wire contract นี้อยู่แล้ว รวม marketplace token ใน body; ไม่จำเป็นต้องเปลี่ยน protocol หลัก |
| แหล่งวัดหลัก | อ่าน `ipt`, `iptdiag`, `an_stat` ฯลฯ โดยตรง; THIP crosswalk เป็น optional source คนละส่วน | Queries CMI อ่าน HOSxP โดยตรง; ไม่ต้องสร้าง reporting schema ของแอปก่อน | แยก direct aggregate provider จาก optional source-view provider |
| Error handling | ตรวจ HTTP, JSON และ MessageCode | อ่าน JSON error ก่อนตัดสิน HTTP 501; จัดการหมดอายุ/429 | THIP ตรวจ HTTP ก่อน JSON สำหรับ non-2xx; เพิ่ม classification ที่อ่าน body โดยไม่ส่ง SQL/secret กลับ UI |
| Build | ไม่บังคับ KPI source view | ไม่บังคับ KPI source view | Docker บังคับ source หรือ foundation flag; Compose ส่งเพียงบาง args; ปรับให้ direct mode สร้างได้และตรวจ config ตาม mode |

ไฟล์อ้างอิงที่ตรวจ:

- IPTImprove: `src/services/cmiApi.ts` (`executeSqlViaApi`, registry, session extraction), `src/session/useBmsSession.ts`, `src/pages/WorklistPage.tsx`, `src/thip/thipApi.ts`, `Dockerfile`.
- CMI-Dashboard: `src/services/bmsSession/session.ts`, `sql.ts`, `helpers.ts`, `src/hooks/useBmsSession.ts`, `src/components/session/SessionValidator.tsx`, `src/services/cmiQueries/sql.ts`, `Dockerfile`.
- THIP: `src/services/bmsSession.ts`, `queryRegistry.ts`, `bmsData.ts`, `publication.ts`, `src/monitoring/provider.ts`, `contract.ts`, `rules.ts`, `Dockerfile`, `docker-compose.yaml`.

`C:/Users/KTLho/Documents/drg-clinical-dashboard` เป็นโฟลเดอร์ว่างเมื่อสำรวจ จึงไม่มี source ให้อ้างอิง ยังไม่ใช้โปรเจ็คอื่นแทนโดยเดาเส้นทาง

สิ่งที่ไม่ควรคัดลอก: raw worklist/clinical detail, patient identifiers, credential cookie/sessionStorage และ session ผ่าน build environment ของโปรเจ็คอ้างอิง THIP ต้องส่งออกจากฐานข้อมูลเฉพาะ aggregate และคง credential ไว้ใน memory ของหน้าเท่านั้น ไม่เปลี่ยน app identifier เป็นชื่อแอปอื่นเพื่อหลบสิทธิ์; BMS/platform owner ต้องตรวจว่า `THIP.KPI.BMS` ได้รับสิทธิ์ที่เหมาะสม

## เหตุที่ THIP ยังไม่มีค่าบนหน้าจอ

| ลำดับ | หลักฐานใน THIP | ผลกระทบ | ทางแก้ |
|---|---|---|---|
| 1 | `connectBmsSession()` รับ session จาก launcher เท่านั้น | เปิด URL ตรง/reload หลัง strip credentials แล้วอาจไม่มี session; ผู้ใช้ reconnect เองไม่ได้ | ช่องกรอก session, alias, retry/disconnect และข้อความที่บอกขั้นตอน |
| 2 | `createMonitoringProvider()` คืน `[]` เมื่อไม่มี runtime หรือ monitoring view | หน้าหลักไม่มีทางอ่าน direct HOSxP; configuration issue กลายเป็นตารางว่าง | typed load diagnostics และ direct provider; ไม่กลืนสาเหตุเป็น empty result |
| 3 | source-view requirement และ foundation flag ควบคุม THIP loader | มี registered SQL แต่ build/runtime อาจไม่เปิดเส้นทางนั้น | source mode ที่ชัดเจนและ config migration |
| 4 | `publishApprovedThip()` และ monitoring contract กันสูตรที่ไม่รับรอง; rules จริงยังไม่ approved | โหลด aggregate สำเร็จก็ยังไม่มีผลเผยแพร่ | หน้าตรวจสอบแยก; คง publication gate เดิม |
| 5 | Compose ไม่ส่ง monitoring source/foundation/concurrency ที่ Dockerfile รองรับ | config ที่ตั้งไว้อาจไม่เข้า frontend bundle | ตรวจ build args ทุกทางและเผย mode/revision ที่ไม่มี secret |
| 6 | query บางชุดอ้าง external staging/แหล่งเป้าหมาย | schema จริงอาจไม่มี dependency; query รวมอาจล้มทั้งชุด | pilot queries ต้องอ่านเฉพาะ dependencies ที่ยืนยัน; isolate ตาม code/family |

ข้อ 1–6 เป็นข้อค้นพบใน local source ไม่ใช่คำยืนยันว่าระบบจริงล้มที่ทุกข้อพร้อมกัน การตรวจ public build ก่อนหน้านี้พบ asset เก่า; รอบนี้ยังไม่ได้ตรวจ public build ใหม่ การ push สำเร็จไม่ใช่หลักฐานว่า BMS ได้ rebuild/redeploy แล้ว

## โครงสร้างที่เสนอ

```text
Launcher / ช่องกรอก session
  → BMS session boundary + database probe
  → registered aggregate queries (direct HOSxP หรือ optional normalized source)
  → ตรวจ schema / period / numeric facts / version / source dependencies
      → หน้าตรวจสอบ: candidate aggregate + หลักฐาน + คำเตือนยังไม่รับรอง
      → publication gate
          → ผล THIP 232 รหัส / 1,552 cadence cells
          → monthly monitoring 232 × 12 cells ตาม rule ที่รับรองแยกกัน
```

ใช้ transport และ query registry เดียวกัน แต่แยก adapter/series ไม่ใส่ draft aggregate ลง `Indicator.monthly` หรือแปลง `rule-unapproved` เป็น `measured` ในผลเผยแพร่

เพิ่ม `CandidateAggregate` และผลโหลดของหน้าตรวจสอบแยกจาก `MonthlyMonitoringResult`: code, series ที่ตรวจ (`thip-report` หรือ `monthly-monitoring`), FY/period, numerator/denominator/value/unit, query key, candidate rule version, measurement state, approval state, reason, data-through และเวลาสังเกตผล query (`observedAt`) พร้อม source provenance ที่ไม่ระบุคน `observedAt` ไม่ใช่วัน refresh ของแหล่งข้อมูล; ถ้าไม่มีหลักฐาน source freshness ให้ `refreshedAt`/`dataThrough` เป็น NULL พร้อมเหตุผล

หน้าตรวจสอบอ่านได้เฉพาะผู้มี session ที่ BMS อนุญาต ไม่มีช่อง arbitrary SQL ไม่มี patient drill-through แสดงป้าย “ข้อมูลจริงเพื่อสอบทาน — สูตรยังไม่รับรอง” ตลอดหน้า และยังไม่ส่งออก candidate CSV ในระยะแรก เพื่อให้ export ผล THIP/monitoring เดิมมีความหมายคงเดิม ทุกจุดแสดงผล candidate ต้องระบุ series/version และไม่ใช้สีผ่านเป้าหรือสรุปผลคุณภาพอย่างเป็นทางการ

### Source mode และการเลือก query

- เสนอ `direct-hosxp` เป็น default สำหรับการเริ่มตรวจ native aggregate; `normalized-source` สำหรับโรงพยาบาลที่มี source view. ตรวจ config ตาม mode ไม่ fallback ข้าม mode โดยเงียบเมื่อ query ล้ม.
- `direct-hosxp` ใช้ SELECT/WITH ที่ลงทะเบียนและตรวจไว้เท่านั้น ไม่รัน generated DDL/refresh ไม่ต้องมี schema `reporting` สำหรับ pilot native queries.
- ไม่เรียก foundation รวม 232 codes เป็น request เริ่มต้น ใช้ allowlist code/family ที่ตรวจ dependency และ query cost แล้ว พร้อม progress, abort และ per-code reasons. Native pilot ไม่อ้าง external staging หรือ `kpi_moph` ที่ยังไม่ยืนยัน.
- จำกัด concurrency/time budget, retry เฉพาะ transient errors แบบมีขอบเขต ไม่ retry auth/SQL/config ไม่แบ่ง observation window ที่ยังไม่ได้พิสูจน์ว่าให้ผลเท่าเดิม.
- `normalized-source` คง strict contract สำหรับผล THIP ครบ 1,552 cells. Direct adapter สร้าง expected grid ครบเช่นกัน แต่ missing/failed/unapproved cells ต้องมี NULL/reason; ไม่อ้าง coverage 100% จากการสร้าง placeholder.
- External aggregate รองรับเมื่อมีแหล่ง read-only ที่ตกลง contract แล้ว ไม่จำเป็นต้องอยู่ใน HOSxP. ถ้าต้อง provision ให้ทำบน reporting database ที่แยกและอนุญาตโดยเจ้าของ ห้ามทำ DDL/INSERT/DELETE กับ HOSxP จากแอป.

### ขอบเขตแต่ละ KPI

ใช้ [evidence matrix](THIP-KPI-DEVELOPMENT-MATRIX-2026-09-30.md) และ [machine mapping](THIP-KPI-DEVELOPMENT-MATRIX-2026-09-30.json) เดิมเป็นฐาน ไม่คัดลอกนิยาม CMI/DRG มาเป็นสูตร THIP

| เส้นทาง | จำนวน | งานก่อนเปิดผลรายเดือน |
|---|---:|---|
| Native monthly candidate | 101 | ตรวจ dependency, cohort/joins/date/unit และสร้าง registered monthly aggregate ต่อ rule; ไม่ถือว่าทั้ง 101 ใช้ได้กับฐานจริงทันที |
| ต้องกำหนดสูตร monthly เพิ่มเติม | 71 | ออกแบบสูตรและ accumulation แยกจาก cadence THIP; ไม่มีสูตรให้คงเหตุผล/NULL |
| External aggregate | 55 | ยืนยัน source/owner/version/freshness และ aggregate contract |
| External population denominator | 5 | ยืนยันประชากร/พื้นที่/ช่วงปีและสูตร denominator ก่อนวัด |

เริ่ม pilot ด้วย DH0101 และ DH0112 เมื่อ dependencies ผ่าน; CE0102, HH0102, SH0101, SM0201 และ external DE1601 เป็นกรณีตรวจเพิ่มเติม ไม่รับประกันความพร้อมจากชื่อ code alone. SH0101 ยังเป็น annual ตาม dictionary; ห้าม annual/12 หรือทำซ้ำผลปีลงเดือน. ผล quarterly/semiannual/annual ต้องอยู่ใน reporting cadence เดิม แม้หน้าตรวจสอบจะเปิดข้อมูลได้

FY ภายในใช้ ค.ศ.ตาม contract THIP แสดง พ.ศ.; adapter ข้ามโปรเจ็คต้องแปลงอย่างชัดเจน เพราะ THIP crosswalk ของ IPTImprove รับ FY พ.ศ. เดือน ต.ค.–ก.ย. มีขอบเขต `[start, end)` และใช้ Asia/Bangkok สำหรับเดือนอนาคต. Denominator ศูนย์ไม่สร้างอัตรา; distinct YTD คำนวณใน DB; ไม่เฉลี่ยเปอร์เซ็นต์รายเดือน; target ที่ยังไม่รับรองคง NULL และแสดง dictionary benchmark เป็น reference แยก

## ลำดับพัฒนาและเกณฑ์ตรวจรับ

| งาน | Dependency / ผู้รับผิดชอบ | ผลส่งมอบและ acceptance criteria |
|---|---|---|
| P0-A: ทำ connection ที่ผู้ใช้แก้เองได้ | แผนนี้ / frontend + BMS owner | ช่อง session/reconnect/disconnect, launcher alias; trim และ strip credentials ก่อน request; URL ต้อง HTTPS (HTTP เฉพาะ loopback ที่อนุญาต), ไม่มี embedded credentials/query/fragment; database probe PostgreSQL; reconnect ยกเลิก request/ล้าง snapshot ของ session เก่า; refresh แจ้งให้ reconnect เมื่อ memory หาย ไม่บันทึก token ลง storage/build/log |
| P0-B: Error และ connection diagnostics | A / frontend + QA | แยก session lookup, permission/expiry, unsupported DB, API/JSON, query failure, empty cohort, missing dependency, unapproved rule; parse MessageCode แม้ HTTP 501; error ขึ้นหน้าที่ถูกต้องและไม่มี raw SQL/body/URL credential; รองรับ cancel และ timeout ครอบคลุม body; session connected ไม่แปลว่ามี measured data |
| P0-C: Native aggregate pilot + หน้าตรวจสอบ | A–B; schema mapping / data owner + frontend | Registered pilot queries ไม่พึ่ง reporting tables; candidate contract ตรวจ duplicate/period/unit/version; หน้าตรวจสอบแสดง facts ที่ยังไม่รับรองพร้อม label/source/query/version/reason; zero-cohort vs empty response vs query failure ต่างกัน; ไม่กระทบผลเผยแพร่/export; mocked success อ่านได้อย่างน้อยหนึ่ง code โดยไม่มี source view |
| P1-D: Direct monitoring provider | C; monthly rule ของแต่ละ code / data owner + frontend | Provider interface รองรับ direct และ normalized source; ครบ 2,784 slots/reasons รวม future; ไม่คืน empty array แทน config failure; monthly native queries แยกจาก annual/cadence queries; distinct/fixed/snapshot/custom YTD มี contract และ tests; 1,552 official cells คงเดิม |
| P1-E: รับรอง pilot และ target | C–D; รายงาน aggregate โรงพยาบาล / KPI owner + quality + data owner | ตรวจ cohort, fan-out, local codes, admit/discharge/date, denominator, target provenance และ effective window; discrepancy log เทียบรายงานจริง; ลง evidence/version/effectivity แยก official กับ monitoring; ถ้าไม่ผ่าน candidate ยังดูเพื่อสอบทานได้แต่เผยแพร่ไม่ได้; ถอน approval ได้ |
| P1-F: Build/deploy configuration | A–D / frontend + platform owner | direct build ไม่ต้องสร้าง source view; normalized mode fail ชัดเมื่อ config ไม่ครบ; Docker/Compose ส่ง args ตาม mode; preserve compatibility หรือแจ้ง migration ของ flags เดิม; source/allowed origins ไม่มี credentials; production bundle ไม่มี preview fixtures; เพิ่ม build revision/mode ที่ตรวจได้ และคู่มือ rebuild BMS/Gitea ให้ตรง commit |
| P1-G: ตรวจระบบจริงตามขอบเขต pilot | E–F; fresh BMS session และ platform พร้อม / BMS + data owner + QA | บนเว็บที่ revision ตรง: session→version→registered aggregate สำเร็จ; ไม่มี source view ก็ตรวจ native pilot ได้; ตรวจ CSP/CORS/สิทธิ์ของ THIP app และ missing dependencies; aggregate ที่เผยแพร่ตรงรายงานรับรอง; ไม่มี raw patient rows หรือ DDL ถูกเรียก; สรุป measured coverage แยกจาก queried/candidate/approved coverage |
| P2-H: ขยายราย family และ external | G ต่อ family / KPI + external data owners | ประเมินครบ 232 codes ตาม 101/71/55/5; เปิดทีละ family เมื่อผ่าน E; external ที่ขาดคง NULL/reason; latency/freshness/coverage alerts ไม่มี PHI; withdraw rule/source แล้วผลกลับ unavailable ไม่ค้างค่าปีหรือ session เก่า |

งาน A–D และ F ทำด้วย local schema/fixtures/mocked BMS ก่อน ส่วน E/G ต้องมีหลักฐานและสิทธิ์จากโรงพยาบาล จึงยังไม่ถือว่าการดึง aggregate จำลองผ่านคือเปิดใช้งานจริงสำเร็จ ไม่ใส่วันเสร็จจากการคาดเดาก่อนตรวจ dependencies

ไฟล์ที่จะเปลี่ยนในระยะ implementation: session/query/error services และ connection UI; `src/monitoring/provider.ts` กับ direct aggregate adapter/registry; candidate validation page/model; Docker/Compose/environment types/build metadata; tests; README, data/source/monitoring contracts และ roadmap. คง `publishApprovedThip()` และ approved monitoring gate แยกจาก candidate path

## การทดสอบที่จำเป็นก่อนถือว่าเสร็จ

1. Transport/session: mocked PasteJSON ตาม reference fields, fallback token, trailing slash/invalid URL, launcher/manual/alias, numeric/string MessageCode, HTTP 501 JSON auth vs SQL errors, 429, invalid JSON, body timeout, disconnect/reconnect races; credential canary ไม่อยู่ใน logs/storage/URL หลังรับ session.
2. Native pilot: mock DB schema ไม่มี `reporting` และไม่มี `kpi_moph` แล้วยังอ่าน native aggregate ได้; missing native table ทำให้เฉพาะ code ที่พึ่ง source นั้น unavailable; unknown/duplicate periods และข้อมูลไม่ตรงหน่วย/version ถูกปฏิเสธ; SQL boundary รับเฉพาะ registered read-only aggregates.
3. นิยาม: joins one-to-many, duplicate events, admission/discharge ข้ามเดือน, observation window ข้ามปี, distinct YTD ต่างจากผลบวกรายเดือน, weighted ratio ต่างจากเฉลี่ยเปอร์เซ็นต์, fixed denominator/snapshot/zero/NULL, FY conversion และเดือนอนาคต; ไม่ reuse annual SH0101 เป็นเดือน.
4. Publication isolation: candidate จริงที่ยังไม่รับรองดูได้เฉพาะหน้าตรวจสอบ แต่ official/monitoring/CSV ยังคง withholding; candidate ไม่เพิ่ม published coverage; target-only ไม่ใช่ measured; approved version/effective period ผิดต้องกันผล; synthetic approval ใช้กับข้อมูลจริงไม่ได้.
5. Compatibility/browser: official 232 codes/1,552 cells และ monitoring 232×12; desktop/mobile, session/error states, FY cancellation, search/filter/drill-through/keyboard/back/forward; export เดิมเฉพาะ snapshot ปี/series ที่ถูกต้องและ CSV formula injection checks.
6. Build/artifacts: test suite/build/source audit/generated diff ที่เกี่ยวข้อง; production ไม่มี fixture rows/preview flag; Docker และ Compose direct/normalized modes; version/mode อ่านได้โดยไม่มี secret. ไม่จำเป็นต้องตรวจซ้ำ unrelated code เมื่อไม่มีการเปลี่ยน.
7. ตรวจรับจริง: read-only pilot เทียบ aggregate กับรายงานโรงพยาบาลในช่วงที่ตกลง; แยก connection success, query success, candidate coverage, approved coverage, data-through และ query latency. ไม่ตั้งเกณฑ์ว่าต้องมี nonzero numerator เพราะ cohort จริงอาจศูนย์.

## งานฝั่งโรงพยาบาล/BMS ที่ต้องเตรียมภายหลัง

- เปิดแอปผ่าน launcher หรือกรอก fresh session ในหน้าที่พัฒนา; ไม่ใช้ cookie ของ Gitea แทน BMS session และไม่ฝัง session ลง URL คู่มือ/environment ของ build.
- BMS owner ยืนยันสิทธิ์ SELECT ของ app/role และ database type; platform owner ยืนยัน API origin, CSP/CORS และวิธี build/deploy จริง. Browser fetch failure อย่างเดียวไม่พอจะฟันธงว่าเป็น CORS.
- Data owner ยืนยัน schema/local codes ของ pilot และส่งรายงาน aggregate สำหรับสอบทาน. Native pilot ไม่ต้องรอสร้าง reporting table; external KPI ยังต้องมีข้อมูลภายนอก.
- Platform owner rebuild artifact จาก revision ที่ตรวจแล้ว และตรวจ revision บนเว็บก่อนทดสอบ; แยกการ push GitHub/Gitea ออกจากการ deploy. เตรียม rollback ของ deployment และการถอน publication approval.

## ขอบเขตรอบวางแผนนี้

อ่าน source ของโปรเจ็คอ้างอิงและ THIP เท่านั้น ไม่แก้ reference projects หรือ runtime THIP ไม่ใช้ session/cookie ที่ผู้ใช้เคยส่ง ไม่เรียก BMS/HOSxP จริง ไม่รัน DDL ไม่เปิด Issues ไม่ commit/push/deploy. มีงานค้างใน IPTImprove อยู่ก่อนแล้วและเก็บไว้ตามเดิม

แผนนี้แก้ dependency ใน roadmap เดิมที่ให้ reporting provisioning มาก่อนการตรวจ native facts: provisioning เป็น optional สำหรับ normalized/external sources ไม่ใช่ prerequisite ของ native direct path. Publication approval ยังคงจำเป็นก่อนเปิดผลทางการ; การเพิ่มหน้าตรวจสอบแยกเป็นความต้องการที่ผู้ใช้ยืนยันในรอบนี้
