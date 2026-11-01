-- BƯỚC 10A. Chỉ tạo schema dashboard và bảng điểm dự đoán Test.
-- Không xóa / sửa dw.* hay staging.*, không tái huấn luyện mô hình.
CREATE SCHEMA IF NOT EXISTS dashboard;
CREATE TABLE IF NOT EXISTS dashboard.test_predictions (
    encounter_id BIGINT PRIMARY KEY REFERENCES dw.fact_admission(encounter_id),
    dt_score DOUBLE PRECISION NOT NULL CHECK (dt_score BETWEEN 0 AND 1),
    rf_score DOUBLE PRECISION NOT NULL CHECK (rf_score BETWEEN 0 AND 1),
    dt_top10 SMALLINT NOT NULL CHECK (dt_top10 IN (0,1)),
    rf_top10 SMALLINT NOT NULL CHECK (rf_top10 IN (0,1)),
    dt_decile SMALLINT NOT NULL CHECK (dt_decile BETWEEN 1 AND 10),
    rf_decile SMALLINT NOT NULL CHECK (rf_decile BETWEEN 1 AND 10)
);
COMMENT ON TABLE dashboard.test_predictions IS
 '15,219 encounters from locked TEST; internal only; no patient numbers. Do not expose as Superset dataset.';
