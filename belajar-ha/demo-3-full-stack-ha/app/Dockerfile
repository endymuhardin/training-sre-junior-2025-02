FROM python:3.11-alpine

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY app.py .

# Health check
HEALTHCHECK --interval=5s --timeout=3s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost:5000/health || exit 1

EXPOSE 5000

CMD ["python", "app.py"]
