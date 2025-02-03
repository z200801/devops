# DevOps Engineer: Початковий План Навчання

## Етап 1: Основи (2-3 місяці)

### Практичні завдання для кожного етапу

#### Блок 1: Linux та командний рядок

1. Налаштування віртуальної машини:
   - Встановити VirtualBox
   - Створити VM з Ubuntu Server
   - Налаштувати мережу в режимі моста

2. Робота з файлами та директоріями:

   ```bash
   # Створити наступну структуру директорій
   /project
   ├── logs
   │   ├── app
   │   └── nginx
   ├── config
   └── backup
   ```

   - Встановити різні права доступу для кожної директорії
   - Створити скрипт для автоматичного бекапу логів

3. Робота з процесами:
   - Написати скрипт моніторингу використання CPU/RAM
   - Налаштувати автоматичний перезапуск процесу при падінні
   - Створити cron-завдання для періодичних операцій

4. Текстові маніпуляції:
   - Написати скрипт для аналізу логів з використанням grep, awk, sed
   - Створити pipeline для обробки текстових даних

### Linux та командний рядок

- Встановлення та налаштування Linux (Ubuntu/CentOS)
- Базові команди терміналу
- Права доступу та користувачі
- Робота з файловою системою
- Текстові редактори (vim/nano)
- Bash скриптинг

#### Блок 2: Мережі

1. Базова конфігурація:
   - Налаштувати статичну IP-адресу
   - Налаштувати DNS-сервер
   - Встановити та налаштувати SSH-сервер
   - Налаштувати фаєрвол (iptables/ufw)

2. Моніторинг мережі:
   - Використання tcpdump для аналізу трафіку
   - Налаштування Wireshark
   - Створення скрипта для моніторингу доступності сервісів

3. Веб-сервер:
   - Встановити та налаштувати Nginx
   - Налаштувати віртуальні хости
   - Налаштувати SSL/TLS сертифікати

### Vagrant та Віртуалізація

- Встановлення та налаштування Vagrant
- Робота з VirtualBox та Libvirt провайдерами
- Vagrantfile та конфігурація
- Multi-machine оточення
- Provisioning (Shell, Ansible)
- Мережеві налаштування

#### Блок: Vagrant

1. Базове налаштування:

   ```bash
   # Встановлення Vagrant
   sudo apt install vagrant
   
   # Встановлення провайдерів
   sudo apt install virtualbox
   sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
   
   # Встановлення плагіна для libvirt
   vagrant plugin install vagrant-libvirt
   ```

2. Практичні завдання з VirtualBox:

   ```ruby
   # Приклад базового Vagrantfile для VirtualBox
   Vagrant.configure("2") do |config|
     config.vm.box = "ubuntu/focal64"
     config.vm.provider "virtualbox" do |vb|
       vb.memory = "2048"
       vb.cpus = 2
     end
     
     config.vm.network "private_network", ip: "192.168.56.10"
     
     config.vm.provision "shell", inline: <<-SHELL
       apt-get update
       apt-get install -y nginx
     SHELL
   end
   ```

   - Створити VM з Ubuntu 20.04
   - Налаштувати порти та мережі
   - Встановити базові пакети через provisioning

3. Практичні завдання з Libvirt:

   ```ruby
   # Приклад Vagrantfile для Libvirt
   Vagrant.configure("2") do |config|
     config.vm.box = "generic/ubuntu2004"
     config.vm.provider :libvirt do |libvirt|
       libvirt.memory = 2048
       libvirt.cpus = 2
       libvirt.nested = true
     end
     
     config.vm.network "private_network", ip: "192.168.121.10"
   end
   ```

   - Налаштувати Libvirt провайдер
   - Створити VM з використанням KVM
   - Налаштувати мережеві мости

4. Multi-machine оточення:

   ```ruby
   # Приклад multi-machine Vagrantfile
   Vagrant.configure("2") do |config|
     config.vm.define "web" do |web|
       web.vm.box = "ubuntu/focal64"
       web.vm.network "private_network", ip: "192.168.56.10"
       web.vm.provision "shell", inline: <<-SHELL
         apt-get update
         apt-get install -y nginx
       SHELL
     end
   
     config.vm.define "db" do |db|
       db.vm.box = "ubuntu/focal64"
       db.vm.network "private_network", ip: "192.168.56.11"
       db.vm.provision "shell", inline: <<-SHELL
         apt-get update
         apt-get install -y postgresql
       SHELL
     end
   end
   ```

   - Створити кластер з веб-сервером та базою даних
   - Налаштувати мережеву взаємодію між VM
   - Автоматизувати налаштування сервісів

5. Ansible provisioning:

   ```ruby
   # Приклад Vagrantfile з Ansible provisioner
   Vagrant.configure("2") do |config|
     config.vm.box = "ubuntu/focal64"
     
     config.vm.provision "ansible" do |ansible|
       ansible.playbook = "playbook.yml"
       ansible.become = true
     end
   end
   ```

   ```yaml
   # playbook.yml
   ---
   - hosts: all
     tasks:
       - name: Update apt cache
         apt:
           update_cache: yes
           
       - name: Install required packages
         apt:
           name: ['nginx', 'curl', 'git']
           state: present
   ```

   - Створити базовий плейбук
   - Налаштувати ролі
   - Використати змінні та шаблони

