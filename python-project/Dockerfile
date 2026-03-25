FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Create non-root user
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser
COPY ETL.py .
RUN chown -R appuser:appgroup /app
USER appuser

# The container will be triggered by Kubernetes CronJob every 1 hour
CMD ["python", "ETL.py"]
