ARG PYTHON_VER="3.11"

FROM python:${PYTHON_VER}-slim AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev && \
    apt-get clean -y && apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

RUN python -m venv /opt/venv

ENV PATH="/opt/venv/bin:$PATH" PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --upgrade pip setuptools wheel && \
    pip install -r requirements.txt --no-cache-dir


FROM python:${PYTHON_VER}-slim

ARG _USER=appuser
ARG _GROUP=appgroup

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libpq5 pgloader postgresql-client mariadb-client && \
    apt-get clean -y && apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/* && \
    groupadd ${_GROUP} && useradd --no-log-init -r --no-create-home -G ${_GROUP} ${_USER}

ENV PATH="/opt/venv/bin:$PATH" PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PYTHONPATH="$PYTHONPATH:/app"

COPY --from=builder /opt/venv /opt/venv

WORKDIR /app
COPY . .
# RUN chown -R ${_USER}:${_GROUP} /app
RUN chown -R root:${_GROUP} /app && \
    chmod -R 750 /app && \
    chmod -R 550 /app/*.py && \
    mkdir -p /app/logs /app/tmp && \
    chown -R ${_USER}:${_GROUP} /app/logs /app/tmp && \
    chmod -R 770 /app/logs /app/tmp

USER ${_USER}
CMD ["/bin/bash", "/app/start.sh"]

