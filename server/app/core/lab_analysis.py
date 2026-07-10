"""
Lab-value analysis: parse OCR-extracted report text and flag values that fall
outside typical adult reference ranges. Also computes cross-report trends.

All logic is pure/offline (no external API), so it is deterministic and unit
testable. Reference ranges are general adult ranges for education only.
"""
import re
from typing import Optional


# name -> (aliases, unit, low, high, category)
# low/high may be None when only one side is clinically relevant.
REFERENCE_RANGES = {
    "Hemoglobin": (["hemoglobin", "haemoglobin", "hgb", "hb"], "g/dL", 12.0, 17.5, "Blood Count"),
    "Hematocrit": (["hematocrit", "haematocrit", "hct", "pcv"], "%", 38.0, 50.0, "Blood Count"),
    "WBC": (["wbc", "white blood cell", "leukocyte", "total leucocyte", "tlc"], "x10^9/L", 4.0, 11.0, "Blood Count"),
    "RBC": (["rbc", "red blood cell"], "x10^12/L", 4.2, 5.9, "Blood Count"),
    "Platelets": (["platelet", "platelets", "plt"], "x10^9/L", 150.0, 450.0, "Blood Count"),
    "Glucose (Fasting)": (["fasting glucose", "fasting blood sugar", "fbs", "glucose", "blood sugar"], "mg/dL", 70.0, 100.0, "Metabolic"),
    "HbA1c": (["hba1c", "a1c", "glycated"], "%", 4.0, 5.6, "Metabolic"),
    "Total Cholesterol": (["total cholesterol", "cholesterol total", "cholesterol"], "mg/dL", None, 200.0, "Lipids"),
    "LDL": (["ldl"], "mg/dL", None, 100.0, "Lipids"),
    "HDL": (["hdl"], "mg/dL", 40.0, None, "Lipids"),
    "Triglycerides": (["triglyceride", "triglycerides", "tg"], "mg/dL", None, 150.0, "Lipids"),
    "Creatinine": (["creatinine"], "mg/dL", 0.6, 1.3, "Kidney"),
    "Urea/BUN": (["blood urea", "bun", "urea"], "mg/dL", 7.0, 20.0, "Kidney"),
    "Sodium": (["sodium", "na+"], "mmol/L", 135.0, 145.0, "Electrolytes"),
    "Potassium": (["potassium", "k+"], "mmol/L", 3.5, 5.1, "Electrolytes"),
    "Calcium": (["calcium"], "mg/dL", 8.5, 10.5, "Electrolytes"),
    "ALT (SGPT)": (["alt", "sgpt"], "U/L", 7.0, 56.0, "Liver"),
    "AST (SGOT)": (["ast", "sgot"], "U/L", 10.0, 40.0, "Liver"),
    "Total Bilirubin": (["total bilirubin", "bilirubin total", "bilirubin"], "mg/dL", 0.1, 1.2, "Liver"),
    "TSH": (["tsh", "thyroid stimulating"], "mIU/L", 0.4, 4.0, "Thyroid"),
    "Vitamin D": (["vitamin d", "25-oh", "25 hydroxy"], "ng/mL", 30.0, 100.0, "Vitamins"),
    "Vitamin B12": (["vitamin b12", "b12", "cobalamin"], "pg/mL", 200.0, 900.0, "Vitamins"),
    "Uric Acid": (["uric acid"], "mg/dL", 3.5, 7.2, "Metabolic"),
}

# Short aliases that need word boundaries to avoid matching inside other words.
_SHORT = {"hb", "hgb", "hct", "pcv", "wbc", "rbc", "plt", "tlc", "fbs", "ldl",
          "hdl", "tg", "bun", "na+", "k+", "alt", "ast", "tsh", "b12", "a1c"}


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


def _find_value(text_lower: str, alias: str) -> Optional[float]:
    """Find the first number that appears shortly after `alias`."""
    esc = re.escape(alias)
    boundary = r"\b" if alias in _SHORT else ""
    # alias, then up to 20 non-value chars, then a number (allow commas)
    pattern = rf"{boundary}{esc}{boundary}[^0-9\-\n]{{0,20}}(-?\d[\d,]*\.?\d*)"
    m = re.search(pattern, text_lower)
    if not m:
        return None
    raw = m.group(1).replace(",", "")
    try:
        return float(raw)
    except ValueError:
        return None


def analyze_lab_text(text: Optional[str]) -> list[dict]:
    """Return a list of findings extracted from report text."""
    if not text:
        return []
    text_lower = text.lower()
    findings: list[dict] = []
    seen: set[str] = set()

    for name, (aliases, unit, low, high, category) in REFERENCE_RANGES.items():
        if name in seen:
            continue
        for alias in aliases:
            value = _find_value(text_lower, alias)
            if value is None:
                continue
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
