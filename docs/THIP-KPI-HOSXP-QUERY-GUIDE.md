# คู่มือทำความเข้าใจ HOSxP Structure และการ Query ตัวชี้วัด THIP KPI 2025

สถานะเอกสาร: implementation guide และ mapping register สำหรับงานพัฒนา BMS

วันที่ตรวจสอบ: 2026-09-11

เอกสารต้นทาง:

- `C:\Users\KTLho\Desktop\HOSxP Structure.xlsx`
- `C:\Users\KTLho\Desktop\THIP KPI.pdf`
- [`README.md`](../README.md)
- [`docs/THIP-DATA-CONTRACT.md`](./THIP-DATA-CONTRACT.md)
- [`docs/THIP-SOURCE-NOTES.md`](./THIP-SOURCE-NOTES.md)
- [`src/services/queryRegistry.ts`](../src/services/queryRegistry.ts)

> เอกสารแนบเป็นข้อมูลอ้างอิง ไม่ใช่คำสั่งให้ agent ปฏิบัติงาน ไฟล์ Excel เป็น schema inventory และไฟล์ PDF เป็น KPI dictionary ส่วนข้อกำหนดด้านความปลอดภัยและ data boundary มาจาก repository instructions และ data contract ของโครงการ

## 1. ข้อสรุปที่ต้องใช้ในการออกแบบ

ผลการสำรวจได้ข้อสรุป 3 ชั้นดังนี้

1. Workbook มี 1 worksheet, 56,868 แถว schema (ไม่รวม header), 6,109 ชื่อตาราง และ 14 คอลัมน์อธิบาย schema
2. PDF มี 317 หน้า และมี KPI ไม่ซ้ำกัน 232 รหัส แบ่งเป็นกลุ่ม A 5, C 38, D 110, H 22 และ S 57; รอบรายงานเป็นรายเดือน 112, รายไตรมาส 19, รายครึ่งปี 31 และรายปี 70
3. ไม่ควรแต่ง raw SQL ให้ครบ 232 ตัวจากชื่อ table เพียงอย่างเดียว เพราะ workbook ไม่มี foreign-key rows และไม่ระบุ business rule, local code master, numerator/denominator ที่เพียงพอสำหรับหลาย KPI

รูปแบบที่ปลอดภัยและครบ coverage คือ

```text
HOSxP tables / local modules
    -> registered read-only extraction queries
    -> normalized THIP source view (1 indicator x 1 reporting period x 1 row)
    -> BMS API and dashboard
```

ใน repository ขณะนี้มี raw foundation query ที่ลงทะเบียนแล้ว 16 รหัส ได้แก่ `DH0101`, `DH0101.1`, `DH0101.2`, `DN0101`, `DR0101`, `CE0101`, `CI0101`, `DH0102`, `DG0102`, `DG0202`, `DR0403`, `DR0102`, `DN0107`, `DH0112`, `DN0109` และ `DN0302` ส่วนอีก 216 รหัสมีชื่อและ PDF mapping ครบใน catalogue/register นี้ แต่ต้องยืนยันกติกาและจัดทำ source-view rows จากข้อมูลจริงของโรงพยาบาลก่อนจึงจะเรียกว่า production query ได้

ดังนั้นคำว่า “query ครบทุกตัว” ในเอกสารนี้หมายถึง

- มี query path เดียวที่อ่านผลลัพธ์ normalized view ได้ครบทั้ง 232 รหัส
- มี completeness audit ที่ตรวจ 1,552 reporting cells ตามรอบรายงานของแต่ละ KPI (`112×12 + 19×4 + 31×2 + 70×1`)
- มีทะเบียนรายรหัส ระบุ PDF page, formula scale, query family, candidate HOSxP tables และสถานะ
- ไม่สร้าง SQL ที่เดา numerator/denominator ของ 216 ตัวที่ยังไม่มีหลักฐานจาก local implementation
- adapter ตรวจว่า `unit` ของ source view ตรงกับ multiplier ในสูตร (`x100`, `x1,000`, `x100,000` หรือ `x1,000,000`) และใช้ multiplier เดียวกันตอนคำนวณ annual roll-up
- dashboard summary เป็นค่า derived จากผลจริงเทียบ target จริงเท่านั้น; KPI ที่ไม่มี target ไม่ถูกนำไปสร้างคะแนนสรุป

## 2. ผลสำรวจ HOSxP Structure.xlsx

### 2.1 ความหมายของ 14 คอลัมน์ใน workbook

Workbook เป็นรายการ table-column ไม่ใช่ data dictionary ที่อธิบายความหมายทางคลินิกทั้งหมด ความหมายเชิง schema ที่ตรวจได้คือ

| ลำดับ | ความหมายที่ใช้ในงานนี้ |
|---:|---|
| 1 | table name |
| 2 | ordinal position ของ column |
| 3 | column name |
| 4 | data type |
| 5 | character maximum length |
| 6 | numeric precision |
| 7 | numeric scale |
| 8 | unique flag |
| 9 | nullable / รับ NULL |
| 10 | default value |
| 11 | auto increment |
| 12 | column comment หรือคำอธิบาย |
| 13 | foreign-key target table |
| 14 | foreign-key target column |

จากการตรวจค่าในคอลัมน์ 13-14 ไม่พบรายการ FK ที่ populate ใน workbook ดังนั้นความสัมพันธ์ด้านล่างเป็น logical join ที่อนุมานจาก HOSxP convention และชื่อ field ต้องตรวจซ้ำด้วย row-count, uniqueness และข้อมูลจริงในฐานของแต่ละโรงพยาบาล

### 2.2 Grain ของตารางหลัก

| Grain ที่ต้องการ | ตารางหลัก | key ที่ใช้เป็นหลัก | สิ่งที่ต้องระวัง |
|---|---|---|---|
| ผู้รับบริการ | `patient`, `person` | `hn`, `person_id`, บาง workflow ใช้ `cid` | เป็น PHI/PII; ไม่ส่งออกจาก query ผลลัพธ์ |
| OPD visit | `ovst` | `vn` | 1 visit มีหลาย diagnosis, lab และรายการยา |
| OPD diagnosis | `ovstdiag` | `vn` + diagnosis row | ต้องกำหนด `diagtype` และอย่านับ visit ซ้ำ |
| IPD admission/discharge | `ipt`, `an_stat` | `an` | `ipt` เป็น event/discharge anchor; `an_stat` มี Pdx, LOS และ summary |
| IPD diagnosis | `iptdiag` | `an` + diagnosis row | 1 admission มีหลาย Sdx; ใช้ `EXISTS` หรือ aggregate ก่อน join |
| IPD medication/service item | `opitemrece` | `an` หรือ `vn` + item row | ระบุ timestamp ของการให้จริง ไม่ใช่เพียงวันที่บันทึก |
| drug master | `drugitems` | `icode` | antibiotic, drugcategory และชื่อยาอาจเป็น local coding |
| IPD death | `death` | local row + `an` เมื่อมี | ต้องยืนยันว่าการตายทุกกรณีมี `an` และ field ใดเป็น cause |
| IPD ward movement | `iptbedmove`, `ward` | `an`, `ward` | ใช้คำนวณ exposure เช่น bed-days/ICU ต้อง aggregate movement ก่อน |
| lab order/result | `lab_head`, `lab_order`, `lab_items` | `lab_order_number`, `lab_items_code` | ต้อง map test name/code และเวลา order/report ให้ชัด |
| operation | `operation_list`, `operation_detail`, `operation_item` | `operation_id`, `operation_item_id` | procedure/status/time-out ไม่ควรนับจากรายการ billing อย่างเดียว |
| ER flow | `er_regist` | `vn` | field เวลาเช่น triage, doctor, finish อาจว่างหรือใช้คนละ workflow |
| chronic clinic | `clinicmember`, `clinic_visit` | `clinicmember_id`, `hn`, `clinic`, `vn` | การ join clinic visit กับ member ต้องกำหนด local rule |
| ANC / newborn / labour | `person_anc`, `person_wbc`, `labor`, `ipt_pregnancy`, `ipt_newborn`, `ipt_labour_infant`, `ipt_labour_child` | `person_id`, `an`, `ipt_labour_id` | แม่-เด็กเป็นคนละ grain และอาจมีหลายเด็กต่อการคลอดเดียว |
| mental / developmental | `depression_screen`, `psych_assess_child`, `psych_plan`, `psych_therapy` | local patient/visit keys | ต้องยืนยันว่า assessment เป็น baseline, follow-up หรือ treatment event |
| employee / HR | `emp`, `emp_history`, `emp_resign`, `emp_stat`, `emp_work_*` | `emp_id` | headcount, FTE, start/end date และ job category ต้องตกลงก่อน |
| stock / supply | `stock_item`, `stock_trancation`, `stock_daily_balance_record`, `stock_item_balance_history`, `supply_sterile*` | `item_id`, transaction id | ชื่อตาราง `trancation` เป็นชื่อใน schema; ห้ามแก้เป็น `transaction` โดยเดา |
| satisfaction survey | `survey_satisfy_*`, `dis_satisfied*` | local survey/visit key | ต้องกำหนด response denominator และแบบสอบถาม version |

### 2.3 Logical joins ที่ใช้เป็น canonical starting point

ตารางต่อไปนี้เป็น join map สำหรับออกแบบ extraction query ไม่ใช่การยืนยัน FK constraint

| ความสัมพันธ์ | join condition เริ่มต้น | ใช้กับ |
|---|---|---|
| IPD core | `ipt.an = an_stat.an` | Pdx, LOS, discharge, DRG/RW, IPD outcome |
| IPD diagnosis | `iptdiag.an = ipt.an` | Pdx/Sdx หรือ diagnosis flags |
| death | `death.an = ipt.an` | mortality; ตรวจว่ามี fallback ด้วย `hn` หรือไม่ |
| IPD medication | `opitemrece.an = ipt.an` และ `opitemrece.icode = drugitems.icode` | antibiotic, aspirin, prophylaxis |
| IPD procedure | `iptoprt.an = ipt.an` | ICD-9/operation billing evidence |
| ward | `iptbedmove.ward = ward.ward` หรือ `nward/oward` ตาม event | ward/ICU/bed exposure |
| OPD diagnosis | `ovstdiag.vn = ovst.vn` | diagnosis, screening, service visit |
| OPD screen | `opdscreen.vn = ovst.vn` | vital signs, BMI, NCD lab/screen |
| OPD medication | `opitemrece.vn = ovst.vn` และ `icode` กับ `drugitems` | outpatient prescribing |
| lab | `lab_head.lab_order_number = lab_order.lab_order_number` และ `lab_order.lab_items_code = lab_items.lab_items_code` | lab result and test identification |
| operation detail | `operation_detail.operation_id = operation_list.operation_id` | start/end, anesthesia, safety checklist |
| operation item | `operation_detail.operation_item_id = operation_item.operation_item_id` | local procedure master |
| CKD | `clinic_ckd_member.clinicmember_id = clinicmember.clinicmember_id`; visit by `vn` | kidney function and ACEI/ARB |
| cancer | `clinicmember_cancer.clinicmember_id = clinicmember.clinicmember_id` | cancer registration and stage |
| ANC/WBC | `person_anc.person_id = person_wbc.person_id` | maternal and child follow-up |
| HR | `emp_history.emp_id = emp.emp_id` and corresponding `emp_*` event keys | turnover, injury, training, absence |
| stock | `stock_* .item_id = stock_item.item_id` | stock balance and inventory turnover |

ก่อนใช้งานจริงให้ตรวจอย่างน้อย 4 ข้อ: key uniqueness, orphan rate, date coverage, และจำนวน row ก่อน/หลัง join ในช่วงเวลาทดสอบเดียวกัน

### 2.4 Domain table inventory ที่พบและประโยชน์ต่อ KPI

| Domain | ตารางที่พบใน workbook | field สำคัญที่ตรวจพบ |
|---|---|---|
| IPD | `ipt`, `an_stat`, `iptdiag`, `iptoprt`, `iptbedmove`, `ward`, `death` | `an`, `regdate/regtime`, `dchdate/dchtime`, `pdx`, `age_y`, `los`, `ward`, `drg`, `rw`, `adjrw` |
| OPD | `ovst`, `ovstdiag`, `opdscreen`, `opitemrece` | `vn`, `hn`, `vstdate/vsttime`, `icd10`, `bpd/bps`, `bmi`, `bw`, `icode` |
| ยา | `drugitems`, `opitemrece` | `icode`, `name`, `antibiotic`, `drugcategory`, `generic_name`, `atc_code`, `recetime` |
| Lab | `lab_head`, `lab_order`, `lab_items` | order/report dates and times, result, item code/name/unit/reference |
| ER | `er_regist` | `er_time_1/2/3`, `enter_er_time`, `doctor_tx_time`, `finish_time`, triage, door-to-needle/balloon, antibiotic time |
| Operation/anesthesia | `operation_list`, `operation_detail`, `operation_item` | operation dates/times, status, ASA-related fields, airway, blood loss, safety/time-out fields |
| Chronic/NCD | `clinicmember`, `clinic`, `clinic_visit`, `clinic_ckd_member*` | clinic registration, status, HbA1c/BP history, GFR/CKD flags |
| Cancer | `patient_cancer_registeration`, `patient_cancer_visit_stat`, `clinicmember_cancer` | diagnosis/stage/pathology/treatment dates and status |
| TB/HIV | `clinicmember_tb`, `tb_register`, `tb_register_visit`, `tb_lab_examination_sputum`, `arv_tx`, `arv_lab` | TB register/visit/lab, ARV regimen and dates |
| Maternal/child | `person_anc`, `person_wbc`, `labor`, `ipt_pregnancy*`, `ipt_newborn`, `ipt_labour_*` | pregnancy, delivery, birth weight, Apgar, asphyxia, neonatal outcome |
| Mental/substance | `depression_screen`, `psych_*` | screening, assessment, plan, therapy |
| Infection | `ipd_nurse_note`, `iptbedmove`, `ward`, `lab_*` | nursing/ventilator fields, ward movement and lab evidence; device-day tables may be custom |
| Employee/HR | `emp`, `emp_history`, `emp_in_out`, `emp_resign`, `emp_stat`, `emp_work_*`, `emp_position`, `emp_department`, `emp_education` | employment dates, status, job group, absence, injury and training |
| Customer | `survey_satisfy_head_pcu`, `survey_satisfy_screen_pcu`, `survey_satisfy_choice_pcu`, `dis_satisfied*` | survey date, scores and dissatisfaction topics |
| Finance/stock/CSSD | `an_stat`, `opitemrece`, `stock_*`, `supply_sterile*`, `blood_request` | income/item money, inventory transactions, CSSD supplies and blood request |

### 2.4.1 Field anchors ที่ตรวจพบจาก workbook

รายการนี้เป็น subset ของ column ที่เกี่ยวข้องกับการทำ KPI และเป็นชื่อที่ตรวจพบใน workbook จริง การมี column ไม่ได้แปลว่า field นั้นมีความหมายหรือคุณภาพข้อมูลพร้อมใช้ ต้องทำ local validation ต่อ

| ตาราง | field anchors ที่ตรวจพบ |
|---|---|
| `ipt` | `an`, `hn`, `vn`, `regdate`, `regtime`, `dchdate`, `dchtime`, `ward`, `dchtype`, `dchstts`, `drg`, `mdc`, `rw`, `adjrw`, `bw`, `first_ward`, `ipt_type`, `spclty`, `dch_doctor`, `operation_status`, `lab_status`, `xray_status`, `update_datetime` |
| `an_stat` | `an`, `pdx`, `hn`, `dx0`-`dx5`, `sex`, `age_y`, `age_m`, `age_d`, `regdate`, `dchdate`, `admdate`, `drg`, `rw`, `los`, `ot`, `spclty`, `ward`, `income`, `item_money`, `paid_money` |
| `iptdiag` | `ipt_diag_id`, `an`, `diagtype`, `doctor`, `icd10`, `entry_datetime`, `modify_datetime`, `diagnosis_note`, `diag_no`, `icd11` |
| `iptoprt` | `iptoprt_id`, `an`, `doctor`, `enddate`, `endtime`, `icd9`, `icode`, `iprice`, `iqty`, `opdate`, `optime`, `oper_type`, `ovst_oper_type`, `oper_note_text` |
| `iptbedmove`, `ward` | movement: `an`, `movedate`, `movetime`, `nward`, `oward`, `nbedno`, `obedno`; ward master: `ward`, `name`, `spclty`, `bedcount`, `real_bedcount`, `is_maternity_ward`, `ward_active` |
| `death` | `death_id`, `hn`, `death_date`, `death_diag_1`-`death_diag_4`, `death_diag_other`, `death_cause`, `death_place`, `an`, `death_diag_icd10`, `last_update` |
| `ovst`, `ovstdiag` | visit: `vn`, `hn`, `an`, `vstdate`, `vsttime`, `doctor`, `spclty`, `cur_dep`, `visit_type`; diagnosis: `ovst_diag_id`, `vn`, `icd10`, `hn`, `vstdate`, `vsttime`, `diagtype` |
| `opdscreen` | `vn`, `hn`, `vstdate`, `vsttime`, `begintime`, `outtime`, `bpd`, `bps`, `bw`, `hr`, `pulse`, `temperature`, `rr`, `height`, `bmi`, `fbs`, `creatinine`, `hba1c`, `tg`, `hdl`, `tc`, `ldl`, `egfr`, `spo2`, smoking/drinking fields |
| `opitemrece` | `vn`, `hn`, `an`, `icode`, `qty`, `drugusage`, `recetime`, `unitprice`, `vstdate`, `vsttime`, `doctor`, `rxdate`, `rxtime`, `item_type`, `sum_price`, `cost`, `income` |
| `drugitems` | `icode`, `name`, `strength`, `units`, `unitprice`, `dosageform`, `drugcategory`, `generic_name`, `antibiotic`, `therapeutic`, `therapeuticgroup`, `atc_code` |
| `lab_head`, `lab_order`, `lab_items` | head: `lab_order_number`, `vn`, `hn`, `order_date`, `report_date`, `report_time`, `department`, `order_time`, `ward`; order: `lab_order_number`, `lab_items_code`, `lab_order_result`, `lab_order_remark`, `laborder_date`, `abnormal_result`; master: `lab_items_code`, `lab_items_name`, `lab_items_unit`, `lab_items_normal_value`, `icode`, `loinc_code` |
| `operation_list` | `operation_id`, `request_date`, `request_time`, `operation_date`, `operation_time`, `hn`, `vn`, `an`, `operation_name`, `operation_position`, `operation_side`, `require_anes`, `require_icu`, `status_id`, `anes_complete`, `operation_anes_physical_status_id`, `operation_consciousness_id`, `operation_respiration_id`, `arrive_date`, `arrive_time`, `doctor_incision_date`, `doctor_closing_date`, `re_operation`, `blood_loss` |
| `operation_detail`, `operation_item` | detail: `operation_detail_id`, `operation_id`, `operation_item_id`, `doctor`, `begin_datetime`, `end_datetime`, `icdcode`, `operation_position`, `icode`, `operation_type_id`, `operation_time_hour`, `operation_time_minute`, `time_out_datetime`, `incision_datetime`, `closure_datetime`, `clinical_term`; item: `operation_item_id`, `name`, `icode`, `icd9`, `operation_group_id` |
| `er_regist` | `vn`, `vstdate`, `er_period`, `er_pt_type`, `er_emergency_type`, `er_dch_type`, `er_doctor`, `er_time_1`, `er_time_2`, `er_time_3`, `enter_er_time`, `doctor_tx_time`, `finish_time`, `door_to_doctor_second`, `length_of_stay_second`, `time_to_triage_second`, `triage_datetime`, `stroke_needle_datetime`, `stemi_balloon_datetime`, `door_to_balloon_second`, `door_to_needle_second`, `do_antibiotics`, `antibiotics_datetime`, `antibiotics_second` |
| `clinicmember`, `clinic_visit`, `clinic_ckd_member*` | `clinicmember_id`, `clinic`, `doctor`, `hn`, `regdate`, `lastvisit`, `dchdate`, `current_status`, chronic fields, `last_hba1c_date/value`, `last_bp`, `ncd_icd10_list`; CKD: GFR type, `scr_gfr_less60`, antihypertensive-related fields; visit: `vn`, CKD GFR type |
| `patient_asthma_screen`, `patient_copd_screen` | `vn`, `hn`, smoking-advice fields, `fev1_percent`, influenza vaccine flag, long-term oxygen field, `screen_date`, `screen_time` |
| cancer tables | `patient_cancer_registeration`: `clinicmember_id`, `hn`, cancer dates, pathology, stage, organ, treatment status/date, discharge; `patient_cancer_visit_stat`: `vn`, `vstdate`, `vsttime`; `clinicmember_cancer`: diagnosis date, topography, morphology, stage |
| maternal/child tables | `person_anc`: `person_id`, ANC/vaccine/blood/labour fields, `preg_no`, `preg_begin_date`, `labor_date`, `edc`, `lmp`, `ga`; `person_wbc`: birth weight, baby service/vaccine/status fields; `ipt_newborn`: `an`, `birth_weight`, `dead`, `born_date/time`, Apgar, asphyxia |
| `labor`, `ipt_labour_infant`, `ipt_labour_child`, `ipt_pregnancy` | labour/delivery dates and times, placenta blood loss, infant weight/Apgar/breath, `ipt_labour_id`, child sex/bw/temperature/Apgar, `an`, delivery type, abort, `labor_date`, gestational age, child/dead child counts |
| `ipd_nurse_note` | `an`, `note_date`, `note_time`, `note_datetime`, temperature, oxygen/saturation fields, operation started, fluid/blood loss, hypercapnic respiratory failure and oxygen ventilator flags |
| `depression_screen`, `psych_*` | visit/patient key, `screen_datetime`, scores, child assessment, plan and therapy event fields |
| TB/HIV tables | `clinicmember_tb`, `tb_register`, `tb_register_visit`, `tb_lab_examination_sputum`, `arv_tx`, `arv_lab`; ARV table includes `hn`, `vn`, `date_entry`, regimen classes and follow-up fields |
| HR tables | `emp_id`, work begin/status, first/last name, sex, position, department, agency, resignation type/date; supporting `emp_history`, `emp_in_out`, `emp_resign`, `emp_stat`, `emp_work_sick`, `emp_work_status`, `emp_work_summary`, `emp_work_schedule` |
| stock tables | `stock_item`: `item_id`, `item_name`, `item_unit`, `icode`, `onhand_qty`, `balance_qty`, `avg_month_use_qty`; `stock_trancation`: item/date/time, transaction type, in/out/left qty and money; balance history and itemdata tables |
| survey/CSSD/blood | survey date and `sum_1`-`sum_5`, dissatisfaction topic/result fields; `supply_sterile`, `supply_sterile_item`; `blood_request` date/time, department, ward, `vn`, `hn`, response complete |

