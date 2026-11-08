"""MangGrade model service: loads the verified TFLite model once and runs it.

The model is loaded a single time at application start-up (see main.py
lifespan). Every check below must pass before the model is used:

    1. the model and labels files exist;
    2. the model file's SHA-256 equals the verified value;
    3. labels.txt lists exactly: Extra Class, Class I, Class II, Reject;
    4. input tensor is float32 [1, 224, 224, 3]; output is float32 [1, 4];
    5. a self-test run returns valid probabilities.

If any check fails, the service is marked unavailable and the reason is
kept, so the API can answer 503 with a clear message. No fallback or
simulated grade is ever produced.

A LiteRT Interpreter is not thread-safe, so every inference holds a lock.
"""

from __future__ import annotations

import hashlib
import importlib.metadata
import logging
import os
import threading
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable, Mapping, Optional, Sequence

import numpy as np

logger = logging.getLogger("manggrade.model")

# Exact class order of the trained model's output (labels.txt / model_info.json).
GRADES: tuple[str, ...] = ("Extra Class", "Class I", "Class II", "Reject")

MODEL_FILENAME = "manggrade_mobilenetv3.tflite"
LABELS_FILENAME = "labels.txt"
MODEL_INFO_FILENAME = "model_info.json"

# SHA-256 of the verified model (MangGrade_Model/manggrade_mobilenetv3.tflite,
# 6,055,136 bytes). Override with MANGGRADE_MODEL_SHA256 only for a newly
# approved model.
VERIFIED_MODEL_SHA256 = "45456c093cb5e95f6d65adf396998caf9971068603beaf8b47f8b49bde2a330b"

INPUT_SHAPE = (1, 224, 224, 3)
OUTPUT_SHAPE = (1, len(GRADES))

# Numerical tolerance for checking that softmax outputs sum to 1.
# This is an integrity check on the model output, NOT a grading threshold.
PROBABILITY_SUM_TOLERANCE = 1e-3

PREPROCESSING_DESCRIPTION = (
    "EXIF upright, RGB, letterbox to 224x224 (LANCZOS, black padding), "
    "JPEG quality-95 round trip, float32 0-255 (no normalisation)"
)

AGGREGATION_METHOD = "mean_probability"
AGGREGATION_NOTE = (
    "Provisional: the final grade is the class with the highest average "
    "probability over the front, back and top photos. This method has not "
    "yet been validated on a separate whole-mango three-view dataset."
)

DEFAULT_MODEL_DIR = Path(__file__).resolve().parent / "model"


class ModelUnavailableError(RuntimeError):
    """The model is not loaded (missing file, failed checks, ...)."""


class InferenceError(RuntimeError):
    """The model ran but failed or produced an invalid output."""


@dataclass(frozen=True)
class Prediction:
    """One image's model output."""

    probabilities: tuple[float, ...]

    @property
    def index(self) -> int:
        # np.argmax returns the FIRST maximum: on an exact tie the earlier
        # class in label order wins (documented, not tuned).
        return int(np.argmax(self.probabilities))

    @property
    def grade(self) -> str:
        return GRADES[self.index]

    @property
    def confidence(self) -> float:
        return float(self.probabilities[self.index])

    def as_dict(self) -> dict[str, Any]:
        return {
            "grade": self.grade,
            "confidence": _round(self.confidence),
            "probabilities": probabilities_dict(self.probabilities),
        }


@dataclass(frozen=True)
class AggregatedPrediction:
    """Final grade for one mango from its per-view predictions."""

    views: Mapping[str, Prediction]
    probabilities: tuple[float, ...]

    @property
    def index(self) -> int:
        return int(np.argmax(self.probabilities))

    @property
    def grade(self) -> str:
        return GRADES[self.index]

    @property
    def confidence(self) -> float:
        return float(self.probabilities[self.index])

    @property
    def views_agree(self) -> bool:
        """True only when every view predicts the same grade (a fact, not a threshold)."""
        return len({p.grade for p in self.views.values()}) == 1


def probabilities_dict(probabilities: Sequence[float]) -> dict[str, float]:
    return {label: _round(p) for label, p in zip(GRADES, probabilities)}


def _round(value: float) -> float:
    return round(float(value), 6)


def aggregate_mean(views: Mapping[str, Prediction]) -> AggregatedPrediction:
    """Average the views' probability vectors (provisional default method)."""
    if not views:
        raise ValueError("At least one view is required.")
    stacked = np.array([p.probabilities for p in views.values()], dtype=np.float64)
    mean = stacked.mean(axis=0)
    return AggregatedPrediction(views=dict(views), probabilities=tuple(float(v) for v in mean))


def check_probabilities(output: np.ndarray) -> tuple[float, ...]:
    """Validate a model output vector; raise InferenceError if it is not a probability vector."""
    vector = np.asarray(output, dtype=np.float64).reshape(-1)
    if vector.shape != (len(GRADES),):
        raise InferenceError(f"Model output has shape {vector.shape}, expected ({len(GRADES)},).")
    if not np.all(np.isfinite(vector)):
        raise InferenceError("Model output contains NaN or infinite values.")
    if np.any(vector < -1e-6) or np.any(vector > 1 + 1e-6):
        raise InferenceError("Model output has values outside [0, 1].")
    if abs(vector.sum() - 1.0) > PROBABILITY_SUM_TOLERANCE:
        raise InferenceError(f"Model output sums to {vector.sum():.6f}, not 1.")
    return tuple(float(v) for v in vector)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def _litert_interpreter(model_path: str):
    from ai_edge_litert.interpreter import Interpreter  # imported lazily

    return Interpreter(model_path=model_path)


def _runtime_version() -> Optional[str]:
    try:
        return "ai-edge-litert " + importlib.metadata.version("ai-edge-litert")
    except importlib.metadata.PackageNotFoundError:
        return None


class ModelService:
    """Owns the single interpreter instance."""

    def __init__(
        self,
        model_dir: Optional[Path] = None,
        expected_sha256: Optional[str] = None,
        interpreter_factory: Optional[Callable[[str], Any]] = None,
    ) -> None:
        self.model_dir = Path(
            model_dir or os.environ.get("MANGGRADE_MODEL_DIR") or DEFAULT_MODEL_DIR
        )
        self.expected_sha256 = (
            expected_sha256 or os.environ.get("MANGGRADE_MODEL_SHA256") or VERIFIED_MODEL_SHA256
        ).lower()
        self._interpreter_factory = interpreter_factory or _litert_interpreter
        self._lock = threading.Lock()
        self._interpreter = None
        self._input_index: Optional[int] = None
        self._output_index: Optional[int] = None
        self._error: Optional[str] = "Model has not been loaded yet."
        self._sha256: Optional[str] = None
        self._load_ms: Optional[float] = None

    # ------------------------------------------------------------------ status
    @property
    def available(self) -> bool:
        return self._interpreter is not None and self._error is None

    @property
    def error(self) -> Optional[str]:
        return self._error

    @property
    def model_path(self) -> Path:
        return self.model_dir / MODEL_FILENAME

    def metadata(self) -> dict[str, Any]:
        """Model facts that are safe to include in API responses."""
        return {
            "file": MODEL_FILENAME,
            "sha256": self._sha256,
            "runtime": _runtime_version(),
            "input": list(INPUT_SHAPE),
            "labels": list(GRADES),
            "preprocessing": PREPROCESSING_DESCRIPTION,
        }

    def status(self) -> dict[str, Any]:
        return {
            "available": self.available,
            "model_status": "loaded" if self.available else "unavailable",
            "error": self._error,
            "model": self.metadata(),
            "load_ms": None if self._load_ms is None else round(self._load_ms, 1),
        }

    # -------------------------------------------------------------------- load
    def load(self) -> bool:
        """Load and verify the model. Never raises; returns True on success."""
        started = time.perf_counter()
        self._interpreter = None
        try:
            interpreter, input_index, output_index, sha256 = self._load_and_check()
        except Exception as error:  # noqa: BLE001 - every failure becomes a clear status
            self._error = str(error) or error.__class__.__name__
            logger.error("MangGrade model NOT loaded: %s", self._error)
            return False

        self._interpreter = interpreter
        self._input_index = input_index
        self._output_index = output_index
        self._sha256 = sha256
        self._error = None
        try:
            self.predict(np.zeros(INPUT_SHAPE[1:], dtype=np.float32))  # self-test
        except Exception as error:  # noqa: BLE001
            self._interpreter = None
            self._error = f"Model self-test failed: {error}"
            logger.error("MangGrade model NOT loaded: %s", self._error)
            return False

        self._load_ms = (time.perf_counter() - started) * 1000
        logger.info("MangGrade model loaded from %s in %.0f ms", self.model_path, self._load_ms)
        return True

    def _load_and_check(self):
        model_path = self.model_path
        labels_path = self.model_dir / LABELS_FILENAME
        if not model_path.is_file():
            raise ModelUnavailableError(f"Model file not found: {model_path}")
        if not labels_path.is_file():
            raise ModelUnavailableError(f"Labels file not found: {labels_path}")

        sha256 = sha256_file(model_path)
        if sha256 != self.expected_sha256:
            raise ModelUnavailableError(
                f"Model file SHA-256 {sha256} does not match the verified model "
                f"{self.expected_sha256}."
            )

        labels = tuple(
            line.strip() for line in labels_path.read_text(encoding="utf-8").splitlines() if line.strip()
        )
        if labels != GRADES:
            raise ModelUnavailableError(
                f"labels.txt lists {list(labels)}, expected {list(GRADES)} in this order."
            )

        try:
            interpreter = self._interpreter_factory(str(model_path))
            interpreter.allocate_tensors()
        except ImportError as error:
            raise ModelUnavailableError(f"LiteRT runtime is not installed: {error}") from error
        except Exception as error:
            raise ModelUnavailableError(f"LiteRT could not load the model: {error}") from error

        inputs = interpreter.get_input_details()
        outputs = interpreter.get_output_details()
        if len(inputs) != 1 or len(outputs) != 1:
            raise ModelUnavailableError(
                f"Expected 1 input and 1 output tensor, found {len(inputs)} and {len(outputs)}."
            )
        _check_tensor("input", inputs[0], INPUT_SHAPE)
        _check_tensor("output", outputs[0], OUTPUT_SHAPE)
        return interpreter, int(inputs[0]["index"]), int(outputs[0]["index"]), sha256

    # ----------------------------------------------------------------- predict
    def predict(self, model_input: np.ndarray) -> Prediction:
        """Run the model on one (224, 224, 3) float32 image (0-255)."""
        if not self.available:
            raise ModelUnavailableError(self._error or "Model is not loaded.")
        array = np.asarray(model_input)
        if array.shape != INPUT_SHAPE[1:] or array.dtype != np.float32:
            raise InferenceError(
                f"Model input must be float32 {INPUT_SHAPE[1:]}, got {array.dtype} {array.shape}."
            )
        if not np.all(np.isfinite(array)):
            raise InferenceError("Model input contains NaN or infinite values.")

        with self._lock:
            try:
                self._interpreter.set_tensor(self._input_index, array[np.newaxis, ...])
                self._interpreter.invoke()
                output = np.array(self._interpreter.get_tensor(self._output_index), copy=True)
            except Exception as error:
                raise InferenceError(f"LiteRT inference failed: {error}") from error
        return Prediction(probabilities=check_probabilities(output))


def _check_tensor(kind: str, details: Mapping[str, Any], expected_shape: tuple[int, ...]) -> None:
    shape = tuple(int(v) for v in np.asarray(details["shape"]).tolist())
    dtype = np.dtype(details["dtype"])
    if shape != expected_shape:
        raise ModelUnavailableError(f"Model {kind} shape is {list(shape)}, expected {list(expected_shape)}.")
    if dtype != np.float32:
        raise ModelUnavailableError(f"Model {kind} type is {dtype.name}, expected float32.")
    scale, _zero_point = details.get("quantization", (0.0, 0))
    if scale not in (0, 0.0):
        raise ModelUnavailableError(f"Model {kind} is quantized; a float32 model is expected.")
