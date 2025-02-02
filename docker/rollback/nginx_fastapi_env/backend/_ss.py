import socket
import psutil


def get_network_ips():
    return {
        interface: [addr.address for addr in addr_list if addr.family == 2]
        for interface, addr_list in psutil.net_if_addrs().items()
        if any(addr.family == 2 for addr in addr_list)
    }

def scan_ports(ip, start_port, end_port):
    open_ports = []
    for port in range(start_port, end_port + 1):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(1)
            if sock.connect_ex((ip, port)) == 0:
                open_ports.append(port)
    return open_ports


if __name__ == "__main__":
    start_port = 1
    end_port = 1024 

    local_ips = [ip for ips in get_network_ips().values() for ip in ips]
    for ip in local_ips:
        open_ports = scan_ports(ip, start_port, end_port)
        if open_ports:
            print(f"Open ports for {ip}: {open_ports}")
        else:
            print(f"No open ports on {ip} in range {start_port}-{end_port}")

