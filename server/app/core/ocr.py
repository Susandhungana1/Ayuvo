"""Report text extraction (OCR), fully offline.

Two-engine approach for maximum accuracy on medical lab reports:

  1. **RapidOCR** (primary) — PaddleOCR's ONNX models via ONNX Runtime.
     Deep-learning text detection + recognition that handles phone photos,
     angled scans, uneven lighting, and tabular layouts far better than
     Tesseract.  CPU-only, ~70 MB total, no GPU needed.

  2. **Tesseract** (fallback) — used when RapidOCR is unavailable, fails, or
     produces no numeric tokens (a sign the layout confused even the DL engine).

Best-effort throughout: every layer degrades to None on error so an upload
never fails because of OCR.  Kept separate from the API router so the logic
is unit-testable without HTTP.
"""

import io
import logging
import math
import re
from typing import Optional

from PIL import Image, ImageOps, ImageFilter, ImageStat

IMAGE_EXTS = (".png", ".jpg", ".jpeg", ".gif", ".bmp", ".tiff", ".webp")
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Image preprocessing (Pure Pillow — no OpenCV dependency)
# ---------------------------------------------------------------------------

_MIN_WIDTH = 1600
_MIN_HEIGHT = 400


def preprocess(image: Image.Image) -> Image.Image:
    """Grayscale → upscale → autocontrast → sharpen.

    Designed for phone photos of printed lab reports: removes colour noise,
    gives the OCR engine enough pixels, and crisps up edges.  We avoid a hard
    black/white threshold because global binarisation wrecks photos with
    uneven lighting — exactly the case we most need to handle.
    """
    img = image.convert("L")

    # Upscale small images to the ~300-DPI sweet spot OCR engines expect.
    if img.width and img.width < _MIN_WIDTH:
        scale = _MIN_WIDTH / img.width
        img = img.resize(
            (_MIN_WIDTH, max(1, int(img.height * scale))),
            Image.LANCZOS,
        )
    # Also ensure minimum height for very wide panoramic crops.
    if img.height and img.height < _MIN_HEIGHT:
        scale = _MIN_HEIGHT / img.height
        img = img.resize(
            (max(1, int(img.width * scale)), _MIN_HEIGHT),
            Image.LANCZOS,
        )

    img = ImageOps.autocontrast(img)
    img = img.filter(ImageFilter.UnsharpMask(radius=1.5, percent=150, threshold=3))
    return img


def _deskew(image: Image.Image) -> Image.Image:
    """Rotate the image to correct slight skew (±15°).

    Uses the variance-of-projection method: for each angle, project the
    binary image onto a horizontal line and measure variance.  The angle
    with the highest variance is the correct deskew angle.  Pure Pillow,
    no numpy/scipy needed.
    """
    # Convert to binary for projection
    bw = image.point(lambda x: 255 if x > 128 else 0, mode="1")
    w, h = bw.size

    best_angle = 0.0
    best_var = 0.0

    # Coarse pass: every 2° from -15 to +15
    for angle_10 in range(-75, 76, 10):
        angle = angle_10 / 10.0
        rotated = bw.rotate(angle, resample=Image.BICUBIC, fillcolor=False)
        # Horizontal projection: sum each row
        proj = [0] * h
        for y in range(h):
            row_bits = rotated.crop((0, y, w, y + 1)).tobytes()
            proj[y] = sum(row_bits)
        var = sum((p - sum(proj) / h) ** 2 for p in proj) / h
        if var > best_var:
            best_var = var
            best_angle = angle

    # Fine pass: 0.5° around the best coarse angle
    for angle_10 in range(
        int((best_angle - 2.5) * 10),
        int((best_angle + 2.5) * 10) + 1,
        5,
    ):
        angle = angle_10 / 10.0
        rotated = bw.rotate(angle, resample=Image.BICUBIC, fillcolor=False)
        proj = [0] * h
        for y in range(h):
            row_bits = rotated.crop((0, y, w, y + 1)).tobytes()
            proj[y] = sum(row_bits)
        var = sum((p - sum(proj) / h) ** 2 for p in proj) / h
        if var > best_var:
            best_var = var
            best_angle = angle

    if abs(best_angle) > 0.3:
        image = image.rotate(best_angle, resample=Image.BICUBIC, fillcolor=255)
    return image


def preprocess_for_tesseract(image: Image.Image) -> Image.Image:
    """Extra preprocessing for Tesseract: deskew + heavier contrast."""
    img = preprocess(image)
    img = _deskew(img)
    return img


# ---------------------------------------------------------------------------
# RapidOCR (primary engine — deep learning via ONNX Runtime)
# ---------------------------------------------------------------------------

_rapid_ocr = None
_rapid_ocr_attempted = False


def _get_rapid_ocr():
    """Lazy-init the RapidOCR engine (heavy import, first call takes ~2s)."""
    global _rapid_ocr, _rapid_ocr_attempted
    if _rapid_ocr_attempted:
        return _rapid_ocr
    _rapid_ocr_attempted = True
    try:
        from rapidocr_onnxruntime import RapidOCR as _ROC
        _rapid_ocr = _ROC()
        logger.info("RapidOCR engine loaded successfully")
    except Exception as e:  # noqa: BLE001
        logger.warning("RapidOCR unavailable, will use Tesseract fallback: %s", e)
        _rapid_ocr = None
    return _rapid_ocr


