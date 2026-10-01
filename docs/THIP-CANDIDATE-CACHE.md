# Candidate aggregate cache — 1 ตุลาคม 2569

หน้าตรวจข้อมูลทีละ KPI เก็บผลสำเร็จใน IndexedDB `thip-candidate-cache`, store `entries`, schema version 2. ไม่ใช่ server cache และไม่โหลดข้อมูลเบื้องหลัง. การปิด browser/refresh ยังต้องรับ launcher capability หรือกรอก session ใหม่; ตรวจ PasteJSON และ PostgreSQL ก่อนอ่าน cache ทุกครั้ง

## Context และอายุผล

- Scope เป็น SHA-256 ของ verified endpoint/hospital/app/bearer/marketplace capability; เก็บเพียง digest ไม่เก็บค่าต้นฉบับหรือข้อมูล runtime. หาก capability เปลี่ยน ถือเป็น context ใหม่แม้เป็นโรงพยาบาลเดิม
- Key แยก scope/FY/series `thip-report`/KPI/query fingerprint. Build สร้าง SHA-256 ของ SQL เต็มและ rule พร้อม cohort evidence ใน runtime manifest; browser hash เฉพาะ digest สองชุด, observation window และหน่วยแสดงผล. เปลี่ยน query/rule แล้วไม่ใช้ผลเก่า โดยไม่ต้องสร้าง SQL 177 ชุดก่อนเริ่มคิว
- รายการเก็บ code/FY, version/fingerprint, observedAt, expiresAt และ sanitized seven-column facts พร้อม optional fact-presence flag. ไม่มี raw HTTP response, error message, credentials หรือ patient rows. derived value/reason/approval ถูกสร้างใหม่โดย candidate validator ก่อนใช้
- อายุไม่เกิน 24 ชั่วโมงจาก observedAt. ปีปัจจุบันหมดอายุไม่เกินต้นเดือนถัดไปตาม Asia/Bangkok รวมขอบเขตปี เพื่อให้ future-month status ไม่ค้าง. Prune รายการหมดอายุตอนเปิด context และตรวจ expiry อีกครั้งก่อนคืนผลให้คิว
- ไม่มีการเลื่อน expiry เมื่ออ่าน cache. เวลาอ่าน query ไม่ใช่ source refresh/data-through; freshness ยังคง NULL และ approval เป็น unapproved

## Interfaces และคิว

`CacheRepository` มี `read(key)`, `readMany(keys)`, `write(entry, signal)`, `clear(scope?, fiscalYear?, namespace?)`, `prune(now)`. `readMany` อ่าน ordered keys ใน transaction เดียว; legacy adapters ที่ไม่มี method นี้ยังใช้ `read` ได้. Context index แยก scope/FY และ expiry index ใช้ prune เมื่อเปิด repository (เว้น prune ซ้ำไม่เกินหนึ่งนาที); clear namespace ตรวจ primary key ของรายการ. Upgrade จาก v1 ล้างรายการที่พิสูจน์ fingerprint ใหม่ไม่ได้แล้วโหลดผ่านคิวเดิม

Implementations คือ IndexedDB และ memory; resilient wrapper เปลี่ยนเป็น memory เมื่อเปิด/เขียน storage ไม่ได้ และแจ้งผู้ใช้โดยไม่หยุดโหลด. การเปิด/transaction มี budget 3 วินาที ไม่รอ blocked storage ไม่สิ้นสุด

`StepCachePort.read(signal)` คืน validated successes เพื่อ hydrate ก่อนยิง query แรก; `write(code, rows, signal)` บันทึกทันทีต่อรหัส. Loader ยังมีเพียงหนึ่ง active request และ gap หนึ่งวินาที. สำเร็จแสดงทันทีระหว่างบันทึก cache. Failed results ไม่ถูกบันทึก; เปิดหน้าใหม่เป็นคิวใหม่จึงโหลดรหัสที่เคยล้มเหลวได้ ส่วน retry ภายในคิวเดิมยังเป็น manual เท่านั้น

