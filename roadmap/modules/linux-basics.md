# Linux та Командний Рядок

## Основи Linux

### Встановлення та налаштування
1. Встановлення Ubuntu/CentOS
2. Налаштування мережі
3. Базова конфігурація системи

### Базові команди
```bash
# Навігація
pwd               # поточна директорія
ls -la           # список файлів
cd /path         # зміна директорії
tree            # дерево директорій

# Робота з файлами
touch file.txt   # створити файл
cp file1 file2   # копіювати
mv file1 file2   # перемістити/перейменувати
rm file         # видалити
rm -rf dir      # видалити директорію

# Перегляд файлів
cat file        # весь файл
less file       # посторінково
head -n 10 file # перші 10 рядків
tail -f file    # останні рядки з оновленням

# Пошук
find / -name "file"  # пошук файлу
grep "text" file     # пошук тексту
```

### Права доступу
```bash
# Зміна прав
chmod 755 file     # rwxr-xr-x
chmod u+x file     # додати виконання
chown user file    # зміна власника
chgrp group file   # зміна групи

# Маски прав
4 - read (r)
2 - write (w)
1 - execute (x)
```

### Процеси
```bash
ps aux           # список процесів
top             # моніторинг процесів
kill -9 PID     # завершити процес
systemctl start/stop/restart service
```

## Bash Скриптинг

### Базовий синтаксис
```bash
#!/bin/bash

# Змінні
NAME="John"
echo "Hello, $NAME"

# Умови
if [ "$1" == "test" ]; then
    echo "Test mode"
else
    echo "Production mode"
fi

# Цикли
for i in {1..5}; do
    echo $i
done

# Функції
function backup() {
    tar -czf backup.tar.gz /path/to/files
}
```

### Практичний приклад
```bash
#!/bin/bash

# Скрипт моніторингу системи
LOG_FILE="/var/log/system_monitor.log"

function check_disk() {
    df -h | grep '/dev/sda1'
}

function check_memory() {
    free -m
}

function check_cpu() {
    top -bn1 | grep "Cpu(s)"
}

# Основний моніторинг
echo "=== System Status $(date) ===" >> $LOG_FILE
check_disk >> $LOG_FILE
check_memory >> $LOG_FILE
check_cpu >> $LOG_FILE
```

## Практичні завдання

### 1. Файлова система
- Створити структуру директорій для веб-проекту
- Налаштувати права доступу
- Створити скрипт для бекапу

### 2. Процеси та сервіси
- Налаштувати автозапуск сервісу
- Створити systemd unit
- Моніторинг процесів

### 3. Логи та моніторинг
- Налаштувати logrotate
- Аналіз логів з grep/awk/sed
- Автоматизація звітів

### 4. Мережа
- Налаштування SSH
- Базовий firewall
- Моніторинг портів