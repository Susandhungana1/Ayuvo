"""Report text extraction (OCR).

Two layers, both best-effort and free, chosen for a real-world mix of clean PDFs,
scanned-PDF exports (no text layer), and messy phone photos of lab reports:

  1. Vision LLM (primary) — sends the page image to a multimodal model that reads
     tables, faint print, and skewed photos far better than classic OCR. Reuses
     the existing OpenRouter key; no new paid service. Skipped when no key is set.
  2. Tesseract (offline fallback) — with Pillow image preprocessing and a
     scanned-PDF rasterize path, so a PDF that is just scanned images (and would
     otherwise yield NO text) still extracts.

Every layer degrades to None on error, so an upload never fails because of OCR.
Kept separate from the API router so the logic is unit-testable without HTTP.
"""

import io
from typing import Optional

from PIL import Image, ImageOps, ImageFilter
import pytesseract

from app.core.config import settings

IMAGE_EXTS = (".png", ".jpg", ".jpeg", ".gif", ".bmp", ".tiff", ".webp")

# Tesseract: LSTM engine (--oem 1) + "assume a uniform block of text" (--psm 6),
# which transcribes tabular lab reports more reliably than the default auto mode
# that tends to shuffle columns and split value/unit pairs.
_TESS_CONFIG = "--oem 1 --psm 6"

# Upscale anything narrower than this before OCR. Tesseract accuracy falls off on
# small, low-DPI crops (a typical phone report photo), so we bring it up toward
# the ~300-DPI sweet spot the engine was trained around.
_MIN_WIDTH = 1600

# For the vision LLM, only the first couple of pages of a multi-page PDF are sent
# (keeps the request small and within free-tier limits; lab results are up front).
_VISION_MAX_PAGES = 2
_VISION_DPI = 200  # rasterize resolution for PDF pages sent to the vision model


def preprocess(image: Image.Image) -> Image.Image:
    """Grayscale → upscale small images → autocontrast → sharpen.

    Pure Pillow (no OpenCV), so we add zero system dependencies. This is the
    single biggest free accuracy win for phone photos: it removes colour noise,
    gives Tesseract enough pixels to work with, and crisps up the edges. We avoid
    a hard black/white threshold on purpose — global binarisation wrecks photos
    with uneven lighting, which is exactly the case we most need to handle.
    """
    img = image.convert("L")  # grayscale
    if img.width and img.width < _MIN_WIDTH:
        scale = _MIN_WIDTH / img.width
        img = img.resize((_MIN_WIDTH, max(1, int(img.height * scale))), Image.LANCZOS)
    img = ImageOps.autocontrast(img)
    img = img.filter(ImageFilter.UnsharpMask(radius=1.5, percent=150, threshold=3))
    return img


def ocr_image_bytes(content: bytes) -> Optional[str]:
    """Run preprocessing + Tesseract on raw image bytes. None on any failure."""
    try:
        image = Image.open(io.BytesIO(content))
        text = pytesseract.image_to_string(preprocess(image), config=_TESS_CONFIG)
        return text.strip() or None
    except Exception as e:  # noqa: BLE001 — OCR is best-effort, never fatal
        print(f"OCR image error: {e}")
        return None


def extract_pdf(content: bytes) -> Optional[str]:
    """Extract a PDF's text. Per page, prefer the embedded text layer; when a page
    has none (a scanned image), rasterize it at ~300 DPI and OCR it. This is what
    rescues scanned hospital reports that used to extract nothing at all."""
    import fitz  # PyMuPDF

    parts: list[str] = []
    try:
        doc = fitz.open(stream=io.BytesIO(content), filetype="pdf")
        for page in doc:
            txt = (page.get_text() or "").strip()
            if not txt:
                pix = page.get_pixmap(dpi=300)
                txt = (ocr_image_bytes(pix.tobytes("png")) or "").strip()
            if txt:
                parts.append(txt)
    except Exception as e:  # noqa: BLE001
        print(f"PDF extract error: {e}")
    joined = "\n".join(parts).strip()
    return joined or None


def extract_text_from_file(content: bytes, filename: str) -> Optional[str]:
    """Offline (Tesseract/PyMuPDF) extraction. The vision layer calls this as its
    fallback, and it is also the whole path when no OpenRouter key is set."""
    name = (filename or "").lower()
    if name.endswith(IMAGE_EXTS):
        return ocr_image_bytes(content)
    if name.endswith(".pdf"):
        return extract_pdf(content)
    return None


# --- Vision LLM primary path -------------------------------------------------

def _pdf_pages_to_png(content: bytes, max_pages: int = _VISION_MAX_PAGES) -> list[bytes]:
    import fitz  # PyMuPDF

    out: list[bytes] = []
    try:
        doc = fitz.open(stream=io.BytesIO(content), filetype="pdf")
        for i, page in enumerate(doc):
            if i >= max_pages:
                break
            out.append(page.get_pixmap(dpi=_VISION_DPI).tobytes("png"))
    except Exception as e:  # noqa: BLE001
        print(f"PDF rasterize error: {e}")
    return out


def _images_for_vision(content: bytes, filename: str) -> list[bytes]:
    name = (filename or "").lower()
    if name.endswith(IMAGE_EXTS):
        return [content]
    if name.endswith(".pdf"):
        return _pdf_pages_to_png(content)
    return []


def _data_url(png_or_image_bytes: bytes) -> str:
    import base64

    b64 = base64.b64encode(png_or_image_bytes).decode("ascii")
    return f"data:image/png;base64,{b64}"


_VISION_PROMPT = (
    "You are an OCR engine for medical lab reports. Transcribe ALL text from the "
    "image(s) exactly as printed. Preserve every test name, numeric value, unit, "
    "and reference range, and keep values on the same line as their test name. "
    "Do not summarise, interpret, translate, or add commentary — output only the "
    "raw transcribed text."
)


async def extract_text_via_vision(content: bytes, filename: str) -> Optional[str]:
    """Primary extractor: a multimodal model reads the page image(s). Returns None
    when no key is configured, there is nothing to send, or the call fails — the
    caller then falls back to Tesseract."""
    if not settings.openrouter_api_key:
        return None
    images = _images_for_vision(content, filename)
    if not images:
        return None

    import httpx

    parts: list[dict] = [{"type": "text", "text": _VISION_PROMPT}]
    for img in images:
        parts.append({"type": "image_url", "image_url": {"url": _data_url(img)}})

    try:
        async with httpx.AsyncClient(timeout=90.0) as client:
            resp = await client.post(
                "https://openrouter.ai/api/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {settings.openrouter_api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": settings.vision_ocr_model,
                    "messages": [{"role": "user", "content": parts}],
                    "temperature": 0,
                },
            )
            if resp.status_code == 200:
                text = (resp.json()["choices"][0]["message"]["content"] or "").strip()
                return text or None
            print(f"Vision OCR error: {resp.status_code} {resp.text[:300]}")
    except Exception as e:  # noqa: BLE001
        print(f"Vision OCR exception: {e}")
    return None


async def extract_report_text(content: bytes, filename: str) -> Optional[str]:
    """Orchestrator used by the API: try the vision LLM first (best accuracy), and
    fall back to offline Tesseract/PyMuPDF when it is unavailable or empty."""
    text = await extract_text_via_vision(content, filename)
    if text:
        return text
    return extract_text_from_file(content, filename)