6. Додаткові завдання:
   - Налаштувати спільні папки (synced folders)
   - Створити власний базовий образ (box)
   - Налаштувати автоматичний старт сервісів
   - Інтегрувати з Docker

7. Проектне завдання:
   Створити повноцінне тестове оточення:
   - Веб-сервер (Nginx)
   - База даних (PostgreSQL)
   - Кешування (Redis)
   - Моніторинг (Prometheus + Grafana)
   - Автоматичне налаштування через Ansible
   - Мережева взаємодія між компонентами
   - Спільні папки для розробки
   - Скрипти для бекапу та відновлення

### Мережі

- TCP/IP протокол
- DNS
- HTTP/HTTPS
- SSH
- Основи мережевої безпеки

#### Блок 3: Git

1. Базові операції:
   - Створити локальний репозиторій
   - Додати файли до staging area
   - Створити комміти з різними типами змін
   - Налаштувати .gitignore

2. Робота з гілками:
   - Створити feature branch
   - Внести зміни та вирішити конфлікти
   - Виконати merge через pull request
   - Використати rebase для актуалізації гілки

3. Командна робота:
   - Налаштувати GitLab/GitHub репозиторій
   - Створити README.md з описом проекту
   - Налаштувати захист основної гілки
   - Створити pull request template

### Git

- Основні команди
- Гілки та злиття
- Pull requests
- Git flow
- Робота з віддаленими репозиторіями

## Етап 2: Програмування та автоматизація (2-3 місяці)

#### Блок 4: Python

1. Базові скрипти:
   - Написати скрипт для парсингу логів
   - Створити утиліту для бекапу файлів
   - Розробити скрипт моніторингу системних ресурсів

2. Автоматизація:
   - Створити REST API для управління сервером
   - Написати скрипт для автоматичного деплою
   - Інтеграція з API хмарних сервісів

3. Обробка даних:
   - Парсинг JSON/YAML конфігурацій
   - Генерація звітів в різних форматах
   - Робота з базами даних

### Python

- Основи синтаксису
- Робота з файлами
- Бібліотеки для автоматизації
- REST API
- JSON/YAML парсинг

#### Блок 5: Infrastructure as Code

1. Terraform:
   - Створити базову інфраструктуру в AWS/GCP
   - Налаштувати мережеву інфраструктуру
   - Створити модулі для повторного використання
   - Використати remote state

2. Ansible:
   - Написати плейбуки для налаштування серверів
   - Використати ролі та шаблони
   - Налаштувати інвентар
   - Створити власну роль

### Infrastructure as Code

- Terraform: основи
- Ansible: базова конфігурація
- CloudFormation (якщо використовується AWS)

### SQL та Бази Даних

#### Основи SQL

1. Базові команди:

   ```sql
   -- DDL (Data Definition Language)
   CREATE DATABASE myapp;
   CREATE TABLE users (
       id SERIAL PRIMARY KEY,
       username VARCHAR(50) UNIQUE NOT NULL,
       created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   );
   ALTER TABLE users ADD COLUMN email VARCHAR(100);
   DROP TABLE users;

   -- DML (Data Manipulation Language)
   INSERT INTO users (username, email) VALUES ('john', 'john@example.com');
   SELECT * FROM users WHERE username LIKE 'j%';
   UPDATE users SET email = 'new@example.com' WHERE id = 1;
   DELETE FROM users WHERE id = 1;
   
   -- Joins
   SELECT orders.id, users.username
   FROM orders
   INNER JOIN users ON orders.user_id = users.id;
   
   -- Агрегація
   SELECT category, COUNT(*), AVG(price)
   FROM products
   GROUP BY category
   HAVING COUNT(*) > 5;
   ```

2. Практичні завдання:
   - Створити схему для e-commerce системи
   - Написати запити для аналізу даних
   - Оптимізувати повільні запити
   - Налаштувати індекси

#### Порівняння MySQL та PostgreSQL

1. Відмінності в синтаксисі:

   ```sql
   -- MySQL
   CREATE TABLE users (
       id INT AUTO_INCREMENT PRIMARY KEY,
       created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   );

   -- PostgreSQL
   CREATE TABLE users (
       id SERIAL PRIMARY KEY,
       created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   );
   ```

2. Ключові особливості:

   **MySQL**:
   - Простіша в налаштуванні та обслуговуванні
   - Менше споживання ресурсів
   - ACID тільки з InnoDB
   - Краща для простих READ-heavy додатків

   **PostgreSQL**:
   - Повна ACID відповідність
   - Розширена підтримка JSON
   - Потужні індекси (GiST, SP-GiST, GIN)
   - Матеріалізовані представлення
   - Наслідування таблиць
   - Краща для складних запитів та великих даних

