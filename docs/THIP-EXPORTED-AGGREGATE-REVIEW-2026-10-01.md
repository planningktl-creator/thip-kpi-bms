# ผลตรวจ Excel aggregate FY2569 และผลต่อแผนเชื่อม BMS

ตรวจเมื่อ: 1 ตุลาคม 2569 · อ่านไฟล์เดิมโดยไม่แก้ไข · ไม่เรียก BMS/HOSxP สด

## หลักฐาน

ไฟล์: `C:/Users/KTLho/Desktop/THIP-ALL-QUERIES-2569-FY2569.xlsx`

SHA-256: `174d5782da109caa667ea24c9b84aec8a82660cc36684c9567ba542011ffb3c3`

มี worksheet เดียว ชื่อ `THIP-ALL-QUERIES-2569-FY2569` มี header และข้อมูล 1,353 แถว คอลัมน์ 7 ช่อง: `indicator_code`, `period_start`, `fiscal_month`, `fiscal_year`, `numerator`, `denominator`, `value`. ไม่มี Excel formulas หรือ Excel error cells; ค่าที่ตรวจเป็นค่าบันทึกใน workbook ไม่ใช่ค่าที่ผู้ตรวจคำนวณแทนต้นฉบับ

ไฟล์นี้เป็นหลักฐานว่ามีผล aggregate ส่งออกมาได้แล้ว แต่ไม่มี query revision, export tool, source timestamp หรือ approval evidence จึงยังไม่ยืนยันว่า deployment ปัจจุบันอ่าน BMS สำเร็จ หรือทุกสูตรตรงรายงานโรงพยาบาล

ผู้ใช้ระบุ SQL ที่ใช้ภายหลัง: `C:/Users/KTLho/Documents/Navicat/PostgreSQL/Servers/test/ktlhos/public/THIP-ALL-QUERIES-2569-FY2569.sql`. อ่านไฟล์นี้เพิ่มเติมแล้วมี 4,856,872 bytes / 97,373 lines; SHA-256 `232a42d98768210d4857d55f15087294a19871005a84859a319604fe473180fa`. Header อ้าง commit `ba8dae2` และแยก HOSxP 177 codes/external 55 codes ซึ่งตรงกับ workbook. เป็น lineage ที่ผู้ใช้ให้ ไม่ได้ replay SQL เพื่อยืนยันผล และ workbook ยังไม่ระบุ source timestamps/approval

## โครงสร้างและ coverage

| รายการ | ผลตรวจ |
|---|---:|
| KPI ที่มีแถว | 177 / 232 รหัส |
| Reporting cells ที่มีแถว | 1,353 / 1,552 |
| Reporting cells ที่ขาด | 199 |
| มีค่า `value` | 867 แถว ใน 114 รหัส |
| `value = NULL` | 486 แถว |
| `numerator = denominator = 0` | 486 แถวเดียวกับ NULL value |
| ค่าเป็นศูนย์โดย denominator > 0 | 471 แถว |
| denominator = 0 แต่ value ไม่ NULL | 0 |
| Duplicate code × FY × month | 0 |
| Unexpected code/period เทียบ catalogue/cadence | 0 |
| วันที่ไม่ตรง anchor FY/month | 0 |
| Negative หรือ nonnumeric facts | 0 |

FY ทุกแถวเป็น ค.ศ.2026 = พ.ศ.2569; fiscal month 1–12 ตรง ต.ค.2025–ก.ย.2026. วันที่ 1 ตุลาคม 2569 เป็นจุดเริ่ม FY2570/2027 แล้ว ดังนั้นการเปิดผลไฟล์นี้ต้องเลือก FY2569 ไม่ผสมกับผลปีปัจจุบัน

รูปแบบแถวสอดคล้อง reporting cadence เดิม ไม่ใช่ monthly monitoring 232×12:

| Cadence | รหัสที่มี | แถวที่มี | รหัสที่ขาด | แถวที่ขาด |
|---|---:|---:|---:|---:|
| monthly | 101 | 1,212 | 11 | 132 |
| quarterly | 14 | 56 | 5 | 20 |
| semiannual | 23 | 46 | 8 | 16 |
| annual | 39 | 39 | 31 | 31 |
| รวม | 177 | 1,353 | 55 | 199 |

เทียบ `src/monitoring/evidence.json` แล้ว **55 รหัสที่ขาดตรงกับ `requires-external-aggregate` ทั้งชุด** ไม่มีรหัส native เพิ่มเติมที่หายจาก expected cadence. DE1601 เป็นหนึ่งในชุดที่ขาด. 177 รหัสที่มีประกอบด้วย native monthly candidates 101 รหัส, รหัสที่ต้องกำหนด monitoring rule เพิ่ม 71 รหัส และ external population denominator candidates 5 รหัส

