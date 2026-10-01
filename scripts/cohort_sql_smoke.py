"""Execute generated SELECTs against an isolated, synthetic PostgreSQL container only.

No host database URL, port, credential, mount or hospital source is accepted.
DDL/fixture inserts apply only to the disposable --network none container.
"""
import json
import subprocess
import time
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = json.loads((ROOT / 'reporting/cohort_profiles.manifest.json').read_text(encoding='utf-8'))
NAME = 'thip-cohort-synthetic-' + uuid.uuid4().hex[:10]

FIXTURE = """
CREATE TABLE patient(hn text, cid text);
INSERT INTO patient VALUES ('H1','C1'),('H2','C2'),('H2','C9'),('H3','C1'),('H4',NULL),('',NULL);
CREATE TABLE person(person_id integer PRIMARY KEY, patient_hn text, cid text);
INSERT INTO person VALUES (1,'H1','C1'),(2,'H2','C2'),(3,'H2','C2'),(4,'HX','CX'),(5,NULL,NULL),(6,'H4',NULL);
CREATE TABLE ovst(vn text, hn text, an text, vstdate date);
INSERT INTO ovst VALUES ('V1','H1',NULL,'2025-10-05'),('V2','H1','A1','2025-10-15'),('V3','H2',NULL,'2025-10-25'),('V3','H2','A2','2025-10-25'),(NULL,NULL,NULL,'2025-10-31'),('VS','H1',NULL,'2025-09-30'),('V4','H1',NULL,'2025-11-01');
CREATE TABLE ipt(an text PRIMARY KEY, hn text, regdate date, dchdate date);
INSERT INTO ipt VALUES ('A1','H1','2025-09-30','2025-10-02'),('A2','H1','2025-10-10','2025-11-02'),('A3','H2','2025-10-20','2025-10-25'),('A4',NULL,'2025-10-31',NULL);
CREATE TABLE emp(emp_id integer PRIMARY KEY, emp_cid text, emp_work_begindate date, emp_resign_enddate date, emp_position_main_id integer DEFAULT 1);
INSERT INTO emp(emp_id,emp_cid,emp_work_begindate,emp_resign_enddate) VALUES (1,'C1','2025-01-01',NULL),(2,'C2','2025-10-31','2025-10-31'),(3,NULL,'2025-10-01',NULL),(4,'C4',NULL,NULL),(5,'C5','2025-11-01',NULL),(6,'C6','2025-10-20','2025-10-19'),(7,'C7','2025-01-01','2025-10-30');
CREATE TABLE opduser(loginname text PRIMARY KEY, cid text);
INSERT INTO opduser VALUES ('u1','C1'),('u2','C1'),('u3',NULL);
CREATE TABLE ovstdiag(vn text, icd10 text);
INSERT INTO ovstdiag VALUES ('V1','F17.2'),('V1','F17.2'),('V1','Z71.6'),('V1','Z71.6'),('V2','F17.2'),('V3','F17.2');
CREATE TABLE iptdiag(an text, icd10 text);
INSERT INTO iptdiag VALUES ('A1','I21.0'),('A1','I21.0'),('A2','I21.0');
CREATE TABLE opdscreen(vn text,hn text,vstdate date,checkup text, advice1 text,advice2 text,advice3 text,advice4 text,advice5 text,advice6 text,advice7 text,advice8 text,advice7_note text);
INSERT INTO opdscreen(vn,hn,vstdate,checkup) VALUES ('V1','H1','2025-10-05','1'),('V1','H1','2025-10-05','1');
CREATE TABLE opitemrece(vn text,icode text);
CREATE TABLE drugitems(icode text,name text);
CREATE TABLE emp_position_main(emp_position_main_id integer PRIMARY KEY, emp_position_main_name text);
INSERT INTO emp_position_main VALUES(1,'Synthetic staff');
CREATE TABLE emp_resign(emp_id integer,emp_resign_date date,emp_resign_type_id integer);
CREATE TABLE emp_resign_type(emp_resign_type_id integer PRIMARY KEY,emp_resign_type_name text);
INSERT INTO emp_resign_type VALUES(1,'voluntary');
INSERT INTO emp_resign VALUES(1,'2025-12-15',1);
"""
IPD_BASE = """WITH periodized AS (SELECT * FROM (VALUES
 ('H1','A1',DATE '2025-10-01',10,'I210',true,false,false,40,2::numeric),
 ('H1','A2',DATE '2025-10-01',10,'I210',false,false,false,40,4::numeric),
 ('H2','A3',DATE '2025-10-01',10,'I210',true,false,false,10,9::numeric)
) x(hn,an,period_start,calendar_month,pdx,died,has_acs_sdx,died_from_acs,age_y,los)) """
ED_BASE = """WITH opd_periodized AS (SELECT DATE '2025-10-01' AS period_start, 10 AS calendar_month, * FROM (VALUES
 (TIMESTAMP '2025-10-05 10:00',TIMESTAMP '2025-10-05 10:30',1),
 (TIMESTAMP '2025-10-15 10:00',TIMESTAMP '2025-10-15 11:30',1),
 (TIMESTAMP '2025-10-25 10:00',TIMESTAMP '2025-10-25 11:00',1),
 (TIMESTAMP '2025-10-06 10:00',TIMESTAMP '2025-10-06 20:00',1),
 (TIMESTAMP '2025-10-05 10:00',TIMESTAMP '2025-10-05 10:30',2)
) x(enter_er_time,finish_time,er_emergency_level_id)) """
HH_BASE = """WITH opd_periodized AS (SELECT *, 'F172'::text AS pdx, 40 AS age_y FROM (VALUES
 ('V1','H1',NULL::text,DATE '2025-10-01',10),('V1','H1',NULL::text,DATE '2025-10-01',10),
 ('V2','H1','A1',DATE '2025-11-01',11),('V3','H2','A2',DATE '2025-10-01',10)
) x(vn,hn,an,period_start,calendar_month)) """

