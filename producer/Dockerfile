
FROM python:3.11-slim
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt
WORKDIR /app
COPY producer.py /app/producer.py
ENTRYPOINT ["python","/app/producer.py"]
