from __future__ import annotations

import re
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

CONTROL_CHARACTERS = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]")


def clean_text(value: str | None) -> str | None:
    if value is None:
        return None
    value = value.strip()
    if not value:
        return None
    if CONTROL_CHARACTERS.search(value):
        raise ValueError("control characters are not allowed")
    return value


class FeedbackInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    rating: int = Field(ge=1, le=5, strict=True)
    comment: str | None = Field(default=None, max_length=1000)

    _clean_comment = field_validator("comment")(clean_text)


class ReportInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    reason: str | None = Field(default=None, max_length=500)

    _clean_reason = field_validator("reason")(clean_text)


class ModerationInput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    action: Literal["publish", "reject", "delete"]
    reason: str | None = Field(default=None, max_length=500)

    _clean_reason = field_validator("reason")(clean_text)

    @model_validator(mode="after")
    def require_action_reason(self):
        if self.action in {"reject", "delete"} and not self.reason:
            raise ValueError("reason is required when rejecting or deleting a comment")
        return self