def docker(*args, input=None):
    process = subprocess.run(['docker', *args], input=input, text=True, encoding='utf-8', capture_output=True, check=True)
    return process.stdout.strip()

def sql(statement):
    return docker('exec','-i',NAME,'psql','-U','postgres','-qAt','-v','ON_ERROR_STOP=1', input=statement)

def query(statement, start='2025-10-01', end='2025-11-01'):
    # Parameter substitution is limited to fixed synthetic date literals in this test.
    statement = statement.replace(':start_date', "DATE '" + start + "'").replace(':end_date', "DATE '" + end + "'")
    return json.loads(sql('SELECT COALESCE(json_agg(q), \'[]\'::json) FROM (' + statement + ') q;'))

def main():
    checks = []
    docker('run','--rm','-d','--name',NAME,'--network','none','--tmpfs','/var/lib/postgresql/data','-e','POSTGRES_PASSWORD=SYNTHETIC_ONLY','postgres:16-alpine')
    try:
        for _ in range(100):
            try: docker('exec',NAME,'pg_isready','-U','postgres'); break
            except subprocess.CalledProcessError: time.sleep(.2)
        else: raise RuntimeError('Synthetic PostgreSQL did not start')
        sql(FIXTURE)
        expected = {
            'patient': {'rows':6,'distinct_hn':4,'distinct_cid':3,'missing_hn':1,'missing_cid':2,'duplicate_hn_rows':1,'duplicate_cid_rows':1},
            'visits': {'rows':5,'distinct_visits':3,'distinct_patients':2,'linked_admission_visits':2,'unlinked_admission_visits':2,'mixed_admission_visits':1,'missing_vn':1,'missing_hn':1,'duplicate_vn_rows':1},
            'admissions': {'rows':4,'admitted_episodes':3,'discharged_episodes':2,'admitted_patients':2,'discharged_patients':2,'missing_hn':1,'missing_an':0,'duplicate_an_rows':0},
            'person': {'rows':6,'distinct_persons':6,'linked_hn':4,'unlinked_hn':2,'cid_agreement':3,'cid_conflict':2,'ambiguous_link':2,'cid_unassessable':3},
            'employees': {'rows':7,'distinct_staff':7,'missing_cid':1,'missing_start':1,'missing_end':4,'invalid_dates':1,'unknown_temporal_staff':2,'candidate_month_end_headcount':3},
            'accounts': {'rows':3,'distinct_accounts':3,'distinct_cid':1,'missing_cid':1,'duplicate_cid_rows':1},
        }
        for profile in MANIFEST['profiles']:
            result = query(profile['sql']); assert all(set(row) == {'profile_key','metric_key','count_value'} for row in result)
            actual = {row['metric_key']:row['count_value'] for row in result}
            for key,value in expected[profile['key']].items(): assert actual[key] == value, (profile['key'],key,actual[key],value)
            checks.append('profile:' + profile['key'])
        visits = next(p['sql'] for p in MANIFEST['profiles'] if p['key']=='visits')
        nov = {r['metric_key']:r['count_value'] for r in query(visits,'2025-11-01','2025-12-01')}
        full = {r['metric_key']:r['count_value'] for r in query(visits,'2025-10-01','2025-12-01')}
        assert nov['distinct_patients']==1 and full['distinct_patients']==2  # not October distinct + November distinct
        assert {r['metric_key']:r['count_value'] for r in query(visits,'2026-01-01','2026-02-01')}['rows']==0
        checks += ['distinct full-window differs from monthly sum','empty episode aggregate is zero']
        for branch in MANIFEST['representativeBranches']:
            code = branch['code']; prefix = IPD_BASE if code.startswith('DH') else ED_BASE if code=='CE0102' else HH_BASE if code=='HH0102' else ''
            facts = query(prefix+branch['sql'],'2025-10-01','2026-10-01'); assert len(facts)==1, (code,facts)
            fact = facts[0]
            expected_fact = {'DH0101':(1,2,50),'DH0112':(6,2,3),'CE0102':(180,3,60),'HH0102':(1,2,50),'HE0101':(1,6,16.67)}.get(code)
            if expected_fact: assert (fact['numerator'],fact['denominator'],fact['value'])==expected_fact, (code,fact)
            else: assert abs(fact['numerator']-1/12)<1e-12 and fact['denominator']==4 and fact['value']==2.08, (code,fact)
            checks.append('branch:' + code)
        assert sql("SELECT pg_typeof(SUM(n)), SUM(n)/NULLIF(12,0)>0 FROM (VALUES(1::bigint)) t(n);")=='numeric|t'
        safe = sql("SELECT COUNT(*) FROM ovst v WHERE EXISTS(SELECT 1 FROM ovstdiag d WHERE d.vn=v.vn AND d.icd10='F17.2');")
        inflated = sql("SELECT COUNT(*) FROM ovst v JOIN ovstdiag d ON d.vn=v.vn WHERE d.icd10='F17.2';")
        assert int(inflated)>int(safe)
        checks += ['SUM(bigint) retains fractional annual average','EXISTS prevents duplicate diagnosis fan-out']
        output = ROOT/'tmp/cohort-sql'; output.mkdir(parents=True,exist_ok=True)
        result = {'passed':checks,'hospitalQueries':0,'postgresImage':'postgres:16-alpine','clinicalApproval':False}
        (output/'result.json').write_text(json.dumps(result,indent=2),encoding='utf-8'); print(json.dumps(result))
    finally: docker('rm','-f',NAME)

if __name__=='__main__': main()