### 2.5 Data boundary และ PHI

- HOSxP ใช้เป็น read-only source เท่านั้น ห้าม `INSERT`, `UPDATE`, `DELETE`, DDL หรือ stored procedure ที่มี side effect
- query ผลลัพธ์ KPI ต้อง aggregate ที่ระดับ indicator/month และไม่คืน `hn`, `cid`, ชื่อ, วันเกิด, ที่อยู่ หรือ raw patient row
- ห้ามใช้ `SELECT *`; ระบุ columns ที่จำเป็นเท่านั้น
- `patient`, `person`, `ovst`, `ipt`, `opitemrece`, lab และ clinical note มีข้อมูลอ่อนไหว ให้ทำงานผ่าน registered query layer และ allowlist
- โรงพยาบาลอาจมี HOSxP version, custom field, local drug code และ local workflow ต่างกัน ต้องเก็บ mapping ใน source view/config ที่ตรวจสอบย้อนกลับได้

## 3. THIP data contract ที่ query ต้องส่งออก

### 3.1 Output grain

ต้องมีหนึ่งแถวต่อ `indicator_code x fiscal_year x fiscal_month` โดย `period_start` เป็นวันแรกของเดือนตามปฏิทิน

| Column | ชนิด/ความหมาย |
|---|---|
| `indicator_code` | รหัสหนึ่งใน catalogue 232 รหัส |
| `period_start` | ISO date วันแรกของเดือน |
| `fiscal_year` | ปีงบประมาณไทยแบบปีสิ้นสุด เช่น Oct 2024 - Sep 2025 = FY 2025 |
| `fiscal_month` | Oct=1, Nov=2, ..., Sep=12 |
| `numerator` | จำนวนหรือผลรวมของเหตุการณ์ที่เข้าเกณฑ์ |
| `denominator` | ประชากร/episode/exposure ที่เข้าเกณฑ์ |
| `value` | ค่าที่คำนวณแล้ว หรือ `NULL` เมื่อ denominator เป็น 0/ไม่มีข้อมูล |
| `target`, `target_scope` | benchmark/target และระดับ reporting-period/annual |
| `percentile` | ค่า percentile เมื่อ source มี |
| `indicator_group` | A, C, D, H หรือ S |
| `unit`, `direction` | percent/rate/ratio/count และทิศทางการแปลผล |
| `category`, `title`, `title_th` | metadata ของตัวชี้วัด |
| `definition`, `formula` | นิยามและสูตรตาม dictionary/local approved rule |
| `numerator_label`, `denominator_label` | label สำหรับ audit |
| `source_tables` | รายการ source ที่ใช้จริง |
| `frequency`, `reference` | ความถี่และเอกสารอ้างอิง |

### 3.2 Fiscal-year rule

```sql
CASE
  WHEN EXTRACT(MONTH FROM period_start) >= 10
    THEN EXTRACT(YEAR FROM period_start)::integer + 1
  ELSE EXTRACT(YEAR FROM period_start)::integer
END AS fiscal_year,
CASE
  WHEN EXTRACT(MONTH FROM period_start) >= 10
    THEN EXTRACT(MONTH FROM period_start)::integer - 9
  ELSE EXTRACT(MONTH FROM period_start)::integer + 3
END AS fiscal_month
```

สำหรับ FY `:fiscal_year` ช่วงวันที่ควรเป็น `:start_date = YYYY-10-01` ของปีก่อนหน้า และ `:end_date = YYYY-10-01` ของปีสิ้นสุด โดย `end_date` เป็น exclusive

### 3.3 Null และ annual roll-up

- `denominator = 0` หรือไม่พร้อมใช้งาน ให้ `value = NULL`; ห้ามแปลงเป็น 0 เพราะจะแปลว่า performance เป็นศูนย์
- เก็บ numerator และ denominator แยกเสมอ เพื่อ audit และคำนวณ annual แบบ weighted ratio
- annual percent/rate: `SUM(numerator) / SUM(denominator) x 100`
- annual ratio/count ให้ใช้สูตรตาม unit ของ KPI; ห้ามนำค่า percent รายงวดมาเฉลี่ยโดยไม่ผ่าน approved definition
- ถ้าไม่มีข้อมูลทั้งปี ให้ annual value เป็น `NULL` และ status เป็น `no-data`

## 4. Query ที่ครอบคลุม KPI ทั้ง 232 ตัวผ่าน normalized source view

SQL ต่อไปนี้เป็น PostgreSQL-compatible SQL สำหรับ registered BMS query layer ตาม contract ของ repository ชื่อ view เป็นตัวอย่างเท่านั้น ต้องแทนด้วยชื่อที่ผ่าน `VITE_BMS_KPI_SOURCE_VIEW` และ allowlist แล้ว ห้ามรับชื่อ view จาก user input โดยตรง

### 4.1 ดึงผลลัพธ์ทุก reporting period ตามปีงบประมาณ

```sql
SELECT
  indicator_code,
  period_start,
  fiscal_year,
  fiscal_month,
  numerator,
  denominator,
  value,
  target,
  target_scope,
  percentile,
  indicator_group,
  unit,
  direction,
  category,
  title,
  title_th,
  definition,
  formula,
  numerator_label,
  denominator_label,
  source_tables,
  frequency,
  reference,
  rule_version,
  refreshed_at
FROM "public"."thip_kpi_monthly"
WHERE period_start >= :start_date
  AND period_start < :end_date
  AND fiscal_year = :fiscal_year
ORDER BY indicator_code, fiscal_month;
```

Parameters ที่ต้องส่งแบบ typed parameter:

```text
start_date  : date     เช่น 2024-10-01 สำหรับ FY 2025
end_date    : date     เช่น 2025-10-01 (exclusive)
fiscal_year : integer  เช่น 2025
```

ใน source code ปัจจุบัน query นี้ถูกสร้างโดย `buildSourceViewQuery()` ใน [`src/services/bmsData.ts`](../src/services/bmsData.ts) และส่งผ่าน `executeRegisteredQuery()` เท่านั้น

### 4.2 ตรวจความครบตามรอบรายงานของ 232 ตัวชี้วัด

ใช้ query นี้หลัง source view refresh เพื่อแยก `missing`, `zero-denominator` และ `ok` โดยไม่คืนข้อมูลผู้ป่วย

> รอบรายงานไม่ได้เหมือนกันทุกตัว: `src/data/thipReporting.ts` กำหนด monthly = เดือน 1–12, quarterly = 1/4/7/10, semiannual = 1/7 และ annual = 1 ของปีงบประมาณ ตัวอย่างด้านล่างย่อ `VALUES` ไว้; `buildCompletenessAuditQuery()` ใน source code จะขยายเป็น 1,552 คู่ `indicator_code × fiscal_month` ให้ครบทุกตัว

```sql
WITH params AS (
  SELECT
    CAST(:start_date AS date) AS start_date,
    CAST(:end_date AS date) AS end_date,
    CAST(:fiscal_year AS integer) AS fiscal_year
),
expected(indicator_code, fiscal_month) AS (
  VALUES
    ('AA0101', 1), ('AA0102', 1), ('AA0103', 1), ('AA0104', 1), ('AA0105', 1),
    ('CA0101', 1), ('CA0102', 1), ('CE0101', 1),
    -- buildCompletenessAuditQuery emits the remaining cadence cells
    ('DH0101', 1), ('DH0101', 2), ('DH0101', 3), ('DH0101', 4),
    ('DH0101', 5), ('DH0101', 6), ('DH0101', 7), ('DH0101', 8),
    ('DH0101', 9), ('DH0101', 10), ('DH0101', 11), ('DH0101', 12)
),
expected_cells AS (
  SELECT
    e.indicator_code,
    (p.start_date + ((e.fiscal_month - 1) * INTERVAL '1 month'))::date AS period_start,
    p.fiscal_year,
    e.fiscal_month
  FROM expected e
  CROSS JOIN params p
)
SELECT
  e.indicator_code,
  e.period_start,
  e.fiscal_year,
  e.fiscal_month,
  s.numerator,
  s.denominator,
  s.value,
  CASE
    WHEN s.indicator_code IS NULL THEN 'missing'
    WHEN s.denominator IS NULL THEN 'unavailable'
    WHEN s.denominator = 0 THEN 'zero-denominator'
    ELSE 'ok'
  END AS completeness_status
FROM expected_cells e
LEFT JOIN "public"."thip_kpi_monthly" s
  ON s.indicator_code = e.indicator_code
 AND s.period_start = e.period_start
 AND s.fiscal_year = e.fiscal_year
 AND s.fiscal_month = e.fiscal_month
ORDER BY e.indicator_code, e.fiscal_month;
```

Expected result ต้องมี 1,552 rows ถ้า source view มี exactly one row ต่อ code/reporting period ตาม cadence ของ dictionary หากได้มากกว่านี้ให้ตรวจ duplicate หรือ row นอก cadence ก่อน หากได้น้อยกว่านี้ให้ตรวจ missing code/period



### 4.3 ตรวจ duplicate ใน source view

```sql
SELECT
  indicator_code,
  period_start,
  fiscal_year,
  fiscal_month,
  COUNT(*) AS row_count
FROM "public"."thip_kpi_monthly"
WHERE period_start >= :start_date
  AND period_start < :end_date
  AND fiscal_year = :fiscal_year
GROUP BY indicator_code, period_start, fiscal_year, fiscal_month
HAVING COUNT(*) <> 1
ORDER BY indicator_code, period_start;
```

### 4.4 ดึง KPI เดียวเพื่อ drill-down metadata

การ drill-down ใน BMS ควร filter จาก normalized view ด้วย parameter ไม่ควรสร้าง raw SQL ใหม่จาก code ที่ส่งมาจาก browser

```sql
SELECT
  indicator_code, period_start, fiscal_year, fiscal_month,
  numerator, denominator, value, target, target_scope,
  indicator_group, unit, direction, category, title, title_th,
  definition, formula, numerator_label, denominator_label,
  source_tables, frequency, reference
FROM "public"."thip_kpi_monthly"
WHERE indicator_code = :indicator_code
  AND period_start >= :start_date
  AND period_start < :end_date
  AND fiscal_year = :fiscal_year
ORDER BY fiscal_month;
```

## 5. Raw HOSxP extraction building blocks

ส่วนนี้เป็น template สำหรับผู้ทำ source view ไม่ใช่ query ที่เปิดให้ frontend ส่งตรงไป HOSxP และไม่ใช่การยืนยันว่า table/field มี semantics เหมือนกันทุกโรงพยาบาล

### 5.1 IPD base cohort ที่ไม่คืน PHI

```sql
WITH ipd_case AS (
  SELECT
    i.an,
    i.regdate,
    i.regtime,
    i.dchdate,
    i.dchtime,
    i.ward,
    s.age_y,
    UPPER(TRIM(s.pdx)) AS pdx,
    EXISTS (
      SELECT 1
      FROM death d
      WHERE d.an = i.an
    ) AS died
  FROM ipt i
  JOIN an_stat s ON s.an = i.an
  WHERE i.dchdate >= :start_date
    AND i.dchdate < :end_date
    AND i.regdate IS NOT NULL
    AND EXTRACT(EPOCH FROM (
      (i.dchdate + COALESCE(i.dchtime, TIME '23:59:59')) -
      (i.regdate + COALESCE(i.regtime, TIME '00:00:00'))
    )) >= 14400
),
periodized AS (
  SELECT
    *,
    DATE_TRUNC('month', dchdate)::date AS period_start,
    EXTRACT(MONTH FROM dchdate)::integer AS calendar_month
  FROM ipd_case
)
SELECT
  period_start,
  CASE WHEN calendar_month >= 10 THEN calendar_month - 9 ELSE calendar_month + 3 END AS fiscal_month,
  CASE WHEN calendar_month >= 10 THEN EXTRACT(YEAR FROM period_start)::integer + 1
       ELSE EXTRACT(YEAR FROM period_start)::integer END AS fiscal_year,
  COUNT(*)::integer AS denominator,
  COUNT(*) FILTER (WHERE died)::integer AS deaths
FROM periodized
GROUP BY period_start, calendar_month
ORDER BY period_start;
```

หลักการของ base cohort:

- ใช้ `an` เป็น episode key และ aggregate ก่อน join ตาราง one-to-many
- current foundation query ใช้ `dchdate` เป็นเดือนของ IPD outcome และตัด LOS ที่น้อยกว่า 4 ชั่วโมงตาม rule ที่ลงทะเบียนไว้
- ถ้าโรงพยาบาลใช้ `an_stat.admdate` หรือ discharge event คนละ field ต้องทำ local mapping และเก็บเหตุผล
- ห้าม join `iptdiag`, `opitemrece` และ `ipd_nurse_note` ตรงเข้ากับ base แล้วนับ `COUNT(*)` เพราะจะคูณจำนวน episode

### 5.2 Diagnosis flag

ใช้ `EXISTS` เมื่อ metric ต้องการเพียง flag ว่ามี diagnosis หรือไม่

```sql
EXISTS (
  SELECT 1
  FROM iptdiag d
  WHERE d.an = c.an
    AND UPPER(TRIM(d.icd10)) IN (:approved_code_1, :approved_code_2)
) AS has_sdx
```

ข้อกำหนดที่ต้องบันทึกใน rule ทุกตัว: ใช้ Pdx จาก `an_stat.pdx` หรือจาก `iptdiag.diagtype`, Sdx ต้องตัด Pdx ซ้ำหรือไม่, ใช้ ICD-10 3 หลัก/4 หลัก/ช่วงรหัส, และ version ของ code set

### 5.3 Medication event

```sql
EXISTS (
  SELECT 1
  FROM opitemrece oi
  JOIN drugitems di ON di.icode = oi.icode
  WHERE oi.an = c.an
    AND di.antibiotic = 'Y'
    AND di.drugcategory ILIKE '%broad%'
    AND EXTRACT(EPOCH FROM (
      oi.vstdate::timestamp + COALESCE(oi.vsttime, TIME '00:00:00') -
      (c.regdate::timestamp + COALESCE(c.regtime, TIME '00:00:00'))
    )) BETWEEN 0 AND 10800
) AS received_in_3_hours
```

ต้องยืนยันว่า `opitemrece.vstdate/vsttime` เป็นเวลาที่ให้ยา ไม่ใช่เวลา order/เบิก/บันทึก และ drug master ของโรงพยาบาลระบุ broad-spectrum ด้วย `drugcategory`, `generic_name`, `atc_code` หรือ local table อื่น

### 5.4 OPD, ER, lab และ operation

| งาน | starting pattern | ตัวแปรที่ต้องยืนยัน |
|---|---|---|
| OPD | `ovst` เป็น visit; join `ovstdiag` และ `opdscreen` ด้วย `vn` | visit type, repeat visit, denominator population |
| ER | `ovst` join `er_regist` ด้วย `vn` | ความหมาย TIME-IN/TIME-OUT, triage และ event timestamp |
| Lab | `lab_head -> lab_order -> lab_items` | item code, abnormal flag, report time, หน่วยและ reference range |
| Operation | `operation_list -> operation_detail -> operation_item` และเทียบ `iptoprt` | operation status, elective/emergency, checklist, procedure code |
| Ward/device | `iptbedmove -> ward` และ nursing/device events | ICU boundary, bed-days/device-days, start/stop event |

