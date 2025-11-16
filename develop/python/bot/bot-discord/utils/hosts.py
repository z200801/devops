import os
import json
import base64
import asyncssh
from dotenv import load_dotenv

load_dotenv()

HOSTS_CONFIG_PATH = os.getenv("HOSTS_CONFIG_PATH", "hosts.json")

_hosts_config = None
_ssh_keys = {}


def load_hosts_config():
    """Load hosts configuration from JSON file."""
    global _hosts_config, _ssh_keys
    
    if not os.path.exists(HOSTS_CONFIG_PATH):
        raise FileNotFoundError(f"Hosts config not found: {HOSTS_CONFIG_PATH}")
    
    with open(HOSTS_CONFIG_PATH, 'r') as f:
        _hosts_config = json.load(f)
    
    # Pre-load SSH keys
    for host_id, host_data in _hosts_config.get("hosts", {}).items():
        key_b64 = host_data.get("ssh_key_base64", "")
        if key_b64:
            key_data = base64.b64decode(key_b64).decode("utf-8")
            _ssh_keys[host_id] = asyncssh.import_private_key(key_data)
    
    return _hosts_config


def get_hosts_config():
    """Get hosts configuration, loading if necessary."""
    global _hosts_config
    if _hosts_config is None:
        load_hosts_config()
    return _hosts_config


def get_host_list():
    """Get list of host IDs."""
    config = get_hosts_config()
    return list(config.get("hosts", {}).keys())


def get_host_info(host_id: str):
    """Get host information by ID."""
    config = get_hosts_config()
    return config.get("hosts", {}).get(host_id)


def get_default_host():
    """Get default host ID."""
    config = get_hosts_config()
    return config.get("default", list(config.get("hosts", {}).keys())[0])


def get_host_display_name(host_id: str):
    """Get human-readable host name."""
    info = get_host_info(host_id)
    if info:
        return info.get("name", host_id)
    return host_id


def get_monitored_hosts():
    """Get list of host IDs where monitor=true."""
    config = get_hosts_config()
    monitored = []
    for host_id, host_data in config.get("hosts", {}).items():
        if host_data.get("monitor", False):
            monitored.append(host_id)
    return monitored


def get_ssh_key(host_id: str):
    """Get pre-loaded SSH key for host."""
    if host_id not in _ssh_keys:
        # Try to load if not cached
        get_hosts_config()
    return _ssh_keys.get(host_id)


async def run_ssh_command_on_host(host_id: str, command: str) -> str:
    """Execute command on specified host via SSH."""
    host_info = get_host_info(host_id)
    if not host_info:
        raise ValueError(f"Unknown host: {host_id}")
    
    ssh_key = get_ssh_key(host_id)
    if not ssh_key:
        raise ValueError(f"No SSH key for host: {host_id}")
    
    async with asyncssh.connect(
        host_info["host"],
        username=host_info["user"],
        client_keys=[ssh_key],
        known_hosts=None
    ) as conn:
        result = await conn.run(command, check=True)
        return result.stdout


# Legacy compatibility - use default host
def get_default_host_address():
    """Get default host address for legacy compatibility."""
    host_id = get_default_host()
    info = get_host_info(host_id)
    return info["host"] if info else "localhost"
