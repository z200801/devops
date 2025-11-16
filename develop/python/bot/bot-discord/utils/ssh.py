import os
import base64
import asyncssh
from dotenv import load_dotenv

load_dotenv()

# Check if using new multi-host config or legacy single host
HOSTS_CONFIG_PATH = os.getenv("HOSTS_CONFIG_PATH", "")

if HOSTS_CONFIG_PATH and os.path.exists(HOSTS_CONFIG_PATH):
    # New multi-host mode
    from utils.hosts import get_default_host_address, run_ssh_command_on_host, get_default_host
    
    SSH_HOST = get_default_host_address()
    
    async def run_ssh_command(command: str, host: str = None, user: str = None) -> str:
        """Execute command on remote host via SSH."""
        if host is None:
            # Use default host from config
            host_id = get_default_host()
            return await run_ssh_command_on_host(host_id, command)
        else:
            # Legacy mode - direct host address (not recommended)
            return await run_ssh_command_on_host(host, command)
else:
    # Legacy single-host mode
    SSH_HOST = os.getenv("SSH_HOST", "localhost")
    SSH_USER = os.getenv("SSH_USER", "user")
    SSH_PRIVATE_KEY_B64 = os.getenv("SSH_PRIVATE_KEY", "")

    if SSH_PRIVATE_KEY_B64:
        _ssh_key_data = base64.b64decode(SSH_PRIVATE_KEY_B64).decode("utf-8")
        _ssh_key = asyncssh.import_private_key(_ssh_key_data)
    else:
        _ssh_key = None

    async def run_ssh_command(command: str, host: str = None, user: str = None) -> str:
        """Execute command on remote host via SSH."""
        host = host or SSH_HOST
        user = user or SSH_USER
        
        async with asyncssh.connect(
            host,
            username=user,
            client_keys=[_ssh_key],
            known_hosts=None
        ) as conn:
            result = await conn.run(command, check=True)
            return result.stdout
