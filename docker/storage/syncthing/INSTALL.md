# Syncthing Cluster Installation Guide

This document provides step-by-step instructions for setting up a secure Syncthing bidirectional replication cluster.

## Prerequisites

Before starting the installation:

- **Linux servers** with Docker and Docker Compose installed
- **Network connectivity** between nodes (ports 8384, 22000, 21027)
- **Required tools**: `jq`, `curl`, `openssl`
- **User permissions**: Docker access without sudo
- **Firewall**: Proper ports opened between cluster nodes

## Installation Steps

### Step 1: Prepare Project Structure

On each server, create the project directory:

```bash
mkdir -p ${HOME}/projects/replica_data/cluster
cd ${HOME}/projects/replica_data/cluster

# Copy project files:
# - docker-compose.yml
# - Makefile  
# - README.md
# - INSTALL.md (this file)
```

### Step 2: Two-Node Cluster Setup

#### Server 1 (srv1 - 192.168.1.103)

```bash
# Set environment variables
export SYNCTHING_HOSTNAME=srv1
export srv_next='192.168.1.104'

# Initialize and start services
make init start service-wait

# Apply security hardening
make global-discovery-disable nat-disable telemetry-disable-all

# Set GUI authentication
make gui-set-password GUI_USER=admin GUI_PASSWORD=admin

# Add the second node
make device-add NODE_IP=${srv_next}
make device-update-address NODE_IP=${srv_next} DEVICE_NAME=node-${srv_next}

# Create and share a folder
make folder-create FOLDER_ID=shared_folder
make folder-share-name FOLDER_ID=shared_folder DEVICE_NAME=node-${srv_next}
```

#### Server 2 (srv2 - 192.168.1.104)

```bash
# Set environment variables
export SYNCTHING_HOSTNAME=srv2
export srv_next='192.168.1.103'

# Initialize and start services
make init start service-wait

# Apply security hardening
make global-discovery-disable nat-disable telemetry-disable-all

# Set GUI authentication
make gui-set-password GUI_USER=admin GUI_PASSWORD=admin

# Add the first node
make device-add NODE_IP=${srv_next}
make device-update-address NODE_IP=${srv_next} DEVICE_NAME=node-${srv_next}

# Approve the shared folder
make folder-approve FOLDER_ID=shared_folder
```

### Step 3: Verification

On both servers, verify the setup:

```bash
# Check device connections
make device-status

# Check folder synchronization
make folder-status

# Verify security settings
make security-summary

# Test GUI access
make gui-test-login GUI_USER=admin GUI_PASSWORD=admin
```

## Adding Additional Nodes

### Server 3 (srv3 - 192.168.1.105)

```bash
# Set environment variables
export SYNCTHING_HOSTNAME=srv3

# Initialize and start services
make init start service-wait

# Apply security hardening
make security-harden

# Set GUI authentication
make gui-set-password GUI_USER=admin GUI_PASSWORD=admin

# Connect to existing cluster nodes
make device-add NODE_IP=192.168.1.103
make device-add NODE_IP=192.168.1.104
```

### On any existing node (srv1 or srv2)

```bash
# Share folders with the new node
make folder-share-name FOLDER_ID=shared_folder DEVICE_NAME=node-192.168.1.105
```

### Back on srv3

```bash
# Approve shared folders
make folder-approve FOLDER_ID=shared_folder
```

## Post-Installation Tasks

### 1. Create Configuration Backup

On each server:
```bash
make config-backup
```

This creates a timestamped backup file that can be used for recovery.

### 2. Configure Firewall

Ensure proper firewall rules are in place:

```bash
# Allow Syncthing ports from your network
sudo ufw allow from 192.168.1.0/24 to any port 22000
sudo ufw allow from 192.168.1.0/24 to any port 21027
sudo ufw allow from 192.168.1.0/24 to any port 8384

# Or for specific server IPs only:
sudo ufw allow from 192.168.1.103 to any port 22000,21027,8384
sudo ufw allow from 192.168.1.104 to any port 22000,21027,8384
sudo ufw allow from 192.168.1.105 to any port 22000,21027,8384
```

### 3. Set Up Monitoring

Optional: Set up basic monitoring for security events:

```bash
# Add to crontab for periodic security checks
echo "0 */6 * * * cd ${HOME}/projects/replica_data/cluster && make security-summary >> /var/log/syncthing-security.log 2>&1" | crontab -
```

### 4. Test Synchronization

Create test files on each node to verify bidirectional sync:

```bash
# On srv1
echo "Test from srv1 $(date)" > data/shared_folder/test-srv1.txt

# On srv2
echo "Test from srv2 $(date)" > data/shared_folder/test-srv2.txt

# Wait a few moments, then check on all nodes
ls -la data/shared_folder/
```

## Customization Options

### Different Port Configuration

If you need to use different ports, modify the docker-compose.yml:

```yaml
ports:
  - "8385:8384"       # Change web UI port
  - "22001:22000"     # Change sync port
  - "22001:22000/udp" # Change QUIC port
  - "21028:21027/udp" # Change discovery port
```

