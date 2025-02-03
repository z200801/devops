# Python для DevOps

## Основи Python

### Базовий синтаксис
```python
# Змінні та типи даних
name = "Server1"
port = 8080
is_active = True
config = {"host": "localhost", "port": 8080}

# Умови
if port < 1024:
    print("Privileged port")
else:
    print("User port")

# Цикли
for key, value in config.items():
    print(f"{key}: {value}")

# Функції
def check_service(host, port, timeout=5):
    try:
        # Логіка перевірки
        return True
    except Exception as e:
        return False
```

### Робота з файлами
```python
# Читання файлу
with open('config.yml', 'r') as f:
    content = f.read()

# Запис у файл
with open('log.txt', 'w') as f:
    f.write('Service started')

# CSV файли
import csv
with open('data.csv', 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        print(row)
```

## Автоматизація

### Системні операції
```python
import os
import subprocess
import shutil

# Операції з файлами
os.makedirs('backup', exist_ok=True)
shutil.copy2('source.txt', 'backup/')

# Запуск команд
result = subprocess.run(['ls', '-l'], 
                       capture_output=True, 
                       text=True)
print(result.stdout)
```

### Мережеві операції
```python
import requests
import socket

# HTTP запити
response = requests.get('http://api.example.com/status')
print(response.json())

# Сокети
sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
result = sock.connect_ex(('localhost', 80))
```

## DevOps Скрипти

### Моніторинг серверів
```python
import psutil
import time

def monitor_system():
    while True:
        cpu = psutil.cpu_percent()
        memory = psutil.virtual_memory().percent
        disk = psutil.disk_usage('/').percent
        
        print(f"CPU: {cpu}%")
        print(f"Memory: {memory}%")
        print(f"Disk: {disk}%")
        
        time.sleep(60)
```

### Docker інтеграція
```python
import docker

client = docker.from_env()

# Список контейнерів
containers = client.containers.list()

# Запуск контейнера
container = client.containers.run(
    "nginx",
    detach=True,
    ports={'80/tcp': 8080}
)
```

### Kubernetes інтеграція
```python
from kubernetes import client, config

config.load_kube_config()
v1 = client.CoreV1Api()

# Список подів
pods = v1.list_pod_for_all_namespaces()
for pod in pods.items:
    print(f"{pod.metadata.namespace} {pod.metadata.name}")
```

## Практичні завдання

### 1. Автоматизація бекапів
- Створити скрипт для бекапу баз даних
- Додати компресію та ротацію
- Налаштувати сповіщення

### 2. Моніторинг
- Збір метрик системи
- Відправка даних в Prometheus
- Автоматичні звіти

### 3. CI/CD інтеграція
- Автоматизація тестів
- Розгортання в Docker
- Інтеграція з Kubernetes