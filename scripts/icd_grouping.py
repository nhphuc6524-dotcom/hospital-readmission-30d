from pathlib import Path
import re
import pandas as pd

ROOT = Path(r"D:\Readmission_Project")

def group_icd9(value):
    if pd.isna(value):
        return "Unknown"

    code = str(value).strip().upper()

    if re.fullmatch(r"E\d{3}(?:\.\d+)?", code):
        return "External causes (E)"

    if re.fullmatch(r"V\d{2}(?:\.\d+)?", code):
        return "Supplementary (V)"

    if not re.fullmatch(r"\d{1,3}(?:\.\d+)?", code):
        return "Unknown"

    number = int(code.split(".")[0])

    if number == 250:
        return "Diabetes"

    ranges = [
        (1, 139, "Infectious"),
        (140, 239, "Neoplasms"),
        (240, 279, "Other endocrine"),
        (280, 289, "Blood"),
        (290, 319, "Mental"),
        (320, 389, "Nervous and sensory"),
        (390, 459, "Circulatory"),
        (460, 519, "Respiratory"),
        (520, 579, "Digestive"),
        (580, 629, "Genitourinary"),
        (630, 679, "Pregnancy"),
        (680, 709, "Skin"),
        (710, 739, "Musculoskeletal"),
        (740, 759, "Congenital"),
        (760, 779, "Perinatal"),
        (780, 799, "Symptoms"),
        (800, 999, "Injury and poisoning"),
    ]

    for low, high, name in ranges:
        if low <= number <= high:
            return name

    return "Unknown"


def main():
    path = ROOT / "data/raw/diabetic_data.csv"

    df = pd.read_csv(
        path,
        usecols=["diag_1", "diag_2", "diag_3"],
        dtype="string",
        na_values=["?", ""]
    )

    assert len(df) == 101766

    print("=== ICD GROUPING ===")

    results = []

    for col in ["diag_1", "diag_2", "diag_3"]:
        new_col = col + "_group"
        df[new_col] = df[col].map(group_icd9)

        counts = df[new_col].value_counts()

        assert counts.sum() == len(df)
        assert df[new_col].notna().all()

        print(f"\n{new_col}:")
        print(counts.to_string())

        for group, count in counts.items():
            results.append({
                "diagnosis_field": col,
                "icd_group": group,
                "encounters": int(count)
            })

    # Chi luu bang tong hop, khong xuat du lieu benh nhan.
    output_dir = ROOT / "reports/icd"
    output_dir.mkdir(parents=True, exist_ok=True)

    output = output_dir / "icd_group_summary.csv"
    pd.DataFrame(results).to_csv(
        output, index=False, encoding="utf-8-sig"
    )

    assert group_icd9("250.8") == "Diabetes"
    assert group_icd9("428") == "Circulatory"
    assert group_icd9("486") == "Respiratory"
    assert group_icd9("38") == "Infectious"
    assert group_icd9("V45") == "Supplementary (V)"
    assert group_icd9("E878") == "External causes (E)"

    print("\nROWS:", len(df))
    print("NEW_COLUMNS: diag_1_group, diag_2_group, diag_3_group")
    print("SUMMARY_FILE:", output)
    print("ICD_GROUPING_PASS")


if __name__ == "__main__":
    main()
