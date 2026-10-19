from io import BytesIO

from fastapi import FastAPI, File, HTTPException, UploadFile
from PIL import Image, UnidentifiedImageError

app = FastAPI(
    title="MangGrade API",
    description="Mango quality grading system prototype",
    version="0.2.0",
)

GRADES = ["Extra Class", "Class I", "Class II", "Reject"]
MAX_IMAGE_BYTES = 10 * 1024 * 1024
MAX_IMAGE_PIXELS = 40_000_000
ALLOWED_MIME_TYPES = {"image/jpeg", "image/png", "image/webp"}
ALLOWED_IMAGE_FORMATS = {"JPEG", "PNG", "WEBP"}


@app.get("/")
def home():
    return {
        "message": "Welcome to MangGrade!",
        "status": "running",
        "model_status": "not connected yet",
        "inference_mode": "not configured",
    }


@app.get("/health")
def health_check():
    return {"status": "healthy"}


@app.get("/model-status")
def model_status():
    """Reports model availability without implying that demo results are predictions."""
    return {
        "available": False,
        "model_status": "not trained or connected",
        "grades": GRADES,
    }


@app.post("/predict")
async def predict_mango(file: UploadFile = File(...)):
    """Validate an uploaded image. No prediction is made until a model is connected."""
    content_type = (file.content_type or "").lower().split(";")[0].strip()
    if content_type not in ALLOWED_MIME_TYPES:
        await file.close()
        raise HTTPException(
            status_code=400,
            detail="Please upload a JPG, PNG, or WEBP image.",
        )

    try:
        # Read at most one byte beyond the limit to avoid loading an arbitrarily
        # large upload into memory.
        contents = await file.read(MAX_IMAGE_BYTES + 1)
    finally:
        await file.close()

    if len(contents) > MAX_IMAGE_BYTES:
        raise HTTPException(
            status_code=413,
            detail="Image must be 10 MB or smaller.",
        )

    try:
        with Image.open(BytesIO(contents)) as image:
            image_format = image.format
            width, height = image.size
            if image_format not in ALLOWED_IMAGE_FORMATS:
                raise HTTPException(
                    status_code=400,
                    detail="The uploaded content must be a JPG, PNG, or WEBP image.",
                )
            if width <= 0 or height <= 0 or width * height > MAX_IMAGE_PIXELS:
                raise HTTPException(
                    status_code=413,
                    detail="Image dimensions are too large to process safely.",
                )
            image.verify()
    except HTTPException:
        raise
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError):
        raise HTTPException(
            status_code=400,
            detail="The uploaded file is not a valid image.",
        )

    return {
        "filename": file.filename,
        "image_format": image_format,
        "width": width,
        "height": height,
        "predicted_grade": None,
        "confidence": None,
        "grades": GRADES,
        "model_status": "not connected",
        "prediction_is_real": False,
        "message": (
            "Image received and validated successfully. "
            "No grade was predicted because the trained model is not connected."
        ),
    }
