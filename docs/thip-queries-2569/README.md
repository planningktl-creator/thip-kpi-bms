# ชุด query รายตัวชี้วัด - THIP KPI 2025 (รพ.กันทรลักษ์ 10929)

232 ไฟล์ - 1 ไฟล์ต่อ 1 ตัวชี้วัด - สร้าง 25 ก.ย. 2569 เวลา 11:19 น. จาก commit `19306cd`

## โครงสร้าง

- `01-hosxp/` - 177 รหัสที่อ่านจาก HOSxP ได้โดยตรง
- `02-external/` - 55 รหัสที่ต้องโหลดข้อมูลเข้า `reporting.thip_external_facts`
- `03-shared/` - 29 ไฟล์: ชุดรวมทั้งชุด, ชุดกลุ่มงาน 18 กลุ่ม, ตัวช่วยระบบ, ตัวตรวจ source view, ตาราง staging และภาคผนวก 232 รหัส
- `INDEX.md` - ดัชนีทั้งหมด (มีลิงก์ไปทุกไฟล์) - `INDEX.csv` - ดัชนีสำหรับ Excel (UTF-8 BOM)

## วิธีรันหนึ่งไฟล์

ทุกไฟล์กำหนดปีงบประมาณให้แล้ว **แก้ที่เดียว**: เปลี่ยนเลขในบรรทัด
`FROM (VALUES (2569)) AS v(fiscal_year)` เป็นปี พ.ศ. ที่ต้องการ แล้ววันที่เริ่ม/สิ้นสุด
ของปีงบจะคำนวณให้เอง (`thip_params`) ไม่ต้องแก้ `:start_date`/`:end_date` เอง

```sql
-- ปีงบประมาณ 2569 (ต.ค. 2568 - ก.ย. 2569)  <-- ค่าที่ฝังไว้
--   thip_params.fy_start = 2025-10-01
--   thip_params.fy_end   = 2026-10-01  (exclusive; วันสุดท้ายที่รวม = 2026-09-30)
```

รันได้เลยด้วย psql (ไฟล์แทนปีงบให้แล้ว):

```bash
psql -f 01-hosxp/THIP_AA0101.sql
```

เปลี่ยนปีงบ: แก้ `(2569)` เป็น `(2570)` ในไฟล์นั้น แล้วรันใหม่

`03-shared/20_source_view_*.sql` (ตัวตรวจ source view) ใช้ `fiscal_year` จาก
`thip_params` เช่นกัน จึงแก้ปีที่จุดเดียวเหมือนกัน

## ชื่อไฟล์

ไฟล์ query รายตัวชี้วัดทุกไฟล์ขึ้นต้นด้วย `THIP_` เช่น `01-hosxp/THIP_AA0101.sql` - เพื่อให้เห็นชัดในรายการไฟล์ว่าคือชุด THIP KPI

## ข้อควรรู้

0. ทุกคำสั่งคืนคอลัมน์ชื่อตัวชี้วัดมาด้วย: `indicator_code, indicator_name_th, indicator_name_en, period_start, fiscal_month, fiscal_year, numerator, denominator, value` - ชื่อถูกฝังอยู่ในตารางงวดรายงาน (expected grid) ของคำสั่งเอง จึงใช้ได้ทันทีโดยไม่ต้อง join ตารางพจนานุกรม

0. ไฟล์ทุกไฟล์ในโฟลเดอร์นี้ **ปลอดอักขระที่ Windows-874 (cp874) ไม่รองรับ** แล้ว ใช้ได้ทั้ง session ที่ `client_encoding` เป็น `UTF8` และ `WIN874`
   - สาเหตุ: อักขระ `-` `#` `>=` `<=` ไม่มีใน cp874 ทำให้ psql ไทยบน Windows ล้มด้วยข้อความ
     `character with byte sequence 0xc2 0xb7 in encoding "UTF8" has no equivalent in encoding "WIN874"`
   - ไฟล์ถูกแทนด้วยอักขระที่ cp874 มี: `-`->`-`, `#`->`#`, `>=`->`>=`, `<=`->`<=` (ความหมายคงเดิม)
   - ถ้ามีไฟล์อื่นที่ต้องใช้กับ session WIN874: `python tmp/sanitize_sql_win874.py --check|--out|--in-place <file>`
1. ทุกไฟล์เป็น read-only (SELECT/WITH) และคืนค่าแบบ aggregate เท่านั้น ไม่มีข้อมูลผู้ป่วยรายบุคคล
2. BMS API มีเพดานเวลาต่อคำขอประมาณ 10 วินาที -> ยิงรายตัวได้สะดวก; ชุดรวมใน `03-shared/` ต้องแบ่งชุดละ 4 รหัส
3. 4 รหัสที่ใช้เวลาชนเพดานและควรยิงเดี่ยว: HC0101, HC0102, HH0104.3, HH0104.4
4. `02-external/` รันไม่ได้จนกว่าจะโหลด staging (`03-shared/01_staging_DDL_external_facts.sql`)
5. ตัวกรองรหัส ICD ที่มีข้อบกพร่อง (DR0201, DC0401, DC0403) และรายการที่ควรยืนยัน (CM0104, CM0105, CM0118, CM0119) อยู่ใน `../THIP-COVERAGE-AUDIT-2569.md`
6. หัวไฟล์ทุกไฟล์อ้างเลขบรรทัดใน `../THIP-ALL-QUERIES-2569.sql` เพื่อเทียบกับชุดรวม

## สร้างใหม่

```bash
# 1) ไฟล์ต้นทางจากซอร์สเรพโอ (รัน vitest ฝั่ง Windows เพราะ native module ของ WSL คนละตัว)
cmd.exe /c "cd /d C:\Users\KTLho\Documents\THIP-KPI-BMS && node scripts\build-thip-source-view.mjs"
cmd.exe /c "cd /d C:\Users\KTLho\Documents\THIP-KPI-BMS && node_modules\.bin\vitest.cmd run tmp/dump_all_queries.test.ts --reporter=basic"
# 2) สร้างไฟล์รายตัว + ตรวจสอบ
/home/ktlhos/.venv/bin/python tmp/build_per_query_files.py
/home/ktlhos/.venv/bin/python tmp/verify_per_query_files.py
```

