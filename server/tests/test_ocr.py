"""Tests for report text extraction (app/core/ocr.py).

Covers the three improvements:
  1. Image preprocessing (grayscale + upscale) and real Tesseract OCR.
  2. Scanned-PDF fallback: a PDF with no text layer is rasterized and OCR'd.
  3. Vision-LLM primary path + graceful fallback to offline OCR.

Network is never touched: the vision layer is exercised with a fake httpx client.
"""

import asyncio
import io

import fitz  # PyMuPDF
import pytest
from PIL import Image, ImageDraw, ImageFont

import app.core.ocr as ocr
from app.core.config import settings


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


def test_extract_text_from_file_ignores_unknown_types():
    assert ocr.extract_text_from_file(b"whatever", "notes.txt") is None


# --- 3. Vision LLM primary path ---------------------------------------------

class _FakeResp:
    status_code = 200

    def json(self):
        return {"choices": [{"message": {"content": "Hemoglobin 13.5 g/dL"}}]}


class _FakeClient:
    captured = None

    def __init__(self, *a, **k):
        pass

    async def __aenter__(self):
        return self

    async def __aexit__(self, *a):
        return False

    async def post(self, url, headers=None, json=None):
        _FakeClient.captured = json
        return _FakeResp()


def test_vision_returns_none_without_api_key(monkeypatch):
    monkeypatch.setattr(settings, "openrouter_api_key", "", raising=False)
    png = _text_image_png("X")
    assert asyncio.run(ocr.extract_text_via_vision(png, "r.png")) is None


def test_vision_transcribes_image(monkeypatch):
    import httpx

    monkeypatch.setattr(settings, "openrouter_api_key", "sk-test", raising=False)
    monkeypatch.setattr(settings, "vision_ocr_model", "some/vision-model", raising=False)
    monkeypatch.setattr(httpx, "AsyncClient", _FakeClient)

    png = _text_image_png("Hemoglobin 13.5")
    out = asyncio.run(ocr.extract_text_via_vision(png, "r.png"))
    assert out == "Hemoglobin 13.5 g/dL"

    # The request carried the configured model and an image part as a data URL.
    payload = _FakeClient.captured
    assert payload["model"] == "some/vision-model"
    content = payload["messages"][0]["content"]
    assert any(p.get("type") == "image_url" for p in content)
    img_part = next(p for p in content if p.get("type") == "image_url")
    assert img_part["image_url"]["url"].startswith("data:image/png;base64,")


def test_orchestrator_prefers_vision(monkeypatch):
    async def fake_vision(content, filename):
        return "FROM VISION"

    monkeypatch.setattr(ocr, "extract_text_via_vision", fake_vision)
    monkeypatch.setattr(ocr, "extract_text_from_file", lambda c, f: "FROM TESSERACT")

    out = asyncio.run(ocr.extract_report_text(b"x", "r.png"))
    assert out == "FROM VISION"


def test_orchestrator_falls_back_to_tesseract(monkeypatch):
    async def fake_vision(content, filename):
        return None  # vision unavailable / empty

    monkeypatch.setattr(ocr, "extract_text_via_vision", fake_vision)
    monkeypatch.setattr(ocr, "extract_text_from_file", lambda c, f: "FROM TESSERACT")

    out = asyncio.run(ocr.extract_report_text(b"x", "r.png"))
    assert out == "FROM TESSERACT"
