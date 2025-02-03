# Мережі

## TCP/IP протокол

### OSI модель
1. Physical Layer
2. Data Link Layer
3. Network Layer (IP)
4. Transport Layer (TCP/UDP)
5. Session Layer
6. Presentation Layer
7. Application Layer (HTTP, FTP, SSH)

### IP адресація
```bash
# Перевірка IP адреси
ip addr show
ifconfig

# Налаштування IP
sudo ip addr add 192.168.1.10/24 dev eth0
sudo ip route add default via 192.168.1.1

# Перевірка з'єднання
ping 8.8.8.8
traceroute google.com
```

## DNS

### Конфігурація
```bash
# /etc/hosts
127.0.0.1 localhost
192.168.1.10 myserver.local

# /etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
```

### DNS утиліти
```bash
# Перевірка DNS
nslookup google.com
dig google.com
host google.com

# DNS зони
dig @8.8.8.8 google.com ANY
```

## HTTP/HTTPS

### Веб-сервер Nginx
```nginx
# /etc/nginx/sites-available/default
server {
    listen 80;
    server_name example.com;
    
    location / {
        proxy_pass http://localhost:3000;
    }
}
```

### SSL/TLS
```bash
# Генерація сертифікату
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout private.key -out certificate.crt

# Let's Encrypt
certbot --nginx -d example.com
```

## SSH

### Конфігурація
```bash
# Генерація ключів
ssh-keygen -t rsa -b 4096

# SSH конфіг
# ~/.ssh/config
Host myserver
    HostName 192.168.1.10
    User admin
    IdentityFile ~/.ssh/id_rsa
```

### SSH команди
```bash
# Копіювання ключа
ssh-copy-id user@remote

# Тунелювання
ssh -L 8080:localhost:80 user@remote

# SCP
scp file.txt user@remote:/path/
```

## Мережева безпека

### Firewall (iptables)
```bash
# Базові правила
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -P INPUT DROP

# UFW
ufw allow 22/tcp
ufw enable
```

### Моніторинг мережі
```bash
# Аналіз трафіку
tcpdump -i eth0
wireshark

# Сканування портів
nmap -sS 192.168.1.0/24
netstat -tulpn
```

## Практичні завдання

### 1. Базове налаштування
- Налаштувати статичний IP
- Налаштувати DNS
- Встановити та налаштувати SSH

### 2. Веб-сервер
- Встановити Nginx
- Налаштувати SSL
- Налаштувати reverse proxy

### 3. Безпека
- Налаштувати firewall
- Налаштувати SSH ключі
- Моніторинг мережі