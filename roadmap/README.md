# DevOps Engineer: План початкового навчання

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
- Текстові редактори (`vim`/`nvim`)
- Bash скриптинг

#### Блок 2: Мережі

1. Базова конфігурація:
   - Налаштувати статичну IP-адресу
   - Налаштувати DNS-сервер
   - Встановити та налаштувати SSH-сервер
   - Налаштувати фаєрвол (iptables/ufw)

2. Моніторинг мережі:
   - Використання `tcpdump` для аналізу трафіку
   - Налаштування `wireshark`
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

4. Базове налаштування:

   ```bash
   # Встановлення Vagrant
   sudo apt install vagrant
   
   # Встановлення провайдерів
   sudo apt install virtualbox
   sudo apt install qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils
   
   # Встановлення плагіна для libvirt
   vagrant plugin install vagrant-libvirt
   ```

5. Практичні завдання з VirtualBox:

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

6. Практичні завдання з Libvirt:

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

7. Multi-machine оточення:

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

8. Ansible provisioning:

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

9. Додаткові завдання:
   - Налаштувати спільні папки (synced folders)
   - Створити власний базовий образ (box)
   - Налаштувати автоматичний старт сервісів
   - Інтегрувати з Docker

10. Проектне завдання:
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

11. Базові операції:

- Створити локальний репозиторій
- Додати файли до staging area
- Створити комміти з різними типами змін
- Налаштувати .gitignore

12. Робота з гілками:

- Створити feature branch
- Внести зміни та вирішити конфлікти
- Виконати merge через pull request
- Використати rebase для актуалізації гілки

13. Командна робота:

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

14. Базові скрипти:

- Написати скрипт для парсингу логів
- Створити утиліту для бекапу файлів
- Розробити скрипт моніторингу системних ресурсів

15. Автоматизація:

- Створити REST API для управління сервером
- Написати скрипт для автоматичного деплою
- Інтеграція з API хмарних сервісів

16. Обробка даних:

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

17. Terraform:

- Створити базову інфраструктуру в AWS/GCP
- Налаштувати мережеву інфраструктуру
- Створити модулі для повторного використання
- Використати remote state

18. Ansible:

- Написати плейбуки для налаштування серверів
- Використати ролі та шаблони
- Налаштувати інвентар
- Створити власну роль

### Infrastructure as Code

- Terraform: основи
- Ansible: базова конфігурація
- CloudFormation (якщо використовується AWS)

## Етап 3: Контейнеризація та оркестрація (2-3 місяці)

#### Блок 6: Docker

19. Базова робота:

- Створити Dockerfile для Python застосунку
- Налаштувати multi-stage build
- Оптимізувати розмір образу
- Налаштувати Docker Registry

20. Docker Compose:

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

21. Базові об'єкти:

- Розгорнути тестовий застосунок в Pod
- Створити Deployment з кількома репліками
- Налаштувати Service для доступу
- Створити Ingress правила

22. Конфігурація:

- Використати ConfigMaps та Secrets
- Налаштувати Persistent Volumes
- Створити власні namespace
- Налаштувати квоти ресурсів

23. Управління:

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

24. Jenkins:

- Налаштувати Jenkins сервер
- Створити pipeline для збірки застосунку
- Налаштувати автоматичні тести
- Інтегрувати з Docker Registry

25. GitLab CI:

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

26. Prometheus + Grafana:

- Встановити Prometheus
- Налаштувати експортери
- Створити дашборди в Grafana
- Налаштувати алертинг

27. ELK Stack:

- Налаштувати Elasticsearch
- Сконфігурувати Logstash пайплайни
- Створити Kibana візуалізації
- Налаштувати ротацію логів

28. Трейсинг:

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

29. **Базовий проект**

- Налаштування Linux-серверу
- Встановлення веб-серверу
- Базове налаштування безпеки
- Написання backup-скриптів

30. **Проект з автоматизації**

- Створення CI/CD пайплайну
- Автоматичне тестування
- Деплой на staging/production

31. **Контейнерний проект**

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

32. **Теорія + Практика**

- 30% часу на теорію
- 70% часу на практичні завдання
- Створення власної лабораторії на локальній машині

33. **Підхід до навчання**

- Концентрація на одній темі за раз
- Практика після кожного теоретичного блоку
- Ведення документації своїх дій
- Створення власних шпаргалок та нотаток

34. **Важливі навички**

- Автоматизація рутинних завдань
- Розуміння безпеки на кожному рівні
- Документування процесів
- Вирішення проблем та troubleshooting

## Критерії успішності

35. **Базовий рівень**

- Впевнена робота в Linux
- Базове розуміння мереж
- Написання простих скриптів

36. **Середній рівень**

- Автоматизація типових завдань
- Робота з контейнерами
- Налаштування CI/CD

37. **Просунутий рівень**

- Розгортання та управління кластером Kubernetes
- Створення комплексних пайплайнів
- Налаштування моніторингу та алертингу
