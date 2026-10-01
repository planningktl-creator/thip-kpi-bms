# รายงานตรวจโครงการ THIP KPI BMS

**วันที่หลักฐาน:** 30 กันยายน 2569 · **จัดทำ:** 1 ตุลาคม 2569
**ขอบเขต:** ตรวจ source code, เอกสาร, SQL, fixtures, deployment/CI configuration และไฟล์ที่มีอยู่ใน working tree; ตรวจ PDF THIP KPI 317 หน้าและ HOSxP schema JSON ที่ผู้ใช้ให้
**ผลส่งมอบที่เกี่ยวข้อง:** [แผนแก้ไขและเกณฑ์ตรวจรับ](PROJECT-AUDIT-REMEDIATION-2026-09-30.md), [ตาราง mapping 232 KPI](THIP-KPI-DEVELOPMENT-MATRIX-2026-09-30.md), [ข้อมูลหลักฐานฉบับเครื่องอ่าน](THIP-KPI-DEVELOPMENT-MATRIX-2026-09-30.json) และ [roadmap](THIP-KPI-DEVELOPMENT-ROADMAP.md)

## ข้อสรุป

โครงการมี catalogue และ query branch ครบ 232 รหัส มีผลตรวจอัตโนมัติ 1,212 tests ผ่าน, build ผ่าน และ fixture ตาม cadence เดิมครบ 1,552 reporting cells แต่ความพร้อมของ SQL ไม่เท่ากับการรับรองสูตร: manifest ปัจจุบันมี foundation 16, ต้องทำ local mapping 216 และมี rule ที่พร้อมเปิด production 0 รหัส ตารางติดตามรายเดือนจึงยังไม่มีรหัสใดที่ควรแสดงผลจริงจนกว่าจะผ่านการรับรองแยกราย KPI

มีข้อบกพร่องด้านความปลอดภัยและความเที่ยงตรงที่ต้องแก้ก่อนนำข้อมูลจริงมาใช้ ผลทดสอบ SQL บน PostgreSQL สังเคราะห์พบว่าผลจากตาราง external ถูกตัดทิ้ง และการแบ่ง query ช่วง quarter อาจทำให้ episode หายหรือถูกนับเป็นศูนย์ ขณะที่การตรวจ browser พบว่าเปลี่ยนปีแล้วข้อมูลเก่ากับปุ่ม export ปีใหม่ยังแสดงพร้อมกันได้ และ access log บันทึกค่า query string กับ Referer ที่ใส่ canary สำหรับ session ได้

รายการด้านล่างคงผลตรวจสองแกนตามการตรวจ **Standards** และ **Spec** แยกกัน หากเป็นปัญหาเดียวกันข้ามแกนจะชี้ไปยังรหัสเดียวกันในแผนแก้ เพื่อไม่นับซ้ำเป็นข้อบกพร่องอิสระ ความรุนแรง P0–P3 เรียงภายในแต่ละแกน

## หลักฐานและขอบเขตการตรวจ

