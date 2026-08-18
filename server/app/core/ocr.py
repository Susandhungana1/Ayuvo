"""Report text extraction (OCR), fully offline.

Tesseract (with Pillow image preprocessing) plus a scanned-PDF rasterize path,
so a PDF that is just scanned images (and would otherwise yield NO text) still
extracts. Best-effort and free. Every layer degrades to None on error, so an
upload never fails because of OCR. Kept separate from the API router so the
logic is unit-testable without HTTP.
"""

import io
from typing import Optional

from PIL import Image, ImageOps, ImageFilter
import pytesseract

IMAGE_EXTS = (".png", ".jpg", ".jpeg", ".gif", ".bmp", ".tiff", ".webp")

# Tesseract: LSTM engine (--oem 1) + "assume a uniform block of text" (--psm 6),
# which transcribes tabular lab reports more reliably than the default auto mode
# that tends to shuffle columns and split value/unit pairs.
_TESS_CONFIG = "--oem 1 --psm 6"

# Upscale anything narrower than this before OCR. Tesseract accuracy falls off on
# small, low-DPI crops (a typical phone report photo), so we bring it up toward
# the ~300-DPI sweet spot the engine was trained around.
_MIN_WIDTH = 1600


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


async def extract_report_text(content: bytes, filename: str) -> Optional[str]:
    """Offline (Tesseract/PyMuPDF) extraction. The name is kept so callers do not
    care which engine produced the text — the old vision-LLM path is gone."""
    name = (filename or "").lower()
    if name.endswith(IMAGE_EXTS):
        return ocr_image_bytes(content)
    if name.endswith(".pdf"):
        return extract_pdf(content)
    return None
