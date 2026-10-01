"""Compare original/pruned registered SELECTs on an isolated synthetic PG16.
No URL/credential for a host database is accepted, no ports or host mounts.
"""
import json
from pathlib import Path
import subprocess
import time
import uuid
import statistics
from cohort_sql_smoke import FIXTURE

ROOT=Path(__file__).resolve().parents[1]
NAME='thip-performance-synthetic-'+uuid.uuid4().hex[:10]
DDL="""
ALTER TABLE patient ADD COLUMN birthday date, ADD COLUMN sex text;
ALTER TABLE ovstdiag ADD COLUMN diagtype text, ADD COLUMN ovst_diag_id integer;
UPDATE ovstdiag SET diagtype='1',ovst_diag_id=1;
ALTER TABLE ipt ADD COLUMN regtime time, ADD COLUMN dchtime time, ADD COLUMN bw numeric;
CREATE TABLE an_stat(an text,age_y integer,los integer,pdx text);
INSERT INTO an_stat VALUES ('A1',40,2,'I210'),('A2',40,4,'I210'),('A3',30,5,'J440'),('A4',40,3,'I210');
CREATE TABLE death(an text,death_date date,death_time time,death_diag_icd10 text,death_cause text,death_diag_1 text,death_diag_2 text,death_diag_3 text,death_diag_4 text);
INSERT INTO death(an,death_date,death_diag_icd10) VALUES ('A1','2025-10-02','I210');
CREATE TABLE er_regist(vn text,enter_er_time timestamp,triage_datetime timestamp,doctor_tx_time timestamp,finish_time timestamp,antibiotics_datetime timestamp,stroke_needle_datetime timestamp,stemi_balloon_datetime timestamp,er_emergency_level_id integer,unplanned_return text,news2_score numeric);
INSERT INTO er_regist(vn,enter_er_time,finish_time,er_emergency_level_id) VALUES ('V1','2025-10-05 08:00','2025-10-05 09:30',1),('V2','2025-10-15 10:00','2025-10-15 11:00',1);
CREATE TABLE clinicmember(clinicmember_id integer,clinic text,hn text,regdate date,lastvisit date,dchdate date,current_status text,clinic_member_status_id integer,age_y integer,sex text,chronic_type text,begin_year integer,last_hba1c_value numeric,last_hba1c_date date,last_bp_bps_value numeric,last_bp_bpd_value numeric,last_bp_date date);
CREATE TABLE labor(laborid integer,an text,hage numeric,labor_type text,mother_method text,infant_sex text,infant_weight numeric,infant_apgarscore1 numeric,infant_apgarscore5 numeric,infant_apgarscore10 numeric,placenta_bloodloss numeric,labour_startdate date,labour_finishdate date);
CREATE TABLE ipt_newborn(an text,mother_an text,born_date date,birth_weight numeric,apgar1 numeric,apgar2 numeric,dead text,has_asphyxia text,birthcondition1 text,birthcondition2 text,anc_complete text);
ALTER TABLE emp ADD COLUMN emp_sex_id integer, ADD COLUMN emp_birthdate date,ADD COLUMN emp_status_id integer,ADD COLUMN emp_type_id integer,ADD COLUMN emp_dep_id integer,ADD COLUMN emp_resign_type_id integer;
-- Scale only synthetic, distinct episodes. Diagnosis fan-out and two admissions
-- for H1 already come from FIXTURE; these do not overwrite those counterexamples.
INSERT INTO ipt(an,hn,regdate,dchdate) SELECT 'PX'||n,'PH'||(n%300),'2025-10-01'::date+(n%330),'2025-10-03'::date+(n%330) FROM generate_series(1,10000) n;
INSERT INTO an_stat SELECT 'PX'||n,40,2,CASE WHEN n%2=0 THEN 'I210' ELSE 'J440' END FROM generate_series(1,10000) n;
INSERT INTO iptdiag SELECT 'PX'||n,'I210' FROM generate_series(1,10000) n UNION ALL SELECT 'PX'||n,'I210' FROM generate_series(1,10000) n;
CREATE INDEX synthetic_diagnosis_episode ON iptdiag(an);
CREATE INDEX synthetic_statistics_episode ON an_stat(an);
ANALYZE;
"""
def docker(*args,input=None):
    process=subprocess.run(['docker',*args],input=input,text=True,encoding='utf-8',capture_output=True)
    if process.returncode:raise RuntimeError(process.stderr)
    return process.stdout.strip()
def sql(statement):return docker('exec','-i',NAME,'psql','-U','postgres','-qAt','-v','ON_ERROR_STOP=1',input=statement)
def fixed(statement):return statement.replace(':start_date',"DATE '2025-10-01'").replace(':end_date',"DATE '2026-10-01'")
def aggregate(statement):return json.loads(sql("SELECT coalesce(json_agg(q),'[]'::json) FROM ("+fixed(statement)+') q;'))
def explain(statement):return json.loads(sql('EXPLAIN (ANALYZE,BUFFERS,FORMAT JSON) '+fixed(statement)))[0]
def main():
    subprocess.run(['node','scripts/export-query-comparison.mjs'],cwd=ROOT,check=True)
    queries=json.loads((ROOT/'tmp/sql-performance/queries.json').read_text(encoding='utf-8'))
    docker('run','--rm','-d','--name',NAME,'--network','none','--tmpfs','/var/lib/postgresql/data','-e','POSTGRES_PASSWORD=SYNTHETIC_ONLY','postgres:16-alpine')
    try:
        for _ in range(100):
            try:docker('exec',NAME,'pg_isready','-U','postgres');break
            except RuntimeError:time.sleep(.2)
        sql(FIXTURE+DDL)
        results=[]
        for query in queries:
            before=aggregate(query['before']);after=aggregate(query['after']);assert before==after,query['code']
            runs={name:[explain(query[name]) for _ in range(5)] for name in ['before','after']}
            results.append({'code':query['code'],'sameAggregate':True,'cells':len(after),'ctes':query['ctes'],'beforeBytes':len(query['before'].encode()),'afterBytes':len(query['after'].encode()),'beforeExecutionMedianMs':statistics.median(x['Execution Time'] for x in runs['before']),'afterExecutionMedianMs':statistics.median(x['Execution Time'] for x in runs['after']),'beforePlanningMedianMs':statistics.median(x['Planning Time'] for x in runs['before']),'afterPlanningMedianMs':statistics.median(x['Planning Time'] for x in runs['after'])})
        report={'hospitalQueries':0,'postgresImage':'postgres:16-alpine','syntheticOnly':True,'hospitalIndexApplied':False,'fixtureIndexes':['iptdiag(an)','an_stat(an)'],'results':results}
        (ROOT/'tmp/sql-performance/result.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report))
    finally:docker('rm','-f',NAME)
if __name__=='__main__':main()
