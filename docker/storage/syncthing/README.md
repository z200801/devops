# Syncthing Bidirectional Replication Cluster

A Docker Compose solution for creating a bidirectional data replication cluster using Syncthing. This setup ensures that data remains available and synchronized across multiple nodes, providing high availability and fault tolerance for your applications.

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Node 1      │◄──►│     Node 2      │◄──►│     Node 3      │
│                 │    │                 │    │                 │
│  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │
│  │ Syncthing │  │    │  │ Syncthing │  │    │  │ Syncthing │  │
│  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │
│  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │
│  │   Data    │  │    │  │   Data    │  │    │  │   Data    │  │
│  │ Directory │  │    │  │ Directory │  │    │  │ Directory │  │
│  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │
│  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │
│  │Your Apps  │  │    │  │Your Apps  │  │    │  │Your Apps  │  │
│  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Key Features

- **Peer-to-Peer Architecture**: No single point of failure
- **Bidirectional Sync**: Changes propagate in all directions
- **Automatic Recovery**: Nodes automatically sync when reconnected
- **Conflict Resolution**: Handles file conflicts gracefully
- **Scalable**: Easy to add new nodes without cluster rebuild
- **Encrypted Communication**: TLS encryption between nodes
- **Hardened Security**: Disabled global discovery, relays, and telemetry
- **Resource Limited**: CPU and memory constraints for production stability

## 🚀 Quick Start

### Prerequisites

- Linux servers with Docker and Docker Compose installed
- Network connectivity between nodes (ports 8384, 22000, 21027)
- User account with Docker permissions
- `jq` utility for JSON processing
- `curl` for API operations
- `openssl` for security operations

### Automated Setup (Recommended)

Use the provided INSTALL.md instructions for streamlined setup:

**Server 1 (srv1):**
```bash
export SYNCTHING_HOSTNAME=srv1
export srv_next='192.168.1.104'
make init start service-wait global-discovery-disable nat-disable telemetry-disable-all
make gui-set-password GUI_USER=admin GUI_PASSWORD=admin
make device-add device-update-address NODE_IP=${srv_next} DEVICE_NAME=node-${srv_next}
make folder-create FOLDER_ID=shared_folder
make folder-share-name FOLDER_ID=shared_folder DEVICE_NAME=node-${srv_next}
```

**Server 2 (srv2):**
```bash
export SYNCTHING_HOSTNAME=srv2
export srv_next='192.168.1.103'
make init start service-wait global-discovery-disable nat-disable telemetry-disable-all
make gui-set-password GUI_USER=admin GUI_PASSWORD=admin
make device-add device-update-address NODE_IP=${srv_next} DEVICE_NAME=node-${srv_next}
make folder-approve FOLDER_ID=shared_folder
```

### Manual Setup

1. **Initialize and start services:**
   ```bash
   make init
   make start
   make service-wait  # Wait for service to be fully ready
   ```

2. **Apply security hardening:**
   ```bash
   make global-discovery-disable
   make nat-disable
   make telemetry-disable-all
   ```

3. **Set GUI authentication:**
   ```bash
   make gui-set-password GUI_USER=admin GUI_PASSWORD=your_secure_password
   ```

4. **Add devices and share folders as needed**

## 📋 Commands Reference

### Service Management

| Command | Description | Example |
|---------|-------------|---------|
| `make help` | Show all available commands | `make help` |
| `make init` | Initialize node directories | `make init` |
| `make start` | Start Syncthing services | `make start` |
| `make stop` | Stop Syncthing services | `make stop` |
| `make restart` | Restart services | `make restart` |
| `make status` | Check container status | `make status` |
| `make service-wait` | Wait for service to be ready | `make service-wait` |
| `make logs` | Follow container logs | `make logs` |
| `make exec` | Open shell in container | `make exec` |
| `make clean` | Clean up containers and volumes | `make clean` |

### Device Management

| Command | Description | Example |
|---------|-------------|---------|
| `make device-id` | Get current device ID | `make device-id` |
| `make device-list` | List all devices with names | `make device-list` |
| `make device-add NODE_IP=<ip>` | Add device by IP | `make device-add NODE_IP=192.168.1.104` |
| `make device-update-address NODE_IP=<ip> DEVICE_NAME=<name>` | Update device address | `make device-update-address NODE_IP=192.168.1.104 DEVICE_NAME=node-192.168.1.104` |
| `make device-remove DEVICE_ID=<id>` | Remove device by ID | `make device-remove DEVICE_ID=TZPMTEL-...` |
| `make device-remove DEVICE_NAME=<name>` | Remove device by name | `make device-remove DEVICE_NAME=node-192.168.1.104` |
| `make device-status` | Show status of all devices | `make device-status` |
| `make device-status DEVICE_NAME=<name>` | Show status of specific device | `make device-status DEVICE_NAME=node-192.168.1.104` |
| `make device-pending` | Show pending device connections | `make device-pending` |
| `make device-approve DEVICE_ID=<id>` | Approve pending device | `make device-approve DEVICE_ID=TZPMTEL-...` |
| `make device-reject DEVICE_ID=<id>` | Reject pending device | `make device-reject DEVICE_ID=TZPMTEL-...` |

