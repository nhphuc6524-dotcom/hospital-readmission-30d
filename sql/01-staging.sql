-- STEP 5A: Chạy trong Query Tool của database dm_course.
-- Dùng bảng TEXT để import CSV 55 cột không mất dữ liệu.
-- Chạy lại từ đầu: script này xoá bảng staging cũ.
CREATE SCHEMA IF NOT EXISTS staging;
DROP TABLE IF EXISTS staging.admissions_raw;
CREATE TABLE staging.admissions_raw (
    "encounter_id" TEXT,
    "patient_nbr" TEXT,
    "race" TEXT,
    "gender" TEXT,
    "age" TEXT,
    "admission_type_id" TEXT,
    "discharge_disposition_id" TEXT,
    "admission_source_id" TEXT,
    "time_in_hospital" TEXT,
    "payer_code" TEXT,
    "medical_specialty" TEXT,
    "num_lab_procedures" TEXT,
    "num_procedures" TEXT,
    "num_medications" TEXT,
    "number_outpatient" TEXT,
    "number_emergency" TEXT,
    "number_inpatient" TEXT,
    "diag_1" TEXT,
    "diag_2" TEXT,
    "diag_3" TEXT,
    "number_diagnoses" TEXT,
    "max_glu_serum" TEXT,
    "A1Cresult" TEXT,
    "metformin" TEXT,
    "repaglinide" TEXT,
    "nateglinide" TEXT,
    "chlorpropamide" TEXT,
    "glimepiride" TEXT,
    "acetohexamide" TEXT,
    "glipizide" TEXT,
    "glyburide" TEXT,
    "tolbutamide" TEXT,
    "pioglitazone" TEXT,
    "rosiglitazone" TEXT,
    "acarbose" TEXT,
    "miglitol" TEXT,
    "troglitazone" TEXT,
    "tolazamide" TEXT,
    "examide" TEXT,
    "citoglipton" TEXT,
    "insulin" TEXT,
    "glyburide-metformin" TEXT,
    "glipizide-metformin" TEXT,
    "glimepiride-pioglitazone" TEXT,
    "metformin-rosiglitazone" TEXT,
    "metformin-pioglitazone" TEXT,
    "change" TEXT,
    "diabetesMed" TEXT,
    "readmitted" TEXT,
    "readmitted_30d" TEXT,
    "A1Cresult_tested" TEXT,
    "max_glu_serum_tested" TEXT,
    "admission_type_id_category" TEXT,
    "discharge_disposition_id_category" TEXT,
    "admission_source_id_category" TEXT
);
-- SAU KHI CHẠY: pgAdmin > Schemas > staging > Tables > admissions_raw
-- > Import/Export Data > Import; Filename chọn step3_cleaned.csv;
-- Format CSV, Header YES, Delimiter ',' , Quote '"', Encoding UTF8.
-- Lưu ý: thử import với đường dẫn D:/Readmission_Project/data/processed/step3_cleaned.csv.
-- Nếu import lỗi, đọc thông báo trước khi chạy 02 và 03.
SELECT COUNT(*) AS imported_rows FROM staging.admissions_raw;
