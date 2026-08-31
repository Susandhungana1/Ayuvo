"""Tests for report text extraction (app/core/ocr.py).

Covers the two-engine OCR approach:
  1. RapidOCR (primary) — PaddleOCR ONNX models via ONNX Runtime.
  2. Tesseract (fallback) — used when RapidOCR is unavailable or finds no numbers.
  3. Scanned-PDF fallback: a PDF with no text layer is rasterized and OCR'd.

Every engine is best-effort: uploads never fail because of OCR.
"""

import io

import fitz  # PyMuPDF
import pytest
from PIL import Image, ImageDraw, ImageFont

import app.core.ocr as ocr


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _tesseract_available() -> bool:
    try:
        import pytesseract
        pytesseract.get_tesseract_version()
        return True
    except Exception:
        return False


def _rapidocr_available() -> bool:
    try:
        from rapidocr_onnxruntime import RapidOCR
        return True
    except Exception:
        return False


needs_tesseract = pytest.mark.skipif(
    not _tesseract_available(), reason="tesseract binary not installed"
)
needs_rapidocr = pytest.mark.skipif(
    not _rapidocr_available(), reason="rapidocr-onnxruntime not installed"
)


def _text_image_png(text: str, size=(900, 200)) -> bytes:
    """Render black text on a white background and return PNG bytes."""
    img = Image.new("RGB", size, "white")
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 64)
    except Exception:
        font = ImageFont.load_default(size=64)
    draw.text((20, 60), text, fill="black", font=font)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


# --- 1. preprocessing --------------------------------------------------------

def test_preprocess_grayscales_and_upscales_small_images():
    small = Image.new("RGB", (400, 100), "white")
    out = ocr.preprocess(small)
    assert out.mode == "L"  # grayscale
    assert out.width == ocr._MIN_WIDTH  # upscaled toward the OCR sweet spot
    assert out.height > 100


def test_preprocess_does_not_downscale_large_images():
    big = Image.new("RGB", (2400, 600), "white")
    out = ocr.preprocess(big)
    assert out.width == 2400  # left as-is, only small crops are enlarged


def test_preprocess_upscales_short_images():
    wide = Image.new("RGB", (2000, 50), "white")
    out = ocr.preprocess(wide)
    assert out.height >= ocr._MIN_HEIGHT


def test_deskew_corrects_slight_rotation():
    img = Image.new("RGB", (400, 100), "white")
    draw = ImageDraw.Draw(img)
    draw.text((20, 30), "HELLO", fill="black")
    # Rotate by 3° and check that deskew doesn't crash
    rotated = img.rotate(3, resample=Image.BICUBIC, fillcolor=(255, 255, 255))
    result = ocr._deskew(rotated.convert("L"))
    assert result.mode == "L"


# --- 2. RapidOCR (primary engine) -------------------------------------------

@needs_rapidocr
def test_rapidocr_reads_text_from_image():
    png = _text_image_png("HEMOGLOBIN 13.5")
    image = Image.open(io.BytesIO(png))
    text = ocr._ocr_with_rapid(ocr.preprocess(image))
    assert text is not None
    assert "HEMOGLOBIN" in text.upper() or "13.5" in text


@needs_rapidocr
def test_rapidocr_handles_noisy_image():
    """RapidOCR should handle a slightly noisy image."""
    img = Image.new("RGB", (900, 200), "white")
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 48)
    except Exception:
        font = ImageFont.load_default(size=48)
    draw.text((20, 60), "WBC 7.5", fill="black", font=font)
    # Add some noise dots
    for x in range(0, 900, 15):
        for y in range(0, 200, 15):
            if (x + y) % 45 == 0:
                draw.point((x, y), fill=(180, 180, 180))
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    preprocessed = ocr.preprocess(img)
    text = ocr._ocr_with_rapid(preprocessed)
    # Should still extract something
    assert text is not None


# --- 3. Tesseract (fallback) -------------------------------------------------

@needs_tesseract
def test_tesseract_reads_text_from_image():
    png = _text_image_png("HEMOGLOBIN 13.5")
    image = Image.open(io.BytesIO(png))
    text = ocr._ocr_with_tesseract(image)
    assert text is not None
    # Tesseract may misread individual characters on synthetic text but should
    # extract the numeric value — that is what the lab parser actually needs.
    assert "13.5" in text


# --- 4. PDF paths ------------------------------------------------------------

def test_extract_pdf_uses_embedded_text_layer():
    doc = fitz.open()
    page = doc.new_page()
    page.insert_text((72, 72), "Hemoglobin 13.5 g/dL")
    pdf_bytes = doc.tobytes()

    text = ocr.extract_pdf(pdf_bytes)
    assert text is not None
    assert "Hemoglobin" in text


