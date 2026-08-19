"""Lab-value parser tests (app/core/lab_analysis.py).

Covers analyte extraction, unit-aware reference ranges, and user overrides.
All pure-function tests — no HTTP, no OCR.
"""
from app.core.lab_analysis import (
    REFERENCE_RANGES, analyze_lab_text, apply_overrides, summarize_findings,
)


def test_parses_classic_cbc_text():
    text = "COMPLETE BLOOD COUNT\nHemoglobin 13.5 g/dL\nWBC 7.2 x10^9/L\nPlatelets 250 x10^9/L"
    findings = analyze_lab_text(text)
    names = {f["name"]: f for f in findings}
    assert names["Hemoglobin"]["value"] == 13.5
    assert names["Hemoglobin"]["status"] == "NORMAL"
    assert names["WBC"]["value"] == 7.2
    assert names["Platelets"]["value"] == 250
    summary = summarize_findings(findings)
    assert summary["overall"] == "NORMAL"
    assert summary["total"] == 3
    assert summary["abnormal_count"] == 0


def test_flags_abnormal_values_and_sorts_them_first():
    text = "Hemoglobin 9.5 g/dL\nWBC 7.2 x10^9/L\nFasting glucose 180 mg/dL"
    findings = analyze_lab_text(text)
    assert findings[0]["status"] != "NORMAL"  # abnormal first
    by_name = {f["name"]: f for f in findings}
    assert by_name["Hemoglobin"]["status"] == "LOW"
    assert by_name["Glucose (Fasting)"]["status"] == "HIGH"
    assert summarize_findings(findings)["overall"] == "ABNORMAL"


def test_unit_aware_glucose_ranges():
    mg = analyze_lab_text("Fasting glucose 98 mg/dL")[0]
    assert mg["status"] == "NORMAL"
    assert mg["unit"] == "mg/dL"
    mmol = analyze_lab_text("Fasting glucose 5.4 mmol/L")[0]
    assert mmol["status"] == "NORMAL"
    assert mmol["unit"] == "mmol/L"
    # A mmol/L value that would be absurd as mg/dL must stay normal.
    assert mmol["value"] == 5.4
    high = analyze_lab_text("Fasting glucose 7.0 mmol/L")[0]
    assert high["status"] == "HIGH"
    assert high["reference_range"] == "3.9–5.6"


def test_creatinine_umol_variant():
    f = analyze_lab_text("Creatinine 90 umol/L")[0]
    assert f["unit"] == "µmol/L"
    assert f["status"] == "NORMAL"


def test_new_analytes_extracted():
    text = (
        "MCV 92 fL\nESR 25 mm/h\nCRP 12 mg/L\nChloride 100 mmol/L\n"
        "GGT 30 U/L\nFerritin 45 ng/mL"
    )
    findings = {f["name"]: f for f in analyze_lab_text(text)}
    assert findings["MCV"]["status"] == "NORMAL"
    assert findings["ESR"]["status"] == "HIGH"
    assert findings["CRP"]["status"] == "HIGH"
    assert findings["Chloride"]["status"] == "NORMAL"
    assert findings["GGT"]["status"] == "NORMAL"
    assert findings["Ferritin"]["status"] == "NORMAL"


def test_short_aliases_do_not_match_inside_words():
    # "hb" must not fire inside "HBA1c", and "t3" not inside unrelated words.
    findings = analyze_lab_text("HBA1c 6.2 %")
    names = {f["name"] for f in findings}
    assert "Hemoglobin" not in names
    assert "HbA1c" in names


def test_overrides_correct_value_and_recompute_status():
    text = "Hemoglobin 13.5 g/dL\nWBC 7.2 x10^9/L"
    findings = analyze_lab_text(text)
    overrides = {"Hemoglobin": {"value": 9.5, "unit": "g/dL"}}
    out = apply_overrides(findings, overrides)
    hb = next(f for f in out if f["name"] == "Hemoglobin")
    assert hb["value"] == 9.5
    assert hb["status"] == "LOW"
    assert hb["reference_range"] == "12–17.5"
    # Untouched findings pass through.
    assert len(out) == 2


def test_overrides_accept_json_string():
    text = "Fasting glucose 98 mg/dL"
    findings = analyze_lab_text(text)
    out = apply_overrides(findings, '{"Glucose (Fasting)": {"value": 130}}')
    g = out[0]
    assert g["value"] == 130
    assert g["status"] == "HIGH"


def test_override_unit_switch_uses_new_ranges():
    text = "Fasting glucose 98 mg/dL"
    findings = analyze_lab_text(text)
    out = apply_overrides(
        findings, {"Glucose (Fasting)": {"value": 9.2, "unit": "mmol/L"}}
    )
    g = out[0]
    assert g["unit"] == "mmol/L"
    assert g["status"] == "HIGH"
    assert g["reference_range"] == "3.9–5.6"


def test_overrides_ignore_unknown_names_and_garbage():
    text = "Hemoglobin 13.5 g/dL"
    findings = analyze_lab_text(text)
    out = apply_overrides(findings, {"Not A Test": {"value": 1}})
    assert out == findings
    assert apply_overrides(findings, "not json {") == findings
    assert apply_overrides(findings, None) == findings


def test_analyte_table_is_well_formed():
    # Every variant has a unit, and short aliases are listed as such.
    for name, (aliases, category, variants) in REFERENCE_RANGES.items():
        assert name and aliases and category and variants
        assert len({u for u, _, _ in variants}) == len(variants), name
        for alias in aliases:
            assert alias.islower()