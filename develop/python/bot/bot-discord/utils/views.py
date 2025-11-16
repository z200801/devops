import discord
from utils.ssh import run_ssh_command, SSH_HOST

# Try to import hosts manager for multi-host support
try:
    from utils.hosts import get_host_list, get_host_display_name, run_ssh_command_on_host, get_default_host
    MULTI_HOST_MODE = True
except ImportError:
    MULTI_HOST_MODE = False


def format_memory_compact(output: str) -> str:
    """Format memory output for mobile."""
    lines = output.strip().split('\n')
    if len(lines) < 2:
        return output
    
    parts = lines[1].split()
    if len(parts) < 7:
        return output
    
    total = parts[1]
    used = parts[2]
    available = parts[6]
    
    try:
        total_val = float(total.replace('Gi', '').replace('Mi', ''))
        used_val = float(used.replace('Gi', '').replace('Mi', ''))
        pct = (used_val / total_val) * 100
    except:
        pct = 0
    
    return f"""🧠 **Memory**
━━━━━━━━━━
Total: {total}
Used: {used} ({pct:.0f}%)
Avail: {available}"""


def format_disk_compact(output: str) -> str:
    """Format disk output for mobile."""
    lines = output.strip().split('\n')
    result = "💾 **Disk Usage**\n━━━━━━━━━━\n"
    
    for line in lines[1:]:
        parts = line.split()
        if len(parts) >= 6:
            mount = parts[5]
            size = parts[1]
            used_pct = parts[4]
            if mount in ['/', '/home', '/var']:
                result += f"{mount}: {used_pct} of {size}\n"
    
    return result.strip()


def format_cpu_compact(output: str) -> str:
    """Format CPU output for mobile."""
    lines = output.strip().split('\n')
    result = "⚡ **CPU Status**\n━━━━━━━━━━\n"
    
    for line in lines:
        if 'load average' in line:
            parts = line.split('load average:')
            if len(parts) > 1:
                loads = parts[1].strip().split(',')
                result += f"Load 1m: {loads[0].strip()}\n"
                if len(loads) > 1:
                    result += f"Load 5m: {loads[1].strip()}\n"
        elif '%Cpu' in line or 'Cpu(s)' in line:
            if 'id' in line:
                parts = line.split(',')
                for part in parts:
                    if 'id' in part:
                        idle = part.strip().split()[0]
                        used = 100 - float(idle)
                        result += f"Usage: {used:.1f}%\n"
                        break
    
    return result.strip() if result.count('\n') > 1 else output


def format_uptime_compact(output: str) -> str:
    """Format uptime output for mobile."""
    line = output.strip()
    result = "⏱️ **Uptime**\n━━━━━━━━━━\n"
    
    if 'up' in line:
        parts = line.split('up')
        if len(parts) > 1:
            uptime_part = parts[1].split(',')[0].strip()
            result += f"Up: {uptime_part}\n"
    
    if 'user' in line:
        for part in line.split(','):
            if 'user' in part:
                result += f"Users: {part.strip()}\n"
                break
    
    if 'load average' in line:
        loads = line.split('load average:')[1].strip()
        result += f"Load: {loads}"
    
    return result.strip()


def format_containers_compact(output: str) -> str:
    """Format containers output for mobile."""
    lines = output.strip().split('\n')
    result = "🐳 **Containers**\n━━━━━━━━━━\n"
    
    if len(lines) <= 1:
        result += "No containers"
        return result
    
    for line in lines[1:]:
        parts = line.split()
        if len(parts) >= 2:
            name = parts[0][:15]
            status = "Unknown"
            for part in parts:
                if part in ["Up", "Exited", "Created", "Restarting"]:
                    status = part
                    break
            result += f"{name}: {status}\n"
    
    return result.strip()


class HostSelectView(discord.ui.View):
    """View with host selection dropdown."""
    
    def __init__(self, command_type: str, compact: bool = False):
        super().__init__(timeout=300)
        self.command_type = command_type
        self.compact = compact
        
        if MULTI_HOST_MODE:
            self.add_item(HostSelect(command_type, compact))


class HostSelect(discord.ui.Select):
    """Dropdown for selecting hosts."""
    
    def __init__(self, command_type: str, compact: bool = False):
        self.command_type = command_type
        self.compact = compact
        
        options = []
        if MULTI_HOST_MODE:
            host_list = get_host_list()
            for host_id in host_list:
                display_name = get_host_display_name(host_id)
                options.append(discord.SelectOption(label=display_name, value=host_id))
            
            if len(host_list) > 1:
                options.append(discord.SelectOption(label="All Hosts", value="__all__", emoji="📊"))
        
        super().__init__(
            placeholder="Select host(s)...",
            min_values=1,
            max_values=len(options),
            options=options
        )
    
    def format_output(self, cmd_type: str, output: str) -> str:
        if not self.compact:
            return f"```\n{output}\n```"
        
        formatters = {
            "memory": format_memory_compact,
            "cpu": format_cpu_compact,
            "disk": format_disk_compact,
            "uptime": format_uptime_compact,
            "containers": format_containers_compact,
        }
        
        formatter = formatters.get(cmd_type)
        if formatter:
            return formatter(output)
        return f"```\n{output}\n```"
    
    async def callback(self, interaction: discord.Interaction):
        await interaction.response.defer()
        
        commands_map = {
            "memory": ("free -mh", "Memory"),
            "cpu": ("top -bn1 | head -20", "CPU"),
            "disk": ("df -h", "Disk"),
            "uptime": ("uptime", "Uptime"),
            "containers": ("docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'", "Containers"),
        }
        
        if self.command_type not in commands_map:
            await interaction.followup.send("Unknown command", ephemeral=True)
            return
        
        cmd, label = commands_map[self.command_type]
        
        selected_hosts = self.values
        if "__all__" in selected_hosts:
            selected_hosts = get_host_list()
        
        for host_id in selected_hosts:
            try:
                output = await run_ssh_command_on_host(host_id, cmd)
                display_name = get_host_display_name(host_id)
                formatted = self.format_output(self.command_type, output)
                
                await interaction.followup.send(
                    f"**{label} on {display_name}:**\n{formatted}",
                    view=QuickActionsView(self.command_type, self.compact)
                )
            except Exception as e:
                display_name = get_host_display_name(host_id)
                await interaction.followup.send(f"❌ **{display_name}:** {str(e)}")