ทุก pattern ต้อง aggregate ให้อยู่ episode/visit level ก่อนนำไปคำนวณ numerator และ denominator

## 6. Foundation query ที่มีอยู่ใน repository แล้ว

แหล่ง executable source of truth คือ [`queryRegistry.thipIpdFoundation`](../src/services/queryRegistry.ts) ไม่ควร copy SQL ไปไว้หลายที่ ตารางนี้สรุป rule และจุดที่ต้อง validate ต่อ

| รหัส | rule ที่ลงทะเบียนปัจจุบัน | source ที่ใช้จริงใน query | PDF printed page | caveat |
|---|---|---|---:|---|
| `DH0101` | IPD อายุ >=18, denominator ใช้ Pdx หรือ qualifying Sdx ACS; numerator ใช้ Pdx ACS ที่เสียชีวิตทุกสาเหตุ หรือ Sdx ACS ที่เสียชีวิตจาก ACS | `ipt`, `an_stat`, `iptdiag`, `death` | 39 | ตรงตาม PDF หน้า 39; ตรวจ Pdx/Sdx code set และความหมาย death cause |
| `DH0101.1` | IPD อายุ >=18, denominator ใช้ Pdx หรือ qualifying Sdx STEMI (I21.0-I21.3); numerator ใช้ Pdx STEMI ที่เสียชีวิตทุกสาเหตุ หรือ Sdx STEMI ที่เสียชีวิตจาก STEMI | `ipt`, `an_stat`, `iptdiag`, `death` | 40 | ตรงตาม PDF หน้า 40; ตรวจ Pdx/Sdx code set และความหมาย death cause |
| `DH0101.2` | IPD อายุ >=18, denominator ใช้ Pdx หรือ qualifying Sdx NSTE-ACS (I21.4/I21.9); numerator ใช้ Pdx NSTE-ACS ที่เสียชีวิตทุกสาเหตุ หรือ Sdx NSTE-ACS ที่เสียชีวิตจาก NSTE-ACS | `ipt`, `an_stat`, `iptdiag`, `death` | 41 | ตรงตาม PDF หน้า 41; ตรวจ Pdx/Sdx code set และความหมาย death cause |
| `DN0101` | IPD stroke ตาม Pdx family I60-I67, numerator คือ died | `ipt`, `an_stat`, `death` | 67 | PDF ใช้ช่วงรหัส ต้องยืนยันการตัด code แบบ 3 หลักกับ local ICD |
| `DR0101` | pneumonia จาก Pdx หรือ Sdx, numerator คือ death | `ipt`, `an_stat`, `iptdiag`, `death` | 79 | ทบทวน J-code list ให้ตรงกับ PDF ฉบับอนุมัติ |
| `CE0101` | sepsis cohort และ broad-spectrum antibiotic ภายใน 3 ชั่วโมง | `ipt`, `an_stat`, `iptdiag`, `opitemrece`, `drugitems` | 194 | PDF แสดง token `A40.0,A41.9,R57.2,R65.1`; current query ใช้ sepsis list กว้างกว่า ต้อง reconcile |
| `CI0101` | sepsis cohort, numerator คือ died | `ipt`, `an_stat`, `iptdiag`, `death` | 199 | PDF แสดง `A40.0,A40.9,A41.0,A41.9,R57.2,R65.1`; current query ใช้ sepsis list กว้างกว่า ต้อง reconcile |
| `DH0102` | IPD อายุ >=18, Pdx ACS, aspirin ภายใน 24 ชั่วโมง | `ipt`, `an_stat`, `opitemrece`, `drugitems` | 42 | ยืนยันชื่อยา/icode และเวลาที่นับเป็น administration |
| `DG0102` | IPD Pdx UGIH, average length of stay | `ipt`, `an_stat` | 121 | ใช้ `an_stat.los`; ตรวจว่าค่า LOS local เป็นวันนอนตาม THIP และไม่เป็นค่า placeholder |
| `DG0202` | IPD Pdx acute appendicitis, mortality | `ipt`, `an_stat`, `iptdiag`, `death` | 123 | ตรวจ K35 code set และความหมายการเสียชีวิต |
| `DR0403` | IPD Pdx COPD, mortality | `ipt`, `an_stat`, `iptdiag`, `death` | 90 | ตรวจ J44 code set และความหมายการเสียชีวิต |
| `DR0102` | pneumonia re-admission ภายใน 28 วัน | `ipt`, `an_stat`, `iptdiag` | 80 | กติกา unplanned เป็น approximation ต้อง sign-off |
| `DN0107` | stroke re-admission ภายใน 28 วัน | `ipt`, `an_stat`, `iptdiag` | 73 | กติกา unplanned เป็น approximation ต้อง sign-off |
| `DH0112` | ACS average length of stay | `ipt`, `an_stat` | 54 | ตรวจ admission/discharge date และ episode grain |
| `DN0109` | stroke average length of stay | `ipt`, `an_stat` | 74 | ตรวจ admission/discharge date และ episode grain |

ใน current code และทะเบียน rule, `CE0101` และ `CI0101` ใช้ printed page 194 และ 199 ตามลำดับ ซึ่งตรงกับเลขหน้าที่พิมพ์ใน footer ของ PDF; เลขหน้าในข้อความ extraction เดิมอาจคลาดเคลื่อนและห้ามใช้แทน printed page

## 7. Query family สำหรับ 216 รหัสที่ยังต้องทำ local mapping

`queryRegistry.thipIpdFoundation` สร้าง fiscal-period grid ให้ foundation ทั้ง 16 รหัสด้วย ดังนั้นช่วง FY ที่ส่งเข้ามาจะได้ 16 รหัส × 12 เดือน = 192 แถว แม้เดือนนั้นไม่มี cohort: `numerator` และ `denominator` จะเป็น 0 และ `value` จะเป็น `NULL` ตาม zero-denominator contract การมีแถวศูนย์นี้ไม่ใช่ synthetic KPI แต่เป็นผลลัพธ์ aggregate ที่ยืนยันว่า query ตรวจช่วงเวลานั้นแล้ว

คำว่า candidate table หมายถึง table ที่ schema มี field น่าจะรองรับ ไม่ได้หมายถึงผ่าน validation แล้ว สำหรับแต่ละ family ต้องสร้าง approved rule ที่มี cohort, numerator, denominator, event date, code master, target และ test case

| Query family | KPI ที่ครอบคลุม | candidate HOSxP source | จุดยากที่ต้องยืนยัน |
|---|---|---|---|
| `ACSC` | AA hospitalization rates | `ovst`, `ovstdiag`, `ipt`, `an_stat`, `iptdiag`, `patient`, `person` | population denominator, age band, Pdx only, coverage area |
| `ANESTHESIA` | CA0101-CA0105 | `operation_list`, `operation_detail`, `ipt`, `an_stat`, `er_regist` | ASA, pre-anesthetic, recovery, re-intubation, capnometry event |
| `SEPSIS_ER` | CE0101, CE0104, CI0101 | `ipt`, `an_stat`, `iptdiag`, `death`, `er_regist`, `opitemrece`, `drugitems` | sepsis code version, ER vs IPD start time, antibiotic administration |
| `ED_FLOW` | CE0102-CE0103 | `ovst`, `er_regist`, `ovstdiag` | TIME-IN/TIME-OUT and emergency eligibility |
| `PRESSURE_ULCER` | CG0101-CG0104 | `ipt`, `an_stat`, `ipd_nurse_note`, `iptbedmove`, `ward` | stage, present-on-admission, risk population, patient-days |
| `MATERNAL_CHILD` | CM0101-CM0209 | `person_anc`, `person_wbc`, `labor`, `ipt_pregnancy`, `ipt_newborn`, `ipt_labour_infant`, `ipt_labour_child` | mother-child linkage, gestation, delivery grain, neonatal window |
| `SURGERY` | CO0101, CO0105, CO0107 | `operation_list`, `operation_detail`, `operation_item`, `iptoprt`, `ipt`, `an_stat` | checklist completion, peri-op window, re-operation definition |
| `MENTAL_DEVELOPMENT` | CP, DM, DS | `psych_assess_child`, `psych_plan`, `psych_therapy`, `depression_screen`, `person_wbc`, `ovst`, `ovstdiag`, `clinicmember` | baseline/follow-up scores and treatment retention |
| `DM_HT` | DC0103-DC0201.2, DP0101 | `clinicmember`, `clinic_visit`, `ovst`, `ovstdiag`, `opdscreen`, `lab_head`, `lab_order`, `lab_items`, `opitemrece`, `drugitems` | good-control thresholds, age subgroup, latest valid lab |
| `HIV_TB` | DC0301-DC0309, DR0201-DR0205 | `clinicmember`, `clinic_visit`, `clinicmember_tb`, `tb_register`, `tb_register_visit`, `tb_lab_examination_sputum`, `arv_tx`, `arv_lab`, `ovstdiag` | cohort enrollment date, 12-month window, test/result semantics |
| `CANCER` | DC0401-DC0403 | `patient_cancer_registeration`, `patient_cancer_visit_stat`, `clinicmember_cancer`, `clinicmember`, `ovst`, `ovstdiag` | cancer site/stage and mortality/re-admission linkage |
| `CKD` | DC0501-DC0502 | `clinicmember`, `clinic_ckd_member`, `clinic_ckd_member_visit`, `lab_head`, `lab_order`, `lab_items`, `opitemrece`, `drugitems` | eGFR calculation, ACEI/ARB mapping, longitudinal target |
| `BREAST_CANCER` | DE0101, DE0103 | cancer tables, `ovst`, `ovstdiag`, `lab_*` | BIRADS, consultation clock, stage definition |
| `STEM_CELL` | DE0501 | `ipt`, `an_stat`, `iptdiag`, `lab_*`, `operation_*` | engraftment date and denominator |
| `TDT` | DE0801 | `ipt`, `an_stat`, `iptdiag`, `lab_*`, `opitemrece`, `drugitems` | iron overload lab threshold and chelator mapping |
| `CLEFT` | DE1201-DE1202 | `ipt`, `an_stat`, `iptdiag`, `operation_list`, `operation_detail`, `operation_item` | age at repair and cleft operation master |
| `INFERTILITY` | DE1301-DE1306 | `ovst`, `ovstdiag`, `operation_list`, `operation_detail`, `operation_item`, `lab_*` | embryo transfer cycle and age at transfer |
| `UGIH` | DE1401-DE1405, DG0101-DG0102 | `ipt`, `an_stat`, `iptdiag`, `operation_*`, `lab_*` | EGD/hemostasis event, risk status, 28-day readmission |
| `NEWBORN` | DE1601 | `ipt_newborn`, `ipt_pregnancy`, `ipt_labour_infant`, `ipt_labour_child`, `labor`, `person_wbc`, `person_anc` | hearing screen within 30 days and child identity |
| `APPENDICITIS` | DG0201-DG0202 | `ipt`, `an_stat`, `iptdiag`, `death`, `operation_*` | abruption/appendix operation coding |
| `ACS` | DH0101-DH0113 | `ipt`, `an_stat`, `iptdiag`, `death`, `er_regist`, `opitemrece`, `drugitems`, `operation_*` | ACS subtype, door time, PCI/fibrinolytic, discharge medication |
| `CABG` | DH0201-DH0204 | `ipt`, `an_stat`, `iptdiag`, `death`, `operation_*`, `opitemrece`, `drugitems` | CABG procedure identification and 30-day window |
| `HEART_FAILURE` | DH0301-DH0302 | `ipt`, `an_stat`, `iptdiag`, `clinicmember`, `ovstdiag`, `opitemrece`, `drugitems`, `lab_*` | LVSD/HFREF evidence and ACEI/ARB/MRA |
| `ATRIAL_FIBRILLATION` | DH0401-DH0402 | `ipt`, `an_stat`, `iptdiag`, `death`, `clinicmember`, `ovstdiag`, `opitemrece`, `drugitems`, `lab_*` | anticoagulant target and intracranial bleed definition |
| `STROKE` | DN0101-DN0110 | `ipt`, `an_stat`, `iptdiag`, `death`, `er_regist`, `operation_*`, `opitemrece`, `drugitems` | stroke subtype, rehabilitation clock, thrombolytic time |
| `HEAD_INJURY` | DN0301-DN0303 | `ipt`, `an_stat`, `iptdiag`, `death`, `operation_*` | craniotomy and 48-hour mortality window |
| `ARTHROPLASTY` | DO0202-DO0304 | `ipt`, `an_stat`, `iptdiag`, `operation_*`, `opitemrece`, `drugitems` | hip/knee procedure, prophylaxis, 90-day/1-year infection |
| `PEDIATRIC_DM` | DP0101 | `person`, `clinicmember`, `ovst`, `ovstdiag`, `opdscreen`, `lab_*` | child age, control threshold, visit period |
| `PNEUMONIA` | DR0101-DR0103 | `ipt`, `an_stat`, `iptdiag`, `death`, `opitemrece`, `drugitems` | pneumonia Pdx/Sdx and 28-day readmission |
| `ASTHMA_COPD` | DR0301-DR0404 | `patient_asthma_screen`, `patient_copd_screen`, `clinicmember`, `clinic_visit`, `ovst`, `ovstdiag`, `opdscreen` | disease cohort, smoking status, readmission |
| `SUBSTANCE` | DS0101-DS0401 | `clinicmember`, `clinic_visit`, `ovst`, `ovstdiag`, `psych_plan`, `psych_therapy` | remission/retention follow-up and substance group |
| `CHRONIC_ED` | HC0101-HC0102 | `patient_asthma_screen`, `patient_copd_screen`, `clinicmember`, `clinic_visit`, `ovst`, `ovstdiag`, `opdscreen` | self-care survey/assessment instrument |
| `EMPLOYEE` | HE0101-HE0106 | `emp`, `emp_history`, `emp_stat`, `emp_work_status`, `emp_work_summary`, `emp_work_schedule`, `emp_position`, `emp_department`, `opdscreen` | employee denominator, check-up, BMI, influenza vaccine |
| `TOBACCO` | HH0101.1-HH0104.5 | `opdscreen`, `patient_asthma_screen`, `patient_copd_screen`, `clinicmember`, `clinic_visit`, `ovst`, `ovstdiag`, `person_anc` | screen/treatment/abstinence follow-up and subgroup |
| `CUSTOMER` | SC0101-SC0106 | `survey_satisfy_head_pcu`, `survey_satisfy_screen_pcu`, `survey_satisfy_choice_pcu`, `dis_satisfied*` | questionnaire version, response denominator, return/recommend |
| `FINANCE` | SF0101-SF0106 | `an_stat`, `ipt`, `opitemrece`, `stock_item`, `stock_trancation` | HOSxP operational fields may not equal audited financial statements |
| `GOVERNANCE` | SG0104 | `stock_item`, `stock_trancation`, `stock_daily_balance_record`, `stock_item_balance_history`, `supply_sterile*` | recycled waste source is likely custom/outside standard HOSxP |
| `HR` | SH0101-SH0307 | `emp`, `emp_history`, `emp_in_out`, `emp_resign`, `emp_stat`, `emp_work_sick`, `emp_work_status`, `emp_work_summary`, `emp_work_schedule`, `emp_position`, `emp_department`, `emp_education` | headcount/FTE, category, training, injury and satisfaction |
| `INFECTION` | SI0101-SI0303 | `ipd_nurse_note`, `ipt`, `iptbedmove`, `ward`, `operation_*`, `lab_*` | device-days and infection surveillance events may need custom source |
| `BLOOD` | SL0101 | `blood_request`, `ipt`, `an_stat`, `operation_*` | selective surgery denominator and transfusion event |
| `MEDICATION` | SM0102-SM0201 | `ovst`, `ovstdiag`, `opitemrece`, `drugitems`, `stock_item`, `stock_trancation`, `stock_daily_balance_record`, `stock_item_balance_history`, `stock_trancation_itemdata` | antibiotic prescribing definition and inventory turn formula |
| `CSSD` | SS0101-SS0103 | `supply_sterile`, `supply_sterile_item`, `operation_list`, `operation_detail` | sterilization test and exact equipment/procedure request |

## 8. Development-ready implementation plan

ส่วนนี้คือสิ่งที่ต้องใช้เริ่มพัฒนาระบบได้ทันที เอกสารเดิมไม่ได้ขาด query สำหรับการอ่านผลลัพธ์ แต่ขาด implementation contract ที่บอกว่า developer ต้องสร้างอะไรและอะไรเป็น dependency จากโรงพยาบาล

### 8.1 สถานะปัจจุบันใน repository

| lane | coverage | ทำได้ทันที | dependency ที่เหลือ |
|---|---:|---|---|
| Catalogue, routing และ UI model | 232/232 | มีใน `src/data/thipCatalogue.ts`, `src/data/thipMeta.ts` และ UI | ไม่มี |
| Rule manifest รายรหัส | 232/232 | มีใน `src/data/thipKpiRules.ts` พร้อม family, PDF page, candidate tables, tokens และสถานะ query | ต้องเปลี่ยนสถานะเมื่อ local owner sign-off |
| Normalized source-view reader | 232/232 | มี `buildSourceViewQuery()` และ adapter ใน `src/services/bmsData.ts` | ต้อง provision ชื่อ view จริง |
| Completeness/duplicate validation | 232 codes ตาม cadence | มี audit SQL, duplicate guard และ coverage gate 1,552 ช่อง | ต้องเชื่อม reporting source |
| Registered foundation calculation | 16/232 | มีใน `queryRegistry.thipIpdFoundation` และมี unit/smoke tests | ต้องยืนยัน HOSxP local semantics |
| Raw calculation สำหรับ KPI ที่เหลือ | 216/232 | ทำ rule manifest และ family adapter ต่อได้โดยไม่แตะ UI | clinical rule, code master, event mapping และ aggregate evidence |

สรุปคือ frontend, contract, source-view adapter, validation และ query registry พร้อมให้พัฒนาต่อได้เลย ระบบไม่มี synthetic production fallback แล้ว ส่วนที่ยังทำให้ตัวเลข production ครบ 232 ไม่ได้คือ “กติกาข้อมูลและ source view ของโรงพยาบาล” ไม่ใช่การขาดชื่อ KPI ในเอกสาร

การเชื่อมต่อ BMS จะลบ launch capability ออกจาก URL ก่อนเรียก PasteJSON และเก็บไว้เฉพาะใน memory ของหน้าเพื่อ retry เมื่อ network/CORS ขัดข้องชั่วคราว; เมื่อ BMS ปฏิเสธ session จะล้าง capability ทิ้งทันที

### 8.2 ไฟล์และ interface ที่ developer ต้อง implement

ให้ใช้แผนนี้เป็น Definition of Ready ของงาน coding

