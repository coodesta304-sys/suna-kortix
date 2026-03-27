# syntax=docker.io/docker/dockerfile:1
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    build-essential \
    pkg-config \
    python3-dev \
    libpq-dev \
    libffi-dev \
    libjpeg-dev \
    libpng-dev \
    fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 22
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# Copy backend files
COPY backend/requirements.txt backend/pyproject.toml backend/uv.lock ./

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend code
COPY backend/ ./backend/

# Copy frontend files
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc* ./
COPY apps ./apps
COPY packages ./packages

# Install frontend dependencies (all workspace packages including shared)
RUN pnpm install --frozen-lockfile

# Build frontend
WORKDIR /app/apps/frontend
ENV NEXT_TELEMETRY_DISABLED=1
ENV NEXT_OUTPUT=standalone
ENV NEXT_PUBLIC_SUPABASE_URL=https://mffcydkfcwgqfnagfnhm.supabase.co
ENV NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1mZmN5ZGtmY3dncWZuYWdmbmhtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ1NDgwNDQsImV4cCI6MjA5MDEyNDA0NH0.SSYf2n1r_X3e3LHcRv5oOyqTbsfWNQcLNfX0CVU7E20
ENV NEXT_PUBLIC_API_URL=https://$RAILWAY_PUBLIC_DOMAIN
ENV MAIN_LLM=wavespeed
RUN pnpm run build

# Go back to app directory
WORKDIR /app

# Environment variables
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1
ENV ENV_MODE=production

# Expose ports
EXPOSE 8000 3000

# Start both services
CMD ["sh", "-c", "cd backend && uvicorn api:app --host 0.0.0.0 --port 8000 & cd apps/frontend && node server.js"]
