from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from feedback_service.config import Settings
from feedback_service.main import create_app


@pytest.fixture
def client(tmp_path: Path):
    app = create_app(
        Settings(
            database_path=tmp_path / "feedback.sqlite3",
            admin_token="test-admin-token-that-is-at-least-32-characters",
            moderator_id="moderator@example.test",
            allowed_service_ids=("studyos-agent",),
            installation_limit_per_minute=20,
            feedback_limit_per_minute=20,
        )
    )
    with TestClient(app) as test_client:
        yield test_client


def issue(client: TestClient) -> str:
    response = client.post("/v1/installations")
    assert response.status_code == 201
    return response.json()["installation_token"]


def auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def admin() -> dict[str, str]:
    return {
        "X-Admin-Token": "test-admin-token-that-is-at-least-32-characters",
        "X-Moderator-Id": "moderator@example.test",
    }
