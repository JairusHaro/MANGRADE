
from io import BytesIO

from fastapi import FastAPI, File, HTTPException, UploadFile
from PIL import Image, UnidentifiedImageError

app = FastAPI(
    title="MangGrade API",
    description="Mango quality grading system prototype",
    version="0.1.0",
)

GRADES = ["Extra Class", "Class I", "Class II", "Reject"]


@app.get("/")
def home():
    return {
        "message": "Welcome to MangGrade!",
        "status": "running",
        "model_status": "not connected yet",
    }


@app.get("/health")
def health_check():
    return {"status": "healthy"}


@app.post("/predict")
async def predict_mango(file: UploadFile = File(...)):
    if file.content_type not in (
        "image/jpeg",
        "image/png",
        "image/webp",
    ):
        raise HTTPException(
            status_code=400,
            detail="Please upload a JPG, PNG, or WEBP image.",
        )

    contents = await file.read()

    if len(contents) > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=413,
            detail="Image must be 10 MB or smaller.",
        )

    try:
        image = Image.open(BytesIO(contents))
        image.verify()
    except (UnidentifiedImageError, OSError):
        raise HTTPException(
            status_code=400,
            detail="The uploaded file is not a valid image.",
        )

    return {
        "filename": file.filename,
        "predicted_grade": None,
        "confidence": None,
        "grades": GRADES,
        "model_status": "not trained",
        "message": (
            "Image received successfully. "
            "Connect a trained model to predict the grade."
        ),
    }