```text
docs/THIP-KPI-HOSXP-QUERY-GUIDE.md   <- contract และ 232-code register นี้
src/data/thipCatalogue.ts             <- catalogue 232 codes (มีแล้ว)
src/data/thipMeta.ts                  <- group metadata และ dictionary count (มีแล้ว)
src/data/thipKpiRules.ts              <- rule manifest ครบ 232 รหัส (มีแล้ว; 16 foundation, 216 needs-local-mapping)
src/services/queryRegistry.ts         <- registered read-only SQL (มีแล้วสำหรับ foundation, extend ตาม family)
src/services/bmsData.ts               <- normalized source-view reader และ cadence-aware coverage gate 1,552 ช่อง (มีแล้ว)
src/services/thipRuleValidation.ts    <- แยก validator เพิ่มได้ถ้าต้องการ (ปัจจุบัน guard อยู่ใน `bmsData.ts`)
src/services/*.test.ts                 <- contract, coverage และ query response tests (มีแล้ว)
scripts/visual_smoke.py                <- browser smoke ใช้ mock เฉพาะ test เท่านั้น (มีแล้ว)
```

ห้ามใส่ raw SQL ที่ผู้ใช้แก้ได้ใน `thipKpiRules.ts` หรือ browser code ให้ manifest อ้าง `queryKey`/`family` เท่านั้น ส่วน SQL อยู่ใน `queryRegistry` หรือ reporting layer ที่ review แล้ว

รูปแบบ manifest ที่มีอยู่จริงใน repository ตอนนี้เป็นแบบนี้:

```ts
{
  code: 'DH0101',
  group: 'D',
  title: 'Acute coronary syndrome: Percent of mortality',
  pdfPage: 39,
  formulaScale: 'a/b x 100',
  queryFamily: 'ACS',
  candidateSourceTables: ['ipt', 'an_stat', 'iptdiag', 'death'],
  diagnosisOrProcedureTokens: ['I21.0', 'I21.1', 'I21.2', 'I21.3'],
  status: 'foundation',
  queryKey: 'thipIpdFoundation',
}
```

สำหรับ 216 รหัสที่ยังไม่ผ่าน local mapping ให้ใช้ `status: 'needs-local-mapping'`, `queryKey: null` และห้ามให้ระบบแสดงเป็น 0; ให้ source view ส่ง no-data/NULL จนกว่าจะผ่าน sign-off เมื่อ KPI ใดพร้อมเปิด production ให้เพิ่ม rule version, episode key, period field, inclusion/exclusion, numerator/denominator rule และ code-set versionลงใน rule evidence หรือ reporting layerที่ผ่าน review แล้ว ไม่ควรอ้างว่าฟิลด์เหล่านี้มีอยู่ใน manifest ปัจจุบันก่อนทำการขยาย schema

### 8.3 Reporting source-view contract ที่ต้อง provision

สร้าง view หรือ table ใน reporting/BMS data layer เท่านั้น ไม่สร้างใน HOSxP production โดยตรง ตัวอย่าง DDL นี้เป็น contract สำหรับทีม data platform ไม่ใช่คำสั่งให้ frontend execute

```sql
CREATE TABLE reporting.thip_kpi_monthly_contract (
  indicator_code varchar(10) NOT NULL,
  period_start date NOT NULL,
  fiscal_year integer NOT NULL,
  fiscal_month smallint NOT NULL CHECK (fiscal_month BETWEEN 1 AND 12),
  numerator numeric(18, 4),
  denominator numeric(18, 4),
  value numeric(18, 4),
  target numeric(18, 4),
  target_scope varchar(16) NOT NULL CHECK (target_scope IN ('monthly', 'annual')),
  percentile numeric(18, 4),
  indicator_group varchar(1) NOT NULL CHECK (indicator_group IN ('A', 'C', 'D', 'H', 'S')),
  unit varchar(16) NOT NULL CHECK (unit IN ('percent', 'rate', 'ratio', 'count')),
  direction varchar(32) NOT NULL CHECK (direction IN ('higher-is-better', 'lower-is-better', 'neutral')),
  category text NOT NULL,
  title text NOT NULL,
  title_th text,
  definition text NOT NULL,
  formula text NOT NULL,
  numerator_label text NOT NULL,
  denominator_label text NOT NULL,
  source_tables text[] NOT NULL CHECK (cardinality(source_tables) > 0),
  frequency text NOT NULL,
  reference text NOT NULL,
  rule_version varchar(64) NOT NULL,
  refreshed_at timestamptz NOT NULL,
  CHECK (unit = 'count' OR denominator IS NOT NULL),
  CHECK (denominator IS NULL OR denominator <> 0 OR value IS NULL),
  CHECK (percentile IS NULL OR percentile BETWEEN 0 AND 100),
  UNIQUE (indicator_code, period_start, fiscal_year, fiscal_month)
);
```

ข้อกำหนดของ source view:

- expose ชื่อ view ที่ผ่าน `VITE_BMS_KPI_SOURCE_VIEW` และ `quoteSourceView()` เท่านั้น
- มีหนึ่ง row ต่อ code/reporting period ตาม cadence ของ code; ถ้าตัวหารเป็นศูนย์ให้เก็บ denominator เป็น 0 และ value เป็น `NULL`
- production completeness ต้องมี full cadence grid 1,552 rows ต่อ FY; sparse rows ใช้ได้เฉพาะระหว่างพัฒนาและต้องขึ้น audit warning
- ทุก row ที่ส่งเข้า production source view ต้องมี metadata ของ KPI ครบและค่า `unit`, `direction`, `target_scope`, `indicator_group` ต้องอยู่ใน allowlist; descriptive metadata ต้องคงที่ทุกงวดของ code เดียวกัน ส่วน target/percentile/facts เป็นข้อมูลระดับงวด; `percentile` ถ้ามีต้องอยู่ในช่วง 0–100; adapter จะ reject row ที่ขาด/ผิดชนิด รวมถึง multiplier ใน `formula` ที่ไม่ตรงกับ rule manifest, numeric fact ที่ไม่ใช่ตัวเลข, ค่า `value` ที่ไม่เป็น `NULL` เมื่อ denominator เป็นศูนย์, หรือค่า percent/rate/ratio ที่ไม่มี denominator เพื่อไม่ให้ระบบเดาหน่วย/สถานะเอง
- frontend ไม่มี benchmark seed; ถ้า source view ส่ง `target = NULL` ระบบจะรักษา `NULL` ของงวดนั้น ไม่ carry-forward จากงวดอื่น และไม่เดา target จากค่าเก่าใน frontend
- ถ้า `target_scope = 'monthly'` ระบบจะไม่ยก target ของงวดใดงวดหนึ่งไปเป็น target ของ annual roll-up; annual target/status จะมีได้เมื่อ source ระบุ target ระดับปีโดยตรง
- ไม่ expose `hn`, `cid`, ชื่อ, วันเกิด, ที่อยู่, note text หรือ raw clinical row
- `rule_version` และ `refreshed_at` ทำให้ผลลัพธ์ตรวจย้อนกลับได้ แม้สอง field นี้จะเป็น extension จากขั้นต่ำใน data contract

### 8.4 Test fixture ที่ทำให้ตรวจ frontend ได้โดยไม่รอ PHI

สร้าง fixture จาก catalogue และ fiscal calendar โดยไม่ใช้ข้อมูลผู้ป่วยจริง

```ts
{
  indicator_code: 'DH0101',
  period_start: '2024-10-01',
  fiscal_year: 2025,
  fiscal_month: 1,
  numerator: 2,
  denominator: 80,
  value: 2.5,
  target: 3.5,
  target_scope: 'monthly',
  indicator_group: 'D',
  unit: 'percent',
  direction: 'lower-is-better'
}
```

Fixture acceptance (ใช้ใน test เท่านั้น ไม่ใช่ production fallback):

- มี code ครบ 232 และ reporting period ครบตาม `src/data/thipReporting.ts`
- มี case `denominator = 0`, missing reporting period, duplicate row, unknown code และ invalid fiscal month
- ตัวอย่าง numerator/denominator เป็น synthetic เท่านั้น
- dashboard ต้องแสดง no-data เมื่อ source row หาย ไม่ตีความเป็น performance = 0

### 8.5 ลำดับการพัฒนาที่แนะนำ

| phase | งาน | ผลลัพธ์ที่ส่งมอบ |
|---|---|---|
| 0 | contract, fixture, validator | dashboard/query tests รันได้กับ 1,552 cadence cells โดยไม่ใช้ PHI |
| 1 | harden foundation 16 ตัว | registered query, code-set snapshot, expected aggregate และ local validation note |
| 2 | IPD clinical outcomes | ACS, stroke, pneumonia, sepsis, surgery, anesthesia, pressure ulcer |
| 3 | OPD/NCD/chronic | ACSC, DM/HT, CKD, HIV/TB, asthma/COPD, tobacco |
| 4 | maternal/child/specialty | maternal, newborn, cancer, UGIH, infertility, cleft, stem cell, arthroplasty |
| 5 | operational/admin | ED, mental, infection, medication, blood, CSSD, customer, HR, finance, governance |

แต่ละ phase ทำ parallel ได้ 3 ชิ้น: rule manifest, registered/source-view query และ test fixture/validation evidence

### 8.6 Definition of Done ราย KPI

KPI จะเปลี่ยนจาก `needs-local-mapping` เป็น `ready` เมื่อมี artifact ครบทุกข้อ

```text
[ ] rule manifest มี code, family, episode key, period field และ rule_version
[ ] PDF definition/formula/page ถูกอ่านและมี domain owner รับรอง
[ ] Pdx/Sdx/procedure/drug/local code set มี version และ source owner
[ ] numerator และ denominator มี label ที่นับได้จริง
[ ] ระบุ event timestamp, inclusion, exclusion และ observation window
[ ] raw query อยู่ใน registered query/reporting layer แบบ read-only
[ ] aggregate ก่อน join one-to-many และมี orphan/duplicate check
[ ] source view มีหนึ่ง row ต่อ code/reporting period ตาม cadence และ metadata ครบ
[ ] มี expected result แบบ aggregate ที่ไม่เป็น PHI อย่างน้อย 3 เดือน
[ ] มี test สำหรับ empty month, zero denominator, boundary date และ unknown code
[ ] domain owner sign-off แล้วจึงเปิดใช้งาน production
```

### 8.7 ข้อมูลขั้นต่ำที่ต้องขอจากโรงพยาบาลเพื่อปิด 216 รหัส

ขอเป็น schema/code mapping และ aggregate validation เท่านั้น ไม่ต้องส่ง session credential หรือ raw patient rows

```text
1. HOSxP version และ database dialect/connector ที่ใช้จริง
2. schema/custom table diff จาก workbook ล่าสุด
3. mapping ของ ICD-10/ICD-9, drug icode, antibiotic/broad-spectrum, procedure, ward/ICU และ clinic
4. ความหมายของวันที่/เวลาแต่ละ workflow เช่น order, administer, report, discharge และ readmission
5. owner ของข้อมูล ANC, newborn, infection device-day, HR, finance, survey และ waste
6. aggregate numerator/denominator ที่ตรวจทานแล้วอย่างน้อย 3 เดือนต่อ family
7. target/benchmark, revision และผู้อนุมัตินิยามเมื่อ PDF กับ local workflow ต่างกัน
```

เมื่อได้ข้อมูลชุดนี้ developer ไม่ต้องเปลี่ยน frontend contract; เติม family adapter, rule manifest, source view rows และ tests ตามทะเบียนท้ายเอกสารได้เลย

ทำทีละ family และเก็บ evidence ไม่ควรสร้าง query ทั้งหมดในครั้งเดียวจากชื่อ field

1. เลือก KPI จากทะเบียนด้านล่างและอ่าน detail page ใน PDF โดยใช้ printed page
2. แปลง definition เป็น cohort rule: population, inclusion, exclusion, episode key และ observation window
3. ล็อก code master/version: ICD-10, ICD-9, drug `icode`, local procedure, clinic, ward, employee category หรือ survey choice
4. ระบุ numerator, denominator, formula scale, direction, target และ target scope แยกกัน
5. เลือก event date เดียวสำหรับ periodization; ห้ามใช้วันที่บันทึกแทนวันที่เกิดเหตุโดยไม่ระบุเหตุผล
6. สร้าง raw extraction แบบ read-only แล้ว aggregate ที่ episode/visit/person level ก่อน join one-to-many
7. เขียนผลเข้า normalized source view ที่มีหนึ่ง row ต่อ code/reporting period ตาม cadence และ metadata ครบ
8. รัน completeness/duplicate audit 1,552 ช่องตาม cadence พร้อมตรวจ `NULL` denominator และ zero denominator
9. เทียบผลกับรายงานโรงพยาบาลหรือ sample ที่ผ่าน de-identification อย่างน้อย 3 เดือน และให้ domain owner sign-off
10. ลงทะเบียน query ผ่าน `queryRegistry`, เขียน unit/integration test, และตรวจว่าไม่มี PHI ใน response

สำหรับการตรวจ export ก่อน provision view ใช้ `scripts/thip_source_audit.py` โดยส่งออกเฉพาะ normalized rows จาก reporting layer:

```powershell
python scripts/thip_source_audit.py --input .\thip-kpi-export.json --fiscal-year 2026
```

คำสั่งนี้อ่าน rule/cadence manifest จาก repository, ตรวจ 232 codes และ 1,552 cells, duplicate, period, metadata, unit/multiplier ตาม formula, ความสอดคล้องของ value กับ numerator/denominator และ zero-denominator แล้วคืน JSON summary ที่ไม่มีค่าจาก row ดิบ; exit code เป็น 1 หากยังไม่พร้อม production

## 9. Checklist สำหรับ review query ทุกตัว

```text
[ ] code อยู่ใน catalogue 232 รหัสและไม่สะกดซ้ำ
[ ] PDF printed page และ revision/reference ถูกบันทึก
[ ] cohort และ denominator ระบุเป็นภาษาที่ทดสอบได้
[ ] Pdx/Sdx/ICD/procedure/drug code set มี version และ owner
[ ] episode key ถูกต้อง และไม่มี row multiplication
[ ] event date/time และ timezone/NULL rule ชัดเจน
[ ] denominator 0 ให้ value = NULL
[ ] numerator + denominator audit ได้ โดยไม่คืน PHI
[ ] reporting period และ FY Oct-Sep ถูกต้อง
[ ] annual roll-up เป็น weighted rule ตาม unit
[ ] source_tables เป็นตารางที่ query จริง ไม่ใช่รายชื่อเดา
[ ] query ถูก register และผ่าน read-only guard
[ ] มี test กับ empty month, duplicate, orphan, boundary date และ invalid code
```

## 10. Known limitations และ discrepancy ที่ต้องติดตาม

- Workbook ไม่ได้บอก HOSxP version, local customization หรือ business meaning ของทุก field; table ที่ไม่อยู่ใน mapping ไม่ควรถูกสรุปว่าไม่มีในฐานจริง
- Workbook ไม่มี populated FK metadata; logical joins ต้อง validate ใน local database
- PDF Thai text บางส่วน extract ไม่ได้ด้วย font encoding ที่ถูกต้อง; ชื่อภาษาอังกฤษ, code, formula scale และ printed page ใช้เป็น index เท่านั้น ต้องเปิดดูหน้า PDF เมื่อต้องยืนยันนิยามภาษาไทย
- หน้า PDF ในทะเบียนนี้ใช้เลข footer ที่พิมพ์บนหน้ารายละเอียด ไม่ใช่ PDF object index
- `CE0101` และ `CI0101` มี code-set evidence ใน PDF ต่างจาก sepsis list ที่ current foundation query ใช้ ต้องทำ reconciliation ก่อน production
- กลุ่ม infection SI ต้องการ device-day/exposure และ event definition ที่ schema inventory มาตรฐานยังไม่ชัดเจน
- กลุ่ม finance SF และ governance SG อาจต้องใช้ระบบบัญชี/สิ่งแวดล้อมนอก HOSxP; ห้ามแทนด้วย field ที่ใกล้เคียงโดยไม่มี approval
- ปัจจุบัน local Vite development ใช้ foundation query 16 รหัสเมื่อไม่มี source view; production build ต้องกำหนด source view และ UI จะรับ normalized rows ที่รู้จัก พร้อมตรวจ coverage ตาม cadence 1,552 ช่องก่อนเรียกข้อมูลว่า complete live (ถ้าไม่ครบ production จะ fail closed)

### 10.1 Local SQL evidence ที่พบในเครื่องสำหรับโรงพยาบาล

จากการตรวจไฟล์ SQL ที่มีอยู่ในเครื่องของผู้พัฒนา พบ implementation evidence เพิ่มเติมที่ควรใช้เป็น input ของ local mapping แต่ยังไม่ควรนำไปเปิด production โดยตรง:

```text
C:\Users\KTLho\Documents\Navicat\PostgreSQL\Servers\test\ktlhos\public\99_SUPER_MASTER_THIP_MOPH.sql
C:\Users\KTLho\Documents\Navicat\PostgreSQL\Servers\test\ktlhos\public\ร้อยละการเสียชีวิตของผู้ป่วยภาวะหัวใจขาดเลือดเฉียบพลัน.sql
```

ไฟล์ `99_SUPER_MASTER_THIP_MOPH.sql` มี logic แบบ aggregate สำหรับรหัส THIP ที่พบใน query จริง 32 รหัส ได้แก่ `CI0101`, `CM0105`, `DC0107`, `DC0201`, `DC0401`, `DG0101`, `DG0102`, `DG0201`, `DG0202`, `DH0101`, `DH0101.1`, `DH0101.2`, `DH0102`, `DH0104`, `DH0106`, `DH0111`, `DH0112`, `DH0114`, `DH0301`, `DN0101`, `DN0102`, `DN0107`, `DN0109`, `DN0302`, `DR0101`, `DR0102`, `DR0112`, `DR0201`, `DR0301`, `DR0401`, `DR0403` และ `DR0412` โดยอ้าง `ipt_drg_result` เป็น source ของ Pdx/Sdx, `ipt.dchstts` เป็นสถานะจำหน่าย และ `opitemrece`/`drugitems` เป็น evidence ของยา

หลักฐานนี้ทำให้เห็นทางต่อของ query จริง แต่มีข้อจำกัดที่ต้องแก้ก่อน register:

- ใช้ `fy_start`, `fy_end`, death status (`3`,`8`) และ lab/vaccine code เป็นค่าคงที่ใน query; ต้องย้ายเป็น hospital configuration ที่มี owner/version และตรวจจาก master จริง
- match ยาจาก `drugitems.name` ด้วย `ILIKE` เป็นเพียง fallback discovery; production ต้องใช้ versioned local `icode` crosswalk และแยก charge/dispense/administration ให้ชัด
- output มีเฉพาะเดือนที่มี cohort ไม่ได้สร้าง cadence grid ที่มีเดือนศูนย์/ตัวหารศูนย์ และไม่มี metadata ตาม normalized source-view contract
- `DN0302` ใน master query ใช้ `is_death` อย่างเดียว ยังไม่ยืนยันช่วงเวลา 48 ชั่วโมง; registered foundation query ใน repository จึงยังใช้ admission/death timestamp และไม่ควรถูกแทนที่โดยอัตโนมัติ
- มีรหัส MOPH ที่ไม่อยู่ใน catalogue THIP และรหัสที่ต้อง reconcile กับ PDF เช่น `DR0112`, `DR0412`, `DH0114`; adapter ต้อง reject code ที่ไม่อยู่ใน 232-code catalogue
- readmission ใช้ `HN + discharge date` เป็น approximation และยังต้องยืนยัน unplanned exclusion, transferred episode และ same-day readmission

