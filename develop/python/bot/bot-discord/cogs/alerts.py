import os
import discord
from discord import app_commands
from discord.ext import commands, tasks
from utils.ssh import run_ssh_command, SSH_HOST

# Try to import hosts manager for multi-host support
try:
    from utils.hosts import get_monitored_hosts, get_host_display_name, run_ssh_command_on_host, get_hosts_config
    MULTI_HOST_MODE = True
except ImportError:
    MULTI_HOST_MODE = False

ALERTS_CHANNEL_ID = int(os.getenv("ALERTS_CHANNEL_ID", "0"))

# Default thresholds from .env
DEFAULT_RAM_THRESHOLD = int(os.getenv("ALERT_RAM_THRESHOLD", "90"))
DEFAULT_DISK_THRESHOLD = int(os.getenv("ALERT_DISK_THRESHOLD", "85"))
DEFAULT_CPU_THRESHOLD = int(os.getenv("ALERT_CPU_THRESHOLD", "80"))
DEFAULT_CHECK_INTERVAL = int(os.getenv("ALERT_CHECK_INTERVAL", "5"))


def get_check_interval():
    """Get check interval from JSON config or .env default."""
    if MULTI_HOST_MODE:
        try:
            config = get_hosts_config()
            return config.get("check_interval", DEFAULT_CHECK_INTERVAL)
        except:
            pass
    return DEFAULT_CHECK_INTERVAL


def get_host_thresholds(host_id: str = None):
    """Get thresholds for host from JSON or use defaults from .env."""
    if MULTI_HOST_MODE and host_id:
        from utils.hosts import get_host_info
        host_info = get_host_info(host_id)
        if host_info:
            thresholds = host_info.get("thresholds", {})
            return {
                "ram": thresholds.get("ram", DEFAULT_RAM_THRESHOLD),
                "disk": thresholds.get("disk", DEFAULT_DISK_THRESHOLD),
                "cpu": thresholds.get("cpu", DEFAULT_CPU_THRESHOLD),
            }
    
    return {
        "ram": DEFAULT_RAM_THRESHOLD,
        "disk": DEFAULT_DISK_THRESHOLD,
        "cpu": DEFAULT_CPU_THRESHOLD,
    }


class Alerts(commands.Cog):
    def __init__(self, bot: commands.Bot):
        self.bot = bot
        check_interval = get_check_interval()
        self.check_system.change_interval(minutes=check_interval)
        self.check_system.start()

    def cog_unload(self):
        self.check_system.cancel()

    async def send_alert(self, level: str, title: str, message: str, host_name: str = None):
        """Send alert to alerts channel."""
        if not ALERTS_CHANNEL_ID:
            return
        
        channel = self.bot.get_channel(ALERTS_CHANNEL_ID)
        if not channel:
            return

        emoji_map = {
            "info": "🟢",
            "warning": "🟡",
            "critical": "🔴"
        }
        color_map = {
            "info": discord.Color.green(),
            "warning": discord.Color.yellow(),
            "critical": discord.Color.red()
        }

        emoji = emoji_map.get(level, "⚪")
        color = color_map.get(level, discord.Color.default())

        embed = discord.Embed(
            title=f"{emoji} {title}",
            description=message,
            color=color
        )
        
        if host_name:
            embed.add_field(name="Host", value=host_name, inline=True)
        else:
            embed.add_field(name="Host", value=SSH_HOST, inline=True)
        
        embed.add_field(name="Severity", value=level.upper(), inline=True)
        embed.set_footer(text="DevOps Bot Alert System")

        await channel.send(embed=embed)

    async def check_single_host(self, host_id: str = None, host_name: str = None):
        """Check a single host for alerts."""
        try:
            # Get thresholds for this host
            thresholds = get_host_thresholds(host_id)
            ram_threshold = thresholds["ram"]
            disk_threshold = thresholds["disk"]
            cpu_threshold = thresholds["cpu"]

            # Determine which SSH function to use
            if MULTI_HOST_MODE and host_id:
                ssh_cmd = lambda cmd: run_ssh_command_on_host(host_id, cmd)
                display_name = host_name or get_host_display_name(host_id)
            else:
                ssh_cmd = run_ssh_command
                display_name = SSH_HOST

            # Check RAM
            ram_output = await ssh_cmd("free | grep Mem | awk '{print $3/$2 * 100}'")
            ram_usage = float(ram_output.strip())
            if ram_usage > ram_threshold:
                await self.send_alert(
                    "critical" if ram_usage > 95 else "warning",
                    "High RAM Usage",
                    f"RAM usage is at **{ram_usage:.1f}%** (threshold: {ram_threshold}%)",
                    display_name
                )

            # Check Disk
            disk_output = await ssh_cmd("df / | tail -1 | awk '{print $5}' | sed 's/%//'")
            disk_usage = float(disk_output.strip())
            if disk_usage > disk_threshold:
                await self.send_alert(
                    "critical" if disk_usage > 95 else "warning",
                    "High Disk Usage",
                    f"Disk usage is at **{disk_usage:.1f}%** (threshold: {disk_threshold}%)",
                    display_name
                )

            # Check CPU (1min load average vs cores)
            cpu_output = await ssh_cmd("nproc && cat /proc/loadavg | awk '{print $1}'")
            lines = cpu_output.strip().split('\n')
            cores = int(lines[0])
            load = float(lines[1])
            cpu_percent = (load / cores) * 100
            if cpu_percent > cpu_threshold:
                await self.send_alert(
                    "critical" if cpu_percent > 95 else "warning",
                    "High CPU Load",
                    f"CPU load is at **{cpu_percent:.1f}%** (threshold: {cpu_threshold}%)",
                    display_name
                )

        except Exception as e:
            await self.send_alert(
                "critical", 
                "Monitoring Error", 
                f"Failed to check system: {str(e)}",
                display_name if 'display_name' in locals() else None
            )

    @tasks.loop(minutes=1)  # Default, will be changed in __init__
    async def check_system(self):
        """Periodic system health check."""
        if MULTI_HOST_MODE:
            # Check all monitored hosts
            monitored_hosts = get_monitored_hosts()
            for host_id in monitored_hosts:
                await self.check_single_host(host_id)
        else:
            # Legacy single-host mode
            await self.check_single_host()

    @check_system.before_loop
    async def before_check(self):
        await self.bot.wait_until_ready()

    @app_commands.command(name="alerts-test", description="Send test alert")
    async def alerts_test(self, interaction: discord.Interaction):
        await interaction.response.defer()
        await self.send_alert("info", "Test Alert", "This is a test alert from DevOps Bot")
        await interaction.followup.send("✅ Test alert sent to alerts channel")

    @app_commands.command(name="alerts-check", description="Run system check now")
    async def alerts_check(self, interaction: discord.Interaction):
        await interaction.response.defer()
        await self.check_system()
        await interaction.followup.send("✅ System check completed")


async def setup(bot: commands.Bot):
    await bot.add_cog(Alerts(bot))