def _ocr_with_rapid(image: Image.Image) -> Optional[str]:
    """Run RapidOCR on a Pillow image.  Returns the concatenated text lines,
    sorted top-to-bottom by vertical position."""
    engine = _get_rapid_ocr()
    if engine is None:
        return None

    # RapidOCR accepts file paths and numpy arrays; for Pillow images we
    # convert to a bytes buffer first.
    buf = io.BytesIO()
    image.save(buf, format="PNG")
    img_bytes = buf.getvalue()

    result, elapse = engine(img_bytes)
    if not result:
        return None

    # result is a list of [bbox, text, confidence].  Sort by vertical centre
    # so lines read top-to-bottom regardless of detection order.
    lines = []
    for bbox, text, conf in result:
        if not text or not text.strip():
            continue
        # Only include lines with reasonable confidence
        if conf < 0.3:
            continue
        y_centre = sum(pt[1] for pt in bbox) / len(bbox)
        x_left = min(pt[0] for pt in bbox)
        lines.append((y_centre, x_left, text.strip()))

    # Sort primarily by vertical position (top to bottom), then by x for
    # lines that are roughly at the same vertical level (same row).
    lines.sort(key=lambda t: (t[0] // 15, t[1]))  # 15px row grouping

    return "\n".join(text for _, _, text in lines) or None


# ---------------------------------------------------------------------------
# Tesseract (fallback engine)
# ---------------------------------------------------------------------------

_TESS_CONFIG = "--oem 1 --psm 6"
_FALLBACK_CONFIGS = ("--oem 1 --psm 4", "--oem 1 --psm 11")


def _count_numbers(text: str) -> int:
    """Lab sheets are number-dense; the pass with the most numeric tokens
    is the one that actually read the value column."""
    return len(re.findall(r"\d+[.,]?\d*", text or ""))


def _ocr_with_tesseract(image: Image.Image) -> Optional[str]:
    """Run Tesseract with automatic fallback page-segmentation modes."""
    try:
        import pytesseract
    except ImportError:
        return None

    img = preprocess_for_tesseract(image)
    try:
        primary = (pytesseract.image_to_string(img, config=_TESS_CONFIG) or "").strip()
    except Exception as e:  # noqa: BLE001
        logger.warning("Tesseract primary pass failed: %s", e)
        return None

    if _count_numbers(primary) > 0:
        return primary

    best, best_count = primary, _count_numbers(primary)
    for config in _FALLBACK_CONFIGS:
        try:
            alt = (pytesseract.image_to_string(img, config=config) or "").strip()
        except Exception:  # noqa: BLE001
            continue
        count = _count_numbers(alt)
        if count > best_count:
            best, best_count = alt, count
    return best or None


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def ocr_image_bytes(content: bytes) -> Optional[str]:
    """Run OCR on raw image bytes.  Tries RapidOCR first, then Tesseract.

    Returns None on any failure — OCR is best-effort and never fatal.
    """
    try:
        image = Image.open(io.BytesIO(content))
    except Exception as e:  # noqa: BLE001
        logger.exception("Could not open image for OCR: %s", e)
        return None

    preprocessed = preprocess(image)

    # --- RapidOCR (primary) ---
    try:
        text = _ocr_with_rapid(preprocessed)
        if text and _count_numbers(text) > 0:
            return text.strip() or None
        # If RapidOCR found text but no numbers, keep it as candidate
        # (Tesseract may do better on the tabular layout).
        rapid_candidate = text
    except Exception as e:  # noqa: BLE001
        logger.warning("RapidOCR failed, trying Tesseract: %s", e)
        rapid_candidate = None

    # --- Tesseract (fallback) ---
    try:
        tess_text = _ocr_with_tesseract(image)
    except Exception as e:  # noqa: BLE001
        logger.warning("Tesseract fallback failed: %s", e)
        tess_text = None

    # Pick the result with more numbers (lab values).
    rapid_count = _count_numbers(rapid_candidate) if rapid_candidate else 0
    tess_count = _count_numbers(tess_text) if tess_text else 0

    if rapid_candidate and rapid_count >= tess_count:
        return rapid_candidate.strip() or None
    if tess_text:
        return tess_text.strip() or None
    return rapid_candidate.strip() if rapid_candidate else None


def extract_pdf(content: bytes) -> Optional[str]:
    """Extract a PDF's text.  Per page, prefer the embedded text layer; when
    a page has none (a scanned image), rasterize it at ~300 DPI and OCR it.
    This rescues scanned hospital reports that used to extract nothing."""
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
        logger.exception("PDF extract error: %s", e)
    joined = "\n".join(parts).strip()
    return joined or None


async def extract_report_text(content: bytes, filename: str) -> Optional[str]:
    """Offline extraction.  The name is kept so callers do not care which
    engine produced the text."""
    name = (filename or "").lower()
    if name.endswith(IMAGE_EXTS):
        return ocr_image_bytes(content)
    if name.endswith(".pdf"):
        return extract_pdf(content)
    return None
