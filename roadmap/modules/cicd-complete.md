# CI/CD Guide

## GitHub Actions

### Базовий workflow
```yaml
# .github/workflows/main.yml
name: CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.x'
        
    - name: Install dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r requirements.txt pytest
        
    - name: Run tests
      run: pytest
      
    - name: Upload test results
      uses: actions/upload-artifact@v3
      with:
        name: test-results
        path: test-reports/

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
      
    - name: Login to DockerHub
      uses: docker/login-action@v2
      with:
        username: ${{ secrets.DOCKERHUB_USERNAME }}
        password: ${{ secrets.DOCKERHUB_TOKEN }}
        
    - name: Build and push
      uses: docker/build-push-action@v4
      with:
        push: true
        tags: user/app:${{ github.sha }}
        cache-from: type=registry,ref=user/app:latest
        cache-to: type=inline

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
    - name: Deploy to Digital Ocean
      uses: appleboy/ssh-action@master
      with:
        host: ${{ secrets.DO_HOST }}
        username: ${{ secrets.DO_USER }}
        key: ${{ secrets.SSH_KEY }}
        script: |
          docker pull user/app:${{ github.sha }}
          docker compose up -d

```

### Reusable Workflow
```yaml
# .github/workflows/reusable.yml
name: Reusable Deploy
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
    secrets:
      ssh_key:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - name: Deploy
        uses: appleboy/ssh-action@master
        with:
          key: ${{ secrets.ssh_key }}
```

## GitLab CI/CD

### Повний pipeline
```yaml
# .gitlab-ci.yml
image: python:3.9

variables:
  PIP_CACHE_DIR: "$CI_PROJECT_DIR/.pip-cache"
  DOCKER_TLS_CERTDIR: "/certs"

cache:
  paths:
    - .pip-cache/
    - venv/

stages:
  - test
  - build
  - deploy
  - review
  - cleanup

.test_template: &test_definition
  stage: test
  script:
    - python -m venv venv
    - source venv/bin/activate
    - pip install -r requirements.txt
    - pytest --junitxml=report.xml
  artifacts:
    reports:
      junit: report.xml

test:python-3.9:
  <<: *test_definition
  image: python:3.9

test:python-3.10:
  <<: *test_definition
  image: python:3.10

build:
  stage: build
  image: docker:20.10.16
  services:
    - docker:20.10.16-dind
  script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA

deploy_staging:
  stage: deploy
  environment:
    name: staging
    url: https://staging.example.com
  script:
    - apt-get update -y && apt-get install openssh-client -y
    - eval $(ssh-agent -s)
    - echo "$SSH_PRIVATE_KEY" | tr -d '\r' | ssh-add -
    - ssh $SERVER_USER@$SERVER_HOST "docker pull $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA && docker-compose up -d"
  only:
    - develop

deploy_production:
  stage: deploy
  environment:
    name: production
    url: https://example.com
  script:
    - apt-get update -y && apt-get install openssh-client -y
    - eval $(ssh-agent -s)
    - echo "$SSH_PRIVATE_KEY" | tr -d '\r' | ssh-add -
    - ssh $SERVER_USER@$SERVER_HOST "docker pull $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA && docker-compose up -d"
  only:
    - main
  when: manual

review:
  stage: review
  script:
    - echo "Deploy to review app"
  environment:
    name: review/$CI_COMMIT_REF_NAME
    url: https://$CI_ENVIRONMENT_SLUG.example.com
    on_stop: stop_review
  only:
    - merge_requests

stop_review:
  stage: cleanup
  script:
    - echo "Remove review app"
  environment:
    name: review/$CI_COMMIT_REF_NAME
    action: stop
  when: manual
  only:
    - merge_requests
```

### Auto DevOps
```yaml
# .gitlab-ci.yml з Auto DevOps
include:
  - template: Auto-DevOps.gitlab-ci.yml

variables:
  AUTO_DEVOPS_DOMAIN: example.com
  POSTGRES_ENABLED: "false"
  AUTO_DEVOPS_BUILD_IMAGE_CNB_ENABLED: "true"
```

## Практичні завдання

### 1. GitHub Actions
- Налаштувати матричне тестування
- Створити reusable workflows
- Налаштувати кешування залежностей
- Додати security scanning

### 2. GitLab CI/CD
- Налаштувати Auto DevOps
- Створити review apps
- Налаштувати динамічні environments
- Використати GitLab Pages

### 3. Безпека
- Сканування Docker образів
- SAST аналіз коду
- Перевірка залежностей
- Secrets management

### 4. Моніторинг та метрики
- Метрики pipeline
- Час виконання jobs
- Використання runners
- Сповіщення про помилки

### 5. Best Practices
- Структура pipeline
- Оптимізація швидкості
- Ефективне кешування
- Стратегії деплою