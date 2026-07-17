import sqlite3
import base64
from concurrent.futures import ThreadPoolExecutor

from fastapi.testclient import TestClient

from feedback_service.main import course_reference
from feedback_service.security import token_hash
from feedback_service.tests.conftest import admin, auth, issue


COURSE_NUMBER = "INFM1234"
COURSE_ID = base64.urlsafe_b64encode(COURSE_NUMBER.encode()).decode().rstrip("=")
MINE = f"/v1/courses/{COURSE_ID}/feedback/mine"
PUBLIC = f"/v1/courses/{COURSE_ID}/feedback/public"


def put(client: TestClient, token: str, rating: int = 5, comment: str | None = None):
    return client.put(
        MINE, headers=auth(token), json={"rating": rating, "comment": comment}
    )


def test_token_is_stored_hashed_and_feedback_is_owned(client: TestClient):
    owner = issue(client)
    stranger = issue(client)
    created = put(client, owner, 4, "Useful service")
    assert created.status_code == 200
    assert created.json()["comment_state"] == "pending"

    assert client.get(MINE, headers=auth(owner)).status_code == 200
    assert client.get(MINE, headers=auth(stranger)).status_code == 404
    assert client.get(MINE, headers=auth("not-a-token")).status_code == 401

    database = client.app.state.database
    with database.connect() as db:
        stored = db.execute("SELECT token_hash FROM installations").fetchall()
    assert all(row["token_hash"] not in (owner, stranger) for row in stored)


def test_rating_comment_bounds_and_plain_text_validation(client: TestClient):
    token = issue(client)
    for rating in (0, 6, 1.5, "5"):
        assert put(client, token, rating).status_code == 422
    assert put(client, token, 5, "x" * 1001).status_code == 422
    assert put(client, token, 5, "bad\x00text").status_code == 422
    assert put(client, token, 1, "  \n ").json()["comment_state"] == "none"


def test_pending_comment_hidden_but_rating_aggregated(client: TestClient):
    first = issue(client)
    second = issue(client)
    assert put(client, first, 5, "pending").status_code == 200
    assert put(client, second, 3).status_code == 200

    public = client.get(PUBLIC).json()
    assert public["rating"] == {"count": 2, "average": 4.0}
    assert public["comments"] == []

    feedback_id = client.get(MINE, headers=auth(first)).json()["id"]
    moderated = client.post(
        f"/v1/admin/feedback/{feedback_id}/moderation",
        headers=admin(),
        json={"action": "publish", "reason": "reviewed"},
    )
    assert moderated.status_code == 200
    comments = client.get(PUBLIC).json()["comments"]
    assert comments[0]["comment"] == "pending"
    assert set(comments[0]) == {"id", "rating", "comment", "published_at"}


def test_report_queue_duplicate_and_comment_deletion_keep_rating(client: TestClient):
    owner = issue(client)
    reporter = issue(client)
    feedback = put(client, owner, 2, "publish me").json()
    client.post(
        f"/v1/admin/feedback/{feedback['id']}/moderation",
        headers=admin(),
        json={"action": "publish"},
    )
    report_url = f"/v1/courses/{COURSE_ID}/feedback/{feedback['id']}/reports"
    assert client.post(report_url, headers=auth(owner), json={}).status_code == 400
    assert (
        client.post(
            report_url, headers=auth(reporter), json={"reason": "spam"}
        ).status_code
        == 201
    )
    assert client.post(report_url, headers=auth(reporter), json={}).status_code == 409

    queue = client.get("/v1/admin/moderation?state=reported", headers=admin())
    assert queue.status_code == 200
    assert queue.json()["items"][0]["report_count"] == 1
    assert queue.json()["items"][0]["reports"][0]["reason"] == "spam"

    deleted = client.post(
        f"/v1/admin/feedback/{feedback['id']}/moderation",
        headers=admin(),
        json={"action": "delete", "reason": "confirmed"},
    )
    assert deleted.json()["comment_state"] == "deleted"
    public = client.get(PUBLIC).json()
    assert public["comments"] == []
    assert public["rating"] == {"count": 1, "average": 2.0}
    mine = client.get(MINE, headers=auth(owner)).json()
    assert mine["comment"] is None
    assert mine["comment_state"] == "deleted"

    with client.app.state.database.connect() as db:
        audit = db.execute(
            """SELECT previous_state, action, reason, moderator_id
               FROM moderation_audit ORDER BY created_at"""
        ).fetchall()
    assert [tuple(row) for row in audit] == [
        ("pending", "publish", None, "moderator@example.test"),
        ("published", "delete", "confirmed", "moderator@example.test"),
    ]

    # A new comment revision must not inherit reports for the old text.
    assert put(client, owner, 4, "new revision").status_code == 200
    client.post(
        f"/v1/admin/feedback/{feedback['id']}/moderation",
        headers=admin(),
        json={"action": "publish"},
    )
    assert (
        client.get("/v1/admin/moderation?state=reported", headers=admin()).json()[
            "items"
        ]
        == []
    )


def test_owner_delete_removes_rating_and_can_upsert_again(client: TestClient):
    token = issue(client)
    assert put(client, token, 5, "bye").status_code == 200
    assert client.delete(MINE, headers=auth(token)).status_code == 204
    assert client.get(MINE, headers=auth(token)).status_code == 404
    assert client.get(PUBLIC).json()["rating"]["count"] == 0
    assert put(client, token, 3).status_code == 200
    assert client.get(PUBLIC).json()["rating"] == {"count": 1, "average": 3.0}


