# Docker Registry Management Makefile

A comprehensive Makefile for managing Docker Registry deployed in Docker Swarm with support for image lifecycle management, garbage collection, and orphaned tag cleanup.

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Quick Start](#quick-start)
- [Usage](#usage)
  - [Stack Management](#stack-management)
  - [Service Management](#service-management)
  - [Registry Information](#registry-information)
  - [Image Management](#image-management)
  - [Cleanup Operations](#cleanup-operations)
  - [Garbage Collection](#garbage-collection)
- [Common Workflows](#common-workflows)
- [Troubleshooting](#troubleshooting)
- [Environment Variables](#environment-variables)

## Features

- **Stack Deployment**: Deploy and manage Docker Swarm stacks
- **Service Management**: Scale, monitor, and manage services
- **Registry Operations**: List, inspect, and manage Docker Registry images
- **API-based Deletion**: Remove images and tags via Registry HTTP API v2
- **Filesystem Cleanup**: Handle orphaned tags and repositories
- **Garbage Collection**: Reclaim storage space from deleted images
- **Verification Tools**: Check manifest validity and health status

## Prerequisites

- Docker Swarm cluster
- Docker Registry 2.x running in swarm stack
- `jq` - JSON processor
- `curl` - HTTP client
- Bash shell

## Configuration

Edit the Makefile variables at the top of the file:

```makefile
ENV               ?= dev              # Environment: dev, qa, prod
TAG               ?= latest           # Default image tag
SERVICE           ?= registry         # Service name
STACK_NAME        ?= registry         # Stack name
REGISTRY_HOST     ?= 10.10.1.2       # Registry host IP
REGISTRY_PORT     ?= 5000            # Registry port
PROJECTS_DIR      ?= $(HOME)/projects/itv
```

## Quick Start

```bash
# Show all available commands
make help

# List all repositories
make registry-list

# List all images with tags and short IDs
make registry-list-all

# Remove an image
make registry-remove-image IMAGE=myapp

# Run garbage collection
make registry-gc
```

## Usage

### Stack Management

```bash
# Initialize deployment directory
make init

# Copy deployment files from repository
make copy-deploy-files

# List all stacks
make stack-ls

# Deploy stack
make stack-deploy

# Remove stack
make stack-rm

# Show stack status
make ps
```

### Service Management

```bash
# List all services
make service-ls

# List services in current stack
make services-stack-ls

# Deploy specific service
make service-deploy SERVICE=registry

# Scale service
make service-scale SERVICE=registry REPLICAS=3

# View service logs
make logs SERVICE=registry

# Show service environment variables
make service-env SERVICE=registry
```

### Registry Information

```bash
# Show registry information and health
make registry-info

# List all repositories
make registry-list

# List all images with tags and short digests
make registry-list-all

# List tags for specific image
make registry-tags IMAGE=backend

# Verify if manifest exists
make registry-verify-manifest IMAGE=backend TAG=v1.0.0

# Check manifest headers (diagnostic)
make registry-check-manifest IMAGE=backend TAG=v1.0.0
```

**Example output:**

```
Tags for backend:
  TAG                  SHORT-ID
  ---                  --------
  v1.0.0               37718409818d
  v1.0.1               a8f3c2d19e45
  latest               37718409818d
  old-tag              <orphaned>
```

### Image Management

#### Remove Specific Tag

```bash
# Remove single tag via API
make registry-remove-tag IMAGE=backend TAG=v1.0.0

# After deletion, run garbage collection
make registry-gc
```

#### Remove Entire Image

```bash
# Remove all tags of an image (tries API first, falls back to filesystem)
make registry-remove-image IMAGE=myapp

# Run garbage collection to reclaim space
make registry-gc
```

**How it works:**
1. Attempts to delete via Registry API for each tag
2. If manifests don't exist (orphaned tags), removes from filesystem
3. Shows which method was used for each tag

#### Remove Old Tags

```bash
# Keep 3 latest tags, remove older ones
make registry-remove-old IMAGE=backend KEEP=3

# Keep 5 latest tags
make registry-remove-old IMAGE=backend KEEP=5

# Run garbage collection
make registry-gc
```

### Cleanup Operations

#### Orphaned Tags

Orphaned tags are tags that appear in the catalog but have no valid manifest. This happens when:
- Registry was stopped during deletion
- Manual filesystem modifications
- Incomplete push operations

```bash
# Remove orphaned tags from filesystem
make registry-cleanup-orphaned IMAGE=myapp

# Remove entire repository from filesystem
make registry-cleanup-repo IMAGE=myapp

# Run garbage collection
make registry-gc
```

### Garbage Collection

Garbage collection (GC) removes unreferenced blobs from storage. **Always run GC after deleting images.**

```bash
# Run garbage collection (production mode)
make registry-gc

# Run garbage collection in dry-run mode (see what would be deleted)
make registry-gc-dry
```

**Important Notes:**
- GC cannot be performed via HTTP API
- Requires direct access to registry container
- Should be run during low-traffic periods
- Dry-run mode is safe for testing

## Common Workflows

### Workflow 1: Remove Test Images

```bash
# List all images
make registry-list-all

# Remove test image
make registry-remove-image IMAGE=test-app

# Reclaim storage space
make registry-gc
```

### Workflow 2: Clean Old Versions

```bash
# Keep only 3 latest versions of production app
make registry-remove-old IMAGE=backend KEEP=3

# Reclaim storage
make registry-gc
```

### Workflow 3: Fix Orphaned Tags

```bash
# Check if tag has valid manifest
make registry-verify-manifest IMAGE=myapp TAG=v1.0.0

# If orphaned, remove from filesystem
make registry-cleanup-repo IMAGE=myapp

# Clean up storage
make registry-gc
```

### Workflow 4: Complete Cleanup

```bash
# List all repositories
make registry-list

# Remove unwanted repositories
make registry-remove-image IMAGE=old-app-1
make registry-remove-image IMAGE=old-app-2
make registry-remove-image IMAGE=test-app

# Run garbage collection once for all
make registry-gc

# Verify cleanup
make registry-info
```

## Troubleshooting

### Issue: "Could not get digest" Error

**Cause:** Tag exists in catalog but has no valid manifest (orphaned tag)

**Solution:**
```bash
# Verify the tag
make registry-verify-manifest IMAGE=myapp TAG=v1.0.0

# If orphaned, remove from filesystem
make registry-cleanup-repo IMAGE=myapp
```

### Issue: Image Still Appears After Deletion

**Cause:** Garbage collection not run

**Solution:**
```bash
# Always run GC after deletion
make registry-gc
```

### Issue: "Registry container not found"

**Cause:** Registry service name doesn't match `STACK_NAME_SERVICE` pattern

**Solution:**
```bash
# Check actual service name
docker service ls

# Update Makefile variables
SERVICE=your-service-name
STACK_NAME=your-stack-name
```

### Issue: Deletion Fails with HTTP 404

**Cause:** Tag doesn't exist or already deleted

**Solution:**
```bash
# Verify tag exists
make registry-tags IMAGE=myapp

# Check manifest
make registry-check-manifest IMAGE=myapp TAG=v1.0.0
```

### Issue: Storage Not Reclaimed After GC

**Possible causes:**
1. Images still referenced by other tags
2. Layers shared with other images
3. GC didn't run successfully

**Solution:**
```bash
# Run GC in dry-run to see what would be deleted
make registry-gc-dry

# Check if other tags reference the same image
make registry-list-all | grep <short-id>

# Force GC
make registry-gc
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ENV` | `dev` | Environment name (dev, qa, prod) |
| `TAG` | `latest` | Default image tag |
| `SERVICE` | `registry` | Service name |
| `STACK_NAME` | `registry` | Stack name in Docker Swarm |
| `REGISTRY_HOST` | `10.10.1.2` | Registry server IP address |
| `REGISTRY_PORT` | `5000` | Registry HTTP port |
| `PROJECTS_DIR` | `$HOME/projects/itv` | Base projects directory |
| `GIT_BRANCH` | `dev` | Git branch for deployment |
| `GIT_BRANCH_DEVOPS` | `devops` | DevOps git branch |
| `DEPLOY_INCLUDES` | `*` | Files to include in deployment |
| `DEPLOY_EXCLUDES` | `""` | Files to exclude from deployment |

**Override examples:**

```bash
# Use different registry
make registry-list REGISTRY_HOST=192.168.1.100 REGISTRY_PORT=5001

# Deploy to production
make stack-deploy ENV=prod TAG=v2.0.0

# Scale production service
make service-scale ENV=prod REPLICAS=5
```

## Best Practices

1. **Always run GC after deletion** - Storage won't be reclaimed until GC runs
2. **Use dry-run first** - Test GC with `--dry-run` before production runs
3. **Tag validation** - Verify manifests before attempting API deletion
4. **Backup important images** - Pull critical images before cleanup
5. **Monitor storage** - Check `registry-info` regularly
6. **Schedule GC** - Run during off-peak hours
7. **Keep versions** - Use `registry-remove-old` instead of removing all tags

## API vs Filesystem Operations

| Operation | Method | Use Case |
|-----------|--------|----------|
| `registry-remove-tag` | API | Remove specific valid tag |
| `registry-remove-image` | API + Filesystem | Remove all tags (auto-detects method) |
| `registry-remove-old` | API | Keep N latest, remove older tags |
| `registry-cleanup-orphaned` | Filesystem | Fix orphaned tags only |
| `registry-cleanup-repo` | Filesystem | Force remove entire repository |

## Registry Configuration Requirements

Your registry must have deletion enabled in `docker-compose.yml`:

```yaml
environment:
  REGISTRY_STORAGE_DELETE_ENABLED: "true"
```

Without this setting, API deletions will fail.

## License

This Makefile is provided as-is for Docker Registry management in Docker Swarm environments.

## Contributing

Improvements and bug fixes are welcome. Please test thoroughly before deploying to production.

---

**Need help?** Run `make help` to see all available commands.