วิธีนำ evidence นี้ไปใช้:

1. รันบน anonymized staging ด้วย `EXPLAIN`/aggregate comparison และตรวจว่าตาราง `ipt_drg_result`, field Pdx/Sdx และ `dchstts` มี semantics ตรงกับ local HOSxP version
2. แยกแต่ละ KPI ออกจาก master query ให้มี numerator/denominator/event date/code-set version ของตัวเอง
3. ทำผลลัพธ์เข้า normalized source view ตาม DDL ในหัวข้อ 8.3 พร้อมเติมแถวที่ไม่มี cohortเป็น `denominator = 0`, `value = NULL`
4. รัน duplicate/completeness audit แล้วจึงเปลี่ยน rule จาก `needs-local-mapping` เป็น `ready` หลัง domain owner sign-off

ดังนั้น local SQL นี้เป็นหลักฐานให้ลดงาน discovery ของ 32 รหัสได้ แต่ไม่ใช่เหตุผลให้ระบบแสดงผลแทน 216 รหัสที่ยังไม่มี validation และไม่ใช่ source ที่ frontend ควรส่ง raw SQL ไปเรียกเอง

## 11. Source of truth ใน repository

- Data boundary และ normalized view contract: [`docs/THIP-DATA-CONTRACT.md`](./THIP-DATA-CONTRACT.md)
- Workbook/PDF evidence notes: [`docs/THIP-SOURCE-NOTES.md`](./THIP-SOURCE-NOTES.md)
- Catalogue 232 codes: [`src/data/thipCatalogue.ts`](../src/data/thipCatalogue.ts)
- Rule manifest 232 codes and query readiness: [`src/data/thipKpiRules.ts`](../src/data/thipKpiRules.ts)
- Registered read-only queries and sixteen foundation calculations: [`src/services/queryRegistry.ts`](../src/services/queryRegistry.ts)
- Source-view query builder and response validation: [`src/services/bmsData.ts`](../src/services/bmsData.ts)

## 12. ทะเบียนตัวชี้วัดครบ 232 รหัส

ตารางต่อไปนี้สร้างจาก catalogue ใน repository แล้ว cross-check กับ detail pages ใน `THIP KPI.pdf` ครบ 232 รหัสและไม่มี duplicate code

คำอธิบายคอลัมน์:

- `PDF หน้า`: printed footer page ของ detail page
- `สูตรย่อ`: scale ที่อ่านได้จาก formula row; `a/b` หมายถึงต้องอ่านนิยามตัวหาร/ตัวตั้งตามหน้า PDF
- `Query family`: กลุ่ม extraction ที่ควรใช้ร่วมกัน
- `HOSxP candidate tables`: table ที่พบจริงใน workbook และเป็นจุดเริ่มต้น ไม่ใช่ approved mapping
- `PDF diagnosis/procedure tokens`: token ที่ extract จากหน้ารายละเอียดเพื่อช่วย review; ต้องยืนยันจากต้นฉบับก่อนลง production
- `FOUNDATION (registered)`: มี registered query ใน repository แล้ว; สถานะนี้ยังไม่แทน local clinical validation
- `SOURCE VIEW / rule pending`: ต้องทำ rule และ publish normalized source-view row ก่อน

### กลุ่ม A

| รหัส | KPI (English) | PDF หน้า | สูตรย่อ | Query family | HOSxP candidate tables | PDF diagnosis/procedure tokens (review) | สถานะ raw query |
|---|---|---:|---|---|---|---|---|
| AA0101 | Epilepsy: Hospitalization rate | 286 | a/b x 100,000 | ACSC | ovst, ovstdiag, ipt, an_stat, iptdiag, patient, person | G40, G41 | SOURCE VIEW / rule pending |
| AA0102 | COPD: Hospitalization rate | 287 | a/b x 100,000 | ACSC | ovst, ovstdiag, ipt, an_stat, iptdiag, patient, person | J10.0, J11.0, J12, J16, J18, J20, J21, J22, J40, J44, J47 | SOURCE VIEW / rule pending |
| AA0103 | Asthma: Hospitalization rate | 288 | a/b x 100,000 | ACSC | ovst, ovstdiag, ipt, an_stat, iptdiag, patient, person | J45, J46 | SOURCE VIEW / rule pending |
| AA0104 | Diabetes Mellitus (DM): Hospitalization rate | 289 | a/b x 100,000 | ACSC | ovst, ovstdiag, ipt, an_stat, iptdiag, patient, person | E10.0, E10.1, E10.6, E10.9, E11.0, E11.1, E11.6, E11.9, E13.0, E13.1, E13.6, E13.9, E14.0, E14.1, E14.6, E14.9 | SOURCE VIEW / rule pending |
| AA0105 | Hypertension: Hospitalization rate | 290 | a/b x 100,000 | ACSC | ovst, ovstdiag, ipt, an_stat, iptdiag, patient, person | I10, I11 | SOURCE VIEW / rule pending |

### กลุ่ม C

| รหัส | KPI (English) | PDF หน้า | สูตรย่อ | Query family | HOSxP candidate tables | PDF diagnosis/procedure tokens (review) | สถานะ raw query |
|---|---|---:|---|---|---|---|---|
| CA0101 | Anesthesia: Intra-operative cardiac arrest ASA physical status I, II | 180 | a/b x 10,000 | ANESTHESIA | operation_list, operation_detail, ipt, an_stat, er_regist | - | SOURCE VIEW / rule pending |
| CA0102 | Anesthesia: Percent of pre-anesthetic visit elective in-patient cases | 181 | a/b x 100 | ANESTHESIA | operation_list, operation_detail, ipt, an_stat, er_regist | - | SOURCE VIEW / rule pending |
| CA0103 | Anesthesia: Percent of patients observed in recovery room | 182 | a/b x 100 | ANESTHESIA | operation_list, operation_detail, ipt, an_stat, er_regist | - | SOURCE VIEW / rule pending |
| CA0104 | Anesthesia: Percent of re-intubation within 2 hours after extubation | 183 | a/b x 100 | ANESTHESIA | operation_list, operation_detail, ipt, an_stat, er_regist | - | SOURCE VIEW / rule pending |
| CA0105 | Anesthesia: Percent of using capnometry during general anesthesia | 184 | a/b x 100 | ANESTHESIA | operation_list, operation_detail, ipt, an_stat, er_regist | - | SOURCE VIEW / rule pending |
| CE0101 | Sepsis: Percent of broad-spectrum antibiotic receiving within 3 hours | 194 | a/b x 100 | SEPSIS_ER | ipt, an_stat, iptdiag, death, er_regist, opitemrece, drugitems | A40.0, A41.9, R57.2, R65.1 | FOUNDATION (registered) |
| CE0102 | ER: Average Emergency Department (ED) TIME-IN, TIME-OUT | 195 | a/b | ED_FLOW | ovst, er_regist, ovstdiag | - | SOURCE VIEW / rule pending |
| CE0103 | ER: Percent of Emergency patients recieveing emergency service (ED TIME-IN, TIME-OUT) within 60 minutes | 197 | a/b x 100 | ED_FLOW | ovst, er_regist, ovstdiag | - | SOURCE VIEW / rule pending |
| CE0104 | Sepsis: Percent of broad-spectrum antibiotic received within 1 hour in emergency room | 198 | a/b x 100 | SEPSIS_ER | ipt, an_stat, iptdiag, death, er_regist, opitemrece, drugitems | A40.0, A41.9, R57.2, R65.1 | SOURCE VIEW / rule pending |
| CG0101 | Pressure Ulcer/Injury: Rate of Pressure ulcer | 188 | a/b x 1,000 | PRESSURE_ULCER | ipt, an_stat, ipd_nurse_note, iptbedmove, ward | - | SOURCE VIEW / rule pending |
| CG0102 | Pressure Ulcer/Injury: Rate of Pressure ulcer in risk patients | 190 | a/b x 1,000 | PRESSURE_ULCER | ipt, an_stat, ipd_nurse_note, iptbedmove, ward | - | SOURCE VIEW / rule pending |
| CG0103 | Pressure Ulcer/Injury: Hospital-acquired pressure ulcer/Injury | 191 | a/b x 100 | PRESSURE_ULCER | ipt, an_stat, ipd_nurse_note, iptbedmove, ward | - | SOURCE VIEW / rule pending |
| CG0104 | Pressure Ulcer/Injury: Hospital-acquired pressure ulcer/Injury (HAPI) rate | 193 | a/b x 100 | PRESSURE_ULCER | ipt, an_stat, ipd_nurse_note, iptbedmove, ward | - | SOURCE VIEW / rule pending |
| CI0101 | Sepsis: Percent of mortality | 199 | a/b x 100 | SEPSIS_ER | ipt, an_stat, iptdiag, death, er_regist, opitemrece, drugitems | A40.0, A40.9, A41.0, A41.9, R57.2, R65.1 | FOUNDATION (registered) |
| CM0101 | Maternal: Mortality rate of mother from pregnancy and/or labour | 161 | a/b x 100,000 | MATERNAL_CHILD | person_anc, person_wbc, labor, ipt_pregnancy, ipt_newborn, ipt_labour_infant, ipt_labour_child | O00, O95, O98, O99, S00, T98, Z37, Z37.0, Z37.7, Z37.9 | SOURCE VIEW / rule pending |
| CM0104 | Maternal: Percent of unplanned re-admission of caesarean section within 28 days | 162 | a/b x 100 | MATERNAL_CHILD | person_anc, person_wbc, labor, ipt_pregnancy, ipt_newborn, ipt_labour_infant, ipt_labour_child | O82.0, O82.1, O82.2, O82.8, O82.9, O84.2 | SOURCE VIEW / rule pending |
| CM0105 | Maternal: Average length of stay of caesarean section | 163 | a/b | MATERNAL_CHILD | person_anc, person_wbc, labor, ipt_pregnancy, ipt_newborn, ipt_labour_infant, ipt_labour_child | - | SOURCE VIEW / rule pending |
| CM0107 | Maternal: Percent of immediate postpartum hemorrhage (Vaginal delivery) | 164 | a/b x 100 | MATERNAL_CHILD | person_anc, person_wbc, labor, ipt_pregnancy, ipt_newborn, ipt_labour_infant, ipt_labour_child | O72, O80, O81, O83, O84.0, O84.1, O84.8, O84.9 | SOURCE VIEW / rule pending |
| CM0109 | Maternal: Percent of eclampsia in pregnancy induce Hypertension | 165 | a/b x 100 | MATERNAL_CHILD | person_anc, person_wbc, labor, ipt_pregnancy, ipt_newborn, ipt_labour_infant, ipt_labour_child | O00, O15.0, O15.9, O99 | SOURCE VIEW / rule pending |
| CM0110 | Maternal: Percent of gestational DM | 166 | a/b x 100 | MATERNAL_CHILD | person_anc, person_wbc, labor, ipt_pregnancy, ipt_newborn, ipt_labour_infant, ipt_labour_child | O00, O24, O99 | SOURCE VIEW / rule pending |
| CM0116 | hysterectomy Maternal: Percent of patients who received antibiotic prophylaxis in abdominal hysterectomy | 167 | a/b x 100 | MATERNAL_CHILD | person_anc, person_wbc, labor, ipt_pregnancy, ipt_newborn, ipt_labour_infant, ipt_labour_child | - | SOURCE VIEW / rule pending |
| CM0117 | Maternal: Percent of abdominal hysterectomy associated infection | 168 | a/b x 100 | MATERNAL_CHILD | person_anc, person_wbc, labor, ipt_pregnancy, ipt_newborn, ipt_labour_infant, ipt_labour_child | - | SOURCE VIEW / rule pending |
| CM0118 | Maternal: Percent of primary cesarean section | 169 | a/b x 100 | MATERNAL_CHILD | person_anc, person_wbc, labor, ipt_pregnancy, ipt_newborn, ipt_labour_infant, ipt_labour_child | O80, O82, O84 | SOURCE VIEW / rule pending |
| CM0119 | Maternal: Percent of cesarean section with Pdx = O80-O84 and Sdx = O80-O84 (NHSO health service indicator) | 170 | a/b x 100 | MATERNAL_CHILD | person_anc, person_wbc, labor, ipt_pregnancy, ipt_newborn, ipt_labour_infant, ipt_labour_child | O80, O82, O84 | SOURCE VIEW / rule pending |
| CM0201 | Child: Perinatal mortality rate (24 weeks) | 171 | a/b x 1,000 | MATERNAL_CHILD | person_anc, person_wbc, labor, ipt_pregnancy, ipt_newborn, ipt_labour_infant, ipt_labour_child | - | SOURCE VIEW / rule pending |
| CM0202 | Child: Perinatal mortality rate (28 weeks) | 172 | a/b x 1,000 | MATERNAL_CHILD | person_anc, person_wbc, labor, ipt_pregnancy, ipt_newborn, ipt_labour_infant, ipt_labour_child | - | SOURCE VIEW / rule pending |
| CM0203 | Child: Neonatal mortality rate | 173 | a/b x 1,000 | MATERNAL_CHILD | person_anc, person_wbc, labor, ipt_pregnancy, ipt_newborn, ipt_labour_infant, ipt_labour_child | - | SOURCE VIEW / rule pending |
| CM0204 | Child: Birth asphyxia rate | 174 | a/b x 1,000 | MATERNAL_CHILD | person_anc, person_wbc, labor, ipt_pregnancy, ipt_newborn, ipt_labour_infant, ipt_labour_child | P21.0, P21.1, P21.9, Z37, Z37.0, Z37.2, Z37.3, Z37.5, Z37.6 | SOURCE VIEW / rule pending |
| CM0205 | Child: Severe birth asphyxia rate | 175 | a/b x 1,000 | MATERNAL_CHILD | person_anc, person_wbc, labor, ipt_pregnancy, ipt_newborn, ipt_labour_infant, ipt_labour_child | P21.0, P21.1, Z37, Z37.0, Z37.2, Z37.3, Z37.5, Z37.6 | SOURCE VIEW / rule pending |
| CM0206 | Child: Percent of low birth weight < 2500 grams | 176 | a/b x 100 | MATERNAL_CHILD | person_anc, person_wbc, labor, ipt_pregnancy, ipt_newborn, ipt_labour_infant, ipt_labour_child | - | SOURCE VIEW / rule pending |
| CM0207 | Child: Percent of neonatal mortality with birth weight < 1,000 grams within 28 days | 177 | a/b x 100 | MATERNAL_CHILD | person_anc, person_wbc, labor, ipt_pregnancy, ipt_newborn, ipt_labour_infant, ipt_labour_child | - | SOURCE VIEW / rule pending |
| CM0208 | Child: Percent of neonatal mortality with birth weight between 1,000 - 1,499 grams within 28 days | 178 | a/b x 100 | MATERNAL_CHILD | person_anc, person_wbc, labor, ipt_pregnancy, ipt_newborn, ipt_labour_infant, ipt_labour_child | - | SOURCE VIEW / rule pending |
| CM0209 | Child: Percent of neonatal mortality with birth weight between 1,500 - 2,499 grams within 28 days | 179 | a/b x 100 | MATERNAL_CHILD | person_anc, person_wbc, labor, ipt_pregnancy, ipt_newborn, ipt_labour_infant, ipt_labour_child | - | SOURCE VIEW / rule pending |
| CO0101 | Operation: Percent of using surgical safety check list | 185 | a/b x 100 | SURGERY | operation_list, operation_detail, operation_item, iptoprt, ipt, an_stat | - | SOURCE VIEW / rule pending |
| CO0105 | Operation: Percent of peri-operative mortality within 24 hours | 186 | a/b x 100 | SURGERY | operation_list, operation_detail, operation_item, iptoprt, ipt, an_stat | - | SOURCE VIEW / rule pending |
| CO0107 | Operation: Percent of re-operation | 187 | a/b x 100 | SURGERY | operation_list, operation_detail, operation_item, iptoprt, ipt, an_stat | - | SOURCE VIEW / rule pending |
| CP0101 | Percent of carers of children with ADHD/LD/MDD having good compliance to treatment | 200 | a/b x 100 | MENTAL_DEVELOPMENT | psych_assess_child, psych_plan, psych_therapy, depression_screen, person_wbc, ovst, ovstdiag, clinicmember | - | SOURCE VIEW / rule pending |
| CP0201 | Percent of children with Neurodevelopmental Disorder being diagnosed within 90 days after registration | 201 | a/b x 100 | MENTAL_DEVELOPMENT | psych_assess_child, psych_plan, psych_therapy, depression_screen, person_wbc, ovst, ovstdiag, clinicmember | F83, F84.0, F84.9, G80.0, G80.9, R62 | SOURCE VIEW / rule pending |

### กลุ่ม D

