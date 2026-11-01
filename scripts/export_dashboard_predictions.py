#!/usr/bin/env python3
"""Xuat diem du doan TEST de nap PostgreSQL noi bo. KHONG huan luyen / toi uu bang Test.
KHÔNG ghi patient_nbr, gioi tinh, chung toc hay nhan Test ra CSV diem so.
"""
from pathlib import Path
import json
import math
import numpy as np
import pandas as pd
from scipy import sparse
import joblib

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'data' / 'processed' / 'step4'
MODEL_DIR = ROOT / 'reports' / 'classification'
OUTPUT = ROOT / 'reports' / 'superset'
OUTPUT.mkdir(parents=True, exist_ok=True)

X = sparse.load_npz(DATA / 'X_test.npz').tocsr()
y = np.load(DATA / 'y_test.npy').astype(int)
ids = pd.read_csv(DATA / 'test_ids_labels.csv')
assert X.shape[0] == len(y) == len(ids) == 15219, 'Test khac so mau du kien'
assert len(np.unique(ids['encounter_id'])) == len(ids), 'Trung encounter_id'
assert np.array_equal(ids['readmitted_30d'].to_numpy(dtype=int), y), 'Nhán Test khong khop'
assert int(y.sum()) == 1680, 'Test positive khac du kien'

info = json.loads((MODEL_DIR / 'training_summary.json').read_text(encoding='utf-8'))
assert info['selected_on_validation'] == 'DecisionTree', 'Mô hình đã khóa không phải DecisionTree'
assert abs(float(info['top_fraction']) - 0.1) < 1e-10

k = math.ceil(len(ids) * 0.10)
assert k == 1522

out = pd.DataFrame({'encounter_id': ids['encounter_id'].astype('int64')})
summary = {'test_encounters': int(len(ids)), 'test_positives': int(y.sum()),
           'follow_up_capacity': k, 'selected_on_validation': 'DecisionTree',
           'top10_tie_break': 'stable, original X_test row order',
           'models': {}}

for name, col_prefix, expected in [('DecisionTree', 'dt', 354), ('RandomForest','rf',353)]:
    model = joblib.load(MODEL_DIR / f'model_{name}.joblib')
    pos_idx = list(model.classes_).index(1)
    score = model.predict_proba(X)[:,pos_idx]
    if not np.all(np.isfinite(score)) or np.any((score < 0) | (score > 1)):
        raise ValueError(f'Invalid probabilities: {name}')

    # Same as 07_evaluation_fairness.ipynb: stable descending sort for tie handling
    order = np.argsort(-score, kind='stable')
    rank0 = np.empty(len(y), dtype=np.int64)
    rank0[order] = np.arange(len(y))
    selected = (rank0 < k).astype(int)
    decile = np.minimum(10, (rank0 * 10 // len(y)) + 1).astype(int)
    hits = int(y[selected == 1].sum())
    if hits != expected:
        raise AssertionError(f'{name}: {hits} hits != previous locked test result {expected}. Check model/files order.')

    # Probabilities are only stored in the local PostgreSQL database, not in shared report.
    out[f'{col_prefix}_score'] = score
    out[f'{col_prefix}_top10'] = selected
    out[f'{col_prefix}_decile'] = decile
    summary['models'][name] = {'hits': hits, 'recall_at_10pct': hits / int(y.sum()),
                               'precision_at_10pct': hits / k}

out = out[['encounter_id','dt_score','rf_score','dt_top10','rf_top10','dt_decile','rf_decile']]
private_csv = OUTPUT / 'test_predictions_local_only.csv'
out.to_csv(private_csv, index=False, encoding='utf-8')
(OUTPUT / 'dashboard_export_summary.json').write_text(json.dumps(summary, indent=2, ensure_ascii=False),encoding='utf-8')
print('EXPORT PASS')
print('Test:', len(out), 'positive:', int(y.sum()), 'follow-up Top10:', k)
print('DecisionTree hits:', summary['models']['DecisionTree']['hits'])
print('RandomForest hits:', summary['models']['RandomForest']['hits'])
print('File local only:', private_csv)
print('KHONG chia se CSV nay hoac day database len cloud.')
