from __future__ import annotations

import argparse
import os
import sqlite3
from pathlib import Path


def create_backup(source: Path, destination: Path) -> None:
    if source.resolve() == destination.resolve():
        raise ValueError("source and destination must differ")
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_name(f".{destination.name}.tmp")
    temporary.unlink(missing_ok=True)
    try:
        with (
            sqlite3.connect(source) as source_db,
            sqlite3.connect(temporary) as backup_db,
        ):
            source_db.backup(backup_db)
            result = backup_db.execute("PRAGMA integrity_check").fetchone()[0]
            if result != "ok":
                raise RuntimeError(f"backup integrity check failed: {result}")
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)


def verify_backup(path: Path) -> None:
    uri = f"file:{path.resolve()}?mode=ro"
    with sqlite3.connect(uri, uri=True) as database:
        result = database.execute("PRAGMA integrity_check").fetchone()[0]
        if result != "ok":
            raise RuntimeError(f"backup integrity check failed: {result}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Create or verify a StudyOS feedback backup"
    )
    subcommands = parser.add_subparsers(dest="command", required=True)
    create = subcommands.add_parser("create")
    create.add_argument("source", type=Path)
    create.add_argument("destination", type=Path)
    verify = subcommands.add_parser("verify")
    verify.add_argument("path", type=Path)
    arguments = parser.parse_args()
    if arguments.command == "create":
        create_backup(arguments.source, arguments.destination)
    else:
        verify_backup(arguments.path)


if __name__ == "__main__":
    main()
