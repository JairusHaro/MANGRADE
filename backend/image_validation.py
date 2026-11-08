"""MangGrade image validation module.

Checks an uploaded mango photo BEFORE it reaches the CNN:

    1. file size          -> check_file_size()
    2. integrity          -> open_image()        (corrupt / unreadable files)
    3. file format        -> check_format()
    4. pixel limit        -> check_pixel_limit() (protects the server)
    5. resolution         -> check_resolution()
    6. brightness         -> check_brightness()
    7. blur               -> check_blur()        (OpenCV Laplacian variance)

validate_image_bytes() runs them in that order and returns a report.
Checks 1-4 are structural: if one fails, the image cannot be analysed,
so the rest are marked "skipped". Checks 5-7 are quality checks: all of
them run, so the user sees every problem with the photo at once.

This module never raises for a bad image; it returns a report. Callers
that must block bad images (e.g. /predict) call require_valid().
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from io import BytesIO
from typing import Any, Optional, Union

import cv2
import numpy as np
from PIL import Image, ImageOps, UnidentifiedImageError
from pydantic import BaseModel, Field

from validation_config import ValidationConfig

# ---------------------------------------------------------------------------
# Response models (Pydantic)
# ---------------------------------------------------------------------------


class CheckStatus(str, Enum):
    PASS = "pass"
    WARNING = "warning"
    FAIL = "fail"
    SKIPPED = "skipped"


class ValidationStatus(str, Enum):
    ACCEPTED = "accepted"
    ACCEPTED_WITH_WARNINGS = "accepted_with_warnings"
    REJECTED = "rejected"


class CheckResult(BaseModel):
    name: str = Field(description="Which check this is, e.g. 'blur'.")
    status: CheckStatus
    message: str
    value: Optional[Union[float, int, str]] = Field(
        default=None, description="The measured value, e.g. the blur score."
    )
    details: dict[str, Any] = Field(default_factory=dict)
    recommendation: Optional[str] = None


class ImageInfo(BaseModel):
    filename: str
    image_format: Optional[str] = None
    width: Optional[int] = None
    height: Optional[int] = None
    received_content_type: Optional[str] = None
    file_size_bytes: int


class ValidationReport(BaseModel):
    status: ValidationStatus
    is_valid: bool = Field(
        description="True when the image may go on to classification "
        "(accepted or accepted_with_warnings)."
    )
    message: str
    image: ImageInfo
    checks: list[CheckResult]
    warnings: list[str] = Field(default_factory=list)
    recommendations: list[str] = Field(default_factory=list)


# HTTP status used when a check rejects an image.
# 400/413 are what /predict already returned, so existing clients behave the same.
FAIL_HTTP_STATUS = {
    "file_size": 413,
    "integrity": 400,
    "format": 400,
    "pixel_limit": 413,
    "resolution": 422,
    "blur": 422,
    "brightness": 422,
}

STRUCTURAL_CHECKS = ["file_size", "integrity", "format", "pixel_limit"]
QUALITY_CHECKS = ["resolution", "brightness", "blur"]


class ImageValidationError(Exception):
    """Raised by require_valid() when an image is rejected."""

    def __init__(self, validated: "ValidatedImage", view: Optional[str] = None):
        self.validated = validated
        self.report = validated.report
        self.status_code = validated.http_status
        self.view = view
        super().__init__(self.detail)

    @property
    def detail(self) -> str:
        if self.view:
            return f"{self.view.capitalize()} photo: {self.report.message}"
        return self.report.message


@dataclass
class ValidatedImage:
    """Result of validation, plus the raw bytes for the model."""

    report: ValidationReport
    contents: bytes
    http_status: int = 200

    @property
    def is_valid(self) -> bool:
        return self.report.is_valid

    def to_rgb(self) -> Image.Image:
        """Decode the upload as an upright RGB PIL image.

        This is the hand-off point for the CNN. Model preprocessing starts
        from this image: see to_model_input(). Do NOT normalise pixel values
        here or later; the trained model rescales 0-255 input internally.
        """
        with Image.open(BytesIO(self.contents)) as image:
            upright = ImageOps.exif_transpose(image)
            return _flatten_alpha(upright).convert("RGB")

    def to_model_input(self) -> np.ndarray:
        """Upright RGB -> letterbox 224 -> JPEG q95 round trip -> float32 0-255.

        Returns a (224, 224, 3) float32 array, exactly the input the trained
        model was evaluated on. See the "Model preprocessing" section below.
        """
        return to_model_input(self.to_rgb())


# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

_FORMAT_LABELS = {"JPEG": "JPG", "PNG": "PNG", "WEBP": "WEBP"}
_FORMAT_ORDER = ["JPEG", "PNG", "WEBP"]


def describe_formats(formats) -> str:
    """{'JPEG','PNG','WEBP'} -> 'JPG, PNG, or WEBP'."""
    ordered = [f for f in _FORMAT_ORDER if f in formats]
    ordered += sorted(f for f in formats if f not in _FORMAT_ORDER)
    labels = [_FORMAT_LABELS.get(f, f) for f in ordered]
    if len(labels) == 1:
        return labels[0]
    if len(labels) == 2:
        return f"{labels[0]} or {labels[1]}"
    return ", ".join(labels[:-1]) + f", or {labels[-1]}"


def _format_megabytes(num_bytes: int) -> str:
    return f"{num_bytes / (1024 * 1024):g}"


def _flatten_alpha(image: Image.Image) -> Image.Image:
    """Put transparent images on a white background so they analyse sensibly."""
    has_alpha = image.mode in ("RGBA", "LA") or (
        image.mode == "P" and "transparency" in image.info
    )
    if not has_alpha:
        return image
    rgba = image.convert("RGBA")
    background = Image.new("RGBA", rgba.size, (255, 255, 255, 255))
    return Image.alpha_composite(background, rgba)


def to_analysis_gray(image: Image.Image, config: ValidationConfig) -> np.ndarray:
    """Upright 8-bit greyscale copy, resized so its long side = analysis_long_side.

    Resizing every image to the same scale makes the blur score comparable
    between a 1600 px phone photo and a 4000 px camera photo.
    """
    upright = ImageOps.exif_transpose(image)

    if upright.mode in ("I;16", "I;16B", "I;16L", "I", "F"):
        # 16-bit / 32-bit greyscale: rescale to 0-255 instead of clipping.
        array = np.asarray(upright, dtype=np.float64)
        top = 65535.0 if upright.mode.startswith("I;16") else max(array.max(), 1.0)
        gray = np.clip(array / top * 255.0, 0, 255).astype(np.uint8)
    else:
        gray = np.asarray(_flatten_alpha(upright).convert("L"), dtype=np.uint8)

    height, width = gray.shape[:2]
    scale = config.analysis_long_side / max(height, width)
    if scale != 1.0:
        interpolation = cv2.INTER_AREA if scale < 1.0 else cv2.INTER_LINEAR
        gray = cv2.resize(
            gray,
            (max(1, round(width * scale)), max(1, round(height * scale))),
            interpolation=interpolation,
        )
    return gray


# ---------------------------------------------------------------------------
# Individual checks
# ---------------------------------------------------------------------------


def check_file_size(size_bytes: int, config: ValidationConfig) -> CheckResult:
    limit = config.max_image_bytes
    if size_bytes > limit:
        return CheckResult(
            name="file_size",
            status=CheckStatus.FAIL,
            message=f"Image must be {_format_megabytes(limit)} MB or smaller.",
            value=size_bytes,
            details={"max_bytes": limit},
            recommendation="Use a lower camera resolution or compress the photo.",
        )
    if size_bytes == 0:
        return CheckResult(
            name="file_size",
            status=CheckStatus.FAIL,
            message="The uploaded file is empty.",
            value=0,
            details={"max_bytes": limit},
            recommendation="Choose the photo again; the upload contained no data.",
        )
    return CheckResult(
        name="file_size",
        status=CheckStatus.PASS,
        message="File size is within the limit.",
        value=size_bytes,
        details={"max_bytes": limit},
    )


def open_image(contents: bytes) -> tuple[Optional[Image.Image], CheckResult]:
    """Open and fully decode the image. Detects corrupt or truncated files.

    verify() checks the file structure, but it cannot catch every truncated
    file, so the image is reopened and fully decoded with load() as well.
    """
    try:
        with Image.open(BytesIO(contents)) as probe:
            probe.verify()
        image = Image.open(BytesIO(contents))
        image.load()
    except (UnidentifiedImageError, OSError, SyntaxError, ValueError, Image.DecompressionBombError):
        return None, CheckResult(
            name="integrity",
            status=CheckStatus.FAIL,
            message="The uploaded file is not a valid image.",
            recommendation="The file is damaged or not a photo. Take or choose the photo again.",
        )
    return image, CheckResult(
        name="integrity",
        status=CheckStatus.PASS,
        message="Image file is readable.",
    )


def check_format(image_format: Optional[str], config: ValidationConfig) -> CheckResult:
    allowed = describe_formats(config.allowed_formats)
    if image_format not in config.allowed_formats:
        return CheckResult(
            name="format",
            status=CheckStatus.FAIL,
            message=f"The uploaded content must be a {allowed} image.",
            value=image_format,
            details={"allowed_formats": sorted(config.allowed_formats)},
            recommendation=f"Save or export the photo as {allowed}.",
        )
    return CheckResult(
        name="format",
        status=CheckStatus.PASS,
        message=f"{_FORMAT_LABELS.get(image_format, image_format)} format is supported.",
        value=image_format,
        details={"allowed_formats": sorted(config.allowed_formats)},
    )


def check_pixel_limit(width: int, height: int, config: ValidationConfig) -> CheckResult:
    pixels = width * height
    if width <= 0 or height <= 0 or pixels > config.max_image_pixels:
        return CheckResult(
            name="pixel_limit",
            status=CheckStatus.FAIL,
            message="Image dimensions are too large to process safely.",
            value=pixels,
            details={"max_pixels": config.max_image_pixels},
            recommendation="Use a lower camera resolution.",
        )
    return CheckResult(
        name="pixel_limit",
        status=CheckStatus.PASS,
        message="Image dimensions are within the processing limit.",
        value=pixels,
        details={"max_pixels": config.max_image_pixels},
    )


def check_resolution(width: int, height: int, config: ValidationConfig) -> CheckResult:
    details = {
        "width": width,
        "height": height,
        "min_width": config.min_width,
        "min_height": config.min_height,
    }
    # Compare the short side with the smaller minimum and the long side with
    # the larger one, so portrait and landscape photos are treated the same.
    short_side, long_side = sorted((width, height))
    min_short, min_long = sorted((config.min_width, config.min_height))
    if short_side < min_short or long_side < min_long:
        return CheckResult(
            name="resolution",
            status=CheckStatus.FAIL,
            message=(
                f"Image resolution {width}x{height} is too low; "
                f"at least {config.min_width}x{config.min_height} is required."
            ),
            value=f"{width}x{height}",
            details=details,
            recommendation="Move closer to the mango or use a higher camera resolution.",
        )
    return CheckResult(
        name="resolution",
        status=CheckStatus.PASS,
        message="Resolution is sufficient for analysis.",
        value=f"{width}x{height}",
        details=details,
    )


def measure_blur(gray: np.ndarray, config: ValidationConfig) -> dict[str, float]:
    """Laplacian variance: globally and as a percentile over a grid of tiles.

    The Laplacian highlights edges; a sharp photo has strong edges, so the
    variance of the Laplacian is high. A blurry photo has weak edges and a
    low variance.

    Why tiles: a mango has smooth skin and the app asks for a plain
    background, so most of a SHARP mango photo is flat. That drags the
    global variance down. Scoring the sharpest tiles (the fruit outline,
    lenticels, stem) measures whether the photo is in focus where there is
    detail. A truly blurry photo has no sharp tile, so it still scores low.
    """
    laplacian = cv2.Laplacian(gray, cv2.CV_64F)
    global_variance = float(laplacian.var())

    grid = config.blur_grid_size
    height, width = laplacian.shape
    tile_variances = []
    for row in range(grid):
        for col in range(grid):
            tile = laplacian[
                row * height // grid : (row + 1) * height // grid,
                col * width // grid : (col + 1) * width // grid,
            ]
            if tile.size:
                tile_variances.append(float(tile.var()))

    score = float(np.percentile(tile_variances, config.blur_percentile))
    return {"score": score, "global_variance": global_variance}


def check_blur(gray: np.ndarray, config: ValidationConfig) -> CheckResult:
    measured = measure_blur(gray, config)
    score = round(measured["score"], 2)
    details = {
        "global_laplacian_variance": round(measured["global_variance"], 2),
        "method": f"{config.blur_percentile:g}th percentile of "
        f"{config.blur_grid_size}x{config.blur_grid_size} tile Laplacian variances",
        "reject_below": config.blur_reject_threshold,
        "warn_below": config.blur_warn_threshold,
    }

    if score < config.blur_reject_threshold:
        return CheckResult(
            name="blur",
            status=CheckStatus.FAIL,
            message=f"Image is too blurry (sharpness score {score}).",
            value=score,
            details=details,
            recommendation="Hold the phone steady, tap the mango to focus, and retake the photo.",
        )
    if score < config.blur_warn_threshold:
        return CheckResult(
            name="blur",
            status=CheckStatus.WARNING,
            message=f"Image is slightly blurry (sharpness score {score}).",
            value=score,
            details=details,
            recommendation="For a more reliable grade, retake the photo with the mango in focus.",
        )
    return CheckResult(
        name="blur",
        status=CheckStatus.PASS,
        message="Image is sharp enough.",
        value=score,
        details=details,
    )


def center_region(gray: np.ndarray, fraction: float) -> np.ndarray:
    """The middle `fraction` of the width and height (where the mango should be)."""
    if fraction >= 1.0:
        return gray
    height, width = gray.shape[:2]
    crop_h = max(1, round(height * fraction))
    crop_w = max(1, round(width * fraction))
    top = (height - crop_h) // 2
    left = (width - crop_w) // 2
    return gray[top : top + crop_h, left : left + crop_w]


def check_brightness(gray: np.ndarray, config: ValidationConfig) -> CheckResult:
    """Mean grey level (0-255) plus the share of blown-out and black pixels.

    Measured on the centre region only, so the background colour (white
    paper, black cloth) does not decide whether the mango is well lit.
    """
    region = center_region(gray, config.brightness_center_fraction)
    mean = round(float(region.mean()), 2)
    highlight_fraction = round(float((region >= config.highlight_level).mean()), 4)
    shadow_fraction = round(float((region <= config.shadow_level).mean()), 4)
    details = {
        "measured_region": f"centre {config.brightness_center_fraction:.0%} of width and height",
        "whole_image_mean_brightness": round(float(gray.mean()), 2),
        "mean_brightness": mean,
        "highlight_clipped_fraction": highlight_fraction,
        "shadow_clipped_fraction": shadow_fraction,
        "dark_reject_below": config.brightness_dark_reject,
        "dark_warn_below": config.brightness_dark_warn,
        "bright_warn_above": config.brightness_bright_warn,
        "bright_reject_above": config.brightness_bright_reject,
        "highlight_clip_warn_above": config.highlight_clip_warn,
        "highlight_clip_reject_above": config.highlight_clip_reject,
        "shadow_clip_warn_above": config.shadow_clip_warn,
    }

    if mean < config.brightness_dark_reject:
        return CheckResult(
            name="brightness",
            status=CheckStatus.FAIL,
            message=f"Image is too dark (brightness {mean} of 255).",
            value=mean,
            details=details,
            recommendation="Move to a brighter place or use daylight, then retake the photo.",
        )
    if mean > config.brightness_bright_reject:
        return CheckResult(
            name="brightness",
            status=CheckStatus.FAIL,
            message=f"Image is overexposed (brightness {mean} of 255).",
            value=mean,
            details=details,
            recommendation="Avoid direct sunlight or flash on the mango, then retake the photo.",
        )
    if highlight_fraction > config.highlight_clip_reject:
        return CheckResult(
            name="brightness",
            status=CheckStatus.FAIL,
            message=(
                f"{highlight_fraction:.0%} of the image is pure white, "
                "which can hide defects on the skin."
            ),
            value=mean,
            details=details,
            recommendation="Reduce glare: avoid flash and direct sunlight, use shade or diffuse light.",
        )

    problems = []
    recommendations = []
    if mean < config.brightness_dark_warn:
        problems.append(f"Image is somewhat dark (brightness {mean} of 255).")
        recommendations.append("Use more light for a clearer view of the skin.")
    if mean > config.brightness_bright_warn:
        problems.append(f"Image is quite bright (brightness {mean} of 255).")
        recommendations.append("Reduce direct light so colours are not washed out.")
    if highlight_fraction > config.highlight_clip_warn:
        problems.append(f"{highlight_fraction:.0%} of the image is blown-out white.")
        recommendations.append("Avoid flash and shiny reflections on the mango.")
    if shadow_fraction > config.shadow_clip_warn:
        problems.append(f"{shadow_fraction:.0%} of the image is pure black.")
        recommendations.append("Make sure the mango itself is well lit.")

    if problems:
        return CheckResult(
            name="brightness",
            status=CheckStatus.WARNING,
            message=" ".join(problems),
            value=mean,
            details=details,
            recommendation=" ".join(recommendations),
        )
    return CheckResult(
        name="brightness",
        status=CheckStatus.PASS,
        message="Lighting is adequate.",
        value=mean,
        details=details,
    )


# ---------------------------------------------------------------------------
# Model preprocessing ("Option B")
# ---------------------------------------------------------------------------
# These steps MUST match manggrade_prepare_dataset.py, which built every
# training/validation/test image:
#     exif_transpose -> RGB -> thumbnail((224, 224), LANCZOS)
#     -> centred on a black 224 x 224 canvas -> saved as JPEG quality 95.
# The model was trained and evaluated on those JPEG files, so the backend
# repeats the JPEG quality-95 step in memory. Verified 2026-11-02 with
# Pillow 12.3.0: this code reproduces all 281 stored test images
# byte-for-byte (tests/test_preprocessing.py guards this).
#
# The output is float32 in the 0-255 range. Do NOT divide by 255 or
# normalise: the model contains its own Rescaling layer (x / 127.5 - 1).
#
# Pillow is pinned in requirements.txt. A different Pillow (or libjpeg)
# version may produce different JPEG bytes: re-run the parity tests first.

MODEL_INPUT_SIZE = 224
TRAINING_JPEG_QUALITY = 95
LETTERBOX_FILL = (0, 0, 0)


def letterbox(image: Image.Image, size: int = MODEL_INPUT_SIZE) -> Image.Image:
    """Shrink to fit size x size keeping the aspect ratio (LANCZOS), centre on black."""
    image = image.copy()
    image.thumbnail((size, size), Image.LANCZOS)
    canvas = Image.new("RGB", (size, size), LETTERBOX_FILL)
    canvas.paste(image, ((size - image.width) // 2, (size - image.height) // 2))
    return canvas


def encode_training_jpeg(image: Image.Image, quality: int = TRAINING_JPEG_QUALITY) -> bytes:
    """Encode exactly like the training images were saved (Pillow, JPEG, quality 95)."""
    buffer = BytesIO()
    image.save(buffer, "JPEG", quality=quality)
    return buffer.getvalue()


def jpeg_roundtrip(image: Image.Image, quality: int = TRAINING_JPEG_QUALITY) -> Image.Image:
    """Encode and decode as JPEG in memory, as the training images were saved and read."""
    with Image.open(BytesIO(encode_training_jpeg(image, quality))) as decoded:
        return decoded.convert("RGB")


def to_model_input(rgb: Image.Image) -> np.ndarray:
    """Upright RGB image -> (224, 224, 3) float32, 0-255 (not normalised)."""
    array = np.asarray(jpeg_roundtrip(letterbox(rgb)), dtype=np.float32)
    if array.shape != (MODEL_INPUT_SIZE, MODEL_INPUT_SIZE, 3):
        raise ValueError(f"Unexpected model input shape {array.shape}")
    return array


# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------


def _skipped(names: list[str], reason: str) -> list[CheckResult]:
    return [
        CheckResult(name=name, status=CheckStatus.SKIPPED, message=reason)
        for name in names
    ]


def _build(
    checks: list[CheckResult], info: ImageInfo, contents: bytes
) -> ValidatedImage:
    failures = [c for c in checks if c.status == CheckStatus.FAIL]
    warnings = [c for c in checks if c.status == CheckStatus.WARNING]
    recommendations = [
        c.recommendation for c in failures + warnings if c.recommendation
    ]

    if failures:
        status = ValidationStatus.REJECTED
        message = " ".join(c.message for c in failures)
        http_status = FAIL_HTTP_STATUS.get(failures[0].name, 422)
    elif warnings:
        status = ValidationStatus.ACCEPTED_WITH_WARNINGS
        message = "Image accepted with warnings: " + " ".join(c.message for c in warnings)
        http_status = 200
    else:
        status = ValidationStatus.ACCEPTED
        message = "Image passed all quality checks."
        http_status = 200

    report = ValidationReport(
        status=status,
        is_valid=not failures,
        message=message,
        image=info,
        checks=checks,
        warnings=[c.message for c in warnings],
        recommendations=recommendations,
    )
    return ValidatedImage(report=report, contents=contents, http_status=http_status)


def validate_image_bytes(
    contents: bytes,
    config: ValidationConfig,
    *,
    filename: str = "uploaded_image",
    content_type: Optional[str] = None,
    size_bytes: Optional[int] = None,
) -> ValidatedImage:
    """Run every check on an uploaded image and return the full report.

    size_bytes is the real upload size when the caller stopped reading
    early (see read_upload); otherwise len(contents) is used.
    """
    size = len(contents) if size_bytes is None else size_bytes
    info = ImageInfo(
        filename=filename,
        received_content_type=content_type or None,
        file_size_bytes=size,
    )
    checks: list[CheckResult] = []

    # 1. File size
    checks.append(check_file_size(size, config))
    if checks[-1].status == CheckStatus.FAIL:
        checks += _skipped(STRUCTURAL_CHECKS[1:] + QUALITY_CHECKS, "Skipped: file size check failed.")
        return _build(checks, info, contents)

    # 2. Integrity (opens and fully decodes the image)
    image, integrity = open_image(contents)
    checks.append(integrity)
    if image is None:
        checks += _skipped(STRUCTURAL_CHECKS[2:] + QUALITY_CHECKS, "Skipped: image could not be read.")
        return _build(checks, info, contents)

    try:
        info.image_format = image.format
        info.width, info.height = image.size

        # 3. Format
        checks.append(check_format(image.format, config))
        # 4. Pixel limit
        checks.append(check_pixel_limit(info.width, info.height, config))
        if any(c.status == CheckStatus.FAIL for c in checks):
            checks += _skipped(
                [n for n in STRUCTURAL_CHECKS if n not in {c.name for c in checks}] + QUALITY_CHECKS,
                "Skipped: an earlier check failed.",
            )
            return _build(checks, info, contents)

        # 5-7. Quality checks: all of them run so every problem is reported.
        checks.append(check_resolution(info.width, info.height, config))
        gray = to_analysis_gray(image, config)
        # Brightness before blur: bad lighting also lowers the blur score,
        # so the lighting message should come first.
        checks.append(check_brightness(gray, config))
        checks.append(check_blur(gray, config))
    finally:
        image.close()

    return _build(checks, info, contents)


async def read_upload(file, config: ValidationConfig) -> tuple[bytes, int]:
    """Read a FastAPI UploadFile without loading more than the limit + 1 byte.

    Returns (contents, size). When the file is over the limit, size is
    limit + 1, which is enough for check_file_size() to reject it.
    """
    try:
        contents = await file.read(config.max_image_bytes + 1)
    finally:
        await file.close()
    return contents, len(contents)


def require_valid(validated: ValidatedImage, view: Optional[str] = None) -> ValidatedImage:
    """Raise ImageValidationError if the image was rejected; otherwise return it."""
    if not validated.is_valid:
        raise ImageValidationError(validated, view=view)
    return validated
