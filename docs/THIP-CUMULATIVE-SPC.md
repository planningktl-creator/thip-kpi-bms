# ผลสะสมและ Control chart — 2 ตุลาคม 2569

ตารางและหน้ารายละเอียดของ shared KPI มีมุมมอง **รายเดือน / งวด** และ **สะสมตั้งแต่ ต.ค.** (`result=cumulative` ใน URL; รองรับ refresh/back/forward). ผลสะสมแสดงในเดือนปลายช่วง ส่วนข้อมูลรายงวดเดิม ตัวตั้ง ตัวหาร และ cadence ยังอยู่ครบ. กดช่องในตารางแล้วเลือก **ดูทุกงวดของรหัส** เพื่อเปิดแนวโน้มและ **Control chart**.

## ผลสะสม

ใช้เฉพาะ accumulation ที่ลงทะเบียนใน rule ของชุดผลนั้น:

- `sum/count`: รวมค่าที่ additive ตามกฎ.
- `weighted-ratio`: Σ ตัวตั้ง / Σ ตัวหาร × scale; ไม่เฉลี่ยร้อยละรายเดือน.
- `fixed-denominator`: รวมตัวตั้งและใช้ตัวหารคงที่ครั้งเดียว; ตัวหารขาด/เปลี่ยน/ศูนย์ทำให้คำนวณไม่ได้.
- `snapshot`: ค่าล่าสุด ณ วันตัดยอด ไม่รวม snapshot หลายเดือน. งวดก่อนขาดไม่ขัดขวาง snapshot ปัจจุบัน.
- `distinct-cohort/custom`: ต้องมี source YTD ตามกฎ ไม่รวมจำนวนคน/ครั้งรายเดือนใน browser.
- `source-period-result`: ยังไม่มีสูตรสะสมที่ยืนยันสำหรับ THIP reporting ชุดนี้; แสดงเหตุผล ไม่ยืมสูตร monitoring โดยปริยาย.

THIP reporting ที่มี explicit monthly bridge ใช้กฎสะสมเดียวกับ bridge. Configured monitoring source ใช้ YTD ที่ผ่าน validator ก่อน หรือคำนวณจากงวดตามกฎเมื่อ source ยังไม่ส่ง YTD. Source YTD ที่ยืนยัน coverage สามารถครอบช่วงที่ไม่มี period rows ได้ตามสัญญาเดิม.

การรวมรายงวดต้องมีทุกงวดตั้งแต่ ต.ค. ถึงเดือนนั้นและไม่มี arithmetic discrepancy. หน่วย/version/lineage/ปี/series ต้องตรงกัน. Missing, future, expired, failed หรือผลที่ยังไม่ผ่าน approved gate ไม่เป็นศูนย์. Source-period quarterly/annual ไม่ถูกแบ่งหรือทำซ้ำเป็นเดือน.

`cumulativeBasis=period-facts` คือผลคำนวณเพื่อสอบทาน โดย `complete=false` เสมอ; การโหลดงวดครบไม่รับรอง clinical coverage ของต้นทาง. ไม่ใช้เวลาอ่าน query แทนวันตัดยอด. `cumulativeBasis=source` เก็บ `complete/through` จาก validated source. UI แสดงตัวตั้ง/ตัวหารสะสม วันตัดยอด และเหตุผล; ไม่ใช้เป้ารายงวดประเมินยอดสะสม.

CSV มีทั้งค่ารายงวดและ `ytd_value/numerator/denominator/complete` เพิ่ม `ytd_basis`, `ytd_reason`, `ytd_through_iso/be`. Review คงป้าย UNAPPROVED REVIEW; approved export ตรวจ approval ของทั้งค่าเดิมและ YTD.

## Control chart

กราฟใช้ **ค่ารายงวดที่ไม่ทับซ้อนกัน** แม้ผู้ใช้เลือกแสดงยอดสะสม. จุด YTD มีเดือนก่อนซ้ำอยู่ จึงไม่ใช้เป็น observations ของ Shewhart chart. YTD ธรรมดาไม่ใช่ CUSUM.

- `p-chart` สำหรับ percent/weighted-ratio ที่ตัวตั้ง–ตัวหารเป็นจำนวนเต็ม, 0 ≤ a ≤ b และ b > 0 ทุกงวดที่ใช้: CL = Σa / Σb × scale, ขอบ 3σ เปลี่ยนตาม b ของแต่ละงวดและอยู่ในช่วง 0–scale.
- หน่วย/โครงสร้างอื่นใช้ Individuals เพื่อสอบทาน: CL เป็นค่าเฉลี่ย, σ = MR̄/1.128; Moving Range ใช้เฉพาะคู่ของงวดที่ต่อเนื่องกัน. ไม่จับคู่ข้ามงวดที่ไม่มีข้อมูล.
- มีขอบควบคุมเมื่อมีอย่างน้อยสองค่าที่พร้อม; Individuals ต้องมีคู่ที่ต่อเนื่องกันอย่างน้อยหนึ่งคู่. ขอบเขตเป็นประมาณการจากปีที่เลือก ไม่ใช่ baseline ที่โรงพยาบาลรับรองหรือขอบเป้าหมาย.
- จุดที่ไม่มีข้อมูล, future, unapproved ใน approved mode, หรือ arithmetic discrepancy ไม่เข้าการคำนวณ. Mixed version/lineage/unit/series ไม่รวมเป็นฐานเดียวกัน.
- ตรวจจุดนอกขอบ 3σ และรัน 8 งวดติดกันข้างเดียวของ CL. งวดขาดตัดรัน; จุดที่ CL ตัดรัน. กราฟไม่เชื่อมข้ามงวดขาด และมีตารางค่าที่ใช้/ขอบเขต/สัญญาณให้อ่านได้.

สูตรอ้างอิง [NIST p-chart](https://www.itl.nist.gov/div898/handbook/pmc/section3/pmc332.htm) และ [NIST Individuals chart](https://www.itl.nist.gov/div898/handbook/pmc/section3/pmc322.htm). สมมติฐาน binomial/independence, distribution, cohort และความคงที่ของกระบวนการยังต้องให้เจ้าของ KPI สอบทานก่อนใช้ตัดสินผล. UI คงป้าย review/approved และระบุขอบเขตเบื้องต้น.

## ตรวจรับ

`pnpm test`, `pnpm build` และ `python scripts/kpi_analysis_browser_smoke.py` (ตั้ง `THIP_SMOKE_BASE_URL` เมื่อใช้ port อื่น). Browser test ใช้ registered-query aggregates สังเคราะห์และ deny real HTTPS: ตรวจ 1440/800/390/320px, อัตราสะสมถ่วงน้ำหนัก, งวดขาด, keyboard, details, SPC จากรายงวด, limits/signals, CSV, URL/history และไม่มี query เพิ่มจากการเปลี่ยนมุมมอง. ไม่มี SQL ใหม่, DB writes, PHI, hospital calls หรือ deployment.