### Folder Management

| Command | Description | Example |
|---------|-------------|---------|
| `make folder-list` | List all folders | `make folder-list` |
| `make folder-create FOLDER_ID=<id>` | Create new folder | `make folder-create FOLDER_ID=shared_folder` |
| `make folder-remove FOLDER_ID=<id>` | Remove folder (preserve data) | `make folder-remove FOLDER_ID=shared_folder` |
| `make folder-remove-with-data FOLDER_ID=<id>` | Remove folder and delete data | `make folder-remove-with-data FOLDER_ID=shared_folder` |
| `make folder-pause FOLDER_ID=<id>` | Pause folder synchronization | `make folder-pause FOLDER_ID=shared_folder` |
| `make folder-resume FOLDER_ID=<id>` | Resume folder synchronization | `make folder-resume FOLDER_ID=shared_folder` |
| `make folder-share FOLDER_ID=<id> DEVICE_ID=<id>` | Share folder with device | `make folder-share FOLDER_ID=data DEVICE_ID=TZPMTEL-...` |
| `make folder-share-name FOLDER_ID=<id> DEVICE_NAME=<name>` | Share folder with device by name | `make folder-share-name FOLDER_ID=data DEVICE_NAME=node-192.168.1.104` |
| `make folder-approve` | List pending folders | `make folder-approve` |
| `make folder-approve FOLDER_ID=<id>` | Approve pending folder | `make folder-approve FOLDER_ID=shared_folder` |
| `make folder-status` | Show all folders synchronization status | `make folder-status` |
| `make folder-status FOLDER_ID=<id>` | Show specific folder status | `make folder-status FOLDER_ID=shared_folder` |

### Security & Configuration

| Command | Description | Example |
|---------|-------------|---------|
| `make security-harden` | Apply all security hardening | `make security-harden` |
| `make security-status` | Show security configuration | `make security-status` |
| `make security-check` | Perform security audit | `make security-check` |
| `make security-monitor` | Monitor security events | `make security-monitor` |
| `make security-summary` | Quick security overview | `make security-summary` |
| `make global-discovery-disable` | Disable global discovery | `make global-discovery-disable` |
| `make global-discovery-enable` | Enable global discovery | `make global-discovery-enable` |
| `make relay-disable` | Disable relay servers | `make relay-disable` |
| `make relay-enable` | Enable relay servers | `make relay-enable` |
| `make nat-disable` | Disable NAT traversal | `make nat-disable` |
| `make nat-enable` | Enable NAT traversal | `make nat-enable` |
| `make telemetry-disable-all` | Disable all telemetry | `make telemetry-disable-all` |
| `make usage-reporting-disable` | Disable usage reporting | `make usage-reporting-disable` |
| `make network-options` | Show network configuration | `make network-options` |

### GUI Management

| Command | Description | Example |
|---------|-------------|---------|
| `make gui-set-password GUI_USER=<user> GUI_PASSWORD=<pass>` | Set GUI authentication | `make gui-set-password GUI_USER=admin GUI_PASSWORD=secret` |
| `make gui-test-login GUI_USER=<user> GUI_PASSWORD=<pass>` | Test GUI login | `make gui-test-login GUI_USER=admin GUI_PASSWORD=secret` |
| `make gui-show-config` | Show GUI configuration | `make gui-show-config` |
| `make gui-remove-password` | Remove GUI authentication | `make gui-remove-password` |
| `make gui-secure-setup GUI_USER=<user> GUI_PASSWORD=<pass>` | Complete secure GUI setup | `make gui-secure-setup GUI_USER=admin GUI_PASSWORD=secret` |

### Backup & Recovery

| Command | Description | Example |
|---------|-------------|---------|
| `make config-backup` | Backup configuration | `make config-backup` |
| `make config-restore BACKUP_FILE=<file>` | Restore from backup | `make config-restore BACKUP_FILE=backup.tar.gz` |
| `make config-list-backups` | List available backups | `make config-list-backups` |
| `make config-restore-emergency BACKUP_FILE=<file>` | Emergency restore | `make config-restore-emergency BACKUP_FILE=backup.tar.gz` |

### Security Monitoring & IP Management

