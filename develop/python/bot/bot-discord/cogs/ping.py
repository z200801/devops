import discord
from discord import app_commands
from discord.ext import commands
from utils.ssh import SSH_HOST

# Import for multi-host support
try:
    from utils.hosts import run_ssh_command_on_host, get_default_host
    MULTI_HOST_MODE = True
except ImportError:
    MULTI_HOST_MODE = False
    from utils.ssh import run_ssh_command


class Ping(commands.Cog):
    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @app_commands.command(name="ping", description="Ping a host")
    @app_commands.describe(target="Target host to ping")
    async def ping(self, interaction: discord.Interaction, target: str):
        await interaction.response.defer()
        try:
            # Use asyncssh directly without check=True
            import asyncssh
            from utils.hosts import get_host_info, get_ssh_key, get_default_host
            
            host_id = get_default_host()
            host_info = get_host_info(host_id)
            ssh_key = get_ssh_key(host_id)
            
            async with asyncssh.connect(
                host_info["host"],
                username=host_info["user"],
                client_keys=[ssh_key],
                known_hosts=None
            ) as conn:
                result = await conn.run(f"ping -c 4 {target}", check=False)
                output = result.stdout + result.stderr
                
            await interaction.followup.send(f"**Ping to {target}:**\n```\n{output}\n```")
        except Exception as e:
            await interaction.followup.send(f"Error: {str(e)}")


async def setup(bot: commands.Bot):
    await bot.add_cog(Ping(bot))
