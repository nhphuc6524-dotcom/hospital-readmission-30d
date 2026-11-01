-- STEP 5B: Tạo kho hình sao. Không dựng Dim_Date giả vì dữ liệu KHÔNG có ngày.
CREATE SCHEMA IF NOT EXISTS dw;
DROP TABLE IF EXISTS dw.fact_admission CASCADE;
DROP TABLE IF EXISTS dw.dim_patient CASCADE;
DROP TABLE IF EXISTS dw.dim_diagnosis CASCADE;
DROP TABLE IF EXISTS dw.dim_specialty CASCADE;
DROP TABLE IF EXISTS dw.dim_admission_type CASCADE;
CREATE TABLE dw.dim_patient (
    patient_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_nbr BIGINT NOT NULL,
    race TEXT NOT NULL,
    gender TEXT NOT NULL,
    age TEXT NOT NULL,
    UNIQUE(patient_nbr, race, gender, age)
);
-- Một bệnh nhân có thể có giá trị thuộc tính thay đổi giữa các lượt;
-- khóa patient_key biểu diễn tổ hợp thông tin tại từng lượt (không ép gộp).
CREATE TABLE dw.dim_diagnosis (
    diagnosis_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    diag_1 TEXT NOT NULL, diag_2 TEXT NOT NULL, diag_3 TEXT NOT NULL,
    UNIQUE(diag_1,diag_2,diag_3)
);
CREATE TABLE dw.dim_specialty (
    specialty_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    medical_specialty TEXT NOT NULL UNIQUE
);
CREATE TABLE dw.dim_admission_type (
    admission_type_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    admission_type_id INTEGER NOT NULL UNIQUE
);
CREATE TABLE dw.fact_admission (
    encounter_id BIGINT PRIMARY KEY,
    patient_key BIGINT NOT NULL REFERENCES dw.dim_patient(patient_key),
    diagnosis_key BIGINT NOT NULL REFERENCES dw.dim_diagnosis(diagnosis_key),
    specialty_key BIGINT NOT NULL REFERENCES dw.dim_specialty(specialty_key),
    admission_type_key BIGINT NOT NULL REFERENCES dw.dim_admission_type(admission_type_key),
    time_in_hospital INTEGER,
    num_lab_procedures INTEGER,
    num_procedures INTEGER,
    num_medications INTEGER,
    number_outpatient INTEGER,
    number_emergency INTEGER,
    number_inpatient INTEGER,
    number_diagnoses INTEGER,
    readmitted_30d SMALLINT NOT NULL CHECK (readmitted_30d IN (0,1))
);
CREATE INDEX ix_fact_patient ON dw.fact_admission(patient_key);
CREATE INDEX ix_fact_diagnosis ON dw.fact_admission(diagnosis_key);
CREATE INDEX ix_fact_specialty ON dw.fact_admission(specialty_key);
CREATE INDEX ix_fact_admission_type ON dw.fact_admission(admission_type_key);
