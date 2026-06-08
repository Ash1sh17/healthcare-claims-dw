DROP TABLE IF EXISTS fact_claims    CASCADE;
DROP TABLE IF EXISTS dim_date       CASCADE;
DROP TABLE IF EXISTS dim_member     CASCADE;
DROP TABLE IF EXISTS dim_provider   CASCADE;
DROP TABLE IF EXISTS dim_plan       CASCADE;
DROP TABLE IF EXISTS dim_diagnosis  CASCADE;

CREATE TABLE dim_date (
    date_key      INT         PRIMARY KEY,
    full_date     DATE        NOT NULL,
    day_of_week   VARCHAR(10) NOT NULL,
    day_of_month  SMALLINT    NOT NULL,
    week_of_year  SMALLINT    NOT NULL,
    month_num     SMALLINT    NOT NULL,
    month_name    VARCHAR(10) NOT NULL,
    quarter       SMALLINT    NOT NULL,
    year          SMALLINT    NOT NULL,
    is_weekend    BOOLEAN     NOT NULL,
    fiscal_year   SMALLINT    NOT NULL
);

CREATE TABLE dim_member (
    member_key      SERIAL       PRIMARY KEY,
    member_id       VARCHAR(10)  NOT NULL UNIQUE,
    first_name      VARCHAR(50)  NOT NULL,
    last_name       VARCHAR(50)  NOT NULL,
    dob             DATE         NOT NULL,
    gender          CHAR(1)      NOT NULL,
    state           CHAR(2)      NOT NULL,
    enrollment_date DATE         NOT NULL,
    risk_score      NUMERIC(5,2) NOT NULL
);

CREATE TABLE dim_provider (
    provider_key  SERIAL        PRIMARY KEY,
    provider_id   VARCHAR(10)   NOT NULL UNIQUE,
    provider_name VARCHAR(100)  NOT NULL,
    specialty     VARCHAR(50)   NOT NULL,
    city          VARCHAR(50)   NOT NULL,
    state         CHAR(2)       NOT NULL
);

CREATE TABLE dim_plan (
    plan_key   SERIAL       PRIMARY KEY,
    plan_id    VARCHAR(10)  NOT NULL UNIQUE,
    plan_name  VARCHAR(100) NOT NULL,
    plan_type  VARCHAR(10)  NOT NULL,
    state      CHAR(2)      NOT NULL
);

CREATE TABLE dim_diagnosis (
    diagnosis_key  SERIAL       PRIMARY KEY,
    diagnosis_code VARCHAR(10)  NOT NULL UNIQUE,
    description    VARCHAR(200) NOT NULL,
    category       VARCHAR(50)  NOT NULL
);

CREATE TABLE fact_claims (
    claim_sk            SERIAL        PRIMARY KEY,
    claim_id            VARCHAR(15)   NOT NULL UNIQUE,
    service_date_key    INT           NOT NULL REFERENCES dim_date(date_key),
    submission_date_key INT           NOT NULL REFERENCES dim_date(date_key),
    member_key          INT           NOT NULL REFERENCES dim_member(member_key),
    provider_key        INT           NOT NULL REFERENCES dim_provider(provider_key),
    plan_key            INT           NOT NULL REFERENCES dim_plan(plan_key),
    diagnosis_key       INT           NOT NULL REFERENCES dim_diagnosis(diagnosis_key),
    claim_type          VARCHAR(20)   NOT NULL,
    bill_type           VARCHAR(20)   NOT NULL,
    claim_status        VARCHAR(10)   NOT NULL,
    denial_reason       VARCHAR(100),
    billed_amount       NUMERIC(12,2) NOT NULL,
    allowed_amount      NUMERIC(12,2) NOT NULL,
    paid_amount         NUMERIC(12,2) NOT NULL DEFAULT 0
);

CREATE INDEX idx_fact_service_date ON fact_claims(service_date_key);
CREATE INDEX idx_fact_member       ON fact_claims(member_key);
CREATE INDEX idx_fact_provider     ON fact_claims(provider_key);
CREATE INDEX idx_fact_plan         ON fact_claims(plan_key);
CREATE INDEX idx_fact_status       ON fact_claims(claim_status);

SELECT 'Schema created successfully' AS status;