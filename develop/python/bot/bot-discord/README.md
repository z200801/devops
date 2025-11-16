# Discord DevOps Bot

Discord bot for monitoring servers and infrastructure via SSH. Supports multiple hosts, customizable alerts, and mobile-friendly output.

## Features

- **Multi-host monitoring** — monitor multiple servers from single bot
- **System metrics** — RAM, CPU, Disk, Uptime
- **Docker monitoring** — containers status, stats, logs
- **Alerts system** — automatic threshold-based alerts with Discord notifications
- **Mobile-friendly** — compact output mode for mobile devices
- **Modular architecture** — easy to extend with new commands (Cogs)
- **Security hardening** — non-root user, dropped capabilities, read-only filesystem

## Quick Start

### 1. Create Discord Bot

1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Create New Application
3. Go to Bot section → Reset Token → copy token
4. Enable "Message Content Intent" if needed
5. Go to OAuth2 → URL Generator
   - Scopes: `bot`, `applications.commands`
   - Bot Permissions: `Send Messages`
6. Open generated URL → authorize bot to your server

### 2. Configure Environment

Copy example files:
```bash
cp .env.example .env
cp hosts.example.json hosts.json
```

Edit `.env`:
```env
DISCORD_TOKEN=your_bot_token_here
HOSTS_CONFIG_PATH=hosts.json
ALERTS_CHANNEL_ID=your_alerts_channel_id

# Default thresholds (used if not specified in hosts.json)
ALERT_RAM_THRESHOLD=90
ALERT_DISK_THRESHOLD=85
ALERT_CPU_THRESHOLD=80
ALERT_CHECK_INTERVAL=5
```

Edit `hosts.json`:
```json
{
  "check_interval": 5,
  "hosts": {
    "server1": {
      "name": "Production Server",
      "host": "192.168.1.10",
      "user": "ubuntu",
      "ssh_key_base64": "BASE64_ENCODED_PRIVATE_KEY",
      "monitor": true,
      "thresholds": {
        "ram": 85,
        "disk": 90,
        "cpu": 75
      }
    },
    "server2": {
      "name": "Dev Server",
      "host": "192.168.1.11",
      "user": "dev",
      "ssh_key_base64": "BASE64_ENCODED_PRIVATE_KEY",
      "monitor": false
    }
  },
  "default": "server1"
}
```

Generate base64 SSH key:
```bash
base64 -w 0 ~/.ssh/id_rsa
```

### 3. Deploy

```bash
docker compose up -d --build
```

Check logs:
```bash
docker compose logs -f
```

## Commands

### System Monitoring
- `/memory` — RAM usage
- `/cpu` — CPU load and top processes
- `/disk` — Disk usage
- `/uptime` — System uptime

### Docker Monitoring
- `/containers` — List running containers
- `/docker-stats` — Container resource usage
- `/docker-logs <container>` — Last 20 lines of container logs

### Control Panel
- `/panel` — Interactive panel with quick action buttons

### Alerts
- `/alerts-test` — Send test alert to alerts channel
- `/alerts-check` — Run manual system check

## UI Features

### Quick Action Buttons
After each command output, buttons appear for:
- 🔄 Refresh current command
- 📱 Toggle compact/full mode
- 🖥️ Select different host(s)
- 🧠⚡💾⏱️🐳 Quick access to other metrics

### Multi-host Selection
Click 🖥️ button to:
- Select single host
- Select multiple hosts
- Select all hosts at once

Results appear as separate messages for each host.

### Compact Mode
Toggle 📱 for mobile-friendly output:
```
🧠 Memory
━━━━━━━━━━
Total: 4.0Gi
Used: 1.3Gi (32%)
Avail: 2.7Gi
```

## Alerts Configuration

### Global Settings (hosts.json)
```json
{
  "check_interval": 5
}
```

### Per-host Thresholds (hosts.json)
```json
{
  "thresholds": {
    "ram": 85,
    "disk": 90,
    "cpu": 75
  }
}
```

If thresholds not specified for host, uses defaults from `.env`.

### Alert Levels
- 🟢 **INFO** — Test alerts
- 🟡 **WARNING** — Threshold exceeded (< 95%)
- 🔴 **CRITICAL** — Threshold exceeded (> 95%)

## Project Structure

```
discord-bot/
├── bot.py                    # Main bot entry point
├── docker-compose.yml        # Docker Compose configuration
├── Dockerfile                # Multi-stage build
├── requirements.txt          # Python dependencies
├── .env                      # Environment variables
├── hosts.json                # Hosts configuration
├── cogs/                     # Bot modules (auto-loaded)
│   ├── alerts.py            # Alerts system
│   ├── docker_monitor.py    # Docker commands
│   ├── panel.py             # Interactive panel
│   └── system_monitor.py    # System metrics commands
└── utils/                    # Shared utilities
    ├── hosts.py             # Multi-host manager
    ├── ssh.py               # SSH connection handler
    └── views.py             # Discord UI components
```

## Adding New Commands

Create new file in `cogs/`:

```python
import discord
from discord import app_commands
from discord.ext import commands
from utils.ssh import run_ssh_command, SSH_HOST
from utils.views import QuickActionsView


class MyModule(commands.Cog):
    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @app_commands.command(name="mycommand", description="My custom command")
    async def mycommand(self, interaction: discord.Interaction):
        await interaction.response.defer()
        try:
            output = await run_ssh_command("your-command-here")
            await interaction.followup.send(
                f"**Result:**\n```\n{output}\n```",
                view=QuickActionsView("mycommand", False)
            )
        except Exception as e:
            await interaction.followup.send(f"Error: {e}")


async def setup(bot: commands.Bot):
    await bot.add_cog(MyModule(bot))
```

Bot automatically loads all `.py` files in `cogs/` directory on startup.

## Security Features

### Docker Security
- **Non-root user** — runs as `appuser`
- **Dropped capabilities** — `cap_drop: ALL`
- **No privilege escalation** — `no-new-privileges: true`
- **Read-only filesystem** — only `/tmp` writable
- **Resource limits** — CPU and memory constraints

### SSH Security
- **Key-based authentication** — no passwords
- **Base64 encoded keys** — stored in JSON config
- **Per-host credentials** — different keys per server

## Troubleshooting

### Bot not responding
```bash
docker compose logs --tail 50
```

### Commands not syncing
Restart Discord client (Ctrl+R) after bot restart.

### SSH connection failed
- Check SSH key is correctly base64 encoded
- Verify public key is in `~/.ssh/authorized_keys` on target host
- Ensure network connectivity between bot container and target hosts

### Alerts not working
- Verify `ALERTS_CHANNEL_ID` is correct
- Check bot has permission to send messages in alerts channel
- Ensure at least one host has `"monitor": true`

## Requirements

- Docker & Docker Compose
- Python 3.11+ (in container)
- Discord Bot Token
- SSH access to target servers

## Dependencies

- discord.py 2.3.2
- asyncssh 2.14.2
- python-dotenv 1.0.1

## License

MIT