| รหัส | KPI (English) | PDF หน้า | สูตรย่อ | Query family | HOSxP candidate tables | PDF diagnosis/procedure tokens (review) | สถานะ raw query |
|---|---|---:|---|---|---|---|---|
| DC0103 | DM: Percent of diabetic retinopathy screening | 92 | a/b x 100 | DM_HT | clinicmember, clinic_visit, ovst, ovstdiag, opdscreen, lab_head, lab_order, lab_items, opitemrece, drugitems | E10, E11, E12, E13, E14 | SOURCE VIEW / rule pending |
| DC0107 | DM: Percent of lower-extremity amputation among patients with diabetes | 93 | a/b x 100 | DM_HT | clinicmember, clinic_visit, ovst, ovstdiag, opdscreen, lab_head, lab_order, lab_items, opitemrece, drugitems | E10, E11, E12, E13, E14 | SOURCE VIEW / rule pending |
| DC0108 | DM: Percent of good controlled of blood sugar in adult | 94 | a/b x 100 | DM_HT | clinicmember, clinic_visit, ovst, ovstdiag, opdscreen, lab_head, lab_order, lab_items, opitemrece, drugitems | E10, E11, E12, E13, E14 | SOURCE VIEW / rule pending |
| DC0108.1 | DM: Percent of good controlled of blood sugar in adult aged ≥ 60 years old | 95 | a/b x 100 | DM_HT | clinicmember, clinic_visit, ovst, ovstdiag, opdscreen, lab_head, lab_order, lab_items, opitemrece, drugitems | E10, E11, E12, E13, E14 | SOURCE VIEW / rule pending |
| DC0108.2 | DM: Percent of good controlled of blood sugar in adult aged < 60 years old | 96 | a/b x 100 | DM_HT | clinicmember, clinic_visit, ovst, ovstdiag, opdscreen, lab_head, lab_order, lab_items, opitemrece, drugitems | E10, E11, E12, E13, E14 | SOURCE VIEW / rule pending |
| DC0201 | HT: Percent of good controlled of blood pressure | 97 | a/b x 100 | DM_HT | clinicmember, clinic_visit, ovst, ovstdiag, opdscreen, lab_head, lab_order, lab_items, opitemrece, drugitems | I10, I11, I12, I13, I14, I15 | SOURCE VIEW / rule pending |
| DC0201.1 | HT: Percent of good controlled of blood pressure of patient aged < 65 years old | 99 | a/b x 100 | DM_HT | clinicmember, clinic_visit, ovst, ovstdiag, opdscreen, lab_head, lab_order, lab_items, opitemrece, drugitems | I10, I11, I12, I13, I14, I15 | SOURCE VIEW / rule pending |
| DC0201.2 | HT: Percent of good controlled of blood pressure of patient aged ≥ 65 years old | 100 | a/b x 100 | DM_HT | clinicmember, clinic_visit, ovst, ovstdiag, opdscreen, lab_head, lab_order, lab_items, opitemrece, drugitems | I10, I11, I12, I13, I14, I15 | SOURCE VIEW / rule pending |
| DC0301 | HIV: Percent of people living with HIV with at least one test viral load (VL) after ARV treatment | 101 | a/b x 100 | HIV_TB | clinicmember, clinic_visit, clinicmember_tb, tb_register, tb_register_visit, tb_lab_examination_sputum, arv_tx, arv_lab, ovstdiag | B20, B21, B22, B23, B24, Z21 | SOURCE VIEW / rule pending |
| DC0302 | HIV: Percent of people living with HIV with viral load (VL) < 50 copies/ml after ARV treatment 12 months ago | 102 | a/b x 100 | HIV_TB | clinicmember, clinic_visit, clinicmember_tb, tb_register, tb_register_visit, tb_lab_examination_sputum, arv_tx, arv_lab, ovstdiag | B20, B21, B22, B23, B24, Z21 | SOURCE VIEW / rule pending |
| DC0306 | HIV: Percent of people living with HIV screening PAP smear | 103 | a/b x 100 | HIV_TB | clinicmember, clinic_visit, clinicmember_tb, tb_register, tb_register_visit, tb_lab_examination_sputum, arv_tx, arv_lab, ovstdiag | B20, B21, B22, B23, B24, Z21 | SOURCE VIEW / rule pending |
| DC0307 | HIV: Percent of people living with HIV newly registered who were tested for syphilis | 104 | a/b x 100 | HIV_TB | clinicmember, clinic_visit, clinicmember_tb, tb_register, tb_register_visit, tb_lab_examination_sputum, arv_tx, arv_lab, ovstdiag | A51, B20, B21, B22, B23, B24, Z21 | SOURCE VIEW / rule pending |
| DC0308 | HIV: Percent of people living with HIV who were currently receiving antiretroviral therapy | 105 | a/b x 100 | HIV_TB | clinicmember, clinic_visit, clinicmember_tb, tb_register, tb_register_visit, tb_lab_examination_sputum, arv_tx, arv_lab, ovstdiag | B20, B21, B22, B23, B24, Z21 | SOURCE VIEW / rule pending |
| DC0309 | HIV: Percent of newly diagnosed people living with HIV were receiving tuberculosis preventive therapy (TPT) | 106 | a/b x 100 | HIV_TB | clinicmember, clinic_visit, clinicmember_tb, tb_register, tb_register_visit, tb_lab_examination_sputum, arv_tx, arv_lab, ovstdiag | B20, B21, B22, B23, B24, Z21 | SOURCE VIEW / rule pending |
| DC0401 | Cancer: Percent of mortality | 107 | a/b x 100 | CANCER | patient_cancer_registeration, patient_cancer_visit_stat, clinicmember_cancer, clinicmember, ovst, ovstdiag, operation_list, operation_detail | C00, C97, D00, D09, Z51.0, Z51.1 | SOURCE VIEW / rule pending |
| DC0402 | Cancer: Percent of unplanned re-admission | 108 | a/b x 100 | CANCER | patient_cancer_registeration, patient_cancer_visit_stat, clinicmember_cancer, clinicmember, ovst, ovstdiag, operation_list, operation_detail | C00, C97, D00, D09, Z51.0, Z51.1 | SOURCE VIEW / rule pending |
| DC0403 | Liver Cancer: Percent of mortality | 109 | a/b x 100 | CANCER | patient_cancer_registeration, patient_cancer_visit_stat, clinicmember_cancer, clinicmember, ovst, ovstdiag, operation_list, operation_detail | C22.0, C22.2, C22.3, C22.4, C22.5, C22.6, C22.7, C22.8, C22.9, Z51.0, Z51.1 | SOURCE VIEW / rule pending |
| DC0501 | CKD: Percent of patients who achieve the kidney function deterioration delayed target | 110 | a/b x 100 | CKD | clinicmember, clinic_ckd_member, clinic_ckd_member_visit, ovst, ovstdiag, lab_head, lab_order, lab_items, opitemrece, drugitems | I12, I13 | SOURCE VIEW / rule pending |
| DC0502 | CKD: Percent of patients who are receiving ACEIs or ARBs | 112 | a/b x 100 | CKD | clinicmember, clinic_ckd_member, clinic_ckd_member_visit, ovst, ovstdiag, lab_head, lab_order, lab_items, opitemrece, drugitems | I12, I13 | SOURCE VIEW / rule pending |
| DE0101 | Breast Cancer: Consultation time in patient with BIRADS 4 or greater mammography result | 130 | a/b | BREAST_CANCER | patient_cancer_registeration, patient_cancer_visit_stat, clinicmember_cancer, clinicmember, ovst, ovstdiag, lab_head, lab_order, lab_items | - | SOURCE VIEW / rule pending |
| DE0103 | Breast Cancer: Percent of early diagnosis of stage 1, 2 | 131 | a/b x 100 | BREAST_CANCER | patient_cancer_registeration, patient_cancer_visit_stat, clinicmember_cancer, clinicmember, ovst, ovstdiag, lab_head, lab_order, lab_items | C50 | SOURCE VIEW / rule pending |
| DE0501 | Stem Cell Transplantation: Engraftment rate within 45 days | 132 | a/b x 100 | STEM_CELL | ipt, an_stat, iptdiag, lab_head, lab_order, lab_items, operation_list, operation_detail | C91, C95, D61 | SOURCE VIEW / rule pending |
| DE0801 | TDT in Pediatrics Patient: Percent of received iron chelator in patient with iron overload (serum ferrous > 1000 ug/L) | 133 | a/b x 100 | TDT | ipt, an_stat, iptdiag, lab_head, lab_order, lab_items, opitemrece, drugitems | - | SOURCE VIEW / rule pending |
| DE1201 | Cleft Lip: Percent of patients who had cleft lip repair with under 6 months of age | 134 | a/b x 100 | CLEFT | ipt, an_stat, iptdiag, operation_list, operation_detail, operation_item | Q35, Q36, Q37 | SOURCE VIEW / rule pending |
| DE1202 | Cleft Palate: Percent of patients who had cleft Palate repair with under 18 months of age | 135 | a/b x 100 | CLEFT | ipt, an_stat, iptdiag, operation_list, operation_detail, operation_item | Q35, Q36, Q37 | SOURCE VIEW / rule pending |
| DE1301 | Infertility: Clinical pregnancy rate per Embryo Transfer following IVF/ICSI and Fresh embryo transfer (age < 34 years) | 136 | a/b x 100 | INFERTILITY | ovst, ovstdiag, operation_list, operation_detail, operation_item, lab_head, lab_order, lab_items | - | SOURCE VIEW / rule pending |
| DE1302 | Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and fresh embryo transfer (age 34 - 39 Years) | 137 | a/b x 100 | INFERTILITY | ovst, ovstdiag, operation_list, operation_detail, operation_item, lab_head, lab_order, lab_items | - | SOURCE VIEW / rule pending |
| DE1303 | Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and fresh embryo transfer (age > 40 years) | 138 | a/b x 100 | INFERTILITY | ovst, ovstdiag, operation_list, operation_detail, operation_item, lab_head, lab_order, lab_items | - | SOURCE VIEW / rule pending |
| DE1304 | Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age < 34 years) | 139 | a/b x 100 | INFERTILITY | ovst, ovstdiag, operation_list, operation_detail, operation_item, lab_head, lab_order, lab_items | - | SOURCE VIEW / rule pending |
| DE1305 | Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age 34 - 39 years) | 140 | a/b x 100 | INFERTILITY | ovst, ovstdiag, operation_list, operation_detail, operation_item, lab_head, lab_order, lab_items | - | SOURCE VIEW / rule pending |
| DE1306 | Infertility: Clinical pregnancy rate per embryo transfer following IVF/ICSI and frozen embryo transfer (age > 40 years) | 141 | a/b x 100 | INFERTILITY | ovst, ovstdiag, operation_list, operation_detail, operation_item, lab_head, lab_order, lab_items | - | SOURCE VIEW / rule pending |
| DE1401 | Upper Gastrointestinal Hemorrhage (UGIH): Percent of patients who had underwent EGD within 24 hours | 142 | a/b x 100 | UGIH | ipt, an_stat, iptdiag, operation_list, operation_detail, operation_item, lab_head, lab_order, lab_items | I85, I98.3, K22.1, K25.0, K25.1, K25.2, K25.4, K25.5, K25.6, K26.0, K26.1, K26.2, K26.4, K26.5, K26.6, K27.0, K27.1, K27.2, K27.4, K27.5, K27.6, K28.0, K28.1, K28.2, K28.4, K28.5, K28.6, K29.0, K70, K71, K74, K92.0, K92.1, K92.2 | SOURCE VIEW / rule pending |
| DE1402 | Upper Gastrointestinal Hemorrhage (UGIH): Percent of high risk patients who had underwent EGD within 24 hours | 143 | a/b x 100 | UGIH | ipt, an_stat, iptdiag, operation_list, operation_detail, operation_item, lab_head, lab_order, lab_items | I85, I98.3, K22.1, K25.0, K25.1, K25.2, K25.4, K25.5, K25.6, K26.0, K26.1, K26.2, K26.4, K26.5, K26.6, K27.0, K27.1, K27.2, K27.4, K27.5, K27.6, K28.0, K28.1, K28.2, K28.4, K28.5, K28.6, K29.0, K70, K71, K74, K92.0, K92.1, K92.2 | SOURCE VIEW / rule pending |
| DE1403 | Non-variceal Upper Gastrointestinal Hemorrhage (UGIH): Percent of hemostatic success by endoscopic approach | 145 | a/b x 100 | UGIH | ipt, an_stat, iptdiag, operation_list, operation_detail, operation_item, lab_head, lab_order, lab_items | K22.1, K25.0, K25.1, K25.2, K25.4, K25.5, K25.6, K26.0, K26.1, K26.2, K26.4, K26.5, K26.6, K27.0, K27.1, K27.2, K27.4, K27.5, K27.6, K28.0, K28.1, K28.2, K28.4, K28.5, K28.6, K29.0 | SOURCE VIEW / rule pending |
| DE1404 | Upper Gastrointestinal Hemorrhage (UGIH): Recurrent rates of UGIH after upper endoscopic treatment | 147 | a/b x 100 | UGIH | ipt, an_stat, iptdiag, operation_list, operation_detail, operation_item, lab_head, lab_order, lab_items | K25.0, K25.1, K25.2, K25.4, K25.5, K25.6, K26.0, K26.1, K26.2, K26.4, K26.5, K26.6, K27.0, K27.1, K27.2, K27.4, K27.5, K27.6, K28.0, K28.1, K28.2, K28.4, K28.5, K28.6, K29.0 | SOURCE VIEW / rule pending |
| DE1405 | Upper Gastrointestinal Hemorrhage (UGIH): Complication rates of upper endoscopic treatment | 149 | a/b x 100 | UGIH | ipt, an_stat, iptdiag, operation_list, operation_detail, operation_item, lab_head, lab_order, lab_items | I85, I98.3, K22.1, K25.0, K25.1, K25.2, K25.4, K25.5, K25.6, K26.0, K26.1, K26.2, K26.4, K26.5, K26.6, K27.0, K27.1, K27.2, K27.4, K27.5, K27.6, K28.0, K28.1, K28.2, K28.4, K28.5, K28.6, K29.0, K31.8, K70, K71, K74, K92.0, K92.1, K92.2 | SOURCE VIEW / rule pending |
| DE1601 | New born: Percent of hearing screening within 30 days | 150 | a/b x 100 | NEWBORN | ipt_newborn, ipt_pregnancy, ipt_pregnancy_vital_sign, ipt_labour_infant, ipt_labour_child, labor, person_wbc, person_anc | - | SOURCE VIEW / rule pending |
| DG0101 | Upper Gastrointestinal Hemorrhage (UGIH): Percent of unplanned re-admission into the hospital within 28 days after last discharge | 120 | a/b x 100 | UGIH | ipt, an_stat, iptdiag, operation_list, operation_detail, operation_item, lab_head, lab_order, lab_items | K25.0, K25.1, K25.2, K25.4, K25.5, K25.6, K26.0, K26.1, K26.2, K26.4, K26.5, K26.6, K27.0, K27.1, K27.2, K27.4, K27.5, K27.6, K28.0, K28.1, K28.2, K28.4, K28.5, K28.6, K29.0, K92.0, K92.1, K92.2 | SOURCE VIEW / rule pending |
| DG0102 | Upper Gastrointestinal Hemorrhage (UGIH): Average length of stay | 121 | a/b | UGIH | ipt, an_stat, iptdiag, operation_list, operation_detail, operation_item, lab_head, lab_order, lab_items | K25.0, K25.1, K25.2, K25.4, K25.5, K25.6, K26.0, K26.1, K26.2, K26.4, K26.5, K26.6, K27.0, K27.1, K27.2, K27.4, K27.5, K27.6, K28.0, K28.1, K28.2, K28.4, K28.5, K28.6, K29.0, K92.0, K92.1, K92.2 | FOUNDATION (registered) |
| DG0201 | Acute Appendicitis: Percent of abruption | 122 | a/b x 100 | APPENDICITIS | ipt, an_stat, iptdiag, death, operation_list, operation_detail, operation_item | K35, K35.2, K35.3, K35.8 | SOURCE VIEW / rule pending |
| DG0202 | Acute Appendicitis: Percent of mortality | 123 | a/b x 100 | APPENDICITIS | ipt, an_stat, iptdiag, death, operation_list, operation_detail, operation_item | K35, K35.2, K35.3, K35.8 | FOUNDATION (registered) |
| DH0101 | Acute coronary syndrome: Percent of mortality | 39 | a/b x 100 | ACS | ipt, an_stat, iptdiag, death, er_regist, opitemrece, drugitems, operation_list, operation_detail | I21.0, I21.1, I21.2, I21.3, I21.4, I21.9 | FOUNDATION (registered) |
| DH0101.1 | Acute coronary syndrome (STEMI): Percent of mortality | 40 | a/b x 100 | ACS | ipt, an_stat, iptdiag, death, er_regist, opitemrece, drugitems, operation_list, operation_detail | I21.0, I21.1, I21.2, I21.3 | FOUNDATION (registered) |
| DH0101.2 | Acute coronary syndrome (NSTE-ACS): Percent of mortality | 41 | a/b x 100 | ACS | ipt, an_stat, iptdiag, death, er_regist, opitemrece, drugitems, operation_list, operation_detail | I21.4, I21.9 | FOUNDATION (registered) |
| DH0102 | Acute coronary syndrome: Percent of patient receiving Aspirin within | 42 | a/b x 100 | ACS | ipt, an_stat, iptdiag, death, er_regist, opitemrece, drugitems, operation_list, operation_detail | I21.0, I21.1, I21.2, I21.3, I21.4, I21.9 | FOUNDATION (registered) |
| DH0103 | Acute coronary syndrome: Percent of Aspirin prescribed at discharge | 43 | a/b x 100 | ACS | ipt, an_stat, iptdiag, death, er_regist, opitemrece, drugitems, operation_list, operation_detail | I21.0, I21.1, I21.2, I21.3, I21.4, I21.9 | SOURCE VIEW / rule pending |
| DH0104 | Acute coronary syndrome: Percent of ACE inhibitors or ARB received for patient who have LVSD | 44 | a/b x 100 | ACS | ipt, an_stat, iptdiag, death, er_regist, opitemrece, drugitems, operation_list, operation_detail | I21.0, I21.1, I21.2, I21.3, I21.4, I21.9, I22.1, I22.8, I22.9 | SOURCE VIEW / rule pending |
| DH0105 | Acute coronary syndrome: Percent of smoking cessation advice given | 46 | a/b x 100 | ACS | ipt, an_stat, iptdiag, death, er_regist, opitemrece, drugitems, operation_list, operation_detail | I21.0, I21.1, I21.2, I21.3, I21.4, I21.9, I22.1, I22.8, I22.9 | SOURCE VIEW / rule pending |
| DH0106 | Acute coronary syndrome: Percent of Beta-blocker receiving during hospital admitted | 47 | a/b x 100 | ACS | ipt, an_stat, iptdiag, death, er_regist, opitemrece, drugitems, operation_list, operation_detail | I21.0, I21.1, I21.2, I21.3, I21.4, I21.9 | SOURCE VIEW / rule pending |
| DH0107 | Acute coronary syndrome: Percent of Beta-blocker prescribed at discharge | 48 | a/b x 100 | ACS | ipt, an_stat, iptdiag, death, er_regist, opitemrece, drugitems, operation_list, operation_detail | I21.0, I21.1, I21.2, I21.3, I21.4, I21.9 | SOURCE VIEW / rule pending |
| DH0108 | Acute coronary syndrome: Average door to EKG time | 49 | a/b | ACS | ipt, an_stat, iptdiag, death, er_regist, opitemrece, drugitems, operation_list, operation_detail | I21.0, I21.1, I21.2, I21.3, I21.4, I21.9, I22.1, I22.8, I22.9 | SOURCE VIEW / rule pending |
| DH0109 | Acute coronary syndrome: Average door to refer time | 50 | a/b | ACS | ipt, an_stat, iptdiag, death, er_regist, opitemrece, drugitems, operation_list, operation_detail | I21.0, I21.1, I21.2, I21.3, I21.4, I21.9, I22.1, I22.8, I22.9 | SOURCE VIEW / rule pending |
| DH0110 | Acute coronary syndrome: Percent of Primary Percutaneous Coronary Intervention (PCI) given within 120 minutes or received Fibrinolytic agent within 30 minutes of arrival | 51 | a/b x 100 | ACS | ipt, an_stat, iptdiag, death, er_regist, opitemrece, drugitems, operation_list, operation_detail | I21.0, I21.1, I21.2, I21.3 | SOURCE VIEW / rule pending |
| DH0111 | Acute coronary syndrome: Percent of unplanned re-admission within | 53 | a/b x 100 | ACS | ipt, an_stat, iptdiag, death, er_regist, opitemrece, drugitems, operation_list, operation_detail | I21.0, I21.1, I21.2, I21.3, I21.4, I21.9, I22.1, I22.8, I22.9 | SOURCE VIEW / rule pending |
| DH0112 | Acute coronary syndrome: Average length of stay | 54 | a/b | ACS | ipt, an_stat, iptdiag, death, er_regist, opitemrece, drugitems, operation_list, operation_detail | I21.0, I21.1, I21.2, I21.3, I21.4, I21.9 | FOUNDATION (registered) |
| DH0113 | Acute coronary syndrome: Percent of time to Fibrinolytic administration agents within 30 minutes of arrival | 55 | a/b x 100 | ACS | ipt, an_stat, iptdiag, death, er_regist, opitemrece, drugitems, operation_list, operation_detail | I21.0, I21.1, I21.2, I21.3, I21.4, I21.9 | SOURCE VIEW / rule pending |
| DH0201 | Coronary Artery Bypass Graft (CABG): Percent of mortality | 57 | a/b x 100 | CABG | ipt, an_stat, iptdiag, death, operation_list, operation_detail, operation_item, opitemrece, drugitems | - | SOURCE VIEW / rule pending |
| DH0202 | Coronary Artery Bypass Graft (CABG): Percent of patient who received antibiotic prophylaxis | 58 | a/b x 100 | CABG | ipt, an_stat, iptdiag, death, operation_list, operation_detail, operation_item, opitemrece, drugitems | - | SOURCE VIEW / rule pending |
| DH0203 | Coronary Artery Bypass Graft (CABG): Percent of surgical site Infection | 59 | a/b x 100 | CABG | ipt, an_stat, iptdiag, death, operation_list, operation_detail, operation_item, opitemrece, drugitems | - | SOURCE VIEW / rule pending |
| DH0204 | Coronary Artery Bypass Graft (CABG): percent of 30-days hospital mortality | 60 | a/b x 100 | CABG | ipt, an_stat, iptdiag, death, operation_list, operation_detail, operation_item, opitemrece, drugitems | - | SOURCE VIEW / rule pending |
| DH0301 | Fraction (HFREF) received Angiotensin II Converting Enzyme inhibitors (ACEIs) or Angiotensin II Receptor Blockers (ARBs) or Mineralocorticoid Receptor Antagonists (MRA) | 61 | a/b x 100 | HEART_FAILURE | ipt, an_stat, iptdiag, clinicmember, ovstdiag, opitemrece, drugitems, lab_head, lab_order, lab_items | I50 | SOURCE VIEW / rule pending |
| DH0302 | Heart failure: Percent of smoking cessation advice given | 63 | a/b x 100 | HEART_FAILURE | ipt, an_stat, iptdiag, clinicmember, ovstdiag, opitemrece, drugitems, lab_head, lab_order, lab_items | I50 | SOURCE VIEW / rule pending |
| DH0401 | Atrial fibrillation: Percent of patient received Warfarin within target | 64 | a/b x 100 | ATRIAL_FIBRILLATION | ipt, an_stat, iptdiag, death, clinicmember, ovstdiag, opitemrece, drugitems, lab_head, lab_order, lab_items | - | SOURCE VIEW / rule pending |
| DH0402 | Atrial Fibrillation: Percent of major bleeding (intracranial hemorrhage) | 66 | a/b x 100 | ATRIAL_FIBRILLATION | ipt, an_stat, iptdiag, death, clinicmember, ovstdiag, opitemrece, drugitems, lab_head, lab_order, lab_items | - | SOURCE VIEW / rule pending |
| DM0101 | GDD: Percent of children with global development delay that improved after intervented | 151 | a/b x 100 | MENTAL_DEVELOPMENT | psych_assess_child, psych_plan, psych_therapy, depression_screen, person_wbc, ovst, ovstdiag, clinicmember | F83, R62 | SOURCE VIEW / rule pending |
| DM0102 | GDD: Percent of children with Global development delay that improved after intervented with TEDA4I | 152 | a/b x 100 | MENTAL_DEVELOPMENT | psych_assess_child, psych_plan, psych_therapy, depression_screen, person_wbc, ovst, ovstdiag, clinicmember | F83, R62 | SOURCE VIEW / rule pending |
| DM0103 | GDD: Percent of children with global development delay that improved after intervented | 153 | a/b x 100 | MENTAL_DEVELOPMENT | psych_assess_child, psych_plan, psych_therapy, depression_screen, person_wbc, ovst, ovstdiag, clinicmember | F83, R62 | SOURCE VIEW / rule pending |
| DM0201 | ASD: Percent of children with autism spectrum disorder (ASD) with social and communication skills improvement | 154 | a/b x 100 | MENTAL_DEVELOPMENT | psych_assess_child, psych_plan, psych_therapy, depression_screen, person_wbc, ovst, ovstdiag, clinicmember | F84.0, F84.9 | SOURCE VIEW / rule pending |
| DM0202 | ASD: Percent of children with autism spectrum disorder (ASD) with social and communication skills improvement with TEDA4I | 155 | a/b x 100 | MENTAL_DEVELOPMENT | psych_assess_child, psych_plan, psych_therapy, depression_screen, person_wbc, ovst, ovstdiag, clinicmember | F84.0, F84.9 | SOURCE VIEW / rule pending |
| DM0203 | ASD: Percent of children with autism spectrum disorder (ASD) that are included in educational system for at least 1 year | 156 | a/b x 100 | MENTAL_DEVELOPMENT | psych_assess_child, psych_plan, psych_therapy, depression_screen, person_wbc, ovst, ovstdiag, clinicmember | F84.0, F84.9 | SOURCE VIEW / rule pending |
| DM0301 | Cerebral Palsy: Percent of children with cerebral palsy that improved after intervented | 157 | a/b x 100 | MENTAL_DEVELOPMENT | psych_assess_child, psych_plan, psych_therapy, depression_screen, person_wbc, ovst, ovstdiag, clinicmember | G80.0, G80.9 | SOURCE VIEW / rule pending |
| DM0302 | Cerebral Palsy: Percent of children with cerebral palsy that improved after intervented | 158 | a/b x 100 | MENTAL_DEVELOPMENT | psych_assess_child, psych_plan, psych_therapy, depression_screen, person_wbc, ovst, ovstdiag, clinicmember | G80.0, G80.9 | SOURCE VIEW / rule pending |
| DM0401 | Child and adolescent psychiatry: Percent of children with Attention- Deficit Hyperactivity Disorder (ADHD) improved after intervented for 6 | 159 | a/b x 100 | MENTAL_DEVELOPMENT | psych_assess_child, psych_plan, psych_therapy, depression_screen, person_wbc, ovst, ovstdiag, clinicmember | F90 | SOURCE VIEW / rule pending |
| DM0402 | Child and adolescent psychiatry: Percent of children and adolescents with Major Depressive Disorder (MDD) improved after intervented for | 160 | a/b x 100 | MENTAL_DEVELOPMENT | psych_assess_child, psych_plan, psych_therapy, depression_screen, person_wbc, ovst, ovstdiag, clinicmember | F32.0, F32.9, F33.0, F33.9, F34.1 | SOURCE VIEW / rule pending |
| DN0101 | Stroke: Percent of mortality | 67 | a/b x 100 | STROKE | ipt, an_stat, iptdiag, death, er_regist, operation_list, operation_detail, opitemrece, drugitems | I60, I61, I62, I63, I64, I65, I66, I67 | FOUNDATION (registered) |
| DN0102 | Ischemic stroke: Percent of patient receiving Antiplatelet within 2 days of hospital admission | 68 | a/b x 100 | STROKE | ipt, an_stat, iptdiag, death, er_regist, operation_list, operation_detail, opitemrece, drugitems | I63, I64, I65, I66 | SOURCE VIEW / rule pending |
| DN0103 | Ischemic stroke: Percent of Antiplatelet or Anticoagulant therapy prescribed at discharge | 69 | a/b x 100 | STROKE | ipt, an_stat, iptdiag, death, er_regist, operation_list, operation_detail, opitemrece, drugitems | I63.0, I63.1, I63.2, I63.3, I63.4, I63.5, I63.6, I63.7, I63.8, I63.9 | SOURCE VIEW / rule pending |
| DN0104 | Ischemic stroke: Percent of patient with Atrial fibrillation/Flutter receiving Anticoagulation therapy | 70 | a/b x 100 | STROKE | ipt, an_stat, iptdiag, death, er_regist, operation_list, operation_detail, opitemrece, drugitems | I48, I63 | SOURCE VIEW / rule pending |
| DN0105 | Stroke: Percent of patients who were given stroke education during their hospital stay | 71 | a/b x 100 | STROKE | ipt, an_stat, iptdiag, death, er_regist, operation_list, operation_detail, opitemrece, drugitems | I60, I61, I62, I63, I64, I65, I66, I67 | SOURCE VIEW / rule pending |
| DN0106 | Stroke: Percent of treatment, physiotherapy or rehabilitation in stroke or paralytic syndrome within 72 hours | 72 | a/b x 100 | STROKE | ipt, an_stat, iptdiag, death, er_regist, operation_list, operation_detail, opitemrece, drugitems | I60, I61, I62, I63, I64, I65, I66, I67 | SOURCE VIEW / rule pending |
| DN0107 | Stroke: Percent of unplanned re-admission of stroke within 28 days | 73 | a/b x 100 | STROKE | ipt, an_stat, iptdiag, death, er_regist, operation_list, operation_detail, opitemrece, drugitems | I60, I61, I62, I63, I64, I65, I66, I67 | FOUNDATION (registered) |
| DN0109 | Stroke: Average length of stay | 74 | a/b | STROKE | ipt, an_stat, iptdiag, death, er_regist, operation_list, operation_detail, opitemrece, drugitems | I60, I61, I62, I63, I64, I65, I66, I67 | FOUNDATION (registered) |
| DN0110 | Ischemic Stroke: Percent of time to Thrombolytic administration agents within 60 minutes of arrival | 75 | a/b x 100 | STROKE | ipt, an_stat, iptdiag, death, er_regist, operation_list, operation_detail, opitemrece, drugitems | I63, I64, I65, I66, I67 | SOURCE VIEW / rule pending |
| DN0301 | Head Injury: Percent of unplanned re-admission of Craniotomy within | 76 | a/b x 100 | HEAD_INJURY | ipt, an_stat, iptdiag, death, operation_list, operation_detail, operation_item | - | SOURCE VIEW / rule pending |
| DN0302 | Head Injury: Percent of mortality within 48 hours | 77 | a/b x 100 | HEAD_INJURY | ipt, an_stat, death | S06.0, S06.1, S06.2, S06.3, S06.4, S06.5, S06.6, S06.7, S06.8, S06.9 | FOUNDATION (registered) |
| DN0303 | Head Injury: Percent of patient underwent craniotomy for Intracranial | 78 | a/b x 100 | HEAD_INJURY | ipt, an_stat, iptdiag, death, operation_list, operation_detail, operation_item | S06.0, S06.1, S06.2, S06.3, S06.4, S06.5, S06.6, S06.7, S06.8, S06.9 | SOURCE VIEW / rule pending |
| DO0202 | Hip arthroplasty: Percent of patients who received antibiotic prophylaxis in Hip arthroplasty | 114 | a/b x 100 | ARTHROPLASTY | ipt, an_stat, iptdiag, operation_list, operation_detail, operation_item, opitemrece, drugitems | - | SOURCE VIEW / rule pending |
| DO0204 | Hip arthroplasty: Percent of hip arthroplasty associated infection within 1 Year | 115 | a/b x 100 | ARTHROPLASTY | ipt, an_stat, iptdiag, operation_list, operation_detail, operation_item, opitemrece, drugitems | - | SOURCE VIEW / rule pending |
| DO0205 | Hip arthroplasty: Percent of hip arthroplasty associated infection within 90 days | 116 | a/b x 100 | ARTHROPLASTY | ipt, an_stat, iptdiag, operation_list, operation_detail, operation_item, opitemrece, drugitems | - | SOURCE VIEW / rule pending |
| DO0302 | Knee Arthroplasty: Percent of patients who received antibiotic prophylaxis | 117 | a/b x 100 | ARTHROPLASTY | ipt, an_stat, iptdiag, operation_list, operation_detail, operation_item, opitemrece, drugitems | - | SOURCE VIEW / rule pending |
| DO0303 | Knee Arthroplasty: Percent of surgical infection within 1 year | 118 | a/b x 100 | ARTHROPLASTY | ipt, an_stat, iptdiag, operation_list, operation_detail, operation_item, opitemrece, drugitems | - | SOURCE VIEW / rule pending |
| DO0304 | Knee Arthroplasty: Percent of surgical infection within 90 days | 119 | a/b x 100 | ARTHROPLASTY | ipt, an_stat, iptdiag, operation_list, operation_detail, operation_item, opitemrece, drugitems | - | SOURCE VIEW / rule pending |
| DP0101 | Diabetes in child and adolescent: Percent of good controlled of blood sugar (age < 18 years) | 124 | a/b x 100 | PEDIATRIC_DM | person, clinicmember, ovst, ovstdiag, opdscreen, lab_head, lab_order, lab_items | E10, E89.1, P70.2 | SOURCE VIEW / rule pending |
| DR0101 | Pneumonia: Percent of mortality after hospital admission | 79 | a/b x 100 | PNEUMONIA | ipt, an_stat, iptdiag, death, opitemrece, drugitems | J10.0, J11.0, J12, J16, J17.0, J17.1, J17.2, J17.3, J17.8, J18, J85.0, J85.1 | FOUNDATION (registered) |
| DR0102 | Pneumonia: Percent of unplanned re-admission within 28 days after last discharge | 80 | a/b x 100 | PNEUMONIA | ipt, an_stat, iptdiag, death, opitemrece, drugitems | J10.0, J11.0, J12, J16, J17.0, J17.1, J17.2, J17.3, J17.8, J18, J85.0, J85.1 | FOUNDATION (registered) |
| DR0103 | Pneumonia: Percent of smoking cessation advice given | 81 | a/b x 100 | PNEUMONIA | ipt, an_stat, iptdiag, death, opitemrece, drugitems | J10.0, J11.0, J12, J16, J17.0, J17.1, J17.2, J17.3, J17.8, J18, J85.0, J85.1 | SOURCE VIEW / rule pending |
| DR0201 | TB: Percent of mortality during 12 months | 82 | a/b x 100 | HIV_TB | clinicmember, clinic_visit, clinicmember_tb, tb_register, tb_register_visit, tb_lab_examination_sputum, arv_tx, arv_lab, ovstdiag | A15, A16 | SOURCE VIEW / rule pending |
| DR0202 | TB: Percentage of people living with HIV having a TB screening | 83 | a/b x 100 | HIV_TB | clinicmember, clinic_visit, clinicmember_tb, tb_register, tb_register_visit, tb_lab_examination_sputum, arv_tx, arv_lab, ovstdiag | B20, B21, B22, B23, B24, Z21 | SOURCE VIEW / rule pending |
| DR0203 | TB: Percent of treatment success | 84 | a/b x 100 | HIV_TB | clinicmember, clinic_visit, clinicmember_tb, tb_register, tb_register_visit, tb_lab_examination_sputum, arv_tx, arv_lab, ovstdiag | A15, A16 | SOURCE VIEW / rule pending |
| DR0204 | TB: Percent of TB having a HIV screening | 85 | a/b x 100 | HIV_TB | clinicmember, clinic_visit, clinicmember_tb, tb_register, tb_register_visit, tb_lab_examination_sputum, arv_tx, arv_lab, ovstdiag | A15, A16 | SOURCE VIEW / rule pending |
| DR0205 | Antiretroviral therapy (ART) TB: Percent of HIV-positive TB patients started on Antiretroviral therapy (ART) | 86 | a/b x 100 | HIV_TB | clinicmember, clinic_visit, clinicmember_tb, tb_register, tb_register_visit, tb_lab_examination_sputum, arv_tx, arv_lab, ovstdiag | A15, A16, B20, B21, B22, B23, B24, Z21 | SOURCE VIEW / rule pending |
| DR0301 | Asthma: Percent of unplanned re-admission within 28 days after last discharge | 87 | a/b x 100 | ASTHMA_COPD | patient_asthma_screen, patient_copd_screen, clinicmember, clinic_visit, ovst, ovstdiag, opdscreen | J45, J46 | SOURCE VIEW / rule pending |
| DR0302 | Asthma: Percent of smoking cessation advice given | 88 | a/b x 100 | ASTHMA_COPD | patient_asthma_screen, patient_copd_screen, clinicmember, clinic_visit, ovst, ovstdiag, opdscreen | J45, J46 | SOURCE VIEW / rule pending |
| DR0401 | COPD: Percent of unplanned re-admission into the hospital within 28 days after last discharge | 89 | a/b x 100 | ASTHMA_COPD | patient_asthma_screen, patient_copd_screen, clinicmember, clinic_visit, ovst, ovstdiag, opdscreen | J44 | SOURCE VIEW / rule pending |
| DR0403 | COPD: Percent of mortality | 90 | a/b x 100 | ASTHMA_COPD | patient_asthma_screen, patient_copd_screen, clinicmember, clinic_visit, ovst, ovstdiag, opdscreen | J44 | FOUNDATION (registered) |
| DR0404 | COPD: Percent of patient with ongoing smoking | 91 | a/b x 100 | ASTHMA_COPD | patient_asthma_screen, patient_copd_screen, clinicmember, clinic_visit, ovst, ovstdiag, opdscreen | J44 | SOURCE VIEW / rule pending |
| DS0101 | Methamphetamine Group: 3 months total remission rate | 126 | a/b x 100 | MENTAL_DEVELOPMENT | psych_assess_child, psych_plan, psych_therapy, depression_screen, person_wbc, ovst, ovstdiag, clinicmember | F15.0, F15.9 | SOURCE VIEW / rule pending |
| DS0201 | Alcohol Group: 3 months total remission rate | 127 | a/b x 100 | MENTAL_DEVELOPMENT | psych_assess_child, psych_plan, psych_therapy, depression_screen, person_wbc, ovst, ovstdiag, clinicmember | F10.0, F10.9 | SOURCE VIEW / rule pending |
| DS0301 | Tobacco Group: 3 months total remission rate | 128 | a/b x 100 | MENTAL_DEVELOPMENT | psych_assess_child, psych_plan, psych_therapy, depression_screen, person_wbc, ovst, ovstdiag, clinicmember | F17.0, F17.9 | SOURCE VIEW / rule pending |
| DS0401 | Opioid Group: 1 year retention rate of opioid in methadone maintenance program | 129 | a/b x 100 | MENTAL_DEVELOPMENT | psych_assess_child, psych_plan, psych_therapy, depression_screen, person_wbc, ovst, ovstdiag, clinicmember | F11.0, F11.9 | SOURCE VIEW / rule pending |

