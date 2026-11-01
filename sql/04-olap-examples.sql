-- Truy vấn OLAP minh hoạ cho báo cáo môn học
-- A: tỷ lệ tái nhập viện theo nhóm tuổi
SELECT p.age, COUNT(*) AS admissions,
 ROUND(100.0 * AVG(f.readmitted_30d),2) AS rate_pct
FROM dw.fact_admission f JOIN dw.dim_patient p USING(patient_key)
GROUP BY p.age ORDER BY p.age;
-- B: rollup theo chuyên khoa / loại nhập viện
SELECT COALESCE(sp.medical_specialty,'ALL SPECIALTIES') AS specialty,
 CASE WHEN GROUPING(a.admission_type_id)=1 THEN 'ALL TYPES'
 ELSE a.admission_type_id::TEXT END AS admission_type,
 COUNT(*) AS admissions, SUM(f.readmitted_30d) AS readmissions
FROM dw.fact_admission f
JOIN dw.dim_specialty sp USING(specialty_key)
JOIN dw.dim_admission_type a USING(admission_type_key)
GROUP BY ROLLUP(sp.medical_specialty, a.admission_type_id)
ORDER BY admissions DESC LIMIT 30;
-- C: window function xếp hạng chuyên khoa có >= 100 lượt
WITH rates AS (
 SELECT sp.medical_specialty,COUNT(*) AS admissions,
 ROUND(100.0*AVG(f.readmitted_30d),2) AS rate_pct
 FROM dw.fact_admission f JOIN dw.dim_specialty sp USING(specialty_key)
 GROUP BY sp.medical_specialty HAVING COUNT(*) >= 100
)
SELECT *, DENSE_RANK() OVER (ORDER BY rate_pct DESC) AS rate_rank
FROM rates ORDER BY rate_rank;
