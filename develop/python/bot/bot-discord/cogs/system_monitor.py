import discord
from discord import app_commands
from discord.ext import commands
from utils.ssh import run_ssh_command, SSH_HOST
from utils.views import QuickActionsView


class SystemMonitor(commands.Cog):
    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @app_commands.command(name="memory", description="Check memory usage")
    async def memory(self, interaction: discord.Interaction):
        await interaction.response.defer()
        try:
            output = await run_ssh_command("free -mh")
            await interaction.followup.send(
                f"**Memory on {SSH_HOST}:**\n```\n{output}\n```",
                view=QuickActionsView("memory")
            )
        except Exception as e:
            await interaction.followup.send(f"Error: {e}")

    @app_commands.command(name="disk", description="Check disk usage")
    async def disk(self, interaction: discord.Interaction):
        await interaction.response.defer()
        try:
            output = await run_ssh_command("df -h")
            await interaction.followup.send(
                f"**Disk on {SSH_HOST}:**\n```\n{output}\n```",
                view=QuickActionsView("disk")
            )
        except Exception as e:
            await interaction.followup.send(f"Error: {e}")

    @app_commands.command(name="uptime", description="Check system uptime")
    async def uptime(self, interaction: discord.Interaction):
        await interaction.response.defer()
        try:
            output = await run_ssh_command("uptime")
            await interaction.followup.send(
                f"**Uptime on {SSH_HOST}:**\n```\n{output}\n```",
                view=QuickActionsView("uptime")
            )
        except Exception as e:
            await interaction.followup.send(f"Error: {e}")

    @app_commands.command(name="cpu", description="Check CPU usage")
    async def cpu(self, interaction: discord.Interaction):
        await interaction.response.defer()
        try:
            output = await run_ssh_command("top -bn1 | head -20")
            await interaction.followup.send(
                f"**CPU on {SSH_HOST}:**\n```\n{output}\n```",
                view=QuickActionsView("cpu")
            )
        except Exception as e:
            await interaction.followup.send(f"Error: {e}")


async def setup(bot: commands.Bot):
    await bot.add_cog(SystemMonitor(bot))
