"""Preprocessing parity regression tests (no model needed).

These prove that the backend turns an original photo into EXACTLY the
224x224 JPEG the model was trained and evaluated on (Option B).
If any test here fails after a library upgrade, do not deploy: the model
would receive different input from what it was evaluated on.
"""

import hashlib
from io import BytesIO

import numpy as np
import PIL
import pytest
from PIL import Image

from conftest import PARITY_DIR, load_parity_fixtures
from image_validation import (
    MODEL_INPUT_SIZE,
    ValidatedImage,
    encode_training_jpeg,
    letterbox,
    to_model_input,
    validate_image_bytes,
)
from validation_config import ValidationConfig

FIXTURES = load_parity_fixtures()
IDS = [f["stored"] for f in FIXTURES]


def _original_bytes(fixture: dict) -> bytes:
    return (PARITY_DIR / "originals" / fixture["original"]).read_bytes()


def _stored_bytes(fixture: dict) -> bytes:
    return (PARITY_DIR / "stored" / fixture["stored"]).read_bytes()


def _validated(fixture: dict) -> ValidatedImage:
    # Generous limits so the parity test never depends on quality thresholds.
    config = ValidationConfig(max_image_pixels=200_000_000, max_image_bytes=50 * 1024 * 1024)
    return validate_image_bytes(_original_bytes(fixture), config, filename=fixture["original"])


def test_pillow_is_the_verified_version():
    # Byte-exact parity was verified with Pillow 12.3.0 (requirements.txt pin).
    assert PIL.__version__ == "12.3.0"


@pytest.mark.parametrize("fixture", FIXTURES, ids=IDS)
def test_fixture_files_are_the_dataset_files(fixture):
    assert hashlib.sha256(_original_bytes(fixture)).hexdigest() == fixture["original_sha256"]
    assert hashlib.sha256(_stored_bytes(fixture)).hexdigest() == fixture["stored_sha256"]


@pytest.mark.parametrize("fixture", FIXTURES, ids=IDS)
def test_backend_jpeg_bytes_identical_to_training_file(fixture):
    """Option B: backend letterbox + JPEG q95 == the stored training file, byte for byte."""
    validated = _validated(fixture)
    produced = encode_training_jpeg(letterbox(validated.to_rgb()))
    assert produced == _stored_bytes(fixture)


@pytest.mark.parametrize("fixture", FIXTURES, ids=IDS)
def test_model_input_identical_to_decoded_training_file(fixture):
    with Image.open(BytesIO(_stored_bytes(fixture))) as stored:
        expected = np.asarray(stored.convert("RGB"), dtype=np.float32)
    produced = _validated(fixture).to_model_input()
    assert produced.dtype == np.float32
    assert produced.shape == (MODEL_INPUT_SIZE, MODEL_INPUT_SIZE, 3)
    assert np.array_equal(produced, expected)


@pytest.mark.parametrize("fixture", FIXTURES, ids=IDS)
def test_exif_orientation_handled_like_training(fixture):
    """Upright size must match what the dataset builder recorded (manifest)."""
    rgb = _validated(fixture).to_rgb()
    with Image.open(BytesIO(_original_bytes(fixture))) as raw:
        orientation = raw.getexif().get(0x0112, 1)
        raw_size = raw.size
    assert orientation == fixture["exif_orientation"]
    expected = raw_size[::-1] if orientation in (5, 6, 7, 8) else raw_size
    assert rgb.size == expected


def test_input_is_not_normalised():
    """Values stay in 0-255. The model rescales internally (x / 127.5 - 1)."""
    fixture = FIXTURES[0]
    array = _validated(fixture).to_model_input()
    assert array.min() >= 0.0
    assert array.max() <= 255.0
    assert array.max() > 1.0  # would be <= 1.0 if someone divided by 255


@pytest.mark.parametrize(
    "size",
    [(1620, 1080), (1080, 1620), (500, 500), (4000, 300), (300, 4000), (223, 100)],
)
def test_letterbox_geometry_and_black_padding(size):
    rng = np.random.default_rng(0)
    pixels = rng.integers(1, 256, size=(size[1], size[0], 3), dtype=np.uint8)  # no pure black
    image = Image.fromarray(pixels, "RGB")
    reference = image.copy()
    reference.thumbnail((MODEL_INPUT_SIZE, MODEL_INPUT_SIZE), Image.LANCZOS)
    box_w, box_h = reference.size
    left, top = (MODEL_INPUT_SIZE - box_w) // 2, (MODEL_INPUT_SIZE - box_h) // 2

    canvas = np.asarray(letterbox(image))
    assert canvas.shape == (MODEL_INPUT_SIZE, MODEL_INPUT_SIZE, 3)
    padding = np.ones((MODEL_INPUT_SIZE, MODEL_INPUT_SIZE), bool)
    padding[top : top + box_h, left : left + box_w] = False
    assert (canvas[padding] == 0).all()
    assert np.array_equal(canvas[top : top + box_h, left : left + box_w], np.asarray(reference))


def _with_orientation(upright: Image.Image, orientation: int) -> bytes:
    """Store `upright` the way a camera would for the given EXIF orientation."""
    inverse = {
        1: lambda im: im,
        2: lambda im: im.transpose(Image.Transpose.FLIP_LEFT_RIGHT),
        3: lambda im: im.transpose(Image.Transpose.ROTATE_180),
        4: lambda im: im.transpose(Image.Transpose.FLIP_TOP_BOTTOM),
        5: lambda im: im.transpose(Image.Transpose.TRANSPOSE),
        6: lambda im: im.transpose(Image.Transpose.ROTATE_90),
        7: lambda im: im.transpose(Image.Transpose.TRANSVERSE),
        8: lambda im: im.transpose(Image.Transpose.ROTATE_270),
    }[orientation]
    exif = Image.Exif()
    exif[0x0112] = orientation
    buffer = BytesIO()
    inverse(upright).save(buffer, "PNG", exif=exif)  # PNG: lossless, so pixels compare exactly
    return buffer.getvalue()


@pytest.mark.parametrize("orientation", range(1, 9))
def test_all_eight_exif_orientations_give_the_same_input(orientation):
    rng = np.random.default_rng(1)
    upright = Image.fromarray(rng.integers(0, 256, size=(400, 640, 3), dtype=np.uint8), "RGB")
    reference = to_model_input(upright)
    validated = ValidatedImage(report=None, contents=_with_orientation(upright, orientation))
    assert np.array_equal(validated.to_model_input(), reference)
