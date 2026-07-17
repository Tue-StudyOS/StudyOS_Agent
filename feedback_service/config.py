from __future__ import annotations

import os
import re
from dataclasses import dataclass
from pathlib import Path


MODERATOR_ID = re.compile(r"^[a-zA-Z0-9._@-]{2,80}$")


@dataclass(frozen=True)
class Settings:
    database_path: Path = Path("/data/feedback.sqlite3")
    admin_token: str = ""
    moderator_id: str = "studyos-admin"
    catalog_api_url: str = "https://studyplanner-api.ben-tischberger.workers.dev"
    cors_origins: tuple[str, ...] = ()
    installation_limit_per_minute: int = 10
    feedback_limit_per_minute: int = 30
    catalog_search_limit_per_minute: int = 30

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            database_path=Path(
                os.getenv("FEEDBACK_DATABASE_PATH", "/data/feedback.sqlite3")
            ),
            admin_token=os.getenv("FEEDBACK_ADMIN_TOKEN", ""),
            moderator_id=os.getenv("FEEDBACK_MODERATOR_ID", "studyos-admin"),
            catalog_api_url=os.getenv(
                "FEEDBACK_CATALOG_API_URL",
                "https://studyplanner-api.ben-tischberger.workers.dev",
            ),
            cors_origins=tuple(
                item.strip()
                for item in os.getenv("FEEDBACK_CORS_ORIGINS", "").split(",")
                if item.strip()
            ),
            installation_limit_per_minute=int(
                os.getenv("FEEDBACK_INSTALLATION_RATE_LIMIT", "10")
            ),
            feedback_limit_per_minute=int(
                os.getenv("FEEDBACK_AUTHOR_RATE_LIMIT", "30")
            ),
            catalog_search_limit_per_minute=int(
                os.getenv("FEEDBACK_CATALOG_RATE_LIMIT", "30")
            ),
        )

    def validate(self) -> None:
        if self.admin_token and len(self.admin_token) < 32:
            raise RuntimeError(
                "FEEDBACK_ADMIN_TOKEN must contain at least 32 characters"
            )
        if not MODERATOR_ID.fullmatch(self.moderator_id):
            raise RuntimeError("FEEDBACK_MODERATOR_ID is invalid")
        if not self.catalog_api_url.startswith("https://"):
            raise RuntimeError("FEEDBACK_CATALOG_API_URL must use HTTPS")
        if (
            self.installation_limit_per_minute < 1
            or self.feedback_limit_per_minute < 1
            or self.catalog_search_limit_per_minute < 1
        ):
            raise RuntimeError("rate limits must be positive")
