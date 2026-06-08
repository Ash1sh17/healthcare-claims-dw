INSERT INTO dim_date (
    date_key, full_date, day_of_week, day_of_month,
    week_of_year, month_num, month_name, quarter,
    year, is_weekend, fiscal_year
)
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT                   AS date_key,
    d                                              AS full_date,
    TRIM(TO_CHAR(d, 'Day'))                        AS day_of_week,
    EXTRACT(DAY     FROM d)::SMALLINT              AS day_of_month,
    EXTRACT(WEEK    FROM d)::SMALLINT              AS week_of_year,
    EXTRACT(MONTH   FROM d)::SMALLINT              AS month_num,
    TRIM(TO_CHAR(d, 'Month'))                      AS month_name,
    EXTRACT(QUARTER FROM d)::SMALLINT              AS quarter,
    EXTRACT(YEAR    FROM d)::SMALLINT              AS year,
    EXTRACT(DOW     FROM d) IN (0, 6)              AS is_weekend,
    CASE WHEN EXTRACT(MONTH FROM d) >= 7
         THEN EXTRACT(YEAR FROM d)::SMALLINT + 1
         ELSE EXTRACT(YEAR FROM d)::SMALLINT
    END                                            AS fiscal_year
FROM GENERATE_SERIES(
    '2022-01-01'::DATE,
    '2025-12-31'::DATE,
    '1 day'
) AS g(d);

SELECT COUNT(*) AS total_days, MIN(full_date), MAX(full_date) FROM dim_date;