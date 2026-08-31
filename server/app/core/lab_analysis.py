"""
Lab-value analysis: parse OCR-extracted report text and flag values that fall
outside typical adult reference ranges. Also computes cross-report trends and
applies user corrections.

All logic is pure/offline (no external API), so it is deterministic and unit
testable. Reference ranges are general adult ranges for education only.

Each analyte maps to one or more unit variants (e.g. glucose in mg/dL or
mmol/L). The unit is sniffed from the text that follows the value; when no
unit is found the first variant acts as the default.
"""
import json
import re
from typing import Optional

# name -> (aliases, category, [(unit, low, high), ...])
# low/high may be None when only one side is clinically relevant.
REFERENCE_RANGES: dict[str, tuple[list[str], str, list[tuple[str, Optional[float], Optional[float]]]]] = {
    # Blood Count
    "Hemoglobin": (["hemoglobin", "haemoglobin", "hgb", "hb"], "Blood Count", [("g/dL", 12.0, 17.5)]),
    "Hematocrit": (["hematocrit", "haematocrit", "hct", "pcv"], "Blood Count", [("%", 38.0, 50.0)]),
    "WBC": (["wbc", "white blood cell", "white blood cells", "leukocyte", "total leucocyte", "tlc"], "Blood Count", [("x10^9/L", 4.0, 11.0)]),
    "RBC": (["rbc", "red blood cell", "red blood cells"], "Blood Count", [("x10^12/L", 4.2, 5.9)]),
    "Platelets": (["platelet", "platelets", "plt"], "Blood Count", [("x10^9/L", 150.0, 450.0)]),
    "MCV": (["mcv", "mean corpuscular volume"], "Blood Count", [("fL", 80.0, 100.0)]),
    "MCH": (["mch", "mean corpuscular hemoglobin"], "Blood Count", [("pg", 27.0, 33.0)]),
    "MCHC": (["mchc"], "Blood Count", [("g/dL", 32.0, 36.0)]),
    "RDW": (["rdw"], "Blood Count", [("%", 11.5, 14.5)]),
    "Neutrophils": (["neutrophil", "neutrophils", "neut"], "Blood Count", [("%", 40.0, 70.0)]),
    "Lymphocytes": (["lymphocyte", "lymphocytes", "lymph"], "Blood Count", [("%", 20.0, 40.0)]),
    "Monocytes": (["monocyte", "monocytes", "mono"], "Blood Count", [("%", 2.0, 10.0)]),
    "Eosinophils": (["eosinophil", "eosinophils", "eos"], "Blood Count", [("%", 1.0, 6.0)]),
    "Basophils": (["basophil", "basophils", "baso"], "Blood Count", [("%", 0.0, 2.0)]),
    "ESR": (["esr", "erythrocyte sedimentation"], "Blood Count", [("mm/h", 0.0, 20.0)]),
    # Metabolic
    "Glucose (Fasting)": (["fasting glucose", "fasting blood sugar", "fbs"], "Metabolic", [("mg/dL", 70.0, 100.0), ("mmol/L", 3.9, 5.6)]),
    "Glucose (Random)": (["random glucose", "random blood sugar", "rbs"], "Metabolic", [("mg/dL", 70.0, 140.0), ("mmol/L", 3.9, 7.8)]),
    "Postprandial Glucose": (["postprandial glucose", "ppbs", "post prandial", "2 hour post", "2hr pp"], "Metabolic", [("mg/dL", None, 140.0), ("mmol/L", None, 7.8)]),
    "HbA1c": (["hba1c", "a1c", "glycated"], "Metabolic", [("%", 4.0, 5.6)]),
    "Uric Acid": (["uric acid"], "Metabolic", [("mg/dL", 3.5, 7.2)]),
    # Lipids (mg/dL and mmol/L variants)
    "Total Cholesterol": (["total cholesterol", "cholesterol total", "cholesterol"], "Lipids", [("mg/dL", None, 200.0), ("mmol/L", None, 5.2)]),
    "LDL": (["ldl"], "Lipids", [("mg/dL", None, 100.0), ("mmol/L", None, 2.6)]),
    "HDL": (["hdl"], "Lipids", [("mg/dL", 40.0, None), ("mmol/L", 1.0, None)]),
    "Triglycerides": (["triglyceride", "triglycerides", "tg"], "Lipids", [("mg/dL", None, 150.0), ("mmol/L", None, 1.7)]),
    # Kidney
    "Creatinine": (["creatinine"], "Kidney", [("mg/dL", 0.6, 1.3), ("µmol/L", 53.0, 115.0)]),
    "Urea/BUN": (["blood urea", "bun", "urea"], "Kidney", [("mg/dL", 7.0, 20.0), ("mmol/L", 2.5, 7.1)]),
    # Electrolytes
    "Sodium": (["sodium", "na+"], "Electrolytes", [("mmol/L", 135.0, 145.0)]),
    "Potassium": (["potassium", "k+"], "Electrolytes", [("mmol/L", 3.5, 5.1)]),
    "Chloride": (["chloride", "cl-"], "Electrolytes", [("mmol/L", 98.0, 107.0)]),
    "Bicarbonate": (["bicarbonate", "co2", "hco3"], "Electrolytes", [("mmol/L", 22.0, 29.0)]),
    "Calcium": (["calcium"], "Electrolytes", [("mg/dL", 8.5, 10.5), ("mmol/L", 2.1, 2.6)]),
    # Liver
    "ALT (SGPT)": (["alt", "sgpt"], "Liver", [("U/L", 7.0, 56.0)]),
    "AST (SGOT)": (["ast", "sgot"], "Liver", [("U/L", 10.0, 40.0)]),
    "GGT": (["ggt", "gamma gt", "gamma glutamyl"], "Liver", [("U/L", 9.0, 48.0)]),
    "Alkaline Phosphatase": (["alkaline phosphatase", "alp"], "Liver", [("U/L", 44.0, 147.0)]),
    "Total Bilirubin": (["total bilirubin", "bilirubin total", "bilirubin"], "Liver", [("mg/dL", 0.1, 1.2), ("µmol/L", 1.7, 20.5)]),
    "Direct Bilirubin": (["direct bilirubin", "conjugated bilirubin"], "Liver", [("mg/dL", None, 0.3)]),
    "Total Protein": (["total protein"], "Liver", [("g/dL", 6.0, 8.3)]),
    "Albumin": (["albumin"], "Liver", [("g/dL", 3.5, 5.0)]),
    "Globulin": (["globulin"], "Liver", [("g/dL", 2.0, 3.5)]),
    # Thyroid
    "TSH": (["tsh", "thyroid stimulating"], "Thyroid", [("mIU/L", 0.4, 4.0)]),
    "T3": (["t3", "triiodothyronine"], "Thyroid", [("ng/dL", 80.0, 200.0)]),
    "Free T4": (["free t4", "t4", "thyroxine"], "Thyroid", [("ng/dL", 0.8, 1.8)]),
    # Vitamins & others
    "Vitamin D": (["vitamin d", "25-oh", "25 hydroxy"], "Vitamins", [("ng/mL", 30.0, 100.0)]),
    "Vitamin B12": (["vitamin b12", "b12", "cobalamin"], "Vitamins", [("pg/mL", 200.0, 900.0)]),
    "Ferritin": (["ferritin"], "Vitamins", [("ng/mL", 12.0, 300.0)]),
    "CRP": (["crp", "c reactive protein"], "Vitamins", [("mg/L", None, 10.0)]),
}

