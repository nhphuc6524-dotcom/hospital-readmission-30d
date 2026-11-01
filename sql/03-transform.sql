-- STEP 5C: Chạy sau khi đã import đủ 101766 dòng vào staging.
-- Vì 02 xoá/tạo lại bảng, 03 có thể chạy lại sau khi TRUNCATE toàn bộ DW.
BEGIN;
DO $$ BEGIN
  IF (SELECT COUNT(*) FROM staging.admissions_raw) <> 101766 THEN
    RAISE EXCEPTION 'Staging cần 101766 dòng, đang có %', (SELECT COUNT(*) FROM staging.admissions_raw);
  END IF;
  IF EXISTS(SELECT 1 FROM staging.admissions_raw WHERE NULLIF(TRIM(encounter_id),'') IS NULL OR NULLIF(TRIM(patient_nbr),'') IS NULL OR readmitted_30d NOT IN ('0','1')) THEN
    RAISE EXCEPTION 'Phát hiện ID trống hoặc nhãn khác 0/1';
  END IF;
END $$;
TRUNCATE TABLE dw.fact_admission, dw.dim_patient, dw.dim_diagnosis,
    dw.dim_specialty, dw.dim_admission_type RESTART IDENTITY CASCADE;
INSERT INTO dw.dim_patient(patient_nbr,race,gender,age)
SELECT DISTINCT patient_nbr::BIGINT, COALESCE(NULLIF(race,''),'Unknown'),
 COALESCE(NULLIF(gender,''),'Unknown'), COALESCE(NULLIF(age,''),'Unknown')
FROM staging.admissions_raw;
INSERT INTO dw.dim_diagnosis(diag_1,diag_2,diag_3)
SELECT DISTINCT COALESCE(NULLIF(diag_1,''),'Unknown'),
 COALESCE(NULLIF(diag_2,''),'Unknown'), COALESCE(NULLIF(diag_3,''),'Unknown')
FROM staging.admissions_raw;
INSERT INTO dw.dim_specialty(medical_specialty)
SELECT DISTINCT COALESCE(NULLIF(medical_specialty,''),'Unknown')
FROM staging.admissions_raw;
INSERT INTO dw.dim_admission_type(admission_type_id)
SELECT DISTINCT admission_type_id::INTEGER FROM staging.admissions_raw;
INSERT INTO dw.fact_admission (
 encounter_id,patient_key,diagnosis_key,specialty_key,admission_type_key,
 time_in_hospital,num_lab_procedures,num_procedures,num_medications,
 number_outpatient,number_emergency,number_inpatient,number_diagnoses,readmitted_30d)
SELECT s.encounter_id::BIGINT, p.patient_key,d.diagnosis_key,sp.specialty_key,a.admission_type_key,
 NULLIF(s.time_in_hospital,'')::INTEGER, NULLIF(s.num_lab_procedures,'')::INTEGER,
 NULLIF(s.num_procedures,'')::INTEGER,NULLIF(s.num_medications,'')::INTEGER,
 NULLIF(s.number_outpatient,'')::INTEGER,NULLIF(s.number_emergency,'')::INTEGER,
 NULLIF(s.number_inpatient,'')::INTEGER,NULLIF(s.number_diagnoses,'')::INTEGER,
 s.readmitted_30d::SMALLINT
FROM staging.admissions_raw s
JOIN dw.dim_patient p ON p.patient_nbr=s.patient_nbr::BIGINT
 AND p.race=COALESCE(NULLIF(s.race,''),'Unknown')
 AND p.gender=COALESCE(NULLIF(s.gender,''),'Unknown')
 AND p.age=COALESCE(NULLIF(s.age,''),'Unknown')
JOIN dw.dim_diagnosis d ON d.diag_1=COALESCE(NULLIF(s.diag_1,''),'Unknown')
 AND d.diag_2=COALESCE(NULLIF(s.diag_2,''),'Unknown')
 AND d.diag_3=COALESCE(NULLIF(s.diag_3,''),'Unknown')
JOIN dw.dim_specialty sp ON sp.medical_specialty=COALESCE(NULLIF(s.medical_specialty,''),'Unknown')
JOIN dw.dim_admission_type a ON a.admission_type_id=s.admission_type_id::INTEGER;
DO $$ BEGIN
 IF (SELECT COUNT(*) FROM dw.fact_admission) <> 101766 THEN
   RAISE EXCEPTION 'Fact thiếu lượt khám: %', (SELECT COUNT(*) FROM dw.fact_admission);
 END IF;
 IF (SELECT SUM(readmitted_30d) FROM dw.fact_admission) <> 11357 THEN
   RAISE EXCEPTION 'Nhãn tái nhập khác Bước 1';
 END IF;
END $$;
COMMIT;
SELECT COUNT(*) AS total_admissions, COUNT(DISTINCT encounter_id) AS unique_encounters,
 SUM(readmitted_30d) AS readmitted_30d,
 ROUND(AVG(readmitted_30d)*100,2) AS readmission_rate_pct
FROM dw.fact_admission;
