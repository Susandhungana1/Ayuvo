"""
Offline drug-interaction checker. Uses a curated local dataset of common,
well-documented interactions so it works for free with no external API or key.
Educational use only — not a substitute for a pharmacist.
"""
import re

# Each rule: frozenset of two normalized generic names -> (severity, note).
# Severity: "severe" | "moderate" | "minor".
INTERACTIONS = {
    frozenset(["warfarin", "aspirin"]): ("severe", "Increased risk of bleeding."),
    frozenset(["warfarin", "ibuprofen"]): ("severe", "Increased bleeding risk (NSAID + anticoagulant)."),
    frozenset(["warfarin", "paracetamol"]): ("moderate", "High-dose paracetamol may increase INR/bleeding."),
    frozenset(["aspirin", "ibuprofen"]): ("moderate", "Ibuprofen can reduce aspirin's heart-protective effect; combined GI bleeding risk."),
    frozenset(["aspirin", "clopidogrel"]): ("moderate", "Additive bleeding risk (dual antiplatelet)."),
    frozenset(["metformin", "alcohol"]): ("moderate", "Raised risk of lactic acidosis and low blood sugar."),
    frozenset(["lisinopril", "potassium"]): ("moderate", "ACE inhibitor + potassium can cause high potassium (hyperkalemia)."),
    frozenset(["lisinopril", "ibuprofen"]): ("moderate", "NSAIDs reduce blood-pressure control and may harm kidneys."),
    frozenset(["lisinopril", "spironolactone"]): ("severe", "Risk of dangerously high potassium."),
    frozenset(["simvastatin", "clarithromycin"]): ("severe", "Greatly increased statin levels; risk of muscle damage (rhabdomyolysis)."),
    frozenset(["simvastatin", "amlodipine"]): ("moderate", "Amlodipine raises simvastatin levels; limit simvastatin dose."),
    frozenset(["atorvastatin", "clarithromycin"]): ("moderate", "Increased statin levels; muscle-damage risk."),
    frozenset(["amoxicillin", "methotrexate"]): ("moderate", "Penicillins can increase methotrexate toxicity."),
    frozenset(["ciprofloxacin", "tizanidine"]): ("severe", "Dangerous drop in blood pressure and sedation."),
    frozenset(["ciprofloxacin", "theophylline"]): ("moderate", "Increased theophylline levels; toxicity risk."),
    frozenset(["digoxin", "furosemide"]): ("moderate", "Low potassium from furosemide increases digoxin toxicity."),
    frozenset(["digoxin", "amiodarone"]): ("severe", "Amiodarone raises digoxin levels; toxicity risk."),
    frozenset(["sildenafil", "nitroglycerin"]): ("severe", "Life-threatening drop in blood pressure."),
    frozenset(["tramadol", "sertraline"]): ("moderate", "Risk of serotonin syndrome."),
    frozenset(["tramadol", "fluoxetine"]): ("moderate", "Risk of serotonin syndrome."),
    frozenset(["omeprazole", "clopidogrel"]): ("moderate", "Omeprazole can reduce clopidogrel's effectiveness."),
    frozenset(["metronidazole", "alcohol"]): ("severe", "Severe nausea, vomiting, flushing (disulfiram-like reaction)."),
    frozenset(["prednisone", "ibuprofen"]): ("moderate", "Combined risk of stomach ulcers and bleeding."),
}

# Map many brand/spelling variants to a normalized generic name.
ALIASES = {
    "warfarin": "warfarin", "coumadin": "warfarin",
    "aspirin": "aspirin", "asa": "aspirin", "acetylsalicylic": "aspirin", "disprin": "aspirin",
    "ibuprofen": "ibuprofen", "brufen": "ibuprofen", "advil": "ibuprofen", "nurofen": "ibuprofen",
    "paracetamol": "paracetamol", "acetaminophen": "paracetamol", "tylenol": "paracetamol", "crocin": "paracetamol",
    "clopidogrel": "clopidogrel", "plavix": "clopidogrel",
    "metformin": "metformin", "glucophage": "metformin",
    "alcohol": "alcohol", "ethanol": "alcohol",
    "lisinopril": "lisinopril", "enalapril": "lisinopril", "ramipril": "lisinopril",
    "potassium": "potassium", "kcl": "potassium",
    "spironolactone": "spironolactone", "aldactone": "spironolactone",
    "simvastatin": "simvastatin", "zocor": "simvastatin",
    "atorvastatin": "atorvastatin", "lipitor": "atorvastatin",
    "amlodipine": "amlodipine", "norvasc": "amlodipine",
    "clarithromycin": "clarithromycin", "biaxin": "clarithromycin",
    "amoxicillin": "amoxicillin", "amoxil": "amoxicillin",
    "methotrexate": "methotrexate",
    "ciprofloxacin": "ciprofloxacin", "cipro": "ciprofloxacin",
    "tizanidine": "tizanidine",
    "theophylline": "theophylline",
    "digoxin": "digoxin", "lanoxin": "digoxin",
    "furosemide": "furosemide", "lasix": "furosemide",
    "amiodarone": "amiodarone", "cordarone": "amiodarone",
    "sildenafil": "sildenafil", "viagra": "sildenafil",
    "nitroglycerin": "nitroglycerin", "nitroglycerine": "nitroglycerin", "gtn": "nitroglycerin", "isosorbide": "nitroglycerin",
    "tramadol": "tramadol",
    "sertraline": "sertraline", "zoloft": "sertraline",
    "fluoxetine": "fluoxetine", "prozac": "fluoxetine",
    "omeprazole": "omeprazole", "prilosec": "omeprazole",
    "metronidazole": "metronidazole", "flagyl": "metronidazole",
    "prednisone": "prednisone", "prednisolone": "prednisone",
}


def normalize_drug(name: str) -> str | None:
    """Map a free-text medicine name to a known generic, or None."""
    if not name:
        return None
    text = name.lower()
    tokens = re.findall(r"[a-z]+", text)
    # try exact tokens first, then substrings
    for tok in tokens:
        if tok in ALIASES:
            return ALIASES[tok]
    for alias, generic in ALIASES.items():
        if alias in text:
            return generic
    return None


def check_interactions(medicine_names: list[str]) -> list[dict]:
    """Given a list of medicine names, return detected interaction pairs."""
    resolved = []  # (original_name, generic)
    for name in medicine_names:
        generic = normalize_drug(name)
        if generic:
            resolved.append((name, generic))

    results: list[dict] = []
    seen_pairs: set[frozenset] = set()
    for i in range(len(resolved)):
        for j in range(i + 1, len(resolved)):
            name_a, gen_a = resolved[i]
            name_b, gen_b = resolved[j]
            if gen_a == gen_b:
                continue
            key = frozenset([gen_a, gen_b])
            if key in INTERACTIONS and key not in seen_pairs:
                severity, note = INTERACTIONS[key]
                results.append({
                    "drug_a": name_a,
                    "drug_b": name_b,
                    "severity": severity,
                    "description": note,
                })
                seen_pairs.add(key)

    order = {"severe": 0, "moderate": 1, "minor": 2}
    results.sort(key=lambda r: order.get(r["severity"], 3))
    return results