Coverage ข้างต้นเป็น coverage ของแถว/value ในไฟล์ ไม่ใช่ approved coverage หรือหลักฐานว่าวัดตามนิยามครบ. Adapter ต้องเติม 199 official cells ที่ขาดด้วย NULL และเหตุผล source ที่ยังไม่อยู่ในไฟล์; ไม่เติมศูนย์และไม่อ้างว่าข้อมูลจริงครบ 1,552 cells

## ข้อค้นพบเรื่องค่า

### ค่า 58 แถวใน 12 รหัสมีทศนิยมถูกตัด

เทียบค่า `numerator / denominator × formulaScale` จาก `src/data/thipKpiRules.ts` กับ `value` ในไฟล์ เฉพาะ denominator > 0:

- 809 แถวสอดคล้องค่าอัตราภายใน tolerance 0.0051 สำหรับค่าที่แสดงสองตำแหน่ง.
- 58 แถวต่างเกิน tolerance และทุกแถวเท่ากับอัตราที่ตัดส่วนทศนิยมออก ไม่ใช่การปัดเศษใกล้สุด.
- กระจายใน CA0103 (12), CA0105 (1), CE0104 (1), CO0105 (1), DE1401 (5), DE1402 (4), DH0106 (1), DH0402 (1), DN0102 (10), DN0103 (9), DN0104 (3), DN0105 (10).
- มี 3 แถวที่ numerator > 0 แต่ value เป็น 0 จึงต้องระวังการตีความค่าศูนย์จาก `value` อย่างเดียว.

ตัวอย่าง CA0103 เดือนแรก: facts 337/502 ให้ 67.131… แต่ source value เป็น 67. ใน candidate SQL ปัจจุบัน `docs/thip-queries-2569/01-hosxp/THIP_CA0103.sql` พบ `COUNT(...) * 100 / NULLIF(COUNT(...), 0)` ก่อน `ROUND(..., 2)`. PostgreSQL หารจำนวนเต็มก่อน จึงสูญเสียทศนิยมแม้ ROUND สองตำแหน่งภายหลัง. ต้องใช้ numeric operand เช่น `100.0` หรือ cast ก่อนหาร และตรวจทุก rate branch/generated artifact ที่เกี่ยวข้อง

SQL ที่ผู้ใช้ระบุมี CA0103 branch ที่บรรทัด 859 และ integer division ที่บรรทัด 914; query แยกรหัสมีรูปแบบเดียวกันที่บรรทัด 11,953. จึงยืนยัน source arithmetic problem ใน SQL ที่ใช้ได้ ไม่ใช่เพียงรูปแบบแสดงผล Excel. ค้นทั้งไฟล์พบ pattern `* 100 /` 138 ตำแหน่ง ซึ่งรวม query ซ้ำหลายชุด ไม่ใช่ 138 รหัสที่ผิด. ต้องตรวจ operand types ราย branch ไม่แก้ด้วย global replacement โดยไม่ทดสอบ. ไม่แก้ค่าในไฟล์เดิมโดยเงียบ; หน้าตรวจสอบควรแสดง source value และ recomputed candidate value แยก พร้อม discrepancy reason; ห้ามใช้ความตรงของ arithmetic เป็นการรับรอง clinical cohort

### 486 แถว 0/0 ยังจำแนก zero-cohort ไม่ได้จากไฟล์นี้

ไฟล์ไม่มี source status หรือ missing reason. Generated query ปัจจุบันมี `LEFT JOIN facts` แล้ว `COALESCE(facts.numerator, 0)` / `COALESCE(facts.denominator, 0)` ดังนั้นไม่พบ facts กับพบ cohort ว่างจริงอาจออกมาเหมือนกัน. ต้องเก็บ `fact_present`, dependency/schema/query outcome และ data-through จาก provider เพื่อแยก missing source, query failure และ zero cohort. ไม่จัดทุกแถว 0/0 เป็น `zero-cohort` โดยอัตโนมัติ

CE0102 และ SM0201 มี 12 แถวแต่ value เป็น NULL ทั้งชุด; SH0101 มี annual row เดียวและ NULL. DH0101/DH0112 มี 12 แถวและ value 11 แถว; HH0102 มีเพียงสอง half-year rows ตามนิยามเดิม. สิ่งเหล่านี้ไม่ใช่เหตุให้นำค่า annual/half-year ไปซ้ำทุกเดือน

### มีค่า population candidate แต่ยังไม่ใช่ population ที่ยืนยัน

AA0101–AA0105 มี denominator เท่ากันในไฟล์. Candidate SQL AA0101 ปัจจุบันใช้ `COUNT(DISTINCT p.hn)` จากตาราง `patient`, และเอกสารข้าง query ระบุข้อจำกัดว่าไม่ใช่ mid-year catchment population ตาม THIP. มีตัวเลขจึงไม่ได้ปิดงาน external population denominator 5 รหัส ต้องยืนยัน source ประชากร/พื้นที่/อายุ/ช่วงเวลาและ owner ก่อนเปิดผลทางการ