### กลุ่ม H

| รหัส | KPI (English) | PDF หน้า | สูตรย่อ | Query family | HOSxP candidate tables | PDF diagnosis/procedure tokens (review) | สถานะ raw query |
|---|---|---:|---|---|---|---|---|
| HC0101 | Customer: Asthma patients or their relative(s) who are able to care for the patient's needs | 270 | a/b | CHRONIC_ED | patient_asthma_screen, patient_copd_screen, clinicmember, clinic_visit, ovst, ovstdiag, opdscreen | J45, J46 | SOURCE VIEW / rule pending |
| HC0102 | Customer: COPD patients or their relative(s) who are able to care for the patient's needs | 271 | a/b x 100 | CHRONIC_ED | patient_asthma_screen, patient_copd_screen, clinicmember, clinic_visit, ovst, ovstdiag, opdscreen | J44.0, J44.1, J44.2 | SOURCE VIEW / rule pending |
| HE0101 | Employee: Percent of employee check-up | 264 | a/b x 100 | EMPLOYEE | emp, emp_history, emp_stat, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department | - | SOURCE VIEW / rule pending |
| HE0102 | Employee: Percent of employee have exceeding BMI | 265 | a/b x 100 | EMPLOYEE | emp, emp_history, emp_stat, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department | - | SOURCE VIEW / rule pending |
| HE0103 | Employee: Percent of employee have behavior-smoky | 266 | a/b x 100 | EMPLOYEE | emp, emp_history, emp_stat, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department | - | SOURCE VIEW / rule pending |
| HE0104 | Employee: Percent of employee (male) obesity | 267 | a/b x 100 | EMPLOYEE | emp, emp_history, emp_stat, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department | - | SOURCE VIEW / rule pending |
| HE0105 | Employee: Percent of employee (female) obesity | 268 | a/b x 100 | EMPLOYEE | emp, emp_history, emp_stat, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department | - | SOURCE VIEW / rule pending |
| HE0106 | Employee: Percent of employee received Influenza immunization | 269 | a/b x 100 | EMPLOYEE | emp, emp_history, emp_stat, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department | - | SOURCE VIEW / rule pending |
| HH0101.1 | Tobacco Use: Percent of smoking tobacco products used by service recipients | 272 | a/b x 100 | TOBACCO | opdscreen, patient_asthma_screen, patient_copd_screen, clinicmember, clinic_visit, ovst, ovstdiag, person_anc | F17.2, Z72.0 | SOURCE VIEW / rule pending |
| HH0101.2 | Tobacco Use: Percent of Tobacco Use Screened of Service Recipients aged ≥ 15 years old at the Outpatient Service. | 273 | a/b x 100 | TOBACCO | opdscreen, patient_asthma_screen, patient_copd_screen, clinicmember, clinic_visit, ovst, ovstdiag, person_anc | F17.2, Z72.0 | SOURCE VIEW / rule pending |
| HH0102 | Tobacco Use: Percentage of nicotine dependence patients receiving nicotine dependence treatment. | 274 | a/b x 100 | TOBACCO | opdscreen, patient_asthma_screen, patient_copd_screen, clinicmember, clinic_visit, ovst, ovstdiag, person_anc | F17.2 | SOURCE VIEW / rule pending |
| HH0103.1 | Tobacco Use: Percentage of nicotine dependence in DM patients receiving nicotine dependence treatment. | 275 | a/b x 100 | TOBACCO | opdscreen, patient_asthma_screen, patient_copd_screen, clinicmember, clinic_visit, ovst, ovstdiag, person_anc | E10, E11, E12, E13, E14, F17.2 | SOURCE VIEW / rule pending |
| HH0103.2 | Tobacco Use: Percentage of nicotine dependence in Hypertension patients receiving nicotine dependence treatment. | 276 | a/b x 100 | TOBACCO | opdscreen, patient_asthma_screen, patient_copd_screen, clinicmember, clinic_visit, ovst, ovstdiag, person_anc | F17.2, I10, I11, I12, I13, I14, I15 | SOURCE VIEW / rule pending |
| HH0103.3 | Tobacco Use: Percentage of nicotine dependence in Asthma patients receiving nicotine dependence treatment | 277 | a/b x 100 | TOBACCO | opdscreen, patient_asthma_screen, patient_copd_screen, clinicmember, clinic_visit, ovst, ovstdiag, person_anc | F17.2, J45, J46 | SOURCE VIEW / rule pending |
| HH0103.4 | Tobacco Use: Percentage of nicotine dependence in COPD patients receiving nicotine dependence treatment. | 278 | a/b x 100 | TOBACCO | opdscreen, patient_asthma_screen, patient_copd_screen, clinicmember, clinic_visit, ovst, ovstdiag, person_anc | F17.2, J44 | SOURCE VIEW / rule pending |
| HH0103.5 | Tobacco Use: Percentage of nicotine dependence in Pregnant patients receiving nicotine dependence treatment. | 279 | a/b x 100 | TOBACCO | opdscreen, patient_asthma_screen, patient_copd_screen, clinicmember, clinic_visit, ovst, ovstdiag, person_anc | F17.2 | SOURCE VIEW / rule pending |
| HH0103.6 | Tobacco Use: Percentage of nicotine dependence in Asthma patients receiving nicotine dependence treatment. | 280 | a/b x 100 | TOBACCO | opdscreen, patient_asthma_screen, patient_copd_screen, clinicmember, clinic_visit, ovst, ovstdiag, person_anc | F17.2 | SOURCE VIEW / rule pending |
| HH0104.1 | Tobacco use: continuous abstinence rate (CAR) at 6 months (DM Patients) | 281 | a/b x 100 | TOBACCO | opdscreen, patient_asthma_screen, patient_copd_screen, clinicmember, clinic_visit, ovst, ovstdiag, person_anc | E10, E11, E12, E13, E14, F17.2 | SOURCE VIEW / rule pending |
| HH0104.2 | Tobacco use: continuous abstinence rate (CAR) at 6 months (Hypertension Patients) | 282 | a/b x 100 | TOBACCO | opdscreen, patient_asthma_screen, patient_copd_screen, clinicmember, clinic_visit, ovst, ovstdiag, person_anc | F17.2, I10, I11, I12, I13, I14, I15 | SOURCE VIEW / rule pending |
| HH0104.3 | Tobacco use: continuous abstinence rate (CAR) at 6 months (Asthma Patients) | 283 | a/b x 100 | TOBACCO | opdscreen, patient_asthma_screen, patient_copd_screen, clinicmember, clinic_visit, ovst, ovstdiag, person_anc | F17.2, J45, J46 | SOURCE VIEW / rule pending |
| HH0104.4 | Tobacco use: continuous abstinence rate (CAR) at 6 months (COPD Patients) | 284 | a/b x 100 | TOBACCO | opdscreen, patient_asthma_screen, patient_copd_screen, clinicmember, clinic_visit, ovst, ovstdiag, person_anc | F17.2, J44 | SOURCE VIEW / rule pending |
| HH0104.5 | Tobacco use: Tobacco use: continuous abstinence rate (CAR) at 6 months (Pregnant Patients) | 285 | a/b x 100 | TOBACCO | opdscreen, patient_asthma_screen, patient_copd_screen, clinicmember, clinic_visit, ovst, ovstdiag, person_anc | - | SOURCE VIEW / rule pending |