| Command | Description | Example |
|---------|-------------|---------|
| `make security-ban-ip IP_ADDRESS=<ip> REASON=<reason>` | Ban IP address | `make security-ban-ip IP_ADDRESS=192.168.1.65 REASON="Failed login"` |
| `make security-unban-ip IP_ADDRESS=<ip>` | Unban IP address | `make security-unban-ip IP_ADDRESS=192.168.1.65` |
| `make security-ban-ip-list` | List banned IPs | `make security-ban-ip-list` |
| `make security-clear-all-bans` | Clear all IP bans | `make security-clear-all-bans` |
| `make monitor-connections` | Monitor active connections | `make monitor-connections` |

### Utility Commands

| Command | Description | Example |
|---------|-------------|---------|
| `make get-api-key-from-config` | Get API key | `make get-api-key-from-config` |
| `make rotate-api-key` | Generate new API key | `make rotate-api-key` |
| `make audit-log` | Show recent activity | `make audit-log` |
| `make emergency-shutdown` | Emergency stop and isolate | `make emergency-shutdown` |

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SYNCTHING_HOSTNAME` | `node0` | Hostname for container |
| `NODE_IP` | - | IP address for device operations |
| `FOLDER_ID` | - | Folder identifier |
| `DEVICE_ID` | - | Device identifier |
| `DEVICE_NAME` | - | Device name |
| `SYNCTHING_UI_PORT` | `8384` | Web UI port |
| `SYNCTHING_SYNC_PORT` | `22000` | Sync port |
| `DATA_DIR` | `${HOME}/projects/replica_data/cluster/data` | Data directory |
| `WAIT_SERVICE_DURATION` | `30` | Service wait timeout |
| `GUI_USER` | - | GUI username |
| `GUI_PASSWORD` | - | GUI password |
| `IP_ADDRESS` | - | IP address for security operations |
| `REASON` | - | Reason for IP ban |

### Directory Structure

```
${HOME}/projects/replica_data/cluster/
└── data/                     # Syncthing data directory (auto-created)
    ├── config/               # Syncthing configuration
    └── <FOLDER_ID>/          # Synchronized folders
```

### Ports Used

- **8384**: Syncthing Web UI
- **22000**: File transfer (TCP/UDP - QUIC)
- **21027**: Local discovery (UDP)

### Container Configuration

The container is configured with security optimizations:
- **Security**: `no-new-privileges`, capability dropping, read-only where possible
- **Resources**: CPU limit (0.2), memory limit (96M)
- **Environment**: Disabled external services, relay servers, and telemetry
- **User**: Runs as non-root user (1000:1000)
- **Network**: Bridge network with controlled access

## 🔄 Workflow Examples

### Setting Up a Two-Node Cluster (Automated)

**Node 1 (192.168.1.103):**
```bash
export SYNCTHING_HOSTNAME=srv1
export srv_next='192.168.1.104'
make init start service-wait global-discovery-disable nat-disable telemetry-disable-all
make gui-set-password GUI_USER=admin GUI_PASSWORD=admin
make device-add device-update-address NODE_IP=${srv_next} DEVICE_NAME=node-${srv_next}
make folder-create FOLDER_ID=shared_folder
make folder-share-name FOLDER_ID=shared_folder DEVICE_NAME=node-${srv_next}
```

**Node 2 (192.168.1.104):**
```bash
export SYNCTHING_HOSTNAME=srv2
export srv_next='192.168.1.103'
make init start service-wait global-discovery-disable nat-disable telemetry-disable-all
make gui-set-password GUI_USER=admin GUI_PASSWORD=admin
make device-add device-update-address NODE_IP=${srv_next} DEVICE_NAME=node-${srv_next}
make folder-approve FOLDER_ID=shared_folder
```

### Adding a Third Node

**Node 3 (192.168.1.105):**
```bash
export SYNCTHING_HOSTNAME=srv3
make init start service-wait
make security-harden
make gui-set-password GUI_USER=admin GUI_PASSWORD=admin
make device-add NODE_IP=192.168.1.103
make device-add NODE_IP=192.168.1.104
```

**From Node 1 or 2:**
```bash
make folder-share-name FOLDER_ID=shared_folder DEVICE_NAME=node-192.168.1.105
```

**Node 3:**
```bash
make folder-approve FOLDER_ID=shared_folder
```

## 📈 Scaling

### Adding New Nodes

1. **Prepare the new server** with the same project structure
2. **Initialize the new node:**
   ```bash
   make init start service-wait
   make security-harden
   make gui-set-password GUI_USER=admin GUI_PASSWORD=secure_password
   ```
3. **Connect to existing cluster:**
   ```bash
   make device-add NODE_IP=<existing_node_ip>
   ```
4. **Share folders with the new node** from any existing node
5. **Approve folders** on the new node
6. **Verify synchronization:**
   ```bash
   make device-status
   make folder-status
   ```

### Removing Nodes

1. **Remove the device from other nodes:**
   ```bash
   make device-remove DEVICE_NAME=node-to-remove
   ```
2. **Stop services on the node to remove:**
   ```bash
   make stop
   ```
3. **Clean up if needed:**
   ```bash
   make clean
   ```

## 🔒 Security

### Network Security

- All node-to-node communication is encrypted with TLS
- Web UI protected with username/password authentication
- No external relay servers used (direct connections only)
- Global discovery disabled for enhanced privacy
- NAT traversal disabled for security
- All telemetry and usage reporting disabled

### Access Control

- GUI requires authentication (configurable via Makefile)
- Each device has a unique cryptographic identity
- Folder sharing requires explicit approval
- IP-based blocking for failed authentication attempts

### Security Monitoring

The system includes comprehensive security monitoring:
- Failed login attempt tracking
- IP-based banning system
- Security event monitoring
- Configuration audit tools

### Firewall Configuration

Ensure the following ports are open between cluster nodes:
```bash
# Allow Syncthing ports from your network
sudo ufw allow from 192.168.1.0/24 to any port 22000
sudo ufw allow from 192.168.1.0/24 to any port 21027
sudo ufw allow from 192.168.1.0/24 to any port 8384
```

## 🔍 Troubleshooting

### Common Issues

#### Services Won't Start
```bash
# Check container status
make status

