# Kubernetes Guide

## Порівняння дистрибутивів

| Характеристика | Minikube | k3s | k8s |
|----------------|----------|-----|-----|
| Призначення | Локальна розробка | Легкі production середовища | Enterprise production |
| Ресурси | 2GB RAM мінімум | 512MB RAM мінімум | 2GB+ RAM на ноду |
| Інсталяція | Простий інсталятор | Один бінарний файл | Складна інсталяція |
| Кластер | Одна нода | Multi-node | Multi-node |
| Підтримка | Спільнота | Rancher (SUSE) | CNCF |

## Встановлення та Налаштування

### Minikube
```bash
# Встановлення
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Запуск кластера
minikube start --driver=docker
minikube status

# Базові команди
minikube kubectl -- get pods -A
minikube dashboard
minikube addons enable metrics-server
minikube tunnel  # для LoadBalancer сервісів
```

### k3s
```bash
# Single node installation
curl -sfL https://get.k3s.io | sh -

# Master node
curl -sfL https://get.k3s.io | sh -s - server \
  --token=SECRET \
  --tls-san master.example.com \
  --cluster-init

# Worker node
curl -sfL https://get.k3s.io | K3S_URL="https://master:6443" \
  K3S_TOKEN="SECRET" sh -

# Конфігурація kubectl
mkdir ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
```

## Основні Компоненти

### 1. Pod та Deployment
```yaml
# basic-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: nginx:1.14.2
    ports:
    - containerPort: 80

# deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.14.2
        ports:
        - containerPort: 80
```

### 2. Service та Ingress
```yaml
# service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: nginx

# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
spec:
  rules:
  - host: nginx.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-service
            port:
              number: 80
```

### 3. ConfigMap та Secret
```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  DB_HOST: "db.example.com"
  DB_PORT: "5432"

# secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  DB_PASSWORD: cGFzc3dvcmQ=  # base64 encoded
```

## Практичні Завдання

### 1. Базове Розгортання
```bash
# Створення namespace
kubectl create namespace myapp

# Розгортання застосунку
kubectl apply -f deployment.yaml -n myapp
kubectl apply -f service.yaml -n myapp
kubectl apply -f ingress.yaml -n myapp

# Перевірка стану
kubectl get all -n myapp
kubectl describe deployment nginx-deployment -n myapp
```

### 2. Моніторинг та Логи
```bash
# Prometheus + Grafana через Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack

# Перегляд логів
kubectl logs -f deployment/nginx-deployment
kubectl logs -f -l app=nginx
```

### 3. Масштабування
```bash
# Ручне масштабування
kubectl scale deployment nginx-deployment --replicas=5

# Автоматичне масштабування
kubectl autoscale deployment nginx-deployment \
  --min=2 --max=5 --cpu-percent=80
```

## Особливості Дистрибутивів

**Minikube:**
- Вбудований Docker registry
- Аддони для розробки
- LoadBalancer емуляція
- Інтегрований dashboard

**k3s:**
- Вбудований SQLite/etcd
- Traefik Ingress за замовчуванням
- Легке оновлення
- Низькі вимоги до ресурсів

**k8s:**
- Повна функціональність
- Enterprise features
- Розширена безпека
- Повний контроль