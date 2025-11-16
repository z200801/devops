import discord
from discord import app_commands
from discord.ext import commands
from utils.ssh import run_ssh_command, SSH_HOST
from utils.views import QuickActionsView

# Try to import hosts manager for multi-host support
try:
    from utils.hosts import get_host_list, get_host_display_name, run_ssh_command_on_host
    MULTI_HOST_MODE = True
except ImportError:
    MULTI_HOST_MODE = False


class MonitoringView(discord.ui.View):
    def __init__(self):
        super().__init__(timeout=None)

    @discord.ui.button(label="Memory", style=discord.ButtonStyle.primary, emoji="🧠", custom_id="btn_memory")
    async def memory_button(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer()
        try:
            output = await run_ssh_command("free -mh")
            await interaction.followup.send(
                f"**Memory on {SSH_HOST}:**\n```\n{output}\n```",
                view=QuickActionsView("memory", False)
            )
        except Exception as e:
            await interaction.followup.send(f"Error: {e}", ephemeral=True)

    @discord.ui.button(label="CPU", style=discord.ButtonStyle.primary, emoji="⚡", custom_id="btn_cpu")
    async def cpu_button(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer()
        try:
            output = await run_ssh_command("top -bn1 | head -20")
            await interaction.followup.send(
                f"**CPU on {SSH_HOST}:**\n```\n{output}\n```",
                view=QuickActionsView("cpu", False)
            )
        except Exception as e:
            await interaction.followup.send(f"Error: {e}", ephemeral=True)

    @discord.ui.button(label="Disk", style=discord.ButtonStyle.secondary, emoji="💾", custom_id="btn_disk")
    async def disk_button(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer()
        try:
            output = await run_ssh_command("df -h")
            await interaction.followup.send(
                f"**Disk on {SSH_HOST}:**\n```\n{output}\n```",
                view=QuickActionsView("disk", False)
            )
        except Exception as e:
            await interaction.followup.send(f"Error: {e}", ephemeral=True)

    @discord.ui.button(label="Uptime", style=discord.ButtonStyle.secondary, emoji="⏱️", custom_id="btn_uptime")
    async def uptime_button(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer()
        try:
            output = await run_ssh_command("uptime")
            await interaction.followup.send(
                f"**Uptime on {SSH_HOST}:**\n```\n{output}\n```",
                view=QuickActionsView("uptime", False)
            )
        except Exception as e:
            await interaction.followup.send(f"Error: {e}", ephemeral=True)

    @discord.ui.button(label="Containers", style=discord.ButtonStyle.success, emoji="🐳", custom_id="btn_containers")
    async def containers_button(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer()
        try:
            output = await run_ssh_command("docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'")
            await interaction.followup.send(
                f"**Containers on {SSH_HOST}:**\n```\n{output}\n```",
                view=QuickActionsView("containers", False)
            )
        except Exception as e:
            await interaction.followup.send(f"Error: {e}", ephemeral=True)


class Panel(commands.Cog):
    def __init__(self, bot: commands.Bot):
        self.bot = bot
        self.bot.add_view(MonitoringView())

    @app_commands.command(name="panel", description="Show monitoring panel with buttons")
    async def panel(self, interaction: discord.Interaction):
        embed = discord.Embed(
            title="🖥️ Server Monitoring Panel",
            description=f"Quick actions for **{SSH_HOST}**",
            color=discord.Color.blue()
        )
        await interaction.response.send_message(embed=embed, view=MonitoringView())


async def setup(bot: commands.Bot):
    await bot.add_cog(Panel(bot))
