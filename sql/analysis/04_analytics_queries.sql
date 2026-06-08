-- Query 1: Monthly Claims Volume & Spend Trend
SELECT
    dd.year,
    dd.month_num,
    dd.month_name,
    COUNT(fc.claim_sk)                                      AS total_claims,
    SUM(fc.billed_amount)                                   AS total_billed,
    SUM(fc.allowed_amount)                                  AS total_allowed,
    SUM(fc.paid_amount)                                     AS total_paid,
    ROUND(SUM(fc.paid_amount) /
          NULLIF(SUM(fc.billed_amount), 0) * 100, 1)        AS paid_to_billed_pct
FROM       fact_claims fc
JOIN       dim_date    dd ON dd.date_key = fc.service_date_key
GROUP BY   dd.year, dd.month_num, dd.month_name
ORDER BY   dd.year, dd.month_num;

-- Query 2: Claim Denial Rate by Plan
SELECT
    dp.plan_name,
    dp.plan_type,
    COUNT(*)                                                           AS total_claims,
    SUM(CASE WHEN fc.claim_status = 'Denied' THEN 1 ELSE 0 END)       AS denied_claims,
    ROUND(
        SUM(CASE WHEN fc.claim_status = 'Denied' THEN 1 ELSE 0 END)::NUMERIC
        / COUNT(*) * 100, 2
    )                                                                  AS denial_rate_pct
FROM       fact_claims fc
JOIN       dim_plan    dp ON dp.plan_key = fc.plan_key
GROUP BY   dp.plan_name, dp.plan_type
ORDER BY   denial_rate_pct DESC;

-- Query 3: Top 10 Diagnoses by Total Paid
SELECT
    dd.diagnosis_code,
    dd.description,
    dd.category,
    COUNT(fc.claim_sk)                                      AS claim_count,
    SUM(fc.paid_amount)                                     AS total_paid,
    ROUND(AVG(fc.paid_amount), 2)                           AS avg_paid_per_claim,
    ROUND(SUM(fc.paid_amount) /
          SUM(SUM(fc.paid_amount)) OVER () * 100, 2)        AS pct_of_total_spend
FROM       fact_claims   fc
JOIN       dim_diagnosis dd ON dd.diagnosis_key = fc.diagnosis_key
GROUP BY   dd.diagnosis_code, dd.description, dd.category
ORDER BY   total_paid DESC
LIMIT 10;

-- Query 4: Provider Performance Scorecard
WITH provider_stats AS (
    SELECT
        dp.provider_id,
        dp.provider_name,
        dp.specialty,
        COUNT(fc.claim_sk)                                             AS total_claims,
        SUM(fc.paid_amount)                                            AS total_paid,
        ROUND(AVG(fc.paid_amount), 2)                                  AS avg_paid_per_claim,
        ROUND(
            SUM(CASE WHEN fc.claim_status = 'Denied' THEN 1 ELSE 0 END)::NUMERIC
            / COUNT(*) * 100, 2
        )                                                              AS denial_rate_pct
    FROM       fact_claims  fc
    JOIN       dim_provider dp ON dp.provider_key = fc.provider_key
    GROUP BY   dp.provider_id, dp.provider_name, dp.specialty
),
specialty_avg AS (
    SELECT specialty, ROUND(AVG(avg_paid_per_claim), 2) AS specialty_avg_cost
    FROM   provider_stats
    GROUP BY specialty
)
SELECT
    ps.*,
    sa.specialty_avg_cost,
    CASE
        WHEN ps.avg_paid_per_claim > sa.specialty_avg_cost * 1.2 THEN 'High Cost Outlier'
        WHEN ps.avg_paid_per_claim < sa.specialty_avg_cost * 0.8 THEN 'Low Cost Outlier'
        ELSE 'Within Normal Range'
    END AS cost_flag
FROM provider_stats ps
JOIN specialty_avg  sa ON sa.specialty = ps.specialty
ORDER BY ps.total_paid DESC;

-- Query 5: Member Risk Stratification
WITH member_spend AS (
    SELECT
        dm.member_id,
        dm.first_name || ' ' || dm.last_name  AS member_name,
        dm.risk_score,
        EXTRACT(YEAR FROM AGE(dm.dob))::INT    AS age,
        dm.gender,
        COUNT(fc.claim_sk)                     AS claim_count,
        SUM(fc.paid_amount)                    AS total_paid
    FROM       fact_claims fc
    JOIN       dim_member  dm ON dm.member_key = fc.member_key
    GROUP BY   dm.member_id, member_name, dm.risk_score, dm.dob, dm.gender
)
SELECT
    *,
    CASE
        WHEN risk_score >= 2.5 AND total_paid >= 5000 THEN 'High Risk / High Cost'
        WHEN risk_score >= 2.5 AND total_paid <  5000 THEN 'High Risk / Low Cost'
        WHEN risk_score <  2.5 AND total_paid >= 5000 THEN 'Low Risk / High Cost'
        ELSE                                                'Low Risk / Low Cost'
    END AS risk_segment
FROM member_spend
ORDER BY total_paid DESC;

-- Query 6: Denial Reason Breakdown
SELECT
    COALESCE(denial_reason, 'Unknown')        AS denial_reason,
    COUNT(*)                                  AS denied_count,
    ROUND(COUNT(*)::NUMERIC /
          SUM(COUNT(*)) OVER () * 100, 2)     AS pct_of_denials,
    SUM(billed_amount)                        AS denied_billed_amount
FROM   fact_claims
WHERE  claim_status = 'Denied'
GROUP BY denial_reason
ORDER BY denied_count DESC;

-- Query 7: Average Days from Service to Submission
SELECT
    dp.plan_name,
    ROUND(AVG(
        TO_DATE(CAST(fc.submission_date_key AS TEXT), 'YYYYMMDD')
        - TO_DATE(CAST(fc.service_date_key  AS TEXT), 'YYYYMMDD')
    ), 1)                                     AS avg_days_to_submission,
    MIN(TO_DATE(CAST(fc.submission_date_key AS TEXT), 'YYYYMMDD')
        - TO_DATE(CAST(fc.service_date_key  AS TEXT), 'YYYYMMDD'))  AS min_days,
    MAX(TO_DATE(CAST(fc.submission_date_key AS TEXT), 'YYYYMMDD')
        - TO_DATE(CAST(fc.service_date_key  AS TEXT), 'YYYYMMDD'))  AS max_days
FROM       fact_claims fc
JOIN       dim_plan    dp ON dp.plan_key = fc.plan_key
GROUP BY   dp.plan_name
ORDER BY   avg_days_to_submission DESC;

-- Query 8: Rolling 3-Month Paid Amount Trend
WITH monthly AS (
    SELECT
        dd.year,
        dd.month_num,
        dd.month_name,
        SUM(fc.paid_amount) AS monthly_paid
    FROM       fact_claims fc
    JOIN       dim_date    dd ON dd.date_key = fc.service_date_key
    GROUP BY   dd.year, dd.month_num, dd.month_name
)
SELECT
    year,
    month_num,
    month_name,
    monthly_paid,
    ROUND(AVG(monthly_paid) OVER (
        ORDER BY year, month_num
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2)                                     AS rolling_3mo_avg,
    LAG(monthly_paid) OVER (ORDER BY year, month_num)  AS prev_month_paid,
    ROUND(
        (monthly_paid - LAG(monthly_paid) OVER (ORDER BY year, month_num))
        / NULLIF(LAG(monthly_paid) OVER (ORDER BY year, month_num), 0) * 100
    , 2)                                      AS mom_growth_pct
FROM monthly
ORDER BY year, month_num;