Then update the Makefile variables accordingly:
```bash
export SYNCTHING_UI_PORT=8385
export SYNCTHING_SYNC_PORT=22001
```

### Custom Data Directory

To use a different data directory:

```bash
export DATA_DIR=/path/to/custom/directory
make init start
```

### Advanced Security Settings

For enhanced security:

```bash
# Disable all external communications
make security-harden

# Set strong GUI password
make gui-set-password GUI_USER=secure_admin GUI_PASSWORD=$(openssl rand -base64 32)

# Enable TLS for GUI (if needed)
make gui-secure-setup GUI_USER=admin GUI_PASSWORD=secure_password
```

## Troubleshooting Installation

### Services Don't Start

```bash
# Check Docker status
sudo systemctl status docker

# Check container logs
make logs

# Verify permissions
ls -la ${HOME}/projects/replica_data/cluster/data/
```

### Devices Won't Connect

```bash
# Test network connectivity
ping <target_ip>
telnet <target_ip> 22000

# Check firewall
sudo ufw status
sudo iptables -L

# Check device status
make device-status
make device-list
```

### Folders Won't Sync

```bash
# Check folder permissions
make exec
# Inside container: ls -la /var/syncthing/

# Check folder status
make folder-status

# Check for pending approvals
make folder-approve
```

### GUI Authentication Issues

```bash
# Verify GUI configuration
make gui-show-config

# Test login
make gui-test-login GUI_USER=admin GUI_PASSWORD=admin

# Reset authentication if needed
make gui-remove-password
make gui-set-password GUI_USER=newuser GUI_PASSWORD=newpass
```

## Security Considerations

### Network Security

- All inter-node communication is encrypted with TLS
- External services (relays, global discovery) are disabled
- Local network isolation is recommended
- Regular security monitoring should be implemented

### Access Control

- GUI authentication is mandatory in production
- Use strong passwords or key-based authentication
- Implement IP-based access restrictions if needed
- Monitor and log access attempts

### Data Protection

- Regular configuration backups are essential
- Monitor folder synchronization status
- Implement proper file system permissions
- Consider encryption at rest for sensitive data

## Maintenance

### Regular Tasks

1. **Monitor cluster health:**
   ```bash
   make device-status
   make folder-status
   make security-summary
   ```

2. **Create configuration backups:**
   ```bash
   make config-backup
   ```

3. **Review security logs:**
   ```bash
   make security-monitor
   make audit-log
   ```

4. **Update containers when needed:**
   ```bash
   make stop
   docker compose pull
   make start
   ```

### Performance Tuning

For better performance in production:

1. **Adjust resource limits** in docker-compose.yml
2. **Monitor CPU and memory usage**
3. **Consider SSD storage** for better I/O performance
4. **Tune network settings** for high-throughput scenarios

## Conclusion

After completing these steps, you should have a fully functional, secure Syncthing cluster with:

- ✅ Bidirectional synchronization between all nodes
- ✅ Security hardening applied
- ✅ GUI authentication configured
- ✅ Monitoring and backup procedures in place
- ✅ Proper network security

For ongoing management, refer to the comprehensive command reference in README.md.

## Quick Reference Commands

### Essential Commands for Daily Operations

```bash
# Service management
make start              # Start services
make stop               # Stop services  
make status             # Check status
make logs               # View logs

# Device management
make device-list        # List all devices
make device-status      # Show device connections
make device-add NODE_IP=<ip>  # Add new device

# Folder management
make folder-list        # List folders
make folder-status      # Show sync status
make folder-create FOLDER_ID=<name>  # Create folder
make folder-approve FOLDER_ID=<name> # Approve pending folder

# Security
make security-summary   # Quick security check
make security-monitor   # Monitor security events
make config-backup      # Backup configuration
```

### Emergency Commands

```bash
# Emergency shutdown
make emergency-shutdown

# Restore from backup
make config-restore BACKUP_FILE=backup.tar.gz

# Security incident response
make security-ban-ip IP_ADDRESS=<malicious_ip> REASON="Security incident"
make security-clear-all-bans  # Clear all bans if needed
```

## Appendix: Environment Variables Reference

| Variable | Purpose | Example |
|----------|---------|---------|
| `SYNCTHING_HOSTNAME` | Container hostname | `srv1`, `srv2`, `srv3` |
| `srv_next` | Next server IP for setup | `192.168.1.104` |
| `NODE_IP` | Target node IP | `192.168.1.103` |
| `DEVICE_NAME` | Device identifier | `node-192.168.1.104` |
| `FOLDER_ID` | Folder identifier | `shared_folder` |
| `GUI_USER` | GUI username | `admin` |
| `GUI_PASSWORD` | GUI password | `secure_password` |
| `DATA_DIR` | Data directory path | `${HOME}/projects/replica_data/cluster/data` |

Save these variables in your shell profile or use them per session as needed.