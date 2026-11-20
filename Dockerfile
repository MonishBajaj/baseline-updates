# Build Vite dashboard, then serve with gunicorn + Flask/WhiteNoise.

FROM node:20-bookworm-slim AS frontend
WORKDIR /app/dashboard
COPY dashboard/package.json dashboard/package-lock.json ./
RUN npm ci
COPY dashboard/ ./
ENV VITE_DATA_MODE=static
ENV VITE_BASE_PATH=/
RUN npm run build:static \
  && test -f dist/index.html

FROM python:3.12-slim-bookworm
WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .
COPY --from=frontend /app/dashboard/dist ./dashboard/dist

EXPOSE 10000
CMD gunicorn app:app --bind 0.0.0.0:${PORT:-10000} --workers 2 --timeout 120
