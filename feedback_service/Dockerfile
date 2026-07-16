FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN addgroup --system --gid 10001 feedback \
    && adduser --system --uid 10001 --ingroup feedback --home /app feedback
WORKDIR /app
COPY feedback_service/requirements.txt ./feedback_service/requirements.txt
RUN pip install --requirement feedback_service/requirements.txt
COPY feedback_service ./feedback_service
RUN mkdir /data /backups && chown feedback:feedback /data /backups

USER feedback
EXPOSE 8080
CMD ["uvicorn", "feedback_service.main:app", "--host", "0.0.0.0", "--port", "8080", "--no-access-log", "--proxy-headers", "--forwarded-allow-ips", "127.0.0.1"]
