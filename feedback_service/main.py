from __future__ import annotations

import hmac
import base64
import binascii
import unicodedata
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
from .catalog import CatalogUnavailable, StudyPlannerCatalog
from .db import Database
from .models import CourseSearchInput, FeedbackInput, ModerationInput, ReportInput
from .security import SlidingWindowLimiter, issue_token, token_hash

bearer = HTTPBearer(auto_error=False)


def course_reference(course_number: str) -> str | None:
    normalized = " ".join(unicodedata.normalize("NFKC", course_number).split()).upper()
    if not normalized:
        return None
    reference = (
        base64.urlsafe_b64encode(normalized.encode()).decode("ascii").rstrip("=")
    )
    return reference if 2 <= len(reference) <= 160 else None


def create_app(
    settings: Settings | None = None, catalog: StudyPlannerCatalog | None = None
) -> FastAPI:
    settings = settings or Settings.from_env()
    settings.validate()
    database = Database(settings.database_path)
    catalog = catalog or StudyPlannerCatalog(settings.catalog_api_url)
    installation_limiter = SlidingWindowLimiter(settings.installation_limit_per_minute)
    author_limiter = SlidingWindowLimiter(settings.feedback_limit_per_minute)
    catalog_limiter = SlidingWindowLimiter(settings.catalog_search_limit_per_minute)
    catalog_global_limiter = SlidingWindowLimiter(
        settings.catalog_search_limit_per_minute * 10
    )

    @asynccontextmanager
    async def lifespan(_: FastAPI):
        database.migrate()
        yield

    app = FastAPI(title="StudyOS Course Ratings", version="1.0.0", lifespan=lifespan)
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

    def course(course_id: str) -> tuple[str, str]:
        """Validate a URL-safe base64 course number without trusting titles."""
        if not 2 <= len(course_id) <= 160:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "course not found")
        try:
            padding = "=" * (-len(course_id) % 4)
            raw = base64.b64decode(course_id + padding, altchars=b"-_", validate=True)
            course_number = raw.decode("utf-8")
        except (binascii.Error, UnicodeDecodeError):
            raise HTTPException(status.HTTP_404_NOT_FOUND, "course not found") from None
        if not 1 <= len(course_number) <= 120 or any(
            ord(char) < 32 or ord(char) == 127 for char in course_number
        ):
            raise HTTPException(status.HTTP_404_NOT_FOUND, "course not found")
        canonical = base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")
        if not hmac.compare_digest(canonical, course_id):
            raise HTTPException(status.HTTP_404_NOT_FOUND, "course not found")
        registered_number = database.course_number(course_id)
        if registered_number is None or course_reference(course_number) != course_id:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "course not found")
        return course_id, registered_number

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

    @app.post("/v1/courses/search")
    def search_courses(
        payload: CourseSearchInput,
        request: Request,
    ) -> dict:
        peer = request.client.host if request.client else "unknown"
        if not catalog_limiter.allow(peer) or not catalog_global_limiter.allow("all"):
            raise HTTPException(
                status.HTTP_429_TOO_MANY_REQUESTS, "rate limit exceeded"
            )
        try:
            result = catalog.search(payload.query, payload.limit)
        except CatalogUnavailable as error:
            raise HTTPException(
                status.HTTP_503_SERVICE_UNAVAILABLE, str(error)
            ) from error
        registrations = []
        rateable_courses = []
        for item in result["courses"]:
            rating_id = course_reference(item["courseNumber"])
            if rating_id is None:
                continue
            item["ratingCourseId"] = rating_id
            registrations.append((rating_id, item["courseNumber"]))
            rateable_courses.append(item)
        result["courses"] = rateable_courses
        database.register_courses(registrations)
        return result

    @app.get("/v1/courses/{course_id}/feedback/public")
    def public_feedback(
        course_id: str,
        limit: Annotated[int, Query(ge=1, le=100)] = 20,
        offset: Annotated[int, Query(ge=0, le=10_000)] = 0,
    ) -> dict:
        course_ref, course_number = course(course_id)
        return database.public_feedback(course_ref, course_number, limit, offset)

    @app.get("/v1/courses/{course_id}/feedback/mine")
    def own_feedback(
        course_id: str, installation_id: str = Depends(installation)
    ) -> dict:
        course_ref, _ = course(course_id)
        row = database.feedback_for_owner(installation_id, course_ref)
        if not row:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "feedback not found")
        return dict(row)

    @app.put("/v1/courses/{course_id}/feedback/mine")
    def put_feedback(
        course_id: str,
        payload: FeedbackInput,
        installation_id: str = Depends(limited_installation),
    ) -> dict:
        return dict(
            database.upsert_feedback(
                installation_id, course(course_id)[0], payload.rating, payload.comment
            )
        )

    @app.delete(
        "/v1/courses/{course_id}/feedback/mine",
        status_code=status.HTTP_204_NO_CONTENT,
    )
    def delete_feedback(
        course_id: str, installation_id: str = Depends(limited_installation)
    ) -> Response:
        if not database.delete_feedback(installation_id, course(course_id)[0]):
            raise HTTPException(status.HTTP_404_NOT_FOUND, "feedback not found")
        return Response(status_code=status.HTTP_204_NO_CONTENT)

    @app.post(
        "/v1/courses/{course_id}/feedback/{feedback_id}/reports",
        status_code=status.HTTP_201_CREATED,
    )
    def report_feedback(
        course_id: str,
        feedback_id: str,
        payload: ReportInput,
        installation_id: str = Depends(limited_installation),
    ) -> dict[str, str]:
        result = database.report(
            installation_id, course(course_id)[0], feedback_id, payload.reason
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
        course_id: str | None = None,
        limit: Annotated[int, Query(ge=1, le=100)] = 50,
        offset: Annotated[int, Query(ge=0, le=10_000)] = 0,
        _moderator_id: str = Depends(admin),
    ) -> dict:
        if course_id is not None:
            course_id = course(course_id)[0]
        items = [
            dict(row)
            for row in database.moderation_queue(
                state,
                course_id,
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
