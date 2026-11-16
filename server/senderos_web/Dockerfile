FROM python:3.12-slim
RUN pip install --no-cache-dir aiohttp==3.12.15
WORKDIR /app
COPY relay.py .
RUN chmod 755 /app && chmod 644 /app/relay.py
USER 65534:65534
CMD ["python", "relay.py"]
