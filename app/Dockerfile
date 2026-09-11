FROM python:3.11-alpine
WORKDIR /app
RUN apk add --no-cache iputils
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY Monitor.py .
EXPOSE 5000
CMD ["python", "Monitor.py"]