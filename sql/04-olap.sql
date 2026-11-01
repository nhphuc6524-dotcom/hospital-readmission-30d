
-- 04-olap.sql
-- De tai 5: Du doan tai nhap vien trong 30 ngay
-- Grain: 1 dong fact = 1 luot nhap vien

-- 1. Kiem tra tinh toan ven
SELECT
    COUNT(*) AS total_encounters,
    COUNT(DISTINCT f.encounter_id) AS unique_encounters,
    COUNT(DISTINCT p.patient_nbr) AS unique_patients,
    SUM(f.readmitted_30d) AS total_readmitted_30d,
    ROUND(AVG(f.readmitted_30d) * 100, 2)
        AS readmission_rate_pct
FROM dw.fact_admission f
JOIN dw.dim_patient p
    ON f.patient_key = p.patient_key;

-- 2. ROLLUP: Ty le tai nhap theo tuoi va gioi tinh
SELECT
    CASE WHEN GROUPING(p.age) = 1
         THEN 'ALL_AGES' ELSE p.age END AS age_group,
    CASE WHEN GROUPING(p.gender) = 1
         THEN 'ALL_GENDERS' ELSE p.gender END AS gender_group,
    COUNT(*) AS encounters,
    SUM(f.readmitted_30d) AS readmissions,
    ROUND(100.0 * AVG(f.readmitted_30d), 2)
        AS readmission_rate_pct
FROM dw.fact_admission f
JOIN dw.dim_patient p
    ON f.patient_key = p.patient_key
GROUP BY ROLLUP(p.age, p.gender)
ORDER BY age_group, gender_group;

-- 3. CUBE: Tuoi va loai nhap vien
SELECT
    CASE WHEN GROUPING(p.age) = 1
         THEN 'ALL_AGES' ELSE p.age END AS age_group,
    CASE WHEN GROUPING(a.admission_type_id) = 1
         THEN 'ALL_TYPES'
         ELSE a.admission_type_id::TEXT END AS admission_type,
    COUNT(*) AS encounters,
    SUM(f.readmitted_30d) AS readmissions,
    ROUND(100.0 * AVG(f.readmitted_30d), 2)
        AS readmission_rate_pct
FROM dw.fact_admission f
JOIN dw.dim_patient p
    ON f.patient_key = p.patient_key
JOIN dw.dim_admission_type a
    ON f.admission_type_key = a.admission_type_key
GROUP BY CUBE(p.age, a.admission_type_id)
HAVING COUNT(*) >= 100
ORDER BY encounters DESC, age_group, admission_type;

-- 4. GROUPING SETS: Chuyen khoa va gioi tinh
SELECT
    CASE WHEN GROUPING(s.medical_specialty) = 1
         THEN 'ALL_SPECIALTIES'
         ELSE s.medical_specialty END AS specialty,
    CASE WHEN GROUPING(p.gender) = 1
         THEN 'ALL_GENDERS'
         ELSE p.gender END AS gender_group,
    COUNT(*) AS encounters,
    SUM(f.readmitted_30d) AS readmissions,
    ROUND(100.0 * AVG(f.readmitted_30d), 2)
        AS readmission_rate_pct
FROM dw.fact_admission f
JOIN dw.dim_patient p
    ON f.patient_key = p.patient_key
JOIN dw.dim_specialty s
    ON f.specialty_key = s.specialty_key
GROUP BY GROUPING SETS (
    (s.medical_specialty, p.gender),
    (s.medical_specialty),
    (p.gender),
    ()
)
HAVING COUNT(*) >= 100
ORDER BY encounters DESC, specialty, gender_group;

-- 5. WINDOW FUNCTION: Xep hang chuyen khoa
-- Chi xep hang nhom co it nhat 200 luot
WITH specialty_stats AS (
    SELECT
        s.medical_specialty,
        COUNT(*) AS encounters,
        SUM(f.readmitted_30d) AS readmissions,
        AVG(f.readmitted_30d) AS rate
    FROM dw.fact_admission f
    JOIN dw.dim_specialty s
        ON f.specialty_key = s.specialty_key
    GROUP BY s.medical_specialty
    HAVING COUNT(*) >= 200
)
SELECT
    ROW_NUMBER() OVER (
        ORDER BY rate DESC, medical_specialty
    ) AS rank_no,
    medical_specialty,
    encounters,
    readmissions,
    ROUND(rate * 100, 2) AS readmission_rate_pct
FROM specialty_stats
ORDER BY rank_no;
