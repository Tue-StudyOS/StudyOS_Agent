from __future__ import annotations

import hmac
from contextlib import asynccontextmanager
from typing import Annotated

from fastapi import (
    Depends,
    FastAPI,
    Header,
    HTTPException,
    Query,
    Request,
    Response,
    status,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .config import MODERATOR_ID, Settings
from .db import Database
from .models import FeedbackInput, ModerationInput, ReportInput
from .security import SlidingWindowLimiter, issue_token, token_hash

bearer = HTTPBearer(auto_error=False)


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or Settings.from_env()
    settings.validate()
    database = Database(settings.database_path)
    installation_limiter = SlidingWindowLimiter(settings.installation_limit_per_minute)
    author_limiter = SlidingWindowLimiter(settings.feedback_limit_per_minute)

    @asynccontextmanager
    async def lifespan(_: FastAPI):
        database.migrate()
        yield

    app = FastAPI(title="StudyOS Feedback Service", version="1.0.0", lifespan=lifespan)
    app.state.database = database
    if settings.cors_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=list(settings.cors_origins),
            allow_credentials=False,
            allow_methods=["GET", "POST", "PUT", "DELETE"],
            allow_headers=[
                "Authorization",
                "Content-Type",
                "X-Admin-Token",
                "X-Moderator-Id",
            ],
        )

    def service(service_id: str) -> str:
        if service_id not in settings.allowed_service_ids:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "service not found")
        return service_id

    def installation(
        credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
    ) -> str:
        if (
            not credentials
            or credentials.scheme.lower() != "bearer"
            or not 32 <= len(credentials.credentials) <= 256
        ):
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "invalid bearer token")
        installation_id = database.installation_id(token_hash(credentials.credentials))
        if not installation_id:
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "invalid bearer token")
        return installation_id

    def limited_installation(
        credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
    ) -> str:
        installation_id = installation(credentials)
        if not author_limiter.allow(installation_id):
            raise HTTPException(
                status.HTTP_429_TOO_MANY_REQUESTS, "rate limit exceeded"
            )
        return installation_id

    def admin(
        x_admin_token: Annotated[str | None, Header()] = None,
        x_moderator_id: Annotated[str | None, Header()] = None,
    ) -> str:
        if (
            not settings.admin_token
            or not x_admin_token
            or not hmac.compare_digest(x_admin_token, settings.admin_token)
        ):
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, "invalid admin token")
        if (
            not x_moderator_id
            or not MODERATOR_ID.fullmatch(x_moderator_id)
            or not hmac.compare_digest(x_moderator_id, settings.moderator_id)
        ):
            raise HTTPException(status.HTTP_400_BAD_REQUEST, "invalid moderator id")
        return settings.moderator_id

    @app.get("/healthz")
    def health() -> dict[str, str]:
        with database.connect() as db:
            db.execute("SELECT 1").fetchone()
        return {"status": "ok"}

    @app.post("/v1/installations", status_code=status.HTTP_201_CREATED)
    def create_installation(request: Request) -> dict[str, str]:
        peer = request.client.host if request.client else "unknown"
        if not installation_limiter.allow(peer):
            raise HTTPException(
                status.HTTP_429_TOO_MANY_REQUESTS, "rate limit exceeded"
            )
        token = issue_token()
        database.create_installation(token_hash(token))
        return {"installation_token": token, "token_type": "bearer"}

    @app.get("/v1/services/{service_id}/feedback/public")
    def public_feedback(
        service_id: str,
        limit: Annotated[int, Query(ge=1, le=100)] = 20,
        offset: Annotated[int, Query(ge=0, le=10_000)] = 0,
    ) -> dict:
        return database.public_feedback(service(service_id), limit, offset)

    @app.get("/v1/services/{service_id}/feedback/mine")
    def own_feedback(
        service_id: str, installation_id: str = Depends(installation)
    ) -> dict:
        row = database.feedback_for_owner(installation_id, service(service_id))
        if not row:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "feedback not found")
        return dict(row)

    @app.put("/v1/services/{service_id}/feedback/mine")
    def put_feedback(
        service_id: str,
        payload: FeedbackInput,
        installation_id: str = Depends(limited_installation),
    ) -> dict:
        return dict(
            database.upsert_feedback(
                installation_id, service(service_id), payload.rating, payload.comment
            )
        )

    @app.delete(
        "/v1/services/{service_id}/feedback/mine",
        status_code=status.HTTP_204_NO_CONTENT,
    )
    def delete_feedback(
        service_id: str, installation_id: str = Depends(limited_installation)
    ) -> Response:
        if not database.delete_feedback(installation_id, service(service_id)):
            raise HTTPException(status.HTTP_404_NOT_FOUND, "feedback not found")
        return Response(status_code=status.HTTP_204_NO_CONTENT)

    @app.post(
        "/v1/services/{service_id}/feedback/{feedback_id}/reports",
        status_code=status.HTTP_201_CREATED,
    )
    def report_feedback(
        service_id: str,
        feedback_id: str,
        payload: ReportInput,
        installation_id: str = Depends(limited_installation),
    ) -> dict[str, str]:
        result = database.report(
            installation_id, service(service_id), feedback_id, payload.reason
        )
        if result == "not_found":
            raise HTTPException(
                status.HTTP_404_NOT_FOUND, "published comment not found"
            )
        if result == "own":
            raise HTTPException(
                status.HTTP_400_BAD_REQUEST, "cannot report own comment"
            )
        if result == "duplicate":
            raise HTTPException(status.HTTP_409_CONFLICT, "comment already reported")
        return {"status": "recorded"}

    @app.get("/v1/admin/moderation")
    def moderation_queue(
        state: Annotated[str, Query(pattern="^(pending|reported)$")] = "pending",
        service_id: str | None = None,
        limit: Annotated[int, Query(ge=1, le=100)] = 50,
        offset: Annotated[int, Query(ge=0, le=10_000)] = 0,
        _moderator_id: str = Depends(admin),
    ) -> dict:
        if service_id is not None:
            service(service_id)
        items = [
            dict(row)
            for row in database.moderation_queue(
                state,
                service_id,
                limit,
                offset,
            )
        ]
        if state == "reported":
            for item in items:
                item["reports"] = [
                    dict(report) for report in database.reports_for_feedback(item["id"])
                ]
        return {
            "items": items,
            "limit": limit,
            "offset": offset,
        }

    @app.post("/v1/admin/feedback/{feedback_id}/moderation")
    def moderate(
        feedback_id: str,
        payload: ModerationInput,
        moderator_id: str = Depends(admin),
    ) -> dict:
        result = database.moderate(
            feedback_id,
            payload.action,
            payload.reason,
            moderator_id,
        )
        if result is None:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "feedback not found")
        if result == "invalid":
            raise HTTPException(
                status.HTTP_409_CONFLICT, "invalid moderation state transition"
            )
        return result

    return app


app = create_app()
