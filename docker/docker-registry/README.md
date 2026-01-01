# Docker Registry Deployment

## Overview

This compose file deploys a private Docker Registry v2 with:
- Resource limits (CPU and Memory)
- Persistent storage
- Health checks
- High availability configuration
- Manager node placement

---
## Prepare
Need add to `/etc/docker/daemon.json`
```
"insecure-registries": ["10.10.1.2:5000"],
```
## Deployment

### Deploy Registry Stack

```bash
# Deploy registry as a stack
docker stack deploy -c docker-compose.registry.yml registry

# Check deployment status
docker stack services registry

# View detailed service info
docker service ps registry_registry

# Check logs
docker service logs -f registry_registry
```

---

## Resource Configuration

### CPU Limits

```yaml
resources:
  limits:
    cpus: '1.0'           # Max 1 full CPU core (100%)
  reservations:
    cpus: '0.25'          # Reserve 0.25 CPU core (25%)
```

**Explanation:**
- `limits.cpus`: Maximum CPU usage allowed
- `reservations.cpus`: Guaranteed CPU allocation
- Format: '0.5' = 50% of one core, '2.0' = 2 full cores

### Memory Limits

```yaml
resources:
  limits:
    memory: 512M          # Maximum 512MB
  reservations:
    memory: 128M          # Reserve 128MB
```

**Explanation:**
- `limits.memory`: Hard limit, container will be killed if exceeded
- `reservations.memory`: Guaranteed memory allocation
- Units: K (KB), M (MB), G (GB)

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY` | Storage path inside container | `/var/lib/registry` |
| `REGISTRY_STORAGE_DELETE_ENABLED` | Allow image deletion | `true` |
| `REGISTRY_HTTP_ADDR` | Listen address | `0.0.0.0:5000` |
| `REGISTRY_HTTP_SECRET` | Session secret (change in production!) | `changeme-generate-random-secret` |
| `REGISTRY_HEALTH_STORAGEDRIVER_ENABLED` | Enable storage health checks | `true` |

---

## Placement Constraints

```yaml
placement:
  constraints:
    - node.role == manager
```

**Why manager only?**
- Registry should be stable and predictable
- Managers have better uptime
- Simplifies networking (single endpoint)

**Alternative constraints:**
```yaml
# Run on specific node
- node.hostname == srv103.lan

# Run on nodes with specific label
- node.labels.registry == true

# Multiple constraints
- node.role == manager
- node.labels.storage == ssd
```

---

## Health Check Configuration

```yaml
healthcheck:
  test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:5000/v2/"]
  interval: 30s      # Check every 30 seconds
  timeout: 5s        # Timeout after 5 seconds
  retries: 3         # 3 failures before unhealthy
  start_period: 40s  # Grace period after startup
```

**Health check process:**
1. Waits `start_period` before first check
2. Executes check every `interval`
3. Marks unhealthy after `retries` consecutive failures
4. Swarm will restart unhealthy containers

---

## Update and Rollback

### Update Configuration

```yaml
update_config:
  parallelism: 1         # Update 1 replica at a time
  delay: 10s             # Wait 10s between updates
  failure_action: rollback  # Auto-rollback on failure
  monitor: 30s           # Monitor for 30s after update
```

### Rollback Configuration

```yaml
rollback_config:
  parallelism: 1         # Rollback 1 replica at a time
  delay: 5s              # Wait 5s between rollbacks
```

---

## Monitoring

### Check Registry Status

```bash
# Service status
docker service ps registry_registry

# Service logs
docker service logs registry_registry

# Resource usage
docker stats $(docker ps -q -f name=registry_registry)

# Health status
docker inspect $(docker ps -q -f name=registry_registry) | jq '.[].State.Health'
```

### Registry API Endpoints

```bash
# Check registry health
curl http://10.10.1.2:5000/v2/

# List repositories
curl http://10.10.1.2:5000/v2/_catalog

# List tags for specific image
curl http://10.10.1.2:5000/v2/swarm-nginx/tags/list

# Get manifest (image metadata)
curl http://10.10.1.2:5000/v2/swarm-nginx/manifests/v1
```

---

## Storage Management

### Check Volume Usage

```bash
# List volumes
docker volume ls | grep registry

# Inspect volume
docker volume inspect registry_registry-data

# Check volume size
docker system df -v | grep registry
```

### Cleanup Old Images

```bash
# Registry garbage collection (requires container access)
docker exec $(docker ps -q -f name=registry_registry) \
  bin/registry garbage-collect /etc/docker/registry/config.yml

# Delete specific image (if DELETE enabled)
# Get digest first
DIGEST=$(curl -I -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  http://10.10.1.2:5000/v2/swarm-nginx/manifests/v1 | \
  grep Docker-Content-Digest | awk '{print $2}')

# Delete using digest
curl -X DELETE http://10.10.1.2:5000/v2/swarm-nginx/manifests/$DIGEST
```

---

## Scaling and Resource Adjustment

### Scale Registry (if needed)

```bash
# Registry typically runs as 1 replica, but can scale
docker service scale registry_registry=2

