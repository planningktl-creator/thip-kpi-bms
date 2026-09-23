# THIP-KPI-BMS กับ IPTImprove: ทำไมตัวหนึ่ง "มีข้อมูล" และอีกตัว "ไม่มี"

บันทึกจากการอ่าน `C:\Users\KTLho\Documents\IPTImprove` แบบ read-only (ไม่แก้ไขไฟล์ในโปรเจ็คตัวอย่าง)
เพื่อตอบคำถามว่า IPTImprove query ข้อมูลมาได้อย่างไร ทั้งที่ THIP-KPI-BMS แสดงผลว่าง

## ข้อสรุปหลัก

**IPTImprove ไม่ได้อ่านผล THIP ได้สำเร็จ** — มันอ่านตาราง `thip_kpi_monthly` ตัวเดียวกับเรา
และตารางนั้นยังไม่มีอยู่จริงบนฐานข้อมูลทั้งสองโปรเจ็ค สิ่งที่ IPTImprove ทำได้จริงคือ
**อ่านตาราง HOSxP ตรง ๆ แบบแบ่งหน้า** (`ipt`, `iptdiag`, `opitemrece`, `an_stat`, `iptbedmove`, `iptoprt`)
ซึ่งเป็นเส้นทางที่ THIP-KPI-BMS ไม่มีในเวอร์ชันแรก เพราะถูกออกแบบให้รอ normalized source view

## หลักฐาน

| ประเด็น | IPTImprove | THIP-KPI-BMS |
| --- | --- | --- |
| query ผล THIP | `thipMonthlyResults` → `FROM thip_kpi_monthly` ([cmiApi.ts:474-487](../src/services/queryRegistry.ts)) | `buildSourceViewQuery` → `"thip_kpi_monthly"` |
| อ่าน HOSxP ตรง | **มี** — 6 ตาราง IPD ผ่าน registered queries | ไม่มีในเวอร์ชันแรก (เพิ่มภายหลังด้วย `VITE_BMS_KPI_LIVE_FOUNDATION`) |
| การจำกัดขนาดผลลัพธ์ | `LIMIT (:page_limit + 1)` + cursor pagination | ไม่มีตอนแรก → statement 479 KB ถูกปฏิเสธ |
| timeout ที่ยอมรับ | `REQUEST_TIMEOUT_MS = 20_000` | เพดานจริงของ endpoint ~10 วิ |
| app identifier | `'DRG.Optimizer.React'` (ค่าคงที่ในโค้ด) | `VITE_BMS_APP_IDENTIFIER` (build arg; ว่างบน deployment เดิม) |
| หน้าจอเมื่อ source view ว่าง | `ยังไม่มีข้อมูลใน source view` | ข้อความ fail-closed เรื่อง `VITE_BMS_KPI_SOURCE_VIEW` |

หลักฐานจากเอกสารวิจัยของโปรเจ็คข้างเคียง (`Documents\HDC App\docs\RESEARCH-HDC-THIP-OBSIDIAN.md:240`)
ระบุตรงกันว่า **"ไม่มี live KPI result source ที่ยืนยันได้"** — repository มีเพียง demo/definition
และ registered query foundation แต่ยังไม่มี hospital source view ที่ส่ง normalized `thip_kpi_monthly`

ดังนั้นตัวเลขที่เห็นบนหน้า `/thip` ของ IPTImprove มาจากสองแหล่งที่ **ไม่ใช่ผล THIP**:

1. `THIP_DICTIONARY_INDICATOR_COUNT = 232` และ `THIP_CROSSWALK` (21 รายการ) — ค่าคงที่ในโค้ด
2. `availableIndicators` — นับจากแถวที่ `thip_kpi_monthly` ส่งกลับ ซึ่งเมื่อตารางไม่มี จะเป็น `—`

ตัวเลขที่ "มีข้อมูล" จริงจึงเป็นของหน้า worklist/DRG ซึ่งอ่านทะเบียน IPD จาก HOSxP โดยตรง

## บทเรียนที่นำมาใช้

1. **เพดานของ BMS API เป็นเวลา ไม่ใช่ขนาด** — IPTImprove ตั้ง timeout 20 วิ และจำกัดผลลัพธ์ด้วย
   `LIMIT` เสมอ จึงไม่เจออาการปฏิเสธที่ THIP-KPI-BMS เจอเมื่อส่ง statement ขนาด 479 KB
2. **อ่าน HOSxP ตรงได้ ถ้า query ถูกจำกัดขอบเขต** — ไม่จำเป็นต้องรอ DBA สร้าง view ก่อน
   (`VITE_BMS_KPI_LIVE_FOUNDATION=true` ทำให้ THIP-KPI-BMS ใช้เส้นทางนี้)
3. **registry เป็น allow-list ปิด** — ทั้งสองโปรเจ็คปฏิเสธ SQL ที่ไม่อยู่ในทะเบียน
4. **ห้ามแสดงค่า demo แทนผลจริง** — ทั้งสองโปรเจ็คแสดงสถานะ "ไม่มีข้อมูล" พร้อมเหตุผล ไม่ประดิษฐ์ตัวเลข

## ข้อจำกัดที่ยังเหลือ

- แม้ตั้ง `VITE_BMS_KPI_LIVE_FOUNDATION=true` แล้ว แอปยังต้องยิงหลาย request
  (ครั้งละ ~0.9-6 วิ เพราะเพดาน 10 วิ) ⇒ ทางที่เร็วกว่าคือ provision `reporting.thip_kpi_monthly`
- 4 ตัวชี้วัด annual (`HC0101`, `HC0102`, `HH0104.3`, `HH0104.4`) ยังเกินเพดานแม้ยิงเดี่ยว
- 55 ตัวชี้วัดที่ต้องโหลดจากภายนอกยังต้องมี `reporting.thip_external_facts`