## ผลต่อแผนพัฒนา

1. เพิ่ม adapter สำหรับ **seven-column aggregate** ในหน้าตรวจสอบ โดยรับ facts จาก registered BMS queries และใช้ workbook เป็นหลักฐานสอบทาน ไม่บังคับให้ผลเริ่มต้นมี metadata ครบ normalized source-view contract และไม่ลด strict contract ของผลเผยแพร่.
2. เติมชื่อ/หน่วย/cadence/formula จาก catalogue และ candidate registry ที่ตรง revision. ข้อมูลที่ไม่มีในไฟล์ เช่น target/source freshness/approval/effectivity ต้องเป็น NULL หรือ explicit unknown; ไม่เดาจากเวลาโหลดไฟล์. เก็บ `observedAt` แยกจาก source `refreshedAt`.
3. แยกการตรวจ arithmetic: numeric division, source vs derived value, rounding policy; synthetic regression case 1/130×100 ต้องไม่เป็น 0. ตรวจ generated drift ของ queries ทั้ง cadence/monthly/yearly หลังแก้ source.
4. เก็บเหตุผลขาด external 55 รหัส/199 official cells และ provenance ของ 0/0. สร้าง expected grid หลังตรวจ input แล้ว; query ไม่ได้ผลต้องไม่แปลงเป็น zero cohort.
5. ใช้ native monthly 101 รหัสเป็น candidate scope; มีแถวรายเดือน 1,212 แถว แต่ค่าไม่ NULL 799 แถว และ 413 แถว 0/0. ตัวเลขนี้ไม่ใช่ approval และไม่รับประกัน source readiness ของทุก code.
6. อีก 71 รหัสใน workbook มี 136 reporting cells ตาม cadence เดิม ไม่ใช่ 852 monthly observations. ยังต้องสร้าง rule ใหม่สำหรับ monitoring; อีก 55 external รหัสต้องรอ source; 5 population รหัสต้องรอ denominator ที่ยืนยัน.
7. คงผล THIP 1,552 cells กับ monitoring 2,784 cells แยกกัน และเพิ่มหน้าตรวจสอบก่อนรับรองตามที่ผู้ใช้ยืนยัน. ห้ามนำ workbook นี้เข้า production fixture หรือเปลี่ยน approval เป็น synthetic/approved เพื่อให้หน้าแสดงค่า.
8. SQL รวมของ Navicat มี DDL, sample external INSERT และ DELETE/INSERT refresh อยู่ด้วย: เช่น CREATE ที่บรรทัด 71,473, sample INSERT ที่ 71,490 และ DELETE refresh ที่ 85,896. ต้องแยก SELECT queries ที่ลงทะเบียนออกจาก provisioning/sample/refresh; ไม่ส่ง SQL ทั้งไฟล์เข้า BMS API และไม่รันกับ HOSxP จาก frontend. Sample rows ต้องไม่ถูกใช้เป็นผลจริง. อ่านหลักฐานนี้เท่านั้น ไม่ได้รันคำสั่งใด.

## เกณฑ์ตรวจรับเพิ่มเติม

- Seven-column response ที่ schema/FY/key ถูกต้องแสดงใน candidate view ได้ แม้ไม่มี target/view configuration; ไม่เข้า published series โดยอัตโนมัติ.
- แสดง row coverage, non-NULL value coverage และ approved coverage แยกกัน; ไฟล์ชุดนี้ให้ expected missing 55 codes / 199 cadence cells โดยไม่มี duplicate/unexpected cells.
- Missing rows กับ 0/0 rows มีเหตุผลต่างกันตาม evidence; หากไฟล์ไม่ให้ evidence ให้แสดง unknown/source not confirmed.
- Regression tests ของอัตราใช้ numeric arithmetic ก่อน ROUND และแยก source discrepancy; ทดสอบค่าต่ำกว่า 1% และ zero denominator.
- FY2569 เข้าเดือน ต.ค.2025–ก.ย.2026; เลือก FY2570 แล้วไม่แสดง/export snapshot นี้.
- Clinical/data owner ยืนยัน query revision, schema/cohort/date, population denominator และผล aggregate กับรายงานทางการก่อนเพิ่ม approval.

ผู้ใช้ระบุ SQL ใน Navicat แล้วและตรวจ source arithmetic/ขอบเขต SELECT เพิ่มเติมตามด้านบน. รอบนี้ไม่แก้ runtime, SQL หรือ Excel; เอกสารบันทึกเฉพาะสรุป ไม่คัดลอก raw exported rows เข้า repository