# Not recommended unless using shared storage
```

### Update Resource Limits

```bash
# Update CPU limit
docker service update \
  --limit-cpu 2.0 \
  registry_registry

# Update memory limit
docker service update \
  --limit-memory 1G \
  registry_registry

# Update both
docker service update \
  --limit-cpu 2.0 \
  --limit-memory 1G \
  --reserve-cpu 0.5 \
  --reserve-memory 256M \
  registry_registry
```

---

## Security Considerations

### Production Recommendations

1. **Generate secure secret:**
```bash
# Generate random secret
openssl rand -base64 32

# Update in compose file
REGISTRY_HTTP_SECRET: <generated-secret>
```

2. **Enable TLS (HTTPS):**
```yaml
environment:
  REGISTRY_HTTP_TLS_CERTIFICATE: /certs/domain.crt
  REGISTRY_HTTP_TLS_KEY: /certs/domain.key
volumes:
  - ./certs:/certs:ro
```

3. **Enable authentication:**
```yaml
environment:
  REGISTRY_AUTH: htpasswd
  REGISTRY_AUTH_HTPASSWD_PATH: /auth/htpasswd
  REGISTRY_AUTH_HTPASSWD_REALM: Registry Realm
volumes:
  - ./auth:/auth:ro
```

Create htpasswd file:
```bash
# Install htpasswd
sudo apt-get install apache2-utils

# Create auth directory
mkdir auth

# Create user
htpasswd -Bc auth/htpasswd admin
```

---

## Troubleshooting

### High Memory Usage

**Check current usage:**
```bash
docker stats $(docker ps -q -f name=registry_registry)
```

**Increase limits:**
```bash
docker service update --limit-memory 1G registry_registry
```

### High CPU Usage

**Check current usage:**
```bash
docker stats $(docker ps -q -f name=registry_registry) --no-stream
```

**Possible causes:**
- Many concurrent push/pull operations
- Large image layers
- Garbage collection running

### Storage Full

**Check disk usage:**
```bash
docker system df -v
```

**Cleanup:**
```bash
# Run garbage collection
docker exec $(docker ps -q -f name=registry_registry) \
  bin/registry garbage-collect /etc/docker/registry/config.yml
```

---

## Advanced Configuration Example

### Full Production Setup

```yaml
version: '3.8'

services:
  registry:
    image: registry:2
    ports:
      - "5000:5000"
    environment:
      REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY: /var/lib/registry
      REGISTRY_STORAGE_DELETE_ENABLED: "true"
      REGISTRY_HTTP_SECRET: <your-random-secret>
      REGISTRY_AUTH: htpasswd
      REGISTRY_AUTH_HTPASSWD_PATH: /auth/htpasswd
      REGISTRY_AUTH_HTPASSWD_REALM: Registry
      REGISTRY_HTTP_TLS_CERTIFICATE: /certs/domain.crt
      REGISTRY_HTTP_TLS_KEY: /certs/domain.key
    volumes:
      - registry-data:/var/lib/registry
      - ./auth:/auth:ro
      - ./certs:/certs:ro
    deploy:
      placement:
        constraints:
          - node.role == manager
          - node.labels.storage == ssd
      resources:
        limits:
          cpus: '2.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 256M
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      update_config:
        parallelism: 1
        delay: 10s
        failure_action: rollback
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "https://localhost:5000/v2/"]
      interval: 30s
      timeout: 5s
      retries: 3

volumes:
  registry-data:
    driver: local

networks:
  default:
    driver: overlay
```

---

## Resource Planning Guide

### Small Deployment (< 10 images)
```yaml
resources:
  limits:
    cpus: '0.5'
    memory: 256M
  reservations:
    cpus: '0.1'
    memory: 64M
```

### Medium Deployment (10-100 images)
```yaml
resources:
  limits:
    cpus: '1.0'
    memory: 512M
  reservations:
    cpus: '0.25'
    memory: 128M
```

### Large Deployment (> 100 images)
```yaml
resources:
  limits:
    cpus: '2.0'
    memory: 2G
  reservations:
    cpus: '0.5'
    memory: 512M
```

---

## Cleanup

### Remove Registry Stack

```bash
# Remove stack
docker stack rm registry

# Wait for cleanup
docker stack ps registry
# Should show: no such service

# Remove volume (if needed - DESTROYS ALL IMAGES!)
docker volume rm registry_registry-data
```

## Error when push to registry
Remove `localhost` from IPv6 `/etc/hosts`
```sh
sudo sed -i '/^::1/ s/localhost//g' /etc/hosts
```
Or

If enabled IPv6 thats maybe problem
Disable IPv6
```sh
fl1="/etc/sysctl.d/99-disable-ipv6.conf"
if [ ! -e ${fl1} ]; then
cat>${fl1}<<- EOT
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOT
fi
```
