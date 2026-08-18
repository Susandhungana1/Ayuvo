"""Tests for report text extraction (app/core/ocr.py).

Covers the two offline paths:
  1. Image preprocessing (grayscale + upscale) and real Tesseract OCR.
  2. Scanned-PDF fallback: a PDF with no text layer is rasterized and OCR'd.

The old vision-LLM layer was removed with the AI features; OCR is fully
offline now. Network is never touched.
"""

import io

import fitz  # PyMuPDF
import pytest
from PIL import Image, ImageDraw, ImageFont

import app.core.ocr as ocr


def _tesseract_available() -> bool:
    try:
        import pytesseract

        pytesseract.get_tesseract_version()
        return True
    except Exception:
        return False


needs_tesseract = pytest.mark.skipif(
    not _tesseract_available(), reason="tesseract binary not installed"
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


@needs_tesseract
def test_ocr_reads_text_from_image():
    png = _text_image_png("HEMOGLOBIN 13.5")
    text = ocr.ocr_image_bytes(png)
    assert text is not None
    assert "HEMOGLOBIN" in text.upper()
    assert "13.5" in text


# --- 2. PDF paths ------------------------------------------------------------

def test_extract_pdf_uses_embedded_text_layer():
    doc = fitz.open()
    page = doc.new_page()
    page.insert_text((72, 72), "Hemoglobin 13.5 g/dL")
    pdf_bytes = doc.tobytes()

    text = ocr.extract_pdf(pdf_bytes)
    assert text is not None
    assert "Hemoglobin" in text


@needs_tesseract
def test_extract_pdf_ocrs_scanned_page_without_text_layer():
    """A PDF that is just a scanned image (no text layer) must still extract via
    the rasterize+OCR fallback — this is the bug that returned nothing before."""
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


def test_extract_report_text_ignores_unknown_types():
    import asyncio

    assert asyncio.run(ocr.extract_report_text(b"whatever", "notes.txt")) is None


def test_extract_report_text_png_goes_through_tesseract(monkeypatch):
    """The orchestrator routes images to Tesseract (no vision layer anymore)."""
    monkeypatch.setattr(ocr, "ocr_image_bytes", lambda b: "HEMOGLOBIN 13.5")

    import asyncio

    out = asyncio.run(ocr.extract_report_text(b"x", "r.png"))
    assert out == "HEMOGLOBIN 13.5"


def test_extract_report_text_pdf_goes_through_pdf_path(monkeypatch):
    monkeypatch.setattr(ocr, "extract_pdf", lambda b: "PLATELETS 250")

    import asyncio

    out = asyncio.run(ocr.extract_report_text(b"x", "r.pdf"))
    assert out == "PLATELETS 250"