def test_feedback_is_isolated_between_registered_courses(client: TestClient):
    other_number = "INFM5678"
    other_id = base64.urlsafe_b64encode(other_number.encode()).decode().rstrip("=")
    client.app.state.database.register_courses([(other_id, other_number)])
    token = issue(client)
    other_mine = f"/v1/courses/{other_id}/feedback/mine"
    other_public = f"/v1/courses/{other_id}/feedback/public"

    assert put(client, token, 5).status_code == 200
    assert (
        client.put(
            other_mine, headers=auth(token), json={"rating": 2, "comment": None}
        ).status_code
        == 200
    )
    assert client.get(PUBLIC).json()["rating"] == {"count": 1, "average": 5.0}
    assert client.get(other_public).json()["rating"] == {
        "count": 1,
        "average": 2.0,
    }
    assert client.delete(other_mine, headers=auth(token)).status_code == 204
    assert client.get(PUBLIC).json()["rating"]["count"] == 1
    assert client.get(other_public).json()["rating"]["count"] == 0


def test_unregistered_course_bucket_is_rejected(client: TestClient):
    unknown = base64.urlsafe_b64encode(b"INFM9999").decode().rstrip("=")
    assert client.get(f"/v1/courses/{unknown}/feedback/public").status_code == 404


def test_course_reference_rejects_normalized_unicode_expansion():
    assert course_reference("💥" * 120) is None


def test_concurrent_upserts_keep_one_owned_feedback(client: TestClient):
    token = issue(client)
    database = client.app.state.database
    installation_id = database.installation_id(token_hash(token))

    with ThreadPoolExecutor(max_workers=4) as executor:
        results = list(
            executor.map(
                lambda rating: database.upsert_feedback(
                    installation_id,
                    COURSE_ID,
                    rating,
                    None,
                ),
                (1, 2, 3, 4),
            )
        )

    assert all(result is not None for result in results)
    with database.connect() as db:
        count = db.execute(
            "SELECT COUNT(*) FROM feedback WHERE installation_id=?",
            (installation_id,),
        ).fetchone()[0]
    assert count == 1


def test_admin_auth_and_pending_queue(client: TestClient):
    token = issue(client)
    feedback_id = put(client, token, 5, "review").json()["id"]
    assert client.get("/v1/admin/moderation").status_code == 401
    assert (
        client.get(
            "/v1/admin/moderation",
            headers={
                "X-Admin-Token": "test-admin-token-that-is-at-least-32-characters"
            },
        ).status_code
        == 400
    )
    queue = client.get("/v1/admin/moderation", headers=admin()).json()["items"]
    assert queue[0]["id"] == feedback_id
    assert queue[0]["comment_state"] == "pending"

    rejected = client.post(
        f"/v1/admin/feedback/{feedback_id}/moderation",
        headers=admin(),
        json={"action": "reject", "reason": "not suitable"},
    )
    assert rejected.json()["comment_state"] == "rejected"
    assert client.get(PUBLIC).json()["comments"] == []
    assert (
        client.post(
            f"/v1/admin/feedback/{feedback_id}/moderation",
            headers=admin(),
            json={"action": "delete"},
        ).status_code
        == 422
    )


def test_moderation_transitions_are_serialized_and_validated(client: TestClient):
    owner = issue(client)
    feedback_id = put(client, owner, 5, "review once").json()["id"]
    database = client.app.state.database

    with ThreadPoolExecutor(max_workers=2) as executor:
        results = list(
            executor.map(
                lambda _: database.moderate(
                    feedback_id,
                    "publish",
                    None,
                    "moderator@example.test",
                ),
                range(2),
            )
        )

    assert sum(isinstance(result, dict) for result in results) == 1
    assert results.count("invalid") == 1
    with database.connect() as db:
        audit = db.execute(
            "SELECT previous_state, action FROM moderation_audit WHERE feedback_id=?",
            (feedback_id,),
        ).fetchall()
    assert [tuple(row) for row in audit] == [("pending", "publish")]

    star_only = put(client, issue(client), 3).json()["id"]
    response = client.post(
        f"/v1/admin/feedback/{star_only}/moderation",
        headers=admin(),
        json={"action": "publish"},
    )
    assert response.status_code == 409


def test_invalid_course_and_health(client: TestClient):
    assert client.get("/healthz").json() == {"status": "ok"}
    assert client.get("/v1/courses/unknown!/feedback/public").status_code == 404
    catalog = client.post("/v1/courses/search", json={"query": "machine", "limit": 1})
    assert catalog.status_code == 200
    assert catalog.json()["courses"][0]["courseNumber"] == COURSE_NUMBER
    assert catalog.json()["courses"][0]["ratingCourseId"] == COURSE_ID
    assert client.post("/v1/courses/search", json={"query": "x"}).status_code == 422
    public = client.get(PUBLIC).json()
    assert public["course_id"] == COURSE_ID
    assert public["course_number"] == COURSE_NUMBER
    assert client.get(f"{PUBLIC}?limit=101").status_code == 422
    assert client.get(f"{PUBLIC}?offset=10001").status_code == 422
    assert (
        client.get("/v1/admin/moderation?limit=101", headers=admin()).status_code == 422
    )


def test_database_enforces_foreign_keys_and_wal(client: TestClient):
    with client.app.state.database.connect() as db:
        assert db.execute("PRAGMA foreign_keys").fetchone()[0] == 1
        assert db.execute("PRAGMA journal_mode").fetchone()[0] == "wal"
        assert db.execute("PRAGMA user_version").fetchone()[0] == 2
        try:
            db.execute(
                """INSERT INTO feedback
                (id, installation_id, course_id, rating, comment_state, created_at, updated_at)
                VALUES ('bad', 'missing', ?, 5, 'none', 'now', 'now')""",
                (COURSE_ID,),
            )
        except sqlite3.IntegrityError:
            pass
        else:
            raise AssertionError("foreign key constraint was not enforced")
