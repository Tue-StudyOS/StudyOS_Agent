from __future__ import annotations

import sqlite3
import uuid
from datetime import UTC, datetime
from pathlib import Path


def now() -> str:
    return datetime.now(UTC).isoformat()


class Database:
    def __init__(self, path: Path):
        self.path = path

    def connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.path, timeout=5)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("PRAGMA busy_timeout = 5000")
        return connection

    def migrate(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.connect() as db:
            db.execute("PRAGMA journal_mode = WAL")
            version = db.execute("PRAGMA user_version").fetchone()[0]
            if version == 0:
                db.executescript(
                    """
                    CREATE TABLE installations (
                        id TEXT PRIMARY KEY,
                        token_hash TEXT NOT NULL UNIQUE,
                        created_at TEXT NOT NULL
                    );
                    CREATE TABLE feedback (
                        id TEXT PRIMARY KEY,
                        installation_id TEXT NOT NULL REFERENCES installations(id),
                        service_id TEXT NOT NULL,
                        rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
                        comment TEXT CHECK (comment IS NULL OR length(comment) <= 1000),
                        comment_state TEXT NOT NULL CHECK (
                            comment_state IN ('none','pending','published','rejected','deleted')
                        ),
                        created_at TEXT NOT NULL,
                        updated_at TEXT NOT NULL,
                        published_at TEXT,
                        deleted_at TEXT,
                        UNIQUE (installation_id, service_id)
                    );
                    CREATE INDEX feedback_public_idx ON feedback(service_id, deleted_at, comment_state);
                    CREATE TABLE reports (
                        id TEXT PRIMARY KEY,
                        feedback_id TEXT NOT NULL REFERENCES feedback(id),
                        reporter_installation_id TEXT NOT NULL REFERENCES installations(id),
                        reason TEXT CHECK (reason IS NULL OR length(reason) <= 500),
                        created_at TEXT NOT NULL,
                        UNIQUE (feedback_id, reporter_installation_id)
                    );
                    CREATE TABLE moderation_audit (
                        id TEXT PRIMARY KEY,
                        feedback_id TEXT NOT NULL REFERENCES feedback(id),
                        previous_state TEXT NOT NULL,
                        action TEXT NOT NULL,
                        reason TEXT,
                        moderator_id TEXT NOT NULL,
                        created_at TEXT NOT NULL
                    );
                    PRAGMA user_version = 1;
                    """
                )
            elif version != 1:
                raise RuntimeError(f"unsupported database schema version: {version}")

    def create_installation(self, digest: str) -> None:
        with self.connect() as db:
            db.execute(
                "INSERT INTO installations (id, token_hash, created_at) VALUES (?, ?, ?)",
                (str(uuid.uuid4()), digest, now()),
            )

    def installation_id(self, digest: str) -> str | None:
        with self.connect() as db:
            row = db.execute(
                "SELECT id FROM installations WHERE token_hash = ?", (digest,)
            ).fetchone()
        return row["id"] if row else None

    def upsert_feedback(
        self, installation_id: str, service_id: str, rating: int, comment: str | None
    ):
        timestamp = now()
        state = "pending" if comment else "none"
        with self.connect() as db:
            row = db.execute(
                """INSERT INTO feedback
                   (id, installation_id, service_id, rating, comment, comment_state, created_at, updated_at)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                   ON CONFLICT(installation_id, service_id) DO UPDATE SET
                     rating=excluded.rating,
                     comment=excluded.comment,
                     comment_state=excluded.comment_state,
                     updated_at=excluded.updated_at,
                     published_at=NULL,
                     deleted_at=NULL
                   RETURNING id""",
                (
                    str(uuid.uuid4()),
                    installation_id,
                    service_id,
                    rating,
                    comment,
                    state,
                    timestamp,
                    timestamp,
                ),
            ).fetchone()
            feedback_id = row["id"]
            # Reports describe the previous comment revision. Resubmission
            # returns the comment to review and must not inherit them.
            db.execute("DELETE FROM reports WHERE feedback_id=?", (feedback_id,))
        return self.feedback_for_owner(installation_id, service_id)

    def feedback_for_owner(self, installation_id: str, service_id: str):
        with self.connect() as db:
            return db.execute(
                """SELECT id, service_id, rating, comment, comment_state, created_at, updated_at
                   FROM feedback WHERE installation_id=? AND service_id=? AND deleted_at IS NULL""",
                (installation_id, service_id),
            ).fetchone()

    def delete_feedback(self, installation_id: str, service_id: str) -> bool:
        timestamp = now()
        with self.connect() as db:
            result = db.execute(
                """UPDATE feedback SET comment=NULL, comment_state='deleted', deleted_at=?, updated_at=?
                   WHERE installation_id=? AND service_id=? AND deleted_at IS NULL""",
                (timestamp, timestamp, installation_id, service_id),
            )
        return result.rowcount == 1

    def public_feedback(self, service_id: str, limit: int, offset: int) -> dict:
        with self.connect() as db:
            aggregate = db.execute(
                "SELECT COUNT(*) count, AVG(rating) average FROM feedback WHERE service_id=? AND deleted_at IS NULL",
                (service_id,),
            ).fetchone()
            comments = db.execute(
                """SELECT id, rating, comment, published_at FROM feedback
                   WHERE service_id=? AND deleted_at IS NULL AND comment_state='published'
                   ORDER BY published_at DESC, id LIMIT ? OFFSET ?""",
                (service_id, limit, offset),
            ).fetchall()
        return {
            "service_id": service_id,
            "rating": {"count": aggregate["count"], "average": aggregate["average"]},
            "comments": [dict(row) for row in comments],
            "pagination": {"limit": limit, "offset": offset},
        }

    def report(
        self,
        installation_id: str,
        service_id: str,
        feedback_id: str,
        reason: str | None,
    ) -> str:
        with self.connect() as db:
            target = db.execute(
                """SELECT installation_id FROM feedback WHERE id=? AND service_id=?
                   AND comment_state='published' AND deleted_at IS NULL""",
                (feedback_id, service_id),
            ).fetchone()
            if not target:
                return "not_found"
            if target["installation_id"] == installation_id:
                return "own"
            try:
                db.execute(
                    "INSERT INTO reports VALUES (?, ?, ?, ?, ?)",
                    (str(uuid.uuid4()), feedback_id, installation_id, reason, now()),
                )
            except sqlite3.IntegrityError:
                return "duplicate"
        return "created"

    def moderation_queue(
        self,
        state: str,
        service_id: str | None,
        limit: int,
        offset: int,
    ):
        where = "f.deleted_at IS NULL AND "
        params: list[str] = []
        if state == "reported":
            where += "f.comment_state='published' AND EXISTS (SELECT 1 FROM reports x WHERE x.feedback_id=f.id)"
        else:
            where += "f.comment_state=?"
            params.append(state)
        if service_id:
            where += " AND f.service_id=?"
            params.append(service_id)
        with self.connect() as db:
            return db.execute(
                f"""SELECT f.id, f.service_id, f.rating, f.comment, f.comment_state,
                    f.created_at, f.updated_at, COUNT(r.id) report_count
                    FROM feedback f LEFT JOIN reports r ON r.feedback_id=f.id
                    WHERE {where} GROUP BY f.id ORDER BY f.updated_at
                    LIMIT ? OFFSET ?""",  # noqa: S608 (fixed clauses)
                [*params, limit, offset],
            ).fetchall()

    def reports_for_feedback(self, feedback_id: str):
        with self.connect() as db:
            return db.execute(
                """SELECT reason, created_at FROM reports
                   WHERE feedback_id=? ORDER BY created_at""",
                (feedback_id,),
            ).fetchall()

    def moderate(
        self,
        feedback_id: str,
        action: str,
        reason: str | None,
        moderator_id: str,
    ):
        with self.connect() as db:
            # Serialize the read/transition/audit sequence so concurrent
            # moderators cannot record the same previous state.
            db.execute("BEGIN IMMEDIATE")
            row = db.execute(
                "SELECT comment_state, comment FROM feedback WHERE id=? AND deleted_at IS NULL",
                (feedback_id,),
            ).fetchone()
            if not row:
                return None
            allowed_states = {
                "publish": {"pending", "rejected"},
                "reject": {"pending", "published"},
                "delete": {"pending", "published", "rejected"},
            }
            if row["comment_state"] not in allowed_states[action]:
                return "invalid"
            timestamp = now()
            new_state = {
                "publish": "published",
                "reject": "rejected",
                "delete": "deleted",
            }[action]
            # Admin deletion removes only the comment. The rating remains in the
            # aggregate; only an owner's DELETE removes their entire feedback.
            deleted_at = None
            comment = None if action == "delete" else row["comment"]
            published_at = timestamp if action == "publish" else None
            db.execute(
                """UPDATE feedback SET comment_state=?, comment=?, published_at=?, deleted_at=?, updated_at=?
                   WHERE id=?""",
                (new_state, comment, published_at, deleted_at, timestamp, feedback_id),
            )
            db.execute(
                "INSERT INTO moderation_audit VALUES (?, ?, ?, ?, ?, ?, ?)",
                (
                    str(uuid.uuid4()),
                    feedback_id,
                    row["comment_state"],
                    action,
                    reason,
                    moderator_id,
                    timestamp,
                ),
            )
            return {
                "id": feedback_id,
                "comment_state": new_state,
                "updated_at": timestamp,
            }
