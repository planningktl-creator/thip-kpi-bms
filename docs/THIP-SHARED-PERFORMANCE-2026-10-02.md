# Shared KPI SPA — ผลตรวจรับ 2 ตุลาคม 2569

รุ่นนี้ใช้ `KpiDataStore` ที่ root เป็นเจ้าของ aggregate, queue และ cache ชุดเดียว ทุกหน้าอ่าน snapshot เดียวกัน การย้ายหน้าไม่เริ่ม query ใหม่ และผลแต่ละรหัสปรากฏก่อนจบคิว โหมดสอบทานเป็นค่าเริ่มต้น ส่วนโหมดรับรองแล้วใช้ publication gate เดิม

## วิธีวัด

วัด production build ที่เสิร์ฟ gzip ด้วย `pnpm perf:check` ห้ารอบต่ออุปกรณ์ รายงาน p75 จาก Chromium จำลอง เครือข่าย 1.6 Mbps / latency 100 ms; มือถือ viewport 390×844 และ CPU slowdown 4 เท่า ตารางคง 232 แถว / 2,784 ช่องใน DOM ทั้งหมด (ประมาณ 12,563 nodes) ใช้ synthetic aggregates และ mocked BMS ไม่มีคำขอฐานโรงพยาบาล

Cache benchmark เริ่มหลังตรวจ session และโหลด module พร้อม อ่าน aggregate 177 รหัสจาก IndexedDB การวัดนี้แยกจากเวลาโหลดคิวและเวลารอหนึ่งวินาทีระหว่าง query ผล interaction เป็น input-to-next-paint ในห้องทดสอบ ไม่ใช่ INP ของผู้ใช้จริง

## ผล p75

| รายการ | Desktop | มือถือจำลอง | เกณฑ์ | ผล |
|---|---:|---:|---|---|
| JavaScript ที่โหลดสำหรับหน้าแรก (gzip) | 153,062 bytes | 153,062 bytes | ≤200,000 bytes | ผ่าน |
| LCP | 1,708 ms | 1,652 ms | ≤2,000 / ≤2,500 ms | ผ่าน |
| Input-to-next-paint | 24 ms | 80 ms | ≤200 ms | ผ่าน |
| CLS | 0.0213 | 0.0591 | ≤0.1 | ผ่าน |
| คืน cache ครบ 177 รหัส | 167 ms | 800 ms | ≤1,000 / ≤2,000 ms | ผ่าน |
| หน้าและ controls พร้อมใช้งาน | 2,036 ms | 2,538 ms | ตัวเลขประกอบ ไม่ใช่ LCP gate | บันทึก |
| Blocking time | 33 ms | 468 ms | ตัวเลขประกอบ | บันทึก |

Baseline ก่อนแผน performance ที่บันทึกไว้คือ JavaScript ประมาณ 490 KB gzip และ LCP มือถือประมาณ 4.7 วินาที จากสองรอบทดสอบ ผลล่าสุดลด payload เหลือประมาณ 153 KB และผ่านเกณฑ์ LCP แต่ baseline ใช้จำนวนรอบต่างกัน จึงไม่ถือเป็นการทดลองเปรียบเทียบภายใต้ protocol เดียวกัน ผลแต่ละรอบล่าสุดอยู่ใน `tmp/performance/result.json` และ CI upload เป็น artifact

## สิ่งที่เปลี่ยน

- Dynamic modules สำหรับ SQL registry, queue, validation, approved charts และหลักฐานรายละเอียดยังโหลดเมื่อจำเป็น หน้าแรกใช้ metadata ขนาดเล็ก พร้อม 101 monthly bridges และ 232 reporting definitions ที่ตรวจ generated drift
- Owner อยู่เหนือ routes; approved reporting dashboard/detail เดิมรับ projection จาก owner โดยไม่มี loader แยก การเปลี่ยน FY/session ล้างผลก่อนเริ่ม context ใหม่และ abort งานเก่า
- Rows/cells ใช้ stable references และ memoization, filters ซ่อนแถวเดิม, deferred search ป้องกัน export ระหว่าง filter ยังไม่ตรง และรายละเอียดสร้างเมื่อเปิด
- Cache restore ใช้ bulk transaction เดิม Native envelope v2 ยังคงเข้ากันได้ ส่วน reporting/monitoring source projection ใช้ envelope v3 แยก namespace; fingerprint ผูก SQL/parameters และ canonical rule รวม cohort
- Session-expiry และ Retry-After เป็น lock ของ context การล้าง cache หรือเปลี่ยนปีไม่เปิดทางให้เรียก query ต่อโดยข้ามข้อกำหนด
- Global load bar และ session controls ใช้ได้ทุกหน้า คง navy/teal และฟอนต์เดิม ปุ่มมือถือมีพื้นที่สัมผัสอย่างน้อย 44 px ตารางเลื่อนแนวนอนพร้อม sticky identity และ keyboard/dialog focus restoration

## ตรวจรับ correctness และ security

| ชุดตรวจ | ผล |
|---|---|
| Unit/integration | 1,313 tests ผ่านใน 40 files |
| Build และ generated artifacts | TypeScript/Vite/precompress ผ่าน; runtime/sourceview/step/cohort checks ผ่าน |
| Cadence และ approval | 232 codes, 1,552 THIP applicable cells, 2,784 monitoring cells; native candidates ยังไม่เพิ่ม approved coverage |
| Mocked browser | Desktop/mobile shared routes, source views, cache, filters/CSV, keyboard/dialog, FY/session changes, legacy approved charts, development preview, step/error/profile/cache regressions ผ่าน |
| Production release isolation | Synthetic fixture rows ไม่อยู่ใน production bundle และ production ปฏิเสธ preview flag |
| Local PostgreSQL | Synthetic cohort checks และ aggregate equivalence/EXPLAIN สำหรับ DH0101, DH0112, CE0102, HH0102, HE0101, SH0101 ผ่าน |
| Nginx/security | HTML no-store, immutable hashed assets, precompressed gzip และ credential-canary log checks ผ่าน |

ตรวจภาพ desktop/mobile และ Impeccable detector โดยคง fonts/accent ของระบบเดิมตาม brief ไม่มีการเปิดฐานจริงเพื่อรับรองสูตร ผล review/CSV ระบุยังไม่รับรองและแยก source value จาก arithmetic comparison ค่าที่ขาดไม่ถูกเติมศูนย์ ISO ใช้ภายใน/คอลัมน์เครื่อง ส่วนวันที่แสดงใช้ พ.ศ. และ Bangkok

## ข้อจำกัดและงานถัดไป

Performance นี้เป็นผลในเครื่องจำลอง ต้องติดตามบนคอมโรงพยาบาลและมือถือจริงต่อไป SQL latency/index ของฐานโรงพยาบาลยังไม่ได้วัด คิว native ที่ไม่พบ cache ยังคง 177 คำขอและช่วงเว้นรวมอย่างน้อย 176 วินาที; การผ่าน performance gate ไม่ได้แปลว่าสูตรผ่านรับรอง เจ้าของ KPI ต้องยืนยัน cohort, event date, target, cardinality และ rule version ก่อนเปิด publication

รอบนี้ไม่เรียก BMS/HOSxP จริง ไม่แก้ข้อมูล ไม่เปิด Issues และไม่มีการ deploy โดยตรง การ commit/push เป็นงานที่ผู้ใช้สั่งแยกไว้