| แหล่ง | ข้อเท็จจริงที่ตรวจได้ | ข้อจำกัด |
|---|---|---|
| THIP KPI.pdf | SHA-256 `6d1a9ad40235b5cea60e99c50df57e39a7d7d9276b97693a506e0db749953901`; เอกสาร 317 หน้า; สกัดหน้ารายละเอียดและเลขหน้าพิมพ์ครบ 232 codes; cadence 112 monthly / 19 quarterly / 31 semiannual / 70 annual | ใช้ CID/font-aware extractor ที่มีใน repo และนำมาใช้ซ้ำโดยไม่เรียก entry point ที่เขียนทับ dictionary; parser อยู่ใน lineage เดียวกับ extractor เดิม จึงไม่ใช่การตรวจนิยามทางคลินิกโดยผู้ตรวจอิสระ |
| HOSxP Structure with primary key.json | SHA-256 `c4dbe6641963635bd14ff485133fd8cb61968f9090bb550652f6b7861671a9d2`; 6,109 tables / 56,891 columns; 5,862 ตารางมี primary key; ไม่มี foreign key ที่ประกาศ | เป็น schema inventory ไม่ใช่ snapshot ข้อมูลจริง; ชนิดข้อมูลและ PK ไม่พิสูจน์ความสัมพันธ์หรือจำนวนแถวในโรงพยาบาล |
| SQL ทั้งหมด | PostgreSQL parser ผ่าน 232 registered branches และไฟล์สามชุดรวม 696 files; qualified column refs ที่ตรวจเทียบ schema ไม่พบชื่อคอลัมน์ขาด | parser pass และ schema-name match ยังไม่พิสูจน์ semantics, unqualified resolution ใน DB จริง, join cardinality หรือผล cohort |
| PostgreSQL | รัน generated source view และ query บางกรณีบน PostgreSQL 16.14 ด้วยตาราง/ข้อมูลสังเคราะห์; refresh สร้าง 1,552 cells; พบ external fact ถูกทิ้งและ split-quarter เปลี่ยนผลจาก 1/1/100% เป็น 0/1/0% แล้วงวดถัดไปไม่มีแถว | ไม่มีการต่อ BMS/HOSxP จริง; synthetic tables จำลองคอลัมน์และค่า ไม่ได้จำลองข้อจำกัดหรือ cardinality ของฐานโรงพยาบาล |
| Browser | Playwright เปิด dashboard ด้วยข้อมูล no-data และ mocked BMS; ทดสอบ desktop/mobile, search, catalog refresh, เปลี่ยน FY ระหว่าง request ค้าง และ export | ปิดกั้น request ออกนอก localhost; ไม่ใช่ connectivity smoke กับ BMS จริง; repository visual smoke หยุดที่ assertion เก่าซึ่งไม่ตรงกับข้อความหน้าเว็บปัจจุบัน |
| Security / dependency | สแกน literal ที่มีความเชื่อมั่นสูงในไฟล์ working tree ปัจจุบันและ Git objects ใน refs ที่มีอยู่ (874 files / 1,131 blobs): ไม่พบ pattern credential ที่ตรวจ; `pnpm audit` พบ 1 moderate advisory ใน dev dependency Vitest | ไม่ใช่การตรวจ PHI ครบทุกแบบ และไม่ดึง remote refs; advisory ซ้ำสอง package entries แต่เป็น GHSA เดียว; ไม่ได้ยืนยันว่ามี production exploit |
| สิ่งที่คงไว้ | ทำงานบน HEAD `19306cd82e15e0440a2c7dfe9eb5ff3bf7cebb01`; มีไฟล์ tracked modified และ generated SQL/สามชุด query ที่ยังไม่ tracked ก่อนเริ่มงาน | เก็บรายการเดิมไว้ ไม่ reset, overwrite หรือแก้ runtime source ในรอบเอกสารนี้ |

## สถานะฐานและเกณฑ์ที่แยกจากกัน

- **มี SQL:** 232/232 codes อยู่ใน registered query boundary; 55 branches ต้องอ่าน aggregate จาก `reporting.thip_external_facts`.
- **ตรง schema snapshot:** qualified physical columns ที่ analyzer พบมีใน schema JSON ครบ; เป็นเพียงการเทียบชื่อคอลัมน์. ตาราง external staging เป็น schema ที่โครงการต้อง provision เอง จึงไม่อยู่ใน HOSxP inventory.
- **ตรงนิยาม THIP:** ยังไม่มีสถานะรับรองครบทุก code; มีข้อโต้แย้ง/ตัวอย่างที่ไม่ตรงนิยามตาม SPEC findings และยังขาดการเทียบ aggregate กับรายงานโรงพยาบาล.
- **ได้รับการรับรอง:** 0/232. ไม่มี owner/evidence/rule version ที่ครบและได้รับ sign-off เพื่อปล่อยค่าจริง.
- **ผล cadence THIP:** ยังคง 1,552 cells: 112×12 + 19×4 + 31×2 + 70×1. Fixture ครบไม่ได้หมายความว่าค่าจริงครบหรือถูกต้อง.
- **ผลติดตามรายเดือน:** มี 232×12 = 2,784 ช่องสำหรับแสดงในอนาคต. ช่องเหล่านี้ต้องเป็น series แยกและมีสูตรรายเดือนของตนเอง; ห้ามเติมผล quarter/year ลงทุกเดือน.