`StepResult` เพิ่ม origin `cache|query`, cachedAt, expiresAt. `StepSnapshot.succeeded` คือผลสำเร็จรวมทั้งสองทาง; `cacheHits` และ `querySucceeded` แยกจำนวนใช้ cache กับ query รอบนี้. ไม่มีการเปลี่ยน BMS HTTP payload หรือ approval/completeness ของ official series

Progress snapshot และ aggregate ที่ส่งออกเป็น readonly/frozen; รายการที่ไม่เปลี่ยนใช้ reference เดิม. เวลา query แยกจากเวลารอ shared lane/ช่วงเว้นคิว. SQL ของแต่ละ code สร้างเมื่อถึงคำขอจริงเท่านั้น; cache hit ไม่สร้างหรือเรียก SQL. ผลที่ยังไม่รับรองยังอยู่ในหน้าสอบทานเท่านั้น

เปลี่ยนปี/session หรือออกจากหน้ายกเลิก request, initialization และ cache write ของ context เก่า; IndexedDB write transaction ผูกกับ AbortSignal. ผลเก่าที่มาช้าไม่กลับมา hydrate หรือเขียน cache. Cache ของปี/context อื่นยังเก็บไว้จนหมดอายุ

## Controls

- **โหลดใหม่ทั้งคิว:** abort คิวเก่า ล้าง cache เฉพาะ context/FY ที่เลือก แล้วสร้างคิวใหม่. ห้ามใช้เพื่อข้าม session/Retry-After lock
- **ล้าง cache ทั้งหมด:** abort คิวและ initialization, ล้าง aggregate store ของแอปนี้และ snapshot ปัจจุบัน แล้วรอผู้ใช้กดโหลดใหม่. ไม่ล้าง browser storage ของแอปอื่น
- Cache unavailable: ผลที่โหลดแล้วใช้ได้ใน memory; การเก็บข้าม refresh ไม่พร้อม. หาก browser ไม่ยอมเข้าถึง storage การล้าง disk ทำไม่ได้จน storage กลับมาพร้อม แต่ผลบนหน้ากับ memory ถูกล้างและยังมีป้าย storage unavailable

## หลักฐานตรวจรับ

Unit/integration 1,276 tests / 35 files ผ่าน รวม context isolation, expiry/month boundary, corrupt facts/version drift, zero/NULL/future, memory/quota fallback และ cancellation ระหว่าง write. TypeScript/Vite build ผ่าน

Browser ใช้ mocked BMS ทุกครั้ง: cache smoke ผ่าน 13 checks รวมปิดเปิด Chromium persistent profile, refresh ก่อน/หลังยืนยัน session, session/FY isolation, force reload, clear-all, expired entries และ denied storage/failed disk clear. Regression คิวเดิมผ่าน 13 checks บน desktop/mobile รวมผลเก่าที่มาช้าไม่เขียน cache; ไม่มี page errors. Screenshots และ results อยู่ใน ignored `tmp/step-browser/`

สูตรยังไม่รับรอง ไม่เปิดผล candidate ใน THIP/monitoring หรือ export. ไม่เรียก BMS/HOSxP จริง ไม่ deploy และไม่ commit/push ในรอบพัฒนานี้
## Separate cohort-profile namespace

The same aggregate repository also hosts `cohort-profile` results with FY/month/profile/SQL/rule fingerprints. They have no candidate KPI facts and cannot hydrate KPI success/approval. KPI force reload clears only `thip-report` for the selected context/year; clear-all aborts and clears both. Profile reads begin only from the manual control after a validated session. See [cohort profile contract](THIP-COHORT-PROFILES.md).

## Performance regression — 2026-10-02

Production benchmark คืน cache 177 รหัสครบโดยไม่เรียก native SQL บน desktop/mobile จำลองห้ารอบ. Browser regression ทดสอบ IndexedDB v2 จริง, refresh/ปิดเปิด browser, force reload, session/FY isolation, expiry, storage denial และ clear-all. ผลและข้อจำกัดของการวัดอยู่ใน [performance report](THIP-PERFORMANCE-2026-10-02.md)
