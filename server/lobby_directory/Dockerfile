FROM python:3.12-alpine

WORKDIR /app
COPY lobby_server.py /app/lobby_server.py

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    LOBBY_HOST=0.0.0.0 \
    LOBBY_PORT=8080 \
    LOBBY_TRUST_PROXY=1

EXPOSE 8080
USER 65534:65534
CMD ["python3", "/app/lobby_server.py"]