## Findings: Standards

| ID / ระดับ | ข้อค้นพบและหลักฐาน | ผลกระทบ |
|---|---|---|
| STD-01 · P1 | Nginx ส่ง access log ลง stdout (`nginx-main.conf:12`) ด้วย log format ปริยายที่มี request URI และ Referer. Container ที่ทดสอบบันทึก launcher query canary, marketplace query canary และ asset Referer canary ได้; Nginx ระบุ field ที่บันทึกใน [log module](https://nginx.org/en/docs/http/ngx_http_log_module.html). | session credential/token ที่เดินทางใน URL หรือ Referer อาจไปอยู่ log/ผู้รวบรวม log. |
| STD-02 · P1 | เปลี่ยน FY ระหว่าง BMS request ค้าง: `App.tsx:83–117` เก็บผลเก่าระหว่างรอ; ปุ่ม export ใช้ `allIndicators` กับปีที่เลือกใหม่ (`DashboardPage.tsx:120–125`). Browser เห็น FY ใหม่พร้อม period เก่า 70 รายการ และ export เปิดใช้งาน/ดาวน์โหลดชื่อปีใหม่ได้ระหว่าง request เก่าค้าง. | ผู้ใช้หรือไฟล์ CSV อาจเข้าใจข้อมูลปีเก่าว่าเป็นของ FY ที่เลือก. |
| STD-03 · P2 | Effect cleanup ใน `App.tsx:88,116` กันผล response เก่ากลับมา render แต่ไม่ abort request เก่า ทั้งที่ transport รองรับ `AbortSignal`. | เสียเวลา/ทรัพยากร BMS เมื่อสลับ FY หรือ unmount ถี่. |
| STD-04 · P2 | timeout ถูก clear หลังได้ response headers ก่อนอ่าน body (`queryRegistry.ts:1148`, `bmsSession.ts:96`); synthetic body ที่ค้างทำให้เวลารวมเกิน deadline โดย signal ไม่ถูกยกเลิก. | การ timeout ไม่ครอบคลุม body parse/stream และอาจค้างนานเกินกำหนด. |
| STD-05 · P2 | การนำทาง catalogue ใช้ state ที่ถูกลบเมื่อ refresh; `App.tsx:154` parse route ที่มี `view=catalog` แต่ปุ่ม navigation ไม่เก็บ state ที่ refresh ต้องใช้. Browser เปิด catalogue ได้ แต่ reload กลับหน้า overview. | Deep link/refresh ของ catalogue ใช้งานไม่ได้. |
| STD-06 · P2 | การรวม annual target ใช้ quarterly/monthly target ตัวแรกที่ไม่เป็น NULL เป็น target ของทั้งปี (`rollup.ts:121–128`). ค่าเป้าหมายที่เปลี่ยนระหว่างงวดถูกกลบ. | annual status เปรียบเทียบผิดเป้าหมายที่มีผลจริง. |
| STD-07 · P2 | SPC run rule เปรียบเทียบ `>= CL` (`controlChart.ts:130`) ทำให้ค่าที่เท่ากับเส้นกลางนับเป็นฝั่งเดียวกัน; synthetic 12 จุดเท่าค่า CL ถูกเตือนครบ 8 จุด. | false positive run signal. |
| STD-08 · P2 | p-chart ถูกเลือกจาก `unit !== 'count'` และ `0 ≤ numerator ≤ denominator` (`controlChart.ts:61`). ratio เช่น DH0112 อาจเข้ากฎ p-chart แม้ข้อมูลยังไม่ผ่าน measurement-model approval. | ชนิด chart ไม่ได้ผูกกับชนิดข้อมูล/ข้อสมมติของตัวชี้วัด. |
| STD-09 · P2 | validator ของ source view ยอมให้ unavailable row ไม่มี `pending_reason` และ completeness ยังผ่าน; จุดตรวจ `bmsData.ts:800,933`. Synthetic source view 1,552 cells สามารถเป็น tier registered ที่ NULL ทุกค่าหรือ pending โดยไม่มีเหตุผล แต่ผ่าน completeness ได้. | บอก coverage ครบแต่ไม่บอกว่าข้อมูลราย code หายเพราะอะไร. ซ้ำข้อ Spec SPEC-07. |
| STD-10 · P2 | CSV escape เฉพาะ quote (`utils/export.ts:4–7,58`); synthetic text field ที่ขึ้นต้น `=1+1` ถูกส่งออกเป็น spreadsheet formula ที่ใช้งานได้. | การเปิด CSV ใน spreadsheet อาจตีความค่าข้อความเป็นสูตร. |
| STD-11 · P2 | Compose ส่ง build args แต่ไม่ส่ง flag foundation ที่ Dockerfile ตรวจ (`docker-compose.yaml:5` เทียบ Dockerfile guard); Compose build แบบไม่ส่ง source view ล้มที่ guard. | เส้นทาง build ผ่าน Compose สร้าง image ไม่ได้ตามการตั้งค่าที่คาด. |
| STD-12 · P2 | Dockerfile/CI ใช้ Node 25 ซึ่งสิ้นสุดการรองรับแล้ว ขณะที่ workflow อีกตัวใช้ Node 22; pin ต่างกัน. ตรวจวงจร release จาก [Node.js release schedule](https://nodejs.org/en/about/previous-releases). | build/runtime toolchain ไม่มี LTS baseline เดียว. |
| STD-13 · P2 | Vitest 3.2.7 และ `@vitest/mocker` อยู่ในช่วง affected ของ GHSA-82fw-gwwq-j7x9; fix `>=4.1.11` ตาม [คำแนะนำผู้ผลิต](https://github.com/vitest-dev/vitest/security/advisories/GHSA-82fw-gwwq-j7x9). `pnpm audit`: moderate 2 entries, 1 advisory; เป็น dev dependency. | ต้องอัปเกรดและทดสอบ compatibility; ผลตรวจนี้ไม่ยืนยัน production exploit. |
| STD-14 · P2 | sidebar ที่ซ่อนบน mobile เลื่อนพ้นจอด้วย CSS (`styles.css:431`) แต่ยังมี 9 controls ที่ focus ได้และ `inert=false` (`Sidebar.tsx:52`). Browser focus probe ยืนยัน. | keyboard/screen-reader focus เข้าเมนูที่มองไม่เห็นได้. |
| STD-15 · P2 | `currentCompleteness` ใน `DashboardPage.tsx:96–110` นับ period ที่มี target เป็น observed แม้ numerator/denominator/value ไม่มี. No-data screenshot จึงขึ้น completeness 12% ทั้งที่ banner เป็น coverage 0/1552 และไม่มีผลจริง. | ตัวเลข completeness สื่อว่ามีข้อมูลทั้งที่นับเพียง dictionary target. |
| STD-16 · P1 gate | Query guard เช็คคำขึ้นต้น SELECT และ blacklist บาง keyword (`queryRegistry.ts:1094`); assertion เป็นการตรวจข้อความ ไม่ใช่สิทธิ์ฐานข้อมูล และ SELECT สามารถเรียก side-effect/privileged function ได้. ไม่พบ arbitrary SQL input ใน UI ปัจจุบันและยังไม่ทดสอบสิทธิ์ BMS จริง. | ต้องถือ database read-only role, จำกัด function/endpoint และบังคับ allowlist ฝั่ง server; client string guard ใช้แทน privilege ไม่ได้. |
| STD-17 · P2 | `.dockerignore` ไม่มี `.env*` และ private agent artifacts; build context `COPY .` เข้าสู่ builder stage. ไม่พบ secret pattern ใน scan แต่ขอบเขต context กว้าง. | ลดโอกาสส่งไฟล์ local credential/artifact เข้า build daemon/cache. |
| STD-18 · P2 | workflow สร้าง fixture/source-view artifacts แต่ไม่ assert working tree clean หลัง generation. | output drift อาจผ่าน CI โดยไม่เห็นความต่างจากไฟล์ที่ commit. |
| STD-19 · P3 | production JS bundle 1,745,772 bytes (gzip 335,290); SQL registry/chart imports ถูกโหลดรวมตั้งแต่เริ่ม. ยังไม่ได้วัด latency บนอุปกรณ์จริง. | ควรแยก lazy route/query catalog ก่อนตั้ง performance budget. |
| STD-20 · P2 | README, source notes, roadmap และ implementation comments ให้สถานะปัจจุบันต่างกันเรื่อง 16/232 กับ registered 232/232, external staging และ production gate. Roadmap เดิมระบุว่ายังต้อง map 216 ทั้งที่ทุก code มี query branch. | ผู้ดูแลอาจเข้าใจ SQL registration ว่าคือการรับรองหรือมองไม่เห็น source-view gap. |
| STD-21 · P3 | `docs/THIP-SOURCE-NOTES.md` อ้าง PDF path คนละตำแหน่งบน Desktop และ schema workbook XLSX; audit รอบนี้อ้างอิง PDF ใน `Desktop/02_PDF` กับ schema JSON ที่ผู้ใช้ให้. ยังไม่ได้ยืนยันว่า workbook เดิมกับ JSON มีเนื้อหา/เวอร์ชันเดียวกัน. | เปิดตาม source note แล้วอาจอ่านหลักฐานคนละไฟล์กับที่ใช้ตรวจ. |

## Findings: Spec

| ID / ระดับ | ข้อค้นพบและหลักฐาน | ผลกระทบ |
|---|---|---|
| SPEC-01 · P1 | source view สร้าง `fact_events` จาก branches แต่ `facts` จำกัดไว้ `m.tier='registered'` และกรอง external code ออก (`thipSourceViewSql.ts:158–159,193–203`). บน PostgreSQL สังเคราะห์ seed external aggregate DE1601=95/100 แต่ผล view กลับ NULL ทั้ง numerator/denominator/value และไม่มี reason ทั้งที่ README บอก external fact จะถูกอ่าน. | external aggregates 55 codes ถูกทิ้ง; source-view behavior ขัดกับเอกสาร. |
| SPEC-02 · P1 | publication tier `getImplementationTier()` อิงชุด registered codes (`thipImplementation.ts:29`) ซึ่งตอนนี้มีครบ 232; source view ใช้ tier นี้ (`thipSourceViewSql.ts:35–43`); completeness ตรวจ contract แต่ไม่ตรวจ approved evidence (`bmsData.ts:1196`). `getRuleReadiness()` อยู่ใน manifest/test แต่อยู่คนละ gate. | SQL candidates/approximations อาจถูกจัด registered โดยไม่ผ่าน owner, local code set และผลรับรอง. 232 registered ไม่เท่ากับ 232 ready. |
| SPEC-03 · P1 | planner แบ่งช่วงเดือนใน query ที่ผลจริงเป็น quarter/semiannual (`thipFoundationPlan.ts:237–249`); base CTE anchor/group ตาม reporting period (`thipFamilyBase.ts:34,92`); merge เลือกผลช่วงแรก (`bmsData.ts:1185`). PostgreSQL synthetic run: full quarter SH0104=1/1/100%; แบ่ง Oct–Nov ได้ 0/1/0% และ Nov–Jan ไม่คืนแถว. | bisection ของเวลาอาจทิ้ง episode ที่อยู่คนละ subwindow หรือแทนผลจริงด้วยศูนย์. |
| SPEC-04 · P1 ก่อนใช้ | generated monthly/yearly query packs ไม่ได้พิสูจน์ว่าสูตรที่ดัดแปลงเป็น KPI รายเดือนที่รับรอง: HH0102 distinct รายเดือนแล้ว `SUM` ทำให้คนเดียวที่เข้า cohort เดือนเดียวถูกนับซ้ำใน YTD; SH0101 ยังใช้สูตรพนักงานลาออกรายปีในไฟล์รายเดือน และการรวม annual headcount ไม่ใช่สูตร turnover รายเดือน. ตัวอย่างไฟล์ `docs/thip-queries-monthly-2569/01-hosxp/THIP_HH0102.sql:296,457–458`, `THIP_SH0101.sql:296,385–386`. | Monthly/YTD result อาจผิด cohort หรือ denominator; ต้อง quarantine จนกว่าจะมีกฎสะสมรายรหัสพร้อม fixtures. |
| SPEC-05 · P1 ก่อนใช้ | สคริปต์แปลง target เดา field ใน `kpi_moph` จากชื่อ/regex และใช้ `MAX(COALESCE(result,mean,c,b,a))`; ไฟล์ HH0102 เป้าหมายอาจกลายเป็นผลจริง 50 แทน benchmark. ปี 2569/2026 มีการจับ 2025 จาก record ก่อนหน้า. ดู `tmp/thip_monthly_report.py:61–75`, generated HH0102:431–445. | target ที่ผิดทำให้สถานะและ dashboard ผิด; target hospital ต้อง NULL ถ้ายังไม่มี crosswalk field/year/unit/effective date ที่ยืนยัน. |
| SPEC-06 · P2 | quarterly target ใช้ค่าแรกของปีแทน target ตามงวด (ดู STD-06). DH0102 ตัวอย่าง target Q1=80%, Q2=95% แต่ annual status ได้ใช้ 80% ทั้งปี. | target change ถูกมองข้าม. |
| SPEC-07 · P2 | pending/unavailable reason หายจาก rows/coverage (ดู STD-09); test completeness ไม่บังคับ reason ต่อ code-period. | เจ้าหน้าที่แยก missing local source, zero cohort และยังไม่รับรองสูตรไม่ได้. |
| SPEC-08 · P2 | เส้นกลางของ SPC ถูกนับเป็นด้านเดียวกัน (ดู STD-07). | สัญญาณ SPC เตือนกรณีไม่มี shift จริง. |
| SPEC-09 · P2 | type ของ unit จำกัด percent/rate/ratio/count (`types/thip.ts:3–8`) และ formatter แสดง ratio คูณ 100; ไม่มี range rule แยกใน metadata (`format.ts:26`, `status.ts:16`). SH0201 เป็นจำนวนเดือนสำรองคลัง, CE0102 เป็นนาที, SH0204 เป็นชั่วโมง/คน แต่ชนิดหน่วยยังไม่แทนตัวเลขเหล่านี้. Benchmark 40 วันของ SM0201 ห้ามเทียบกับเดือนโดยอัตโนมัติ. | value, target และ status อาจเทียบคนละหน่วยหรือใช้ range threshold ไม่ครบ. |

## ข้อจำกัดของ rule ที่บันทึกไว้

- AA0101–AA0105: ตัวหารใน SQL ปัจจุบันนับ `COUNT(DISTINCT patient.hn)` ทั้งฐาน; นิยาม PDF ระบุ population ตามเขตรับผิดชอบ/อายุและ numerator cohort เฉพาะช่วงอายุ. คงไว้เป็นข้อจำกัดที่ต้องแก้ ไม่ตีความว่า SQL ตรงนิยาม.
- SM0201: ใช้ stock transaction ในเดือนเพื่อคำนวณ inventory turn; รายการที่ยังมี on-hand แต่ไม่มี transaction ในเดือนต้องใช้ month-end snapshot/carry-forward ที่นิยามชัด.
- Cardinality ของ joins, ความถูกต้องของ local code sets, เงื่อนไข encounter และสูตร clinical ไม่สามารถรับรองจาก schema inventory/fixtures ได้. Join predicates ทั้งหมดที่ไม่มี FK ถูกระบุเป็น candidate และต้องให้เจ้าของ HOSxP ตรวจด้วย cardinality query/aggregate reconciliation.
- ไฟล์ monthly/yearly ที่มีอยู่เป็นงานค้างก่อนเริ่มตรวจ เก็บไว้เหมือนเดิม แต่ให้ถือเป็น draft/unapproved. Manifest ของ original generated query pack คำนวณ hash จาก SQL ก่อน transform; การเทียบ hash ของ final file จึงตรวจยืนยันไม่ได้. Monthly/yearly pack hashes ตรง manifest และทั้ง 696 files parse ผ่าน; เรื่องนี้ยืนยันได้แค่ความสมบูรณ์เชิงรูปแบบ.
- generated source-view กับ `reporting/thip_kpi_monthly.sql` มีความต่าง 407 unified-diff lines (hash generated `61f7d03e9d8066eb49aaf50e73351e99345be2ac78828dc8cf51846d2a2c2cbc`; working file `0f3c6b2749d2094a90360617331d0316622034a2c06eca4a602d4ea0285839b2`). มีการเปลี่ยน integer division เป็น floating ratio ใน generated form; synthetic PostgreSQL ได้ 33.00 เทียบ 33.33. ต้องสร้าง/ตรวจ generated artifact แบบ deterministic ก่อนนำไป provision.
- generated DDL สร้าง `reporting.thip_kpi_monthly` แต่ต้องมี schema `reporting` อยู่ก่อน; synthetic run ต้อง provision schema เอง. เพิ่ม preflight/documented schema provisioning.

## Controls ที่ทำงานได้ในขอบเขตที่ตรวจ

- Session launcher query ถูก strip ก่อน query; credential อยู่ใน memory และ browser storage ใน mocked flow ว่าง; ไม่มี secret literal ตาม pattern scan.
- Query builder มีการ quote identifier/parameter values และ family SQL ส่ง aggregate projection; telemetry จำกัดข้อความ/metadata ไม่บันทึก SQL/token/raw rows.
- Contract ตรวจ unknown/duplicate codes, reporting cadence, field metadata, formula multiplier, numeric shape, percentile range และ zero denominator; no-data ไม่แปลงเป็น 0.
- Fixture checker ตรวจ 232 codes / 1,552 cadence cells และ negative fixtures 6 ชุด.
- Container serve health/page ได้ HTTP 200; CSP, Referrer-Policy, nosniff, no-store; Nginx ทำงานพอร์ต unprivileged; Compose ใช้ read-only rootfs, cap_drop และ no-new-privileges.
- UI มี empty/error labels, semantic controls, focus/skip-link และ reduced-motion rules ในส่วนที่ตรวจ.

## Browser และ build verification

| Check | ผล |
|---|---|
| `pnpm test` | ผ่าน 30 test files / 1,212 tests |
| `pnpm build` | ผ่าน |
| Fixture validator / source audit | ผ่าน 232 codes / 1,552 cells; audit fixture สังเคราะห์ทุกแถววัดค่าได้ |
| Playwright no-data dashboard | แสดง 232 rows; search ลดเหลือ 1 row |
| Mocked BMS | แสดง 232 rows; launcher credential หายจาก URL; local/session storage ไม่มีค่า |
| Catalog navigation / refresh | เข้าได้ แต่ refresh คืนหน้า overview (STD-05) |
| เปลี่ยนปีขณะ request ค้าง | FY ใหม่แสดง period เก่า 70 รายการ; export ยัง enabled และชื่อไฟล์เป็นปีใหม่ (STD-02) |
| Mobile sidebar | ซ่อนด้วยตำแหน่ง แต่ 9 buttons focusable และ sidebar ไม่ inert (STD-14) |
| Repository visual smoke | **ไม่ผ่าน** เพราะ assertion บรรทัด 99 ค้นหาข้อความเดิม “ตัวตั้ง ตัวหาร และสถานะของทุกงวดรายงาน”; ไม่ได้ยืนยันภาพ UI ครบทุก assertion |
| Docker image smoke | build ผ่านเมื่อให้ source view; negative build ไม่มี source view fail closed ตามที่ตั้งใจ. Access log canary พบ (STD-01) |

## Dependencies และความพร้อม

`pnpm audit` ปรึกษาคำแนะนำ GHSA ที่แนบด้านบนแล้ว. แหล่งเทคนิคและกฎของ dependency ให้ยึดเอกสารผู้ผลิต/official source; การทดสอบความหมาย KPI ต้องยึด PDF กับผล aggregate ที่เจ้าของข้อมูลโรงพยาบาลตรวจรับ. ไม่มีการสร้าง GitHub issue, ติดต่อระบบภายนอก หรือ deploy ในงานตรวจนี้.