### กลุ่ม S

| รหัส | KPI (English) | PDF หน้า | สูตรย่อ | Query family | HOSxP candidate tables | PDF diagnosis/procedure tokens (review) | สถานะ raw query |
|---|---|---:|---|---|---|---|---|
| SC0101 | Customer: Percent of outpatient satisfaction (overall) | 250 | a/b x 100 | CUSTOMER | survey_satisfy_head_pcu, survey_satisfy_screen_pcu, survey_satisfy_choice_pcu, dis_satisfied, dis_satisfied_result, dis_satisfied_topic | - | SOURCE VIEW / rule pending |
| SC0102 | Customer: Percent of inpatient satisfaction (overall) | 251 | a/b x 100 | CUSTOMER | survey_satisfy_head_pcu, survey_satisfy_screen_pcu, survey_satisfy_choice_pcu, dis_satisfied, dis_satisfied_result, dis_satisfied_topic | - | SOURCE VIEW / rule pending |
| SC0103 | Customer: Percent of outpatients who return to receive care | 252 | a/b x 100 | CUSTOMER | survey_satisfy_head_pcu, survey_satisfy_screen_pcu, survey_satisfy_choice_pcu, dis_satisfied, dis_satisfied_result, dis_satisfied_topic | - | SOURCE VIEW / rule pending |
| SC0104 | Customer: Percent of inpatients who return to receive care | 253 | a/b x 100 | CUSTOMER | survey_satisfy_head_pcu, survey_satisfy_screen_pcu, survey_satisfy_choice_pcu, dis_satisfied, dis_satisfied_result, dis_satisfied_topic | - | SOURCE VIEW / rule pending |
| SC0105 | Customer: Percent of outpatients who would recommend friends or family to receive care at this facility | 254 | a/b x 100 | CUSTOMER | survey_satisfy_head_pcu, survey_satisfy_screen_pcu, survey_satisfy_choice_pcu, dis_satisfied, dis_satisfied_result, dis_satisfied_topic | - | SOURCE VIEW / rule pending |
| SC0106 | Customer: Percent of inpatients who would recommend friends or family to receive care at this facility | 255 | a/b x 100 | CUSTOMER | survey_satisfy_head_pcu, survey_satisfy_screen_pcu, survey_satisfy_choice_pcu, dis_satisfied, dis_satisfied_result, dis_satisfied_topic | - | SOURCE VIEW / rule pending |
| SF0101 | Financial: Current ratio | 244 | a/b | FINANCE | an_stat, ipt, opitemrece, stock_item, stock_trancation | - | SOURCE VIEW / rule pending |
| SF0102 | Financial: Quick ratio | 245 | a/b | FINANCE | an_stat, ipt, opitemrece, stock_item, stock_trancation | - | SOURCE VIEW / rule pending |
| SF0103 | Financial: Fixed asset turnover | 246 | a/b | FINANCE | an_stat, ipt, opitemrece, stock_item, stock_trancation | - | SOURCE VIEW / rule pending |
| SF0104 | Financial: Day in account receivable (average collection period for account receivables) | 247 | a/b | FINANCE | an_stat, ipt, opitemrece, stock_item, stock_trancation | - | SOURCE VIEW / rule pending |
| SF0105 | Financial: Net profit margin | 248 | a/b x 100 | FINANCE | an_stat, ipt, opitemrece, stock_item, stock_trancation | - | SOURCE VIEW / rule pending |
| SF0106 | Financial: Return on asset (ROA) | 249 | a/b x 100 | FINANCE | an_stat, ipt, opitemrece, stock_item, stock_trancation | - | SOURCE VIEW / rule pending |
| SG0104 | Governance: Percent of recycled waste | 256 | a/b | GOVERNANCE | stock_item, stock_trancation, stock_daily_balance_record, stock_item_balance_history, supply_sterile, supply_sterile_item | - | SOURCE VIEW / rule pending |
| SH0101 | HRM: Turnover rate | 212 | a/b x 100 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0102 | HRM: Percent of employee work-related Injury | 213 | a/b x 100 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0103 | HRM: Percent of employee work-related Illness | 214 | a/b x 100 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0104 | HRM: Turnover rate of physician and dentist | 215 | a/b x 100 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0105 | HRM: Turnover rate of nurses | 216 | a/b x 100 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0106 | HRM: Turnover rate of allied health personnel | 217 | a/b x 100 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0107 | HRM: Turnover rate of back office personnel | 218 | a/b x 100 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0201 | HRD: Percent of physician/dentist satisfaction (level 4-5) | 219 | a/b x 100 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0202 | HRD: Percent of nurse satisfaction (level 4-5) | 220 | a/b x 100 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0203 | HRD: Percent of allied health personel satisfaction (level 4-5) | 221 | a/b x 100 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0204 | HRD: Training hour per person per year of physician/dentist | 222 | a/b | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0205 | HRD: HRD: Training hour per person per Year of nurse | 223 | a/b | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0206 | HRD: Percent of physician and dentist satisfaction (average) | 224 | a/b x 100 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0207 | HRD: Percent of physician and dentist satisfaction (level 1-2) | 225 | a/b x 100 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0208 | HRD: Percentage of nurse satisfaction (average) | 226 | a/b x 100 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0209 | HRD: Percentage of nurse satisfaction (level 1-2) | 227 | a/b x 100 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0210 | HRD: Percent of allied health personnel satisfaction (average) | 228 | a/b x 100 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0211 | HRD: Percent of allied health personnel satisfaction (level 1-2) | 229 | a/b x 100 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0212 | HRD: Percent of back office personnel satisfaction (average) | 230 | a/b x 100 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0213 | HRD: Percentage of back office personnel satisfaction (level 4-5) | 231 | a/b x 100 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0214 | HRD: Percentage of back office personnel satisfaction (level 1-2) | 232 | a/b x 100 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0215 | HRD: Training hour per person per year of allied health personnel | 233 | a/b | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0216 | HRD: Training hour per person per year of back office personnel | 234 | a/b | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0301 | HRH: Injury (Illnesses) Frequency Rate (IFR) | 235 | a/b x 1,000,000 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0302 | HRH: Injury Severity Rate: ISR of Direct Contact with Patients | 236 | a/b x 1,000,000 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0303 | HRH: Injury Severity Rate: ISRof non Direct Contact with Patients | 238 | a/b x 1,000,000 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0306 | HRH: Injury (illnesses) Frequency Rate: IFR of direct contact with patients | 240 | a/b x 1,000,000 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SH0307 | HRH: Injury (Illnesses) Frequency Rate : IFR of Non-direct Contact with Patients | 242 | a/b x 1,000,000 | HR | emp, emp_history, emp_in_out, emp_resign, emp_stat, emp_work_sick, emp_work_status, emp_work_summary, emp_work_schedule, emp_position, emp_department, emp_education | - | SOURCE VIEW / rule pending |
| SI0101 | VAP: Rate of ventilator-associated pneumonia (All) | 202 | a/b x 1,000 | INFECTION | ipd_nurse_note, ipt, iptbedmove, ward, operation_list, operation_detail, lab_head, lab_order, lab_items | - | SOURCE VIEW / rule pending |
| SI0102 | VAP: Rate of ventilator-associated pneumonia in ICU | 203 | a/b x 1,000 | INFECTION | ipd_nurse_note, ipt, iptbedmove, ward, operation_list, operation_detail, lab_head, lab_order, lab_items | - | SOURCE VIEW / rule pending |
| SI0103 | VAP: Rate of ventilator-associated pneumonia outside ICU | 204 | a/b x 1,000 | INFECTION | ipd_nurse_note, ipt, iptbedmove, ward, operation_list, operation_detail, lab_head, lab_order, lab_items | - | SOURCE VIEW / rule pending |
| SI0201 | BSI: Rate of CABSI (All) | 205 | a/b x 1,000 | INFECTION | ipd_nurse_note, ipt, iptbedmove, ward, operation_list, operation_detail, lab_head, lab_order, lab_items | - | SOURCE VIEW / rule pending |
| SI0202 | BSI: Rate of CABSI in ICU | 206 | a/b x 1,000 | INFECTION | ipd_nurse_note, ipt, iptbedmove, ward, operation_list, operation_detail, lab_head, lab_order, lab_items | - | SOURCE VIEW / rule pending |
| SI0203 | BSI: Rate of CABSI outside ICU | 207 | a/b x 1,000 | INFECTION | ipd_nurse_note, ipt, iptbedmove, ward, operation_list, operation_detail, lab_head, lab_order, lab_items | - | SOURCE VIEW / rule pending |
| SI0301 | CAUTI: Rate of CAUTI (All) | 208 | a/b x 1,000 | INFECTION | ipd_nurse_note, ipt, iptbedmove, ward, operation_list, operation_detail, lab_head, lab_order, lab_items | - | SOURCE VIEW / rule pending |
| SI0302 | CAUTI: Rate of CAUTI in ICU | 209 | a/b x 1,000 | INFECTION | ipd_nurse_note, ipt, iptbedmove, ward, operation_list, operation_detail, lab_head, lab_order, lab_items | - | SOURCE VIEW / rule pending |
| SI0303 | CAUTI: Rate of CAUTI outside ICU | 210 | a/b x 1,000 | INFECTION | ipd_nurse_note, ipt, iptbedmove, ward, operation_list, operation_detail, lab_head, lab_order, lab_items | - | SOURCE VIEW / rule pending |
| SL0101 | Crossmatch-to-Transfusion ratios (C:T) in selective surgery cases | 211 | a/b | BLOOD | blood_request, ipt, an_stat, operation_list, operation_detail | - | SOURCE VIEW / rule pending |
| SM0102 | Medication Use: Percent of Antibiotic prescribing rate on Upper respiratory infection | 260 | a/b x 100 | MEDICATION | ovst, ovstdiag, opitemrece, drugitems, stock_item, stock_trancation, stock_daily_balance_record, stock_item_balance_history, stock_trancation_itemdata | B05.3, H65.0, H65.1, H65.9, H66.0, H66.4, H66.9, H67.0, H67.1, H67.8, H72.0, H72.2, H72.8, H72.9, J00, J01.0, J01.4, J01.8, J01.9, J02.0, J02.9, J03.0, J03.8, J03.9, J04.0, J04.2, J05.0, J05.1, J06.0, J06.8, J06.9, J10.1, J11.1, J20.0, J20.9, J21.0, J21.8, J21.9 | SOURCE VIEW / rule pending |
| SM0103 | Medication Use: Percent of Antibiotic prescribing on Acute diarrhea | 261 | a/b x 100 | MEDICATION | ovst, ovstdiag, opitemrece, drugitems, stock_item, stock_trancation, stock_daily_balance_record, stock_item_balance_history, stock_trancation_itemdata | A00.0, A00.1, A00.9, A02.0, A03.0, A03.3, A03.8, A03.9, A04.0, A04.9, A05.0, A05.3, A05.4, A05.9, A08.0, A08.5, A09, A09.0, A09.9, K52.1, K52.8, K52.9 | SOURCE VIEW / rule pending |
| SM0201 | Medication management: Inventory turn | 262 | a/b (inventory turn; ตรวจสูตรใน PDF) | MEDICATION | ovst, ovstdiag, opitemrece, drugitems, stock_item, stock_trancation, stock_daily_balance_record, stock_item_balance_history, stock_trancation_itemdata | - | SOURCE VIEW / rule pending |
| SS0101 | CSSD: Percent of examination of effective sterilization | 257 | a/b x 100 | CSSD | supply_sterile, supply_sterile_item, operation_list, operation_detail | - | SOURCE VIEW / rule pending |
| SS0102 | CSSD: Percent of exact medical equipment prepared for specific procedures | 258 | a/b x 100 | CSSD | supply_sterile, supply_sterile_item, operation_list, operation_detail | - | SOURCE VIEW / rule pending |
| SS0103 | CSSD: Percent of medical supplies which are accurately provided by the CSSD | 259 | a/b x 100 | CSSD | supply_sterile, supply_sterile_item, operation_list, operation_detail | - | SOURCE VIEW / rule pending |
