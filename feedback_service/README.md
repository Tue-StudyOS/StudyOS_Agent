# StudyOS course ratings service

A small FastAPI service backed by SQLite. It proxies public, read-only course
lookup to StudyPlanner and stores ratings by stable course number. Ratings are
public immediately while optional comments enter a moderation queue. Anonymous
installation credentials are random 256-bit bearer tokens; only their SHA-256
digests are stored.
Moderation is manual by default, so there is no third-party API, data transfer,
or usage-based moderation bill.

## Run

Copy `compose.example.yml`, generate a long random `FEEDBACK_ADMIN_TOKEN`, set
the exact frontend origins in `FEEDBACK_CORS_ORIGINS`, and run
`docker compose up --build`. The SQLite database is kept in the named volume.
The API schema is available at `/docs`; health checks use `/healthz`.

Never embed the admin token in a client. Put this service behind HTTPS and a
reverse proxy. The in-process limits (10 installation issuances per peer and 30
writes per author per minute by default) are only a deterministic safety net;
the proxy must enforce distributed IP and global limits, body-size limits, and
request timeouts. Configure trusted proxy IPs in the container command before
relying on forwarded client addresses. Token issuance is intentionally
anonymous and therefore Sybil-prone; comments default to `pending` for this
reason.

## Configuration

- `FEEDBACK_DATABASE_PATH` (default `/data/feedback.sqlite3`)
- `FEEDBACK_ADMIN_TOKEN` (admin endpoints remain inaccessible when empty)
- `FEEDBACK_MODERATOR_ID` (audit identity bound to the admin token)
- `FEEDBACK_CATALOG_API_URL` (default: the public StudyPlanner API)
- `FEEDBACK_CATALOG_RATE_LIMIT` (per peer/minute; default `30`)
- `FEEDBACK_CORS_ORIGINS` (comma-separated exact origins; empty disables CORS)
- `FEEDBACK_INSTALLATION_RATE_LIMIT` and `FEEDBACK_AUTHOR_RATE_LIMIT`

## Moderation operations

List pending or reported comments from a trusted admin machine, then publish,
reject, or delete the text. Admin deletion leaves the numeric rating active;
owner deletion removes both rating and comment from public results.

```sh
curl -H "X-Admin-Token: $FEEDBACK_ADMIN_TOKEN" \
  -H "X-Moderator-Id: $FEEDBACK_MODERATOR_ID" \
  "https://feedback.example.edu/v1/admin/moderation?state=pending&limit=50"

curl -X POST \
  -H "X-Admin-Token: $FEEDBACK_ADMIN_TOKEN" \
  -H "X-Moderator-Id: $FEEDBACK_MODERATOR_ID" \
  -H "Content-Type: application/json" \
  -d '{"action":"publish","reason":"manual review"}' \
  "https://feedback.example.edu/v1/admin/feedback/FEEDBACK_ID/moderation"
```

Every moderation action records the supplied moderator identifier in
`moderation_audit`; reject/delete actions require a reason. The configured ID is
bound to the admin secret instead of trusting an arbitrary request label. Use
separate service deployments/credentials if independent moderator attribution is
required. Reasons and reports are never returned by
public endpoints. Rotate the admin token after suspected exposure. This version
intentionally has no automated third-party moderation:
provider privacy, retention, failure behavior, and billing must be reviewed
before such an integration is enabled, and failures must fall back to pending
human review.

## Course identity and privacy boundary

`POST /v1/courses/search` forwards only the public search text to the shared
StudyPlanner catalog and caches up to 64 bounded results in memory for five
minutes. POST keeps search terms out of URL history and ordinary access logs;
operators must still avoid request-body logging. ALMA
credentials, cookies, enrollment lists, profiles, and timetables never reach
this service. Course feedback is grouped longitudinally by course number, so
different semesters contribute to one course's aggregate.

The “My courses” shortcuts are computed in the app and are not uploaded as a
list; selecting one sends its title as a catalog search. Installation tokens do
not prove a unique person, university membership,
or enrollment. These are community ratings, not verified-student reviews.

Schema v1 belonged to the abandoned app/service-rating prototype. The service
refuses to relabel that data as course feedback; back it up and recreate the
volume before starting this schema-v2 build.

## Launch and retention checklist

Before public deployment, the team must name a moderation owner, response
expectation, and escalation/contact path. Publish a short notice covering the
pseudonymous installation identifier, public ratings/comments, report and
moderation processing, deletion behavior, backup location/expiry, and operator
contact. Choose and automate retention for rejected/deleted text, audit events,
reports, inactive installations, and backups; this repository does not invent a
course-wide retention period. Do not collect university credentials, email
addresses, profile data, or raw device fingerprints in this service.

## Backup and restore

Create an online, transactionally consistent backup inside the running
container and verify it before copying it to separate storage:

```sh
docker compose exec feedback python -m feedback_service.backup create \
  /data/feedback.sqlite3 /backups/feedback-$(date +%F).sqlite3
docker compose exec feedback python -m feedback_service.backup verify \
  /backups/feedback-$(date +%F).sqlite3
```

Backups still contain comments and pseudonymous installation hashes; restrict
their access and define an expiry matching the project's retention notice. To
restore, stop the service, verify the selected backup, replace
`/data/feedback.sqlite3`, remove stale `-wal`/`-shm` sidecars, then restart and
check `/healthz` plus a public read. Practice this against a disposable volume
before launch.

Run one application process per SQLite volume; scale at the reverse proxy only
after moving to a multi-writer database.