class QuickActionsView(discord.ui.View):
    def __init__(self, current_command: str = None, compact: bool = False):
        super().__init__(timeout=300)
        self.current_command = current_command
        self.compact = compact

    def format_output(self, cmd_type: str, output: str) -> str:
        if not self.compact:
            return f"```\n{output}\n```"
        
        formatters = {
            "memory": format_memory_compact,
            "cpu": format_cpu_compact,
            "disk": format_disk_compact,
            "uptime": format_uptime_compact,
            "containers": format_containers_compact,
        }
        
        formatter = formatters.get(cmd_type)
        if formatter:
            return formatter(output)
        return f"```\n{output}\n```"

    @discord.ui.button(label="📱", style=discord.ButtonStyle.secondary, custom_id="toggle_compact", row=0)
    async def toggle_compact(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer()
        new_compact = not self.compact
        mode = "📱 Compact" if new_compact else "🖥️ Full"
        await interaction.followup.send(
            f"Display mode: **{mode}**",
            view=QuickActionsView(self.current_command, new_compact),
            ephemeral=True
        )

    @discord.ui.button(label="🖥️", style=discord.ButtonStyle.secondary, custom_id="select_hosts", row=0)
    async def select_hosts(self, interaction: discord.Interaction, button: discord.ui.Button):
        if not MULTI_HOST_MODE:
            await interaction.response.send_message("Multi-host mode not enabled", ephemeral=True)
            return
        
        await interaction.response.send_message(
            "Select host(s) to query:",
            view=HostSelectView(self.current_command, self.compact),
            ephemeral=True
        )

    @discord.ui.button(label="🔄", style=discord.ButtonStyle.primary, custom_id="refresh_btn", row=0)
    async def refresh(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer()
        try:
            commands_map = {
                "memory": ("free -mh", "Memory"),
                "cpu": ("top -bn1 | head -20", "CPU"),
                "disk": ("df -h", "Disk"),
                "uptime": ("uptime", "Uptime"),
                "containers": ("docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'", "Containers"),
            }
            if self.current_command in commands_map:
                cmd, label = commands_map[self.current_command]
                output = await run_ssh_command(cmd)
                formatted = self.format_output(self.current_command, output)
                await interaction.followup.send(
                    f"**{label} on {SSH_HOST}:**\n{formatted}",
                    view=QuickActionsView(self.current_command, self.compact)
                )
        except Exception as e:
            await interaction.followup.send(f"Error: {e}", ephemeral=True)

    @discord.ui.button(label="🧠", style=discord.ButtonStyle.secondary, custom_id="mem_btn", row=1)
    async def memory(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer()
        try:
            output = await run_ssh_command("free -mh")
            formatted = self.format_output("memory", output)
            await interaction.followup.send(
                f"**Memory on {SSH_HOST}:**\n{formatted}",
                view=QuickActionsView("memory", self.compact)
            )
        except Exception as e:
            await interaction.followup.send(f"Error: {e}", ephemeral=True)

    @discord.ui.button(label="⚡", style=discord.ButtonStyle.secondary, custom_id="cpu_btn", row=1)
    async def cpu(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer()
        try:
            output = await run_ssh_command("top -bn1 | head -20")
            formatted = self.format_output("cpu", output)
            await interaction.followup.send(
                f"**CPU on {SSH_HOST}:**\n{formatted}",
                view=QuickActionsView("cpu", self.compact)
            )
        except Exception as e:
            await interaction.followup.send(f"Error: {e}", ephemeral=True)

    @discord.ui.button(label="💾", style=discord.ButtonStyle.secondary, custom_id="disk_btn", row=1)
    async def disk(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer()
        try:
            output = await run_ssh_command("df -h")
            formatted = self.format_output("disk", output)
            await interaction.followup.send(
                f"**Disk on {SSH_HOST}:**\n{formatted}",
                view=QuickActionsView("disk", self.compact)
            )
        except Exception as e:
            await interaction.followup.send(f"Error: {e}", ephemeral=True)

    @discord.ui.button(label="⏱️", style=discord.ButtonStyle.secondary, custom_id="uptime_btn", row=1)
    async def uptime(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer()
        try:
            output = await run_ssh_command("uptime")
            formatted = self.format_output("uptime", output)
            await interaction.followup.send(
                f"**Uptime on {SSH_HOST}:**\n{formatted}",
                view=QuickActionsView("uptime", self.compact)
            )
        except Exception as e:
            await interaction.followup.send(f"Error: {e}", ephemeral=True)

    @discord.ui.button(label="🐳", style=discord.ButtonStyle.success, custom_id="containers_btn", row=2)
    async def containers(self, interaction: discord.Interaction, button: discord.ui.Button):
        await interaction.response.defer()
        try:
            output = await run_ssh_command("docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'")
            formatted = self.format_output("containers", output)
            await interaction.followup.send(
                f"**Containers on {SSH_HOST}:**\n{formatted}",
                view=QuickActionsView("containers", self.compact)
            )
        except Exception as e:
            await interaction.followup.send(f"Error: {e}", ephemeral=True)
