# docker

# docker-compose

# docker-compose-scale

# docker-compose-nginx

# nginx

# Docker compose scale nginx + backend python

# Run

```sh
docker compose down && docker compose up 
```

# Monitoring network

```sh
docker run -it --rm --name netshoot --net container:nginx-backend-1 nicolaka/netshoot
```

# Get sockets

```pyhon
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(1)
result = s.connect_ex(("localhost", 80))
print("Open" if result == 0 else "Closed")
```

```python
import socket

def get_local_ips():
    local_ips = []
    hostname = socket.gethostname()
    try:
        local_ips.append(socket.gethostbyname(hostname))
    except socket.gaierror:
        pass

    # Додатково отримуємо всі IP-адреси, пов'язані з локальними інтерфейсами
    for iface in socket.if_nameindex():
        try:
            ip = socket.getaddrinfo(iface[1], None, socket.AF_INET)[0][4][0]
            if ip not in local_ips:
                local_ips.append(ip)
        except socket.gaierror:
            pass

    return local_ips

def scan_ports(ip, start_port, end_port):
    open_ports = []
    for port in range(start_port, end_port + 1):
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(1)
        result = sock.connect_ex((ip, port))
        if result == 0:
            open_ports.append(port)
        sock.close()
    return open_ports

if __name__ == "__main__":
    start_port = 1
    end_port = 1024  # Скануємо порти від 1 до 1024

    local_ips = get_local_ips()
    for ip in local_ips:
        open_ports = scan_ports(ip, start_port, end_port)
        if open_ports:
            print(f"Відкриті порти на {ip}: {open_ports}")
        else:
            print(f"Немає відкритих портів на {ip} у діапазоні {start_port}-{end_port}")
```
