import discord
from discord import app_commands
from discord.ext import commands
from utils.ssh import run_ssh_command, SSH_HOST
from utils.views import QuickActionsView


class DockerMonitor(commands.Cog):
    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @app_commands.command(name="containers", description="List running containers")
    async def containers(self, interaction: discord.Interaction):
        await interaction.response.defer()
        try:
            output = await run_ssh_command("docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'")
            await interaction.followup.send(
                f"**Containers on {SSH_HOST}:**\n```\n{output}\n```",
                view=QuickActionsView("containers")
            )
        except Exception as e:
            await interaction.followup.send(f"Error: {e}")

    @app_commands.command(name="docker-stats", description="Container resource usage")
    async def docker_stats(self, interaction: discord.Interaction):
        await interaction.response.defer()
        try:
            output = await run_ssh_command("docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}'")
            await interaction.followup.send(
                f"**Docker stats on {SSH_HOST}:**\n```\n{output}\n```",
                view=QuickActionsView("containers")
            )
        except Exception as e:
            await interaction.followup.send(f"Error: {e}")

    @app_commands.command(name="docker-logs", description="Container logs (last 20 lines)")
    @app_commands.describe(container="Container name")
    async def docker_logs(self, interaction: discord.Interaction, container: str):
        await interaction.response.defer()
        try:
            output = await run_ssh_command(f"docker logs --tail 20 {container}")
            if len(output) > 1900:
                output = output[-1900:]
            await interaction.followup.send(
                f"**Logs for {container}:**\n```\n{output}\n```",
                view=QuickActionsView("containers")
            )
        except Exception as e:
            await interaction.followup.send(f"Error: {e}")


async def setup(bot: commands.Bot):
    await bot.add_cog(DockerMonitor(bot))
