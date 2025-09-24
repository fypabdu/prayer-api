FROM python:3.12-slim

LABEL authors="fypabdu"

# Prevent Python from buffering stdout
ENV PYTHONUNBUFFERED=1

# Set working directory
WORKDIR /app

# Install system dependencies (needed by psycopg2/mysqlclient if used later)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the entire project
COPY . .

# Collect static files (optional for Django)
RUN python manage.py collectstatic --noinput || true

# Expose the port
EXPOSE 8000

# Run with Gunicorn
CMD ["gunicorn", "prayer_api.wsgi:application", "--bind", "0.0.0.0:8000"]