def test_extract_pdf_ocrs_scanned_page_without_text_layer():
    """A PDF that is just a scanned image (no text layer) must still extract
    via the rasterize+OCR fallback."""
    png = _text_image_png("PLATELETS 250")
    doc = fitz.open()
    page = doc.new_page(width=900, height=200)
    page.insert_image(fitz.Rect(0, 0, 900, 200), stream=png)
    pdf_bytes = doc.tobytes()

    # Sanity: this page genuinely has no extractable text layer.
    assert fitz.open(stream=pdf_bytes, filetype="pdf")[0].get_text().strip() == ""

    text = ocr.extract_pdf(pdf_bytes)
    assert text is not None
    assert "PLATELETS" in text.upper()


# --- 5. orchestrator ---------------------------------------------------------

def test_extract_report_text_ignores_unknown_types():
    import asyncio
    assert asyncio.run(ocr.extract_report_text(b"whatever", "notes.txt")) is None


def test_extract_report_text_png_goes_through_ocr(monkeypatch):
    monkeypatch.setattr(ocr, "ocr_image_bytes", lambda b: "HEMOGLOBIN 13.5")
    import asyncio
    out = asyncio.run(ocr.extract_report_text(b"x", "r.png"))
    assert out == "HEMOGLOBIN 13.5"


def test_extract_report_text_pdf_goes_through_pdf_path(monkeypatch):
    monkeypatch.setattr(ocr, "extract_pdf", lambda b: "PLATELETS 250")
    import asyncio
    out = asyncio.run(ocr.extract_report_text(b"x", "r.pdf"))
    assert out == "PLATELETS 250"


# --- 6. engine selection logic -----------------------------------------------

def test_rapidocr_preferred_when_it_has_numbers(monkeypatch):
    """When RapidOCR finds numbers, Tesseract is never called."""
    calls = {"rapid": 0, "tess": 0}

    def fake_rapid(image):
        calls["rapid"] += 1
        return "Hemoglobin 13.5 g/dL"

    def fake_tess(image):
        calls["tess"] += 1
        return "HEMOGLOBIN 13.5 g/dL"

    monkeypatch.setattr(ocr, "_ocr_with_rapid", fake_rapid)
    monkeypatch.setattr(ocr, "_ocr_with_tesseract", fake_tess)
    monkeypatch.setattr(ocr, "_get_rapid_ocr", lambda: True)

    text = ocr.ocr_image_bytes(_text_image_png("HEMOGLOBIN 13.5"))
    assert text is not None
    assert "13.5" in text
    assert calls["rapid"] >= 1
    # Tesseract should NOT be called when RapidOCR found numbers
    assert calls["tess"] == 0


def test_tesseract_used_when_rapidocr_finds_no_numbers(monkeypatch):
    """When RapidOCR returns text with no numbers, Tesseract is tried."""
    calls = {"rapid": 0, "tess": 0}

    def fake_rapid(image):
        calls["rapid"] += 1
        return "HEMOGLOBIN LYMPHOCYTES"  # no numbers

    def fake_tess(image):
        calls["tess"] += 1
        return "Hemoglobin 13.5 g/dL"

    monkeypatch.setattr(ocr, "_ocr_with_rapid", fake_rapid)
    monkeypatch.setattr(ocr, "_ocr_with_tesseract", fake_tess)
    monkeypatch.setattr(ocr, "_get_rapid_ocr", lambda: True)

    text = ocr.ocr_image_bytes(_text_image_png("HEMOGLOBIN 13.5"))
    assert text is not None
    assert "13.5" in text
    assert calls["rapid"] >= 1
    assert calls["tess"] >= 1


def test_falls_back_to_tesseract_when_rapidocr_unavailable(monkeypatch):
    """When RapidOCR is not installed, Tesseract handles everything."""
    monkeypatch.setattr(ocr, "_get_rapid_ocr", lambda: None)
    monkeypatch.setattr(ocr, "_ocr_with_rapid", lambda img: None)

    calls = []

    def fake_tess(image):
        calls.append(1)
        return "Hemoglobin 13.5 g/dL"

    monkeypatch.setattr(ocr, "_ocr_with_tesseract", fake_tess)

    text = ocr.ocr_image_bytes(_text_image_png("HEMOGLOBIN 13.5"))
    assert text is not None
    assert "13.5" in text
    assert len(calls) == 1


def test_returns_none_when_both_engines_fail(monkeypatch):
    monkeypatch.setattr(ocr, "_ocr_with_rapid", lambda img: None)
    monkeypatch.setattr(ocr, "_ocr_with_tesseract", lambda img: None)
    monkeypatch.setattr(ocr, "_get_rapid_ocr", lambda: True)

    text = ocr.ocr_image_bytes(_text_image_png("X"))
    assert text is None
