# Ayuvo API image.
#
# Why Docker (vs Render's native Python runtime): report OCR uses pytesseract,
# which is only a Python wrapper around the `tesseract` *system binary*. The
# native runtime can't install that binary, so image / scanned-PDF text
# extraction silently returned None in production. This image bakes tesseract in
# so Render behaves exactly like local dev.
FROM python:3.12-slim

# tesseract-ocr: the OCR engine pytesseract shells out to (English data incl.).
# The rest are slim runtime libs Pillow/PyMuPDF expect for image handling.
# --no-install-recommends + apt-list cleanup keep the image small.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        tesseract-ocr \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install deps first so Docker layer-caches them across code-only changes.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Render injects $PORT at runtime; fall back to 3001 for local `docker run`.
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-3001}"]
