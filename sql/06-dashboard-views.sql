-- BƯỚC 10B. Views đọc từ Star Schema và điểm Test.
-- Dataset hiển thị KHÔNG có encounter_id / patient_nbr.
-- Cảnh báo: v_*_eval vẫn chứa các quan sát mức lượt nhập viện; giữ nội bộ.

-- Full dataset; so lieu mo ta, KHONG phai hieu qua du doan.
CREATE OR REPLACE VIEW dashboard.v_full_overview AS
SELECT
    p.age AS age_group,
    p.gender,
    p.race,
    sp.medical_specialty,
    a.admission_type_id,
    f.time_in_hospital,
    CASE
        WHEN f.time_in_hospital BETWEEN 1 AND 3 THEN '01. 1-3 ngay'
        WHEN f.time_in_hospital BETWEEN 4 AND 7 THEN '02. 4-7 ngay'
        WHEN f.time_in_hospital BETWEEN 8 AND 14 THEN '03. 8-14 ngay'
        ELSE '04. Khac/Chua ro'
    END AS stay_group,
    f.num_medications,
    f.readmitted_30d::integer AS readmitted_30d
FROM dw.fact_admission AS f
JOIN dw.dim_patient AS p ON f.patient_key = p.patient_key
JOIN dw.dim_specialty AS sp ON f.specialty_key = sp.specialty_key
JOIN dw.dim_admission_type AS a ON f.admission_type_key = a.admission_type_key;

-- Tập TEST đã khóa, có điểm đánh giá, hai mô hình, nhãn thực tế.
-- Khong co ma benh nhan/encounter trong view nay.
CREATE OR REPLACE VIEW dashboard.v_test_eval AS
SELECT
    p.age AS age_group,
    p.gender,
    p.race,
    sp.medical_specialty,
    a.admission_type_id,
    CASE
        WHEN f.time_in_hospital BETWEEN 1 AND 3 THEN '01. 1-3 ngay'
        WHEN f.time_in_hospital BETWEEN 4 AND 7 THEN '02. 4-7 ngay'
        WHEN f.time_in_hospital BETWEEN 8 AND 14 THEN '03. 8-14 ngay'
        ELSE '04. Khac/Chua ro'
    END AS stay_group,
    f.time_in_hospital,
    f.readmitted_30d::integer AS readmitted_30d,
    t.dt_score,
    t.rf_score,
    t.dt_top10,
    t.rf_top10,
    t.dt_decile,
    t.rf_decile,
    CASE WHEN t.dt_score >= 0.5 THEN 1 ELSE 0 END AS dt_pred_050,
    CASE WHEN t.rf_score >= 0.5 THEN 1 ELSE 0 END AS rf_pred_050,
    CASE WHEN t.dt_top10 = 1 AND f.readmitted_30d = 1 THEN 1 ELSE 0 END AS dt_top10_hit,
    CASE WHEN t.rf_top10 = 1 AND f.readmitted_30d = 1 THEN 1 ELSE 0 END AS rf_top10_hit,
    CASE WHEN t.dt_score >= 0.5 AND f.readmitted_30d = 1 THEN 1 ELSE 0 END AS dt_tp_050,
    CASE WHEN t.dt_score < 0.5 AND f.readmitted_30d = 1 THEN 1 ELSE 0 END AS dt_fn_050
FROM dashboard.test_predictions AS t
JOIN dw.fact_admission AS f ON f.encounter_id = t.encounter_id
JOIN dw.dim_patient AS p ON f.patient_key = p.patient_key
JOIN dw.dim_specialty AS sp ON f.specialty_key = sp.specialty_key
JOIN dw.dim_admission_type AS a ON f.admission_type_key = a.admission_type_key;

-- Bang so sanh ket qua Toan bo TEST, dung cho chart danh gia mining.
-- Baseline ngau nhien LA KY VONG, khong phai score/thu tu co y nghia.
CREATE OR REPLACE VIEW dashboard.v_model_scorecard AS
SELECT 'DecisionTree'::TEXT AS model,
       COUNT(*)::INTEGER AS test_encounters,
       SUM(readmitted_30d)::INTEGER AS true_positives,
       SUM(dt_top10)::INTEGER AS selected_top10,
       SUM(dt_top10_hit)::INTEGER AS captured_top10,
       ROUND(100.0 * SUM(dt_top10_hit) / NULLIF(SUM(readmitted_30d), 0), 4) AS recall_at_10_pct,
       ROUND(100.0 * SUM(dt_top10_hit) / NULLIF(SUM(dt_top10), 0), 4) AS precision_at_10_pct
FROM dashboard.v_test_eval
UNION ALL
SELECT 'RandomForest', COUNT(*)::INTEGER,
       SUM(readmitted_30d)::INTEGER,
       SUM(rf_top10)::INTEGER,
       SUM(rf_top10_hit)::INTEGER,
       ROUND(100.0 * SUM(rf_top10_hit) / NULLIF(SUM(readmitted_30d), 0), 4),
       ROUND(100.0 * SUM(rf_top10_hit) / NULLIF(SUM(rf_top10), 0), 4)
FROM dashboard.v_test_eval
UNION ALL
SELECT 'Random selection (expected)', COUNT(*)::INTEGER,
       SUM(readmitted_30d)::INTEGER, NULL::INTEGER, NULL::INTEGER,
       ROUND(100.0 * 1522 / NULLIF(COUNT(*), 0), 4),
       ROUND(100.0 * SUM(readmitted_30d) / NULLIF(COUNT(*), 0), 4)
FROM dashboard.v_test_eval;

-- Data mart bo sung: tau cac bien quantile tien su giuong mo hinh.
COMMENT ON VIEW dashboard.v_full_overview IS
 'All 101766 historical encounters; descriptive not predictive evaluation';
COMMENT ON VIEW dashboard.v_test_eval IS
 'Locked TEST only (15219); one row per admission, no identifiers; internal access only';
COMMENT ON VIEW dashboard.v_model_scorecard IS
 'Test-only comparison; baseline is random expectation, not empirical ranking';
