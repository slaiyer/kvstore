# syntax=docker/dockerfile:1

FROM python:3.10-slim as builder
WORKDIR /opt/venv
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
COPY src/requirements.txt .
RUN python3 -m pip install --upgrade pip \
      && python3 -m pip install -r requirements.txt
COPY src/router.py .

FROM python:3.10-slim
WORKDIR /opt/venv
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
EXPOSE 8000
CMD ["uvicorn", "router:APP", "--host", "0.0.0.0", "--port", "8000"]