3. Практичні кейси:

   **MySQL підходить для**:
   - Веб-додатків з простою схемою
   - Систем з високим навантаженням на читання
   - Проектів з обмеженими ресурсами

   **PostgreSQL підходить для**:
   - Складних аналітичних систем
   - Геопросторових додатків
   - Систем з складною логікою та валідацією

4. Завдання з адміністрування:
   - Налаштувати реплікацію
   - Створити бекап та відновлення
   - Налаштувати користувачів та права
   - Моніторинг продуктивності

## Етап 3: Контейнеризація та оркестрація (2-3 місяці)

#### Блок 6: Docker

1. Базова робота:
   - Створити Dockerfile для Python застосунку
   - Налаштувати multi-stage build
   - Оптимізувати розмір образу
   - Налаштувати Docker Registry

2. Docker Compose:
   - Створити композицію з кількох сервісів
   - Налаштувати мережеву взаємодію
   - Організувати персистентність даних
   - Налаштувати масштабування

### Docker

- Концепції контейнеризації
- Dockerfile
- Docker Compose
- Мережі в Docker
- Volumes та персистентність даних

#### Блок 7: Kubernetes

1. Базові об'єкти:
   - Розгорнути тестовий застосунок в Pod
   - Створити Deployment з кількома репліками
   - Налаштувати Service для доступу
   - Створити Ingress правила

2. Конфігурація:
   - Використати ConfigMaps та Secrets
   - Налаштувати Persistent Volumes
   - Створити власні namespace
   - Налаштувати квоти ресурсів

3. Управління:
   - Встановити Helm та створити чарт
   - Налаштувати автоматичне масштабування
   - Впровадити стратегії розгортання
   - Налаштувати моніторинг кластера

### Kubernetes

- Архітектура K8s
- Pod, Deployment, Service
- ConfigMaps та Secrets
- Helm
- Моніторинг кластера

## Етап 4: CI/CD та моніторинг (2-3 місяці)

#### Блок 8: CI/CD

1. Jenkins:
   - Налаштувати Jenkins сервер
   - Створити pipeline для збірки застосунку
   - Налаштувати автоматичні тести
   - Інтегрувати з Docker Registry

2. GitLab CI:
   - Налаштувати .gitlab-ci.yml
   - Створити multi-stage pipeline
   - Налаштувати автоматичний деплой
   - Використати артефакти та кеш

### CI/CD

- Jenkins/GitLab CI
- Побудова пайплайнів
- Автоматизація тестування
- Автоматичний деплой

#### Блок 9: Моніторинг

1. Prometheus + Grafana:
   - Встановити Prometheus
   - Налаштувати експортери
   - Створити дашборди в Grafana
   - Налаштувати алертинг

2. ELK Stack:
   - Налаштувати Elasticsearch
   - Сконфігурувати Logstash пайплайни
   - Створити Kibana візуалізації
   - Налаштувати ротацію логів

3. Трейсинг:
   - Встановити Jaeger
   - Налаштувати трейсинг в застосунку
   - Аналізувати перформанс
   - Оптимізувати затримки

### Моніторинг

- Prometheus
- Grafana
- ELK Stack
- Alerting

## Практичні проекти

1. **Базовий проект**
   - Налаштування Linux-серверу
   - Встановлення веб-серверу
   - Базове налаштування безпеки
   - Написання backup-скриптів

2. **Проект з автоматизації**
   - Створення CI/CD пайплайну
   - Автоматичне тестування
   - Деплой на staging/production

3. **Контейнерний проект**
   - Контейнеризація додатку
   - Налаштування Kubernetes кластера
   - Моніторинг та логування

## Рекомендовані ресурси

### Документація

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Documentation](https://docs.docker.com/)
- [Terraform Documentation](https://www.terraform.io/docs)

### Практика

- Linux Academy
- KodeKloud
- Катакода (інтерактивні туторіали)

### Сертифікації для розгляду

- Linux Foundation Certified System Administrator (LFCS)
- Certified Kubernetes Administrator (CKA)
- AWS Certified DevOps Engineer

## Методичні рекомендації

1. **Теорія + Практика**
   - 30% часу на теорію
   - 70% часу на практичні завдання
   - Створення власної лабораторії на локальній машині

2. **Підхід до навчання**
   - Концентрація на одній темі за раз
   - Практика після кожного теоретичного блоку
   - Ведення документації своїх дій
   - Створення власних шпаргалок та нотаток

3. **Важливі навички**
   - Автоматизація рутинних завдань
   - Розуміння безпеки на кожному рівні
   - Документування процесів
   - Вирішення проблем та troubleshooting

## Критерії успішності

1. **Базовий рівень**
   - Впевнена робота в Linux
   - Базове розуміння мереж
   - Написання простих скриптів

2. **Середній рівень**
   - Автоматизація типових завдань
   - Робота з контейнерами
   - Налаштування CI/CD

3. **Просунутий рівень**
   - Розгортання та управління кластером Kubernetes
   - Створення комплексних пайплайнів
   - Налаштування моніторингу та алертингу
