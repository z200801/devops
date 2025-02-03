# Docker

## Основи Docker

### Базові команди
```bash
# Контейнери
docker run nginx
docker ps
docker stop container_id
docker rm container_id

# Образи
docker images
docker pull nginx
docker rmi nginx
docker build -t myapp .
```

### Dockerfile
```dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
EXPOSE 8000

CMD ["python", "app.py"]
```

## Docker Compose

### Базова конфігурація
```yaml
# docker-compose.yml
version: '3'

services:
  web:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - .:/app
    environment:
      - DATABASE_URL=postgres://user:pass@db:5432/dbname
    depends_on:
      - db
  
  db:
    image: postgres:13
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=dbname
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=pass

volumes:
  postgres_data:
```

## Мережі Docker

### Типи мереж
- bridge
- host
- none
- overlay
- macvlan

```bash
# Створення мережі
docker network create mynetwork

# Підключення контейнера
docker run --network mynetwork nginx
```

## Volumes та Персистентність

### Типи монтування
```bash
# Volume
docker volume create myvolume
docker run -v myvolume:/data nginx

# Bind mount
docker run -v $(pwd):/app nginx

# tmpfs
docker run --tmpfs /app nginx
```

## Multi-stage Builds

```dockerfile
# Build stage
FROM node:14 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Production stage
FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

## Docker Registry

```bash
# Локальний registry
docker run -d -p 5000:5000 registry

# Push/Pull
docker tag myapp localhost:5000/myapp
docker push localhost:5000/myapp
docker pull localhost:5000/myapp
```

## Практичні завдання

### 1. Базові операції
- Створити Dockerfile
- Зібрати образ
- Запустити контейнер
- Керувати контейнерами

### 2. Docker Compose
- Створити композицію сервісів
- Налаштувати мережу
- Налаштувати volumes
- Масштабування сервісів

### 3. Оптимізація
- Multi-stage builds
- Оптимізація розміру образу
- Кешування шарів
- Безпека контейнерів

### 4. Production
- Registry налаштування
- CI/CD інтеграція
- Моніторинг контейнерів
- Логування