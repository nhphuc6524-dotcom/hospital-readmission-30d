-- 15219 Test, 1680 duong tinh, DT:354 hits, RF:353 hits, capacity:1522.
SELECT * FROM dashboard.v_model_scorecard ORDER BY model;

DO $$
DECLARE
    n INTEGER;
    pos INTEGER;
    dt_k INTEGER;
    rf_k INTEGER;
    dt_hit INTEGER;
    rf_hit INTEGER;
BEGIN
    SELECT COUNT(*), SUM(readmitted_30d), SUM(dt_top10), SUM(rf_top10),
           SUM(dt_top10_hit), SUM(rf_top10_hit)
    INTO n, pos, dt_k, rf_k, dt_hit, rf_hit
    FROM dashboard.v_test_eval;
    IF n <> 15219 OR pos <> 1680 OR dt_k <> 1522 OR rf_k <> 1522
       OR dt_hit <> 354 OR rf_hit <> 353 THEN
        RAISE EXCEPTION
        'INVALID dashboard: n=%, pos=%, dt_k=%, rf_k=%, dt_hit=%, rf_hit=%',
        n,pos,dt_k,rf_k,dt_hit,rf_hit;
    END IF;
    IF (SELECT COUNT(*) FROM dashboard.v_full_overview) <> 101766 THEN
        RAISE EXCEPTION 'INVALID full overview row count';
    END IF;
    RAISE NOTICE 'DASHBOARD DATA PASS: Test %, positives %, DT top10 %, RF top10 %, hits DT %, RF %',
        n, pos, dt_k, rf_k, dt_hit, rf_hit;
END $$;
