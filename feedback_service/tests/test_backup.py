import sqlite3
from pathlib import Path

from feedback_service.backup import create_backup, verify_backup


def test_online_backup_can_be_opened_as_a_restored_database(tmp_path: Path):
    source = tmp_path / "feedback.sqlite3"
    backup = tmp_path / "backups" / "feedback-backup.sqlite3"
    with sqlite3.connect(source) as database:
        database.execute("CREATE TABLE example (value TEXT NOT NULL)")
        database.execute("INSERT INTO example VALUES ('restorable')")

    create_backup(source, backup)
    verify_backup(backup)

    with sqlite3.connect(backup) as restored:
        assert (
            restored.execute("SELECT value FROM example").fetchone()[0] == "restorable"
        )
