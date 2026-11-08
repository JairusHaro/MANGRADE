"""Model service tests.

* Loading checks and aggregation use a fake interpreter (run anywhere).
* Real-model tests (marked requires_litert) load the verified TFLite file
  and compare its outputs with the values recorded in Colab (LiteRT 2.3.0).
  They are skipped automatically where ai-edge-litert is not installed.
"""

import hashlib
import shutil

import numpy as np
import pytest

from conftest import PARITY_DIR, load_parity_fixtures, requires_litert
from fakes import fake_factory
from image_validation import ValidatedImage, letterbox, validate_image_bytes
from model_service import (
    AGGREGATION_NOTE,
    DEFAULT_MODEL_DIR,
    GRADES,
    MODEL_FILENAME,
    VERIFIED_MODEL_SHA256,
    InferenceError,
    ModelService,
    ModelUnavailableError,
    Prediction,
    aggregate_mean,
    check_probabilities,
)
from validation_config import ValidationConfig

FIXTURES = load_parity_fixtures()
IDS = [f["stored"] for f in FIXTURES]


# --------------------------------------------------------------- model files
def test_bundled_model_files_are_the_verified_ones():
    model = DEFAULT_MODEL_DIR / MODEL_FILENAME
    assert hashlib.sha256(model.read_bytes()).hexdigest() == VERIFIED_MODEL_SHA256
    assert model.stat().st_size == 6_055_136
    labels = (DEFAULT_MODEL_DIR / "labels.txt").read_text(encoding="utf-8").split()
    assert " ".join(labels) == "Extra Class Class I Class II Reject"


def test_grades_order_matches_model_info():
    import json

    info = json.loads((DEFAULT_MODEL_DIR / "model_info.json").read_text(encoding="utf-8"))
    assert tuple(info["output"]["order"]) == GRADES
    assert info["input"]["shape"] == [1, 224, 224, 3]


# ------------------------------------------------------------- loading checks
def _service(model_dir=DEFAULT_MODEL_DIR, **fake_kwargs):
    return ModelService(model_dir=model_dir, interpreter_factory=fake_factory(**fake_kwargs))


def test_load_succeeds_with_valid_files_and_runs_self_test():
    factory = fake_factory()
    service = ModelService(model_dir=DEFAULT_MODEL_DIR, interpreter_factory=factory)
    assert service.load() is True
    assert service.available
    assert service.error is None
    assert factory.created[0].invocations == 1  # self-test ran
    status = service.status()
    assert status["model_status"] == "loaded"
    assert status["model"]["sha256"] == VERIFIED_MODEL_SHA256
    assert status["model"]["labels"] == list(GRADES)


def test_not_loaded_service_refuses_to_predict():
    service = _service()
    assert not service.available
    with pytest.raises(ModelUnavailableError):
        service.predict(np.zeros((224, 224, 3), np.float32))


def test_missing_model_file(tmp_path):
    shutil.copy(DEFAULT_MODEL_DIR / "labels.txt", tmp_path / "labels.txt")
    service = _service(tmp_path)
    assert service.load() is False
    assert "Model file not found" in service.error
    with pytest.raises(ModelUnavailableError, match="not found"):
        service.predict(np.zeros((224, 224, 3), np.float32))


def test_wrong_sha256_is_rejected(tmp_path):
    (tmp_path / MODEL_FILENAME).write_bytes(b"not the verified model")
    shutil.copy(DEFAULT_MODEL_DIR / "labels.txt", tmp_path / "labels.txt")
    service = _service(tmp_path)
    assert service.load() is False
    assert "does not match the verified model" in service.error


@pytest.mark.parametrize(
    "labels",
    [
        "Class I\nExtra Class\nClass II\nReject\n",  # wrong order
        "Extra Class\nClass I\nClass II\n",  # missing class
        "Extra\nClass I\nClass II\nReject\n",  # renamed
    ],
)
def test_wrong_labels_are_rejected(tmp_path, labels):
    shutil.copy(DEFAULT_MODEL_DIR / MODEL_FILENAME, tmp_path / MODEL_FILENAME)
    (tmp_path / "labels.txt").write_text(labels, encoding="utf-8")
    service = _service(tmp_path)
    assert service.load() is False
    assert "expected ['Extra Class', 'Class I', 'Class II', 'Reject']" in service.error


@pytest.mark.parametrize(
    "kwargs, message",
    [
        ({"input_shape": (1, 256, 256, 3)}, "input shape"),
        ({"output_shape": (1, 5)}, "output shape"),
        ({"input_dtype": np.uint8}, "input type"),
    ],
)
def test_wrong_tensor_signature_is_rejected(kwargs, message):
    service = _service(**kwargs)
    assert service.load() is False
    assert message in service.error


def test_missing_runtime_is_reported():
    def factory(path):
        raise ImportError("No module named 'ai_edge_litert'")

    service = ModelService(model_dir=DEFAULT_MODEL_DIR, interpreter_factory=factory)
    assert service.load() is False
    assert "LiteRT runtime is not installed" in service.error


def test_self_test_failure_marks_service_unavailable():
    service = _service(output_fn=lambda x: [0.9, 0.9, 0.9, 0.9])  # not a probability vector
    assert service.load() is False
    assert "self-test failed" in service.error
    assert not service.available


# ----------------------------------------------------------------- inference
def test_predict_validates_input():
    service = _service()
    assert service.load()
    with pytest.raises(InferenceError):
        service.predict(np.zeros((224, 224, 3), np.float64))
    with pytest.raises(InferenceError):
        service.predict(np.zeros((1, 224, 224, 3), np.float32))
    bad = np.zeros((224, 224, 3), np.float32)
    bad[0, 0, 0] = np.nan
    with pytest.raises(InferenceError):
        service.predict(bad)


def test_interpreter_failure_becomes_inference_error():
    factory = fake_factory()
    service = ModelService(model_dir=DEFAULT_MODEL_DIR, interpreter_factory=factory)
    assert service.load()
    factory.created[0].fail_invoke = True
    with pytest.raises(InferenceError, match="simulated interpreter failure"):
        service.predict(np.zeros((224, 224, 3), np.float32))


@pytest.mark.parametrize(
    "output",
    [[0.5, 0.5, 0.5, 0.5], [np.nan, 0.5, 0.5, 0.0], [1.2, -0.2, 0.0, 0.0], [0.5, 0.5, 0.0]],
)
def test_invalid_outputs_are_rejected(output):
    with pytest.raises(InferenceError):
        check_probabilities(np.array(output, np.float32))


def test_prediction_fields():
    p = Prediction(probabilities=(0.1, 0.2, 0.6, 0.1))
    assert p.grade == "Class II"
    assert p.confidence == pytest.approx(0.6)
    d = p.as_dict()
    assert d["grade"] == "Class II"
    assert list(d["probabilities"]) == list(GRADES)


def test_exact_tie_uses_first_class_in_label_order():
    assert Prediction(probabilities=(0.0, 0.5, 0.5, 0.0)).grade == "Class I"


# --------------------------------------------------------------- aggregation
def test_mean_aggregation_and_views_agree():
    views = {
        "front": Prediction((0.6, 0.3, 0.1, 0.0)),
        "back": Prediction((0.2, 0.7, 0.1, 0.0)),
        "top": Prediction((0.5, 0.4, 0.1, 0.0)),
    }
    result = aggregate_mean(views)
    assert result.probabilities == pytest.approx((1.3 / 3, 1.4 / 3, 0.1, 0.0))
    assert result.grade == "Class I"
    assert result.views_agree is False

    same = {v: Prediction((0.1, 0.8, 0.1, 0.0)) for v in ("front", "back", "top")}
    assert aggregate_mean(same).views_agree is True


def test_aggregation_note_states_it_is_not_validated():
    assert "not yet been validated" in AGGREGATION_NOTE


def test_aggregation_needs_views():
    with pytest.raises(ValueError):
        aggregate_mean({})


# ------------------------------------------------------- real model (LiteRT)
@pytest.fixture(scope="module")
def real_service():
    service = ModelService()
    assert service.load(), service.error
    return service


def _model_input(fixture):
    original = (PARITY_DIR / "originals" / fixture["original"]).read_bytes()
    config = ValidationConfig(max_image_pixels=200_000_000, max_image_bytes=50 * 1024 * 1024)
    return validate_image_bytes(original, config, filename=fixture["original"])


@requires_litert
def test_real_model_loads_with_expected_signature(real_service):
    status = real_service.status()
    assert status["available"] is True
    assert status["model"]["runtime"].startswith("ai-edge-litert ")


@requires_litert
@pytest.mark.parametrize("fixture", FIXTURES, ids=IDS)
def test_real_model_matches_colab_on_original_photo(real_service, fixture):
    """Original photo -> backend Option B -> same probabilities as the stored test image in Colab."""
    prediction = real_service.predict(_model_input(fixture).to_model_input())
    assert prediction.probabilities == pytest.approx(fixture["probabilities_stored"], abs=2e-3)
    expected_top = GRADES[int(np.argmax(fixture["probabilities_stored"]))]
    assert prediction.grade == expected_top


@requires_litert
@pytest.mark.parametrize("fixture", FIXTURES, ids=IDS)
def test_real_model_without_q95_reproduces_option_a(real_service, fixture):
    """Guard: skipping the q95 step reproduces the different Option A outputs."""
    rgb = _model_input(fixture).to_rgb()
    option_a = np.asarray(letterbox(rgb), dtype=np.float32)
    prediction = real_service.predict(option_a)
    assert prediction.probabilities == pytest.approx(fixture["probabilities_option_a"], abs=2e-3)
    assert prediction.grade != GRADES[int(np.argmax(fixture["probabilities_stored"]))]


@requires_litert
def test_real_model_is_deterministic(real_service):
    x = ValidatedImage(report=None, contents=(PARITY_DIR / "stored" / IDS[0]).read_bytes()).to_model_input()
    first = real_service.predict(x).probabilities
    assert all(real_service.predict(x).probabilities == first for _ in range(3))
