FROM python:3.11-alpine@sha256:0d55920083f1ce1e38ac292e2772f924b4f8bb4188d336c79bf66963039e6146
WORKDIR /app
RUN apk add --no-cache iputils
RUN addgroup -g 10001 appgroup && \
    adduser -u 10001 -G appgroup -h /home/appuser -s /sbin/nologin -D appuser && \
    chown appuser:appgroup /app
COPY --chown=appuser:appgroup Monitor.py .
USER appuser
CMD ["python", "Monitor.py"]