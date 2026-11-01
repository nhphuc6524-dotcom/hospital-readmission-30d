-- STEP 9: Superset dataset view, based on step 5 star schema.
-- View excludes patient identifiers; does not invent dates.
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE OR REPLACE VIEW analytics.vw_readmission_dashboard AS
SELECT
    f.encounter_id,
    p.gender,
    p.race,
    p.age AS age_group,
    sp.medical_specialty,
    a.admission_type_id,
    f.time_in_hospital,
    CASE
        WHEN f.time_in_hospital BETWEEN 1 AND 3 THEN '1-3 ngay'
        WHEN f.time_in_hospital BETWEEN 4 AND 7 THEN '4-7 ngay'
        WHEN f.time_in_hospital BETWEEN 8 AND 14 THEN '8-14 ngay'
        ELSE 'Khac/Chua ro'
    END AS stay_group,
    f.num_medications,
    f.num_lab_procedures,
    f.readmitted_30d::integer AS readmitted_30d
FROM dw.fact_admission AS f
JOIN dw.dim_patient AS p ON f.patient_key=p.patient_key
JOIN dw.dim_specialty AS sp ON f.specialty_key=sp.specialty_key
JOIN dw.dim_admission_type AS a ON f.admission_type_key=a.admission_type_key;

-- Run once under database owner dm (or postgres admin) to permit Superset's dm user to query it:
GRANT USAGE ON SCHEMA analytics TO dm;
GRANT SELECT ON analytics.vw_readmission_dashboard TO dm;
GRANT USAGE ON SCHEMA dw TO dm;
GRANT SELECT ON ALL TABLES IN SCHEMA dw TO dm;

-- Validate view integrity
SELECT
    COUNT(*) AS total_admissions,
    SUM(readmitted_30d) AS readmitted_under_30_days,
    ROUND(AVG(readmitted_30d::numeric)*100,2) AS readmission_rate_pct
FROM analytics.vw_readmission_dashboard;
