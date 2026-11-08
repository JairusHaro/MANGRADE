"""Configurable thresholds for MangGrade image validation.

Every value has a sensible default and can be overridden WITHOUT editing
code by setting an environment variable named MANGGRADE_<FIELD NAME>.

Examples (Windows PowerShell, before starting uvicorn):
    $env:MANGGRADE_BLUR_REJECT_THRESHOLD = "30"
    $env:MANGGRADE_MIN_WIDTH = "480"
    $env:MANGGRADE_ALLOWED_FORMATS = "JPEG,PNG"

Examples (Command Prompt):
    set MANGGRADE_BLUR_REJECT_THRESHOLD=30
"""

from __future__ import annotations

import os
from dataclasses import dataclass, fields

ENV_PREFIX = "MANGGRADE_"


@dataclass(frozen=True)
class ValidationConfig:
    # ---- 1. File format -------------------------------------------------
    # Pillow format names. "JPEG" covers both .jpg and .jpeg files.
    allowed_formats: frozenset = frozenset({"JPEG", "PNG", "WEBP"})

    # ---- 2. File size ---------------------------------------------------
    max_image_bytes: int = 10 * 1024 * 1024  # 10 MB
    # Upper limit on width x height, protects the server from huge images.
    max_image_pixels: int = 40_000_000

    # ---- 3. Resolution --------------------------------------------------
    # MobileNet input is 224 x 224; require headroom above that.
    min_width: int = 320
    min_height: int = 320

    # ---- 4. Blur (Laplacian variance) -----------------------------------
    # Every image is resized so its longest side equals this value before
    # measuring, so the thresholds mean the same thing for any upload size.
    analysis_long_side: int = 1024
    # The image is split into a grid of tiles; the score used for the
    # decision is this percentile of the tile scores (see image_validation).
    blur_grid_size: int = 8
    blur_percentile: float = 90.0
    # Score below reject threshold -> rejected; below warn -> warning.
    # PROVISIONAL: calibrate on your own mango photos (calibrate_thresholds.py).
    blur_reject_threshold: float = 40.0
    blur_warn_threshold: float = 100.0

    # ---- 5. Brightness (mean grey level, 0 = black, 255 = white) --------
    # Brightness is measured on the centre of the photo, where the Scan
    # screen's frame guide places the mango, so a white or black background
    # does not decide the result. 0.5 = the middle half of width and height;
    # 1.0 = the whole image.
    brightness_center_fraction: float = 0.5
    brightness_dark_reject: float = 40.0
    brightness_dark_warn: float = 70.0
    brightness_bright_warn: float = 200.0
    brightness_bright_reject: float = 225.0
    # Share of pixels that are pure white (blown-out highlights hide defects).
    highlight_level: int = 250
    highlight_clip_warn: float = 0.05
    highlight_clip_reject: float = 0.25
    # Share of pixels that are pure black. Warning only, because a dark
    # background is normal and should not reject an otherwise good photo.
    shadow_level: int = 5
    shadow_clip_warn: float = 0.50

    def __post_init__(self) -> None:
        problems = []
        if self.blur_reject_threshold > self.blur_warn_threshold:
            problems.append("blur_reject_threshold must be <= blur_warn_threshold")
        if not (
            self.brightness_dark_reject
            <= self.brightness_dark_warn
            < self.brightness_bright_warn
            <= self.brightness_bright_reject
        ):
            problems.append(
                "brightness thresholds must satisfy "
                "dark_reject <= dark_warn < bright_warn <= bright_reject"
            )
        if self.highlight_clip_warn > self.highlight_clip_reject:
            problems.append("highlight_clip_warn must be <= highlight_clip_reject")
        if not 0 < self.brightness_center_fraction <= 1:
            problems.append("brightness_center_fraction must be between 0 and 1")
        if not 0 < self.blur_percentile <= 100:
            problems.append("blur_percentile must be between 0 and 100")
        if self.blur_grid_size < 1 or self.analysis_long_side < 64:
            problems.append("blur_grid_size must be >= 1 and analysis_long_side >= 64")
        if not self.allowed_formats:
            problems.append("allowed_formats must not be empty")
        if problems:
            raise ValueError("Invalid validation config: " + "; ".join(problems))


def _parse(raw: str, default):
    """Convert an environment string to the same type as the default."""
    if isinstance(default, bool):
        return raw.strip().lower() in {"1", "true", "yes", "on"}
    if isinstance(default, int):
        return int(raw)
    if isinstance(default, float):
        return float(raw)
    if isinstance(default, frozenset):
        return frozenset(p.strip().upper() for p in raw.split(",") if p.strip())
    return raw


def load_config() -> ValidationConfig:
    """Build the config from defaults plus any MANGGRADE_* environment variables."""
    defaults = ValidationConfig()
    overrides = {}
    for field in fields(ValidationConfig):
        raw = os.environ.get(ENV_PREFIX + field.name.upper())
        if raw is not None:
            overrides[field.name] = _parse(raw, getattr(defaults, field.name))
    return ValidationConfig(**overrides)
