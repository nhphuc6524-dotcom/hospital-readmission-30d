CREATE OR REPLACE VIEW dashboard.v_icd_readmission AS
WITH codes AS (
    SELECT
        f.readmitted_30d,
        UPPER(TRIM(d.diag_1)) AS icd,
        CASE
            WHEN TRIM(d.diag_1) ~ '^[0-9]{1,3}(\.[0-9]+)?$'
            THEN SPLIT_PART(TRIM(d.diag_1), '.', 1)::integer
            ELSE NULL
        END AS code_num
    FROM dw.fact_admission f
    LEFT JOIN dw.dim_diagnosis d
        ON f.diagnosis_key = d.diagnosis_key
),
grouped AS (
    SELECT
        readmitted_30d,
        CASE
            WHEN icd ~ '^E[0-9]{3}(\.[0-9]+)?$'
                THEN 'External causes (E)'
            WHEN icd ~ '^V[0-9]{2}(\.[0-9]+)?$'
                THEN 'Supplementary (V)'
            WHEN code_num = 250 THEN 'Diabetes'
            WHEN code_num BETWEEN 1 AND 139 THEN 'Infectious'
            WHEN code_num BETWEEN 140 AND 239 THEN 'Neoplasms'
            WHEN code_num BETWEEN 240 AND 279 THEN 'Other endocrine'
            WHEN code_num BETWEEN 280 AND 289 THEN 'Blood'
            WHEN code_num BETWEEN 290 AND 319 THEN 'Mental'
            WHEN code_num BETWEEN 320 AND 389 THEN 'Nervous and sensory'
            WHEN code_num BETWEEN 390 AND 459 THEN 'Circulatory'
            WHEN code_num BETWEEN 460 AND 519 THEN 'Respiratory'
            WHEN code_num BETWEEN 520 AND 579 THEN 'Digestive'
            WHEN code_num BETWEEN 580 AND 629 THEN 'Genitourinary'
            WHEN code_num BETWEEN 630 AND 679 THEN 'Pregnancy'
            WHEN code_num BETWEEN 680 AND 709 THEN 'Skin'
            WHEN code_num BETWEEN 710 AND 739 THEN 'Musculoskeletal'
            WHEN code_num BETWEEN 740 AND 759 THEN 'Congenital'
            WHEN code_num BETWEEN 760 AND 779 THEN 'Perinatal'
            WHEN code_num BETWEEN 780 AND 799 THEN 'Symptoms'
            WHEN code_num BETWEEN 800 AND 999 THEN 'Injury and poisoning'
            ELSE 'Unknown'
        END AS icd_group
    FROM codes
)
SELECT
    icd_group,
    COUNT(*) AS encounters,
    SUM(readmitted_30d) AS readmitted_cases,
    ROUND(
        100.0 * SUM(readmitted_30d) / NULLIF(COUNT(*), 0),
        2
    ) AS readmission_rate_pct
FROM grouped
GROUP BY icd_group;