# Short aliases that need word boundaries to avoid matching inside other words.
_SHORT = {"hb", "hgb", "hct", "pcv", "wbc", "rbc", "plt", "tlc", "mcv", "mch",
          "mchc", "rdw", "esr", "fbs", "rbs", "ppbs", "ldl", "hdl", "tg", "bun",
          "na+", "k+", "cl-", "alt", "ast", "ggt", "alp", "t3", "t4", "tsh",
          "b12", "a1c", "crp"}

# (normalized token, display unit). Looked up in the text right after a value.
_UNIT_ALIASES = [
    ("mg/dl", "mg/dL"),
    ("mmol/l", "mmol/L"),
    ("µmol/l", "µmol/L"),
    ("umol/l", "µmol/L"),
    ("mcmol/l", "µmol/L"),
    ("g/dl", "g/dL"),
    ("ng/ml", "ng/mL"),
    ("pg/ml", "pg/mL"),
    ("u/l", "U/L"),
    ("iu/l", "IU/L"),
    ("mciu/ml", "mIU/L"),
    ("mm/h", "mm/h"),
]

# Up to this many characters after the number are inspected for a unit token.
_UNIT_CONTEXT = 14


def _status(value: float, low: Optional[float], high: Optional[float]) -> str:
    if low is not None and value < low:
        return "LOW"
    if high is not None and value > high:
        return "HIGH"
    return "NORMAL"


def _range_label(low: Optional[float], high: Optional[float]) -> str:
    if low is not None and high is not None:
        return f"{low:g}–{high:g}"
    if high is not None:
        return f"< {high:g}"
    if low is not None:
        return f"> {low:g}"
    return "-"


def _normalize_unit(s: str) -> str:
    """Lowercase, strip spaces/dots so 'mg / dl' and 'mg/dL' both become
    'mg/dl'. 'micro' folds onto the µ token."""
    norm = re.sub(r"[^a-z0-9µμ/]", "", s.lower())
    return norm.replace("micro", "µ")


def _detect_unit(context: str) -> Optional[str]:
    """Return the display unit found in the text right after a value, if any."""
    norm = _normalize_unit(context)
    for token, display in _UNIT_ALIASES:
        if token in norm:
            return display
    return None


def _find_value(text_lower: str, alias: str) -> Optional[tuple[float, str]]:
    """Find the first number that appears shortly after `alias`, plus the text
    that follows it (used to sniff the unit).

    Handles both Tesseract-style (alias and value on the same line) and
    RapidOCR-style (each item on its own line; value may be on the line below
    or above the alias).
    """
    esc = re.escape(alias)
    boundary = r"\b" if alias in _SHORT else ""

    # Pattern 1: same line (Tesseract) — alias, then up to 20 chars, then number.
    pattern = rf"{boundary}{esc}{boundary}[^0-9\-\n]{{0,20}}(-?\d[\d,]*\.?\d*)([^\n]{{0,{_UNIT_CONTEXT}}})"
    m = re.search(pattern, text_lower)
    if m:
        raw = m.group(1).replace(",", "")
        try:
            return float(raw), m.group(2)
        except ValueError:
            pass

    # Pattern 2: value on the NEXT line after the alias (RapidOCR common).
    # If that line turns out to be a reference range (e.g. "32.0 - 36.0"),
    # skip it and check the line after that.
    pattern_next = rf"{boundary}{esc}{boundary}\s*\n\s*(-?\d[\d,]*\.?\d*)([^\n]{{0,{_UNIT_CONTEXT}}})"
    m = re.search(pattern_next, text_lower)
    if m:
        raw = m.group(1).replace(",", "")
        trailing = m.group(2).strip()
        # If trailing looks like a reference range, the actual value is on the
        # next line.  Try it.
        if trailing.startswith("-") or " - " in trailing:
            skip_pattern = rf"{boundary}{esc}{boundary}\s*\n\s*\d[^\n]*\n\s*(-?\d[\d,]*\.?\d*)([^\n]{{0,{_UNIT_CONTEXT}}})"
            m2 = re.search(skip_pattern, text_lower)
            if m2:
                raw = m2.group(1).replace(",", "")
                try:
                    return float(raw), m2.group(2)
                except ValueError:
                    pass
        else:
            try:
                return float(raw), m.group(2)
            except ValueError:
                pass

    # Pattern 3: value on a PREVIOUS line before the alias (RapidOCR sometimes
    # detects the value before the label, with unit/range lines in between).
    # Allow up to 3 intervening lines for short aliases to avoid false matches.
    if alias in _SHORT or len(alias) <= 12:
        pattern_prev = rf"\n\s*(-?\d[\d,]*\.?\d*)(?:\n[^\n]{{0,30}}){{0,3}}\n\s*{re.escape(alias)}\b"
        m = re.search(pattern_prev, text_lower)
        if m:
            raw = m.group(1).replace(",", "")
            # Context: get the line after the matched number for unit detection.
            num_end = m.end(1)
            line_end = text_lower.find("\n", num_end)
            context = text_lower[num_end:line_end] if line_end > 0 else ""
            try:
                return float(raw), context
            except ValueError:
                pass

    return None


def _range_for(name: str, unit: str) -> tuple[Optional[float], Optional[float]]:
    """Reference range for a canonical analyte name and display unit."""
    spec = REFERENCE_RANGES.get(name)
    if not spec:
        return None, None
    for u, low, high in spec[2]:
        if u == unit:
            return low, high
    # Unknown unit — fall back to the default variant's range.
    return spec[2][0][1], spec[2][0][2]


def analyze_lab_text(text: Optional[str]) -> list[dict]:
    """Return a list of findings extracted from report text."""
    if not text:
        return []
    text_lower = text.lower()
    findings: list[dict] = []
    seen: set[str] = set()

    for name, (aliases, category, variants) in REFERENCE_RANGES.items():
        if name in seen:
            continue
        for alias in aliases:
            found = _find_value(text_lower, alias)
            if found is None:
                continue
            value, context = found
            unit, low, high = variants[0]
            detected = _detect_unit(context)
            if detected:
                for u, lo, hi in variants:
                    if u == detected:
                        unit, low, high = u, lo, hi
                        break
            status = _status(value, low, high)
            findings.append({
                "name": name,
                "value": value,
                "unit": unit,
                "status": status,
                "reference_range": _range_label(low, high),
                "category": category,
            })
            seen.add(name)
            break

    # Show abnormal findings first, then normal.
    findings.sort(key=lambda f: 0 if f["status"] != "NORMAL" else 1)
    return findings


def summarize_findings(findings: list[dict]) -> dict:
    abnormal = [f for f in findings if f["status"] != "NORMAL"]
    return {
        "total": len(findings),
        "abnormal_count": len(abnormal),
        "overall": "ABNORMAL" if abnormal else ("NORMAL" if findings else "NO_DATA"),
    }


def apply_overrides(findings: list[dict], overrides: Optional[str | dict]) -> list[dict]:
    """Apply user corrections on top of OCR findings.

    `overrides` is either a JSON string or a dict of
    {name: {"value": float, "unit": str?}}. Only names already present in
    findings are corrected; status and range are recomputed against the
    (possibly new) unit's reference range.
    """
    if not overrides:
        return findings
    if isinstance(overrides, str):
        try:
            overrides = json.loads(overrides)
        except (ValueError, TypeError):
            return findings
    if not isinstance(overrides, dict):
        return findings

    result: list[dict] = []
    for f in findings:
        override = overrides.get(f["name"])
        if not override or override.get("value") is None:
            result.append(f)
            continue
        try:
            value = float(override["value"])
        except (TypeError, ValueError):
            result.append(f)
            continue
        unit = override.get("unit") or f["unit"]
        low, high = _range_for(f["name"], unit)
        result.append({
            **f,
            "value": value,
            "unit": unit,
            "status": _status(value, low, high),
            "reference_range": _range_label(low, high),
        })
    return result