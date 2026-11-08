"""Shared test setup for the MangGrade backend.

Run from the backend folder:
    python -m pytest
"""

import json
import sys
from pathlib import Path

import pytest

BACKEND_DIR = Path(__file__).resolve().parents[1]
FIXTURES_DIR = Path(__file__).resolve().parent / "fixtures"
PARITY_DIR = FIXTURES_DIR / "parity"

# Make main.py, image_validation.py, model_service.py importable.
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))


def load_parity_fixtures() -> list[dict]:
    data = json.loads((PARITY_DIR / "fixtures.json").read_text(encoding="utf-8"))
    return data["fixtures"]


@pytest.fixture(scope="session")
def parity_fixtures() -> list[dict]:
    return load_parity_fixtures()


def litert_available() -> bool:
    try:
        from ai_edge_litert.interpreter import Interpreter  # noqa: F401
    except Exception:
        return False
    return True


requires_litert = pytest.mark.skipif(
    not litert_available(),
    reason="ai-edge-litert is not installed (run in the backend .venv313)",
)


def fastapi_testclient_available() -> bool:
    try:
        import httpx  # noqa: F401
        from fastapi.testclient import TestClient  # noqa: F401
    except Exception:
        return False
    return True


requires_testclient = pytest.mark.skipif(
    not fastapi_testclient_available(),
    reason="FastAPI TestClient needs fastapi and httpx (see requirements.txt)",
)
