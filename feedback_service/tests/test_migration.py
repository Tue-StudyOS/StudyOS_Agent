import sqlite3
from pathlib import Path

from feedback_service.db import Database


def test_v1_service_feedback_requires_explicit_recreation(tmp_path: Path):
    path = tmp_path / "feedback.sqlite3"
    with sqlite3.connect(path) as db:
        db.executescript(
            """
            CREATE TABLE feedback (
                id TEXT PRIMARY KEY,
                service_id TEXT NOT NULL
            );
            INSERT INTO feedback VALUES ('feedback-1', 'legacy-course');
            PRAGMA user_version = 1;
            """
        )

    try:
        Database(path).migrate()
    except RuntimeError as error:
        assert "cannot be migrated as course ratings" in str(error)
    else:
        raise AssertionError("a service-feedback database must not be relabeled")