# View logs
make logs

# Restart services
make restart
```

#### Nodes Not Connecting
```bash
# Check network connectivity
ping <node_ip>
telnet <node_ip> 22000

# Check device status
make device-status

# Monitor connections
make monitor-connections

# View detailed logs
make logs
```

#### Folders Not Syncing
```bash
# Check folder status
make folder-status

# Check if folder is shared
make folder-list

# Check device connections
make device-status

# Check for pending folders
make folder-approve
```

#### Permission Issues
```bash
# Fix ownership using proper variables
make folder-create FOLDER_ID=test

# Check container user
make exec
# Then inside container: id
```

#### Authentication Issues
```bash
# Test GUI login
make gui-test-login GUI_USER=admin GUI_PASSWORD=your_password

# Show current GUI config
make gui-show-config

# Reset authentication
make gui-remove-password
make gui-set-password GUI_USER=newuser GUI_PASSWORD=newpass
```

### Security Issues

```bash
# Check security status
make security-summary

# Monitor security events
make security-monitor

# Check for suspicious activity
make audit-log

# Ban problematic IP
make security-ban-ip IP_ADDRESS=suspicious.ip.here REASON="Multiple failed logins"
```

### Useful Debugging Commands

```bash
# Get device information
make device-list

# Check API key
make get-api-key-from-config

# Check pending connections
make device-pending

# Show folder synchronization status
make folder-status

# Open shell in container
make exec

# Follow logs in real-time
make logs

# Monitor active connections
make monitor-connections
```

### Web UI Access

Access the Syncthing web interface at:
- **Local**: http://localhost:8384
- **Remote**: http://<server-ip>:8384 (if firewall allows)

**Default authentication:**
- Username: Set via `GUI_USER` variable
- Password: Set via `GUI_PASSWORD` variable

The web interface provides detailed status information, advanced configuration options, and real-time sync monitoring.

## 🚨 Emergency Procedures

### Emergency Shutdown
```bash
make emergency-shutdown
```

### Configuration Backup and Recovery
```bash
# Create backup before making changes
make config-backup

# In case of issues, restore from backup
make config-restore BACKUP_FILE=syncthing_config_backup_YYYYMMDD_HHMMSS.tar.gz

# Emergency restore (no confirmation)
make config-restore-emergency BACKUP_FILE=backup.tar.gz
```

### Security Incident Response
```bash
# Immediate response
make security-monitor
make security-ban-ip IP_ADDRESS=malicious.ip REASON="Security incident"

# Investigation
make audit-log
make monitor-connections
make security-check

# Recovery
make config-restore BACKUP_FILE=clean_backup.tar.gz
```

## 📝 Notes

- Device names follow the pattern `node-<IP>` when added via `device-add`
- Folders are created in `/var/syncthing/<FOLDER_ID>` inside containers
- The system automatically handles file conflicts by creating `.sync-conflict` files
- Large files are transferred in chunks for better reliability
- The cluster continues to function even when some nodes are offline
- Container resources are limited to prevent system overload
- All external communications (relays, discovery, telemetry) are disabled by default
- Regular configuration backups are recommended before major changes
