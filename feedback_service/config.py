from __future__ import annotations

import os
import re
from dataclasses import dataclass
from pathlib import Path


def _csv(value: str) -> tuple[str, ...]:
    return tuple(item.strip() for item in value.split(",") if item.strip())


MODERATOR_ID = re.compile(r"^[a-zA-Z0-9._@-]{2,80}$")


@dataclass(frozen=True)
class Settings:
    database_path: Path = Path("/data/feedback.sqlite3")
    admin_token: str = ""
    moderator_id: str = "studyos-admin"
    allowed_service_ids: tuple[str, ...] = ("studyos-agent",)
    cors_origins: tuple[str, ...] = ()
    installation_limit_per_minute: int = 10
    feedback_limit_per_minute: int = 30

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            database_path=Path(
                os.getenv("FEEDBACK_DATABASE_PATH", "/data/feedback.sqlite3")
            ),
            admin_token=os.getenv("FEEDBACK_ADMIN_TOKEN", ""),
            moderator_id=os.getenv("FEEDBACK_MODERATOR_ID", "studyos-admin"),
            allowed_service_ids=_csv(
                os.getenv("FEEDBACK_SERVICE_IDS", "studyos-agent")
            ),
            cors_origins=_csv(os.getenv("FEEDBACK_CORS_ORIGINS", "")),
            installation_limit_per_minute=int(
                os.getenv("FEEDBACK_INSTALLATION_RATE_LIMIT", "10")
            ),
            feedback_limit_per_minute=int(
                os.getenv("FEEDBACK_AUTHOR_RATE_LIMIT", "30")
            ),
        )

    def validate(self) -> None:
        if not self.allowed_service_ids:
            raise RuntimeError(
                "FEEDBACK_SERVICE_IDS must contain at least one service ID"
            )
        if self.admin_token and len(self.admin_token) < 32:
            raise RuntimeError(
                "FEEDBACK_ADMIN_TOKEN must contain at least 32 characters"
            )
        if not MODERATOR_ID.fullmatch(self.moderator_id):
            raise RuntimeError("FEEDBACK_MODERATOR_ID is invalid")
        if self.installation_limit_per_minute < 1 or self.feedback_limit_per_minute < 1:
            raise RuntimeError("rate limits must be positive")
