DROP TABLE IF EXISTS stg_members;
DROP TABLE IF EXISTS stg_claims;
DROP TABLE IF EXISTS stg_dim_plans;
DROP TABLE IF EXISTS stg_dim_providers;
DROP TABLE IF EXISTS stg_dim_diagnoses;

CREATE TABLE stg_members      (member_id TEXT, first_name TEXT, last_name TEXT, dob TEXT,
                                gender TEXT, state TEXT, plan_id TEXT, enrollment_date TEXT, risk_score TEXT);
CREATE TABLE stg_claims       (claim_id TEXT, member_id TEXT, provider_id TEXT, plan_id TEXT,
                                diagnosis_code TEXT, claim_type TEXT, bill_type TEXT,
                                service_date TEXT, submission_date TEXT, billed_amount TEXT,
                                allowed_amount TEXT, paid_amount TEXT, claim_status TEXT, denial_reason TEXT);
CREATE TABLE stg_dim_plans    (plan_id TEXT, plan_name TEXT, plan_type TEXT, state TEXT);
CREATE TABLE stg_dim_providers(provider_id TEXT, provider_name TEXT, specialty TEXT, city TEXT, state TEXT);
CREATE TABLE stg_dim_diagnoses(diagnosis_code TEXT, description TEXT, category TEXT);

\COPY stg_dim_plans     FROM 'data/dim_plans.csv'     CSV HEADER;
\COPY stg_dim_providers FROM 'data/dim_providers.csv' CSV HEADER;
\COPY stg_dim_diagnoses FROM 'data/dim_diagnoses.csv' CSV HEADER;
\COPY stg_members       FROM 'data/members.csv'       CSV HEADER;
\COPY stg_claims        FROM 'data/claims.csv'        CSV HEADER;

INSERT INTO dim_plan (plan_id, plan_name, plan_type, state)
SELECT plan_id, plan_name, plan_type, state FROM stg_dim_plans
ON CONFLICT (plan_id) DO NOTHING;

INSERT INTO dim_provider (provider_id, provider_name, specialty, city, state)
SELECT provider_id, provider_name, specialty, city, state FROM stg_dim_providers
ON CONFLICT (provider_id) DO NOTHING;

INSERT INTO dim_diagnosis (diagnosis_code, description, category)
SELECT diagnosis_code, description, category FROM stg_dim_diagnoses
ON CONFLICT (diagnosis_code) DO NOTHING;

INSERT INTO dim_member (member_id, first_name, last_name, dob, gender, state, enrollment_date, risk_score)
SELECT member_id, first_name, last_name, dob::DATE, gender, state,
       enrollment_date::DATE, risk_score::NUMERIC(5,2)
FROM stg_members
ON CONFLICT (member_id) DO NOTHING;

INSERT INTO fact_claims (
    claim_id, service_date_key, submission_date_key,
    member_key, provider_key, plan_key, diagnosis_key,
    claim_type, bill_type, claim_status, denial_reason,
    billed_amount, allowed_amount, paid_amount
)
SELECT
    c.claim_id,
    TO_CHAR(c.service_date::DATE,    'YYYYMMDD')::INT,
    TO_CHAR(c.submission_date::DATE, 'YYYYMMDD')::INT,
    m.member_key,
    p.provider_key,
    pl.plan_key,
    d.diagnosis_key,
    c.claim_type,
    c.bill_type,
    c.claim_status,
    NULLIF(c.denial_reason, ''),
    c.billed_amount::NUMERIC(12,2),
    c.allowed_amount::NUMERIC(12,2),
    c.paid_amount::NUMERIC(12,2)
FROM       stg_claims      c
JOIN       dim_member      m  ON m.member_id       = c.member_id
JOIN       dim_provider    p  ON p.provider_id     = c.provider_id
JOIN       dim_plan        pl ON pl.plan_id        = c.plan_id
JOIN       dim_diagnosis   d  ON d.diagnosis_code  = c.diagnosis_code
ON CONFLICT (claim_id) DO NOTHING;

SELECT 'dim_plan'      AS table_name, COUNT(*) AS rows FROM dim_plan      UNION ALL
SELECT 'dim_provider',                COUNT(*)          FROM dim_provider  UNION ALL
SELECT 'dim_member',                  COUNT(*)          FROM dim_member    UNION ALL
SELECT 'dim_diagnosis',               COUNT(*)          FROM dim_diagnosis UNION ALL
SELECT 'fact_claims',                 COUNT(*)          FROM fact_claims
ORDER BY table_name;