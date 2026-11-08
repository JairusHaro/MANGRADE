"""API tests for /predict and /predict-multiview (FastAPI TestClient).

Most tests swap in a model service backed by a fake interpreter, so they
test the API flow, not the model. The tests marked requires_litert use the
real verified model.

Needs fastapi + httpx (requirements.txt); skipped automatically otherwise.
"""

from io import BytesIO

import numpy as np
import pytest
from PIL import Image

from conftest import PARITY_DIR, requires_litert, requires_testclient
from fakes import fake_factory

pytestmark = requires_testclient

# Photos that pass the current validation thresholds (checked 2026-11-06).
FRONT = "IMG_20260828_113209.jpg"
BACK = "IMG_0606.JPG"
TOP = "Carabao_0031.jpg"
GRADES = ["Extra Class", "Class I", "Class II", "Reject"]


def _photo(name: str) -> tuple[str, bytes, str]:
    return (name, (PARITY_DIR / "originals" / name).read_bytes(), "image/jpeg")


def _too_small_png() -> tuple[str, bytes, str]:
    buffer = BytesIO()
    Image.fromarray(np.full((200, 200, 3), 128, np.uint8)).save(buffer, "PNG")
    return ("small.png", buffer.getvalue(), "image/png")


def _three_views():
    return {"front": _photo(FRONT), "back": _photo(BACK), "top": _photo(TOP)}


@pytest.fixture
def main_module():
    import main

    return main


@pytest.fixture
def client_with(main_module, monkeypatch):
    """Build a TestClient whose app uses the given ModelService."""
    from fastapi.testclient import TestClient
    from model_service import ModelService

    clients = []

    def make(service=None, loaded=True, **fake_kwargs):
        if service is None:
            service = ModelService(interpreter_factory=fake_factory(**fake_kwargs))
            if loaded:
                assert service.load(), service.error
        monkeypatch.setattr(main_module, "MODEL_SERVICE", service)
        client = TestClient(main_module.app)
        client.__enter__()  # runs the lifespan (load is skipped when already loaded)
        clients.append(client)
        return client

    yield make
    for client in clients:
        client.__exit__(None, None, None)


# ---------------------------------------------------------- basic endpoints
def test_home_and_model_status_report_loaded(client_with):
    client = client_with()
    assert client.get("/").json()["model_status"] == "loaded"
    status = client.get("/model-status").json()
    assert status["available"] is True
    assert status["grades"] == GRADES
    assert status["model"]["labels"] == GRADES
    assert "not yet been validated" in status["aggregation"]["note"]


def test_health_unchanged(client_with):
    assert client_with().get("/health").json() == {"status": "healthy"}


# ------------------------------------------------------- /predict-multiview
def test_multiview_returns_real_prediction_with_per_view_results(client_with):
    response = client_with().post("/predict-multiview", files=_three_views())
    assert response.status_code == 200, response.text
    data = response.json()

    # Keys the Flutter app already reads.
    assert data["prediction_is_real"] is True
    assert data["predicted_grade"] in GRADES
    assert isinstance(data["confidence"], float)
    assert data["view_order"] == ["front", "back", "top"]
    assert data["grades"] == GRADES
    assert data["model_status"] == "loaded"

    # New fields.
    assert list(data["probabilities"]) == GRADES
    assert sum(data["probabilities"].values()) == pytest.approx(1, abs=1e-3)
    assert data["aggregation"]["method"] == "mean_probability"
    assert data["aggregation"]["views_used"] == ["front", "back", "top"]
    for view in ("front", "back", "top"):
        prediction = data["views"][view]["prediction"]
        assert prediction["grade"] in GRADES
        assert list(prediction["probabilities"]) == GRADES
        assert "validation" in data["views"][view]
        assert data["views"][view]["width"] > 0

    # Final grade = argmax of the mean of the three views.
    mean = np.mean([[data["views"][v]["prediction"]["probabilities"][g] for g in GRADES]
                    for v in ("front", "back", "top")], axis=0)
    assert data["predicted_grade"] == GRADES[int(np.argmax(mean))]
    assert data["confidence"] == pytest.approx(float(mean.max()), abs=1e-5)
    grades = {data["views"][v]["prediction"]["grade"] for v in ("front", "back", "top")}
    assert data["views_agree"] is (len(grades) == 1)


@pytest.mark.parametrize("missing", [["top"], ["back", "top"], ["front", "back", "top"]])
def test_multiview_missing_photo_is_a_clear_422(client_with, missing):
    files = {k: v for k, v in _three_views().items() if k not in missing}
    if not files:
        response = client_with().post("/predict-multiview", data={"x": "1"})
    else:
        response = client_with().post("/predict-multiview", files=files)
    assert response.status_code == 422
    data = response.json()
    assert data["missing"] == missing
    assert isinstance(data["detail"], str)
    assert data["detail"].startswith("Missing photo: " + ", ".join(missing))
    assert data["errors"]  # FastAPI's standard error list is kept


def test_multiview_rejected_photo_keeps_existing_error_format(client_with):
    files = _three_views()
    files["back"] = _too_small_png()
    response = client_with().post("/predict-multiview", files=files)
    assert response.status_code == 422
    data = response.json()
    assert data["view"] == "back"
    assert data["detail"].startswith("Back photo:")
    assert data["validation"]["status"] == "rejected"


def test_multiview_returns_503_when_model_unavailable(client_with, tmp_path):
    from model_service import ModelService

    service = ModelService(model_dir=tmp_path, interpreter_factory=fake_factory())
    client = client_with(service=service)  # lifespan tries to load and fails
    assert service.available is False
    response = client.post("/predict-multiview", files=_three_views())
    assert response.status_code == 503
    data = response.json()
    assert isinstance(data["detail"], str)
    assert data["model_status"] == "unavailable"
    assert "Model file not found" in data["model_error"]
    assert client.get("/model-status").json()["available"] is False


def test_multiview_inference_failure_is_500_with_view(client_with, main_module):
    client = client_with()
    main_module.MODEL_SERVICE._interpreter.fail_invoke = True
    response = client.post("/predict-multiview", files=_three_views())
    assert response.status_code == 500
    data = response.json()
    assert data["view"] == "front"
    assert data["detail"].startswith("Front photo:")


# ------------------------------------------------------------------ /predict
def test_predict_single_image_returns_real_prediction(client_with):
    response = client_with().post("/predict", files={"file": _photo(FRONT)})
    assert response.status_code == 200, response.text
    data = response.json()
    for key in ("filename", "image_format", "width", "height", "received_content_type",
                "predicted_grade", "confidence", "grades", "model_status",
                "prediction_is_real", "message", "validation"):
        assert key in data, key
    assert data["prediction_is_real"] is True
    assert data["predicted_grade"] in GRADES
    assert list(data["probabilities"]) == GRADES


def test_predict_missing_file_is_a_clear_422(client_with):
    response = client_with().post("/predict", data={"x": "1"})
    assert response.status_code == 422
    assert response.json()["missing"] == ["file"]
    assert isinstance(response.json()["detail"], str)


def test_validate_endpoint_keeps_default_422_for_missing_file(client_with):
    response = client_with().post("/validate", data={"x": "1"})
    assert response.status_code == 422
    assert isinstance(response.json()["detail"], list)  # FastAPI default, unchanged


def test_predict_rejected_image_unchanged(client_with):
    response = client_with().post("/predict", files={"file": _too_small_png()})
    assert response.status_code == 422
    assert response.json()["validation"]["status"] == "rejected"


# ------------------------------------------------------- real model (LiteRT)
@requires_litert
def test_real_model_multiview_end_to_end(client_with):
    from model_service import ModelService

    service = ModelService()
    assert service.load(), service.error
    response = client_with(service=service).post("/predict-multiview", files=_three_views())
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["prediction_is_real"] is True
    assert data["model"]["sha256"].startswith("45456c09")
    # Each view must match the Colab values for the same original photo.
    import json

    expected = {f["original"]: f["probabilities_stored"]
                for f in json.loads((PARITY_DIR / "fixtures.json").read_text())["fixtures"]}
    for view, name in (("front", FRONT), ("back", BACK), ("top", TOP)):
        got = [data["views"][view]["prediction"]["probabilities"][g] for g in GRADES]
        assert got == pytest.approx(expected[name], abs=2e-3), view
