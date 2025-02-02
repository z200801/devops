# FastAPI Backend Application with Rollback System

This project demonstrates a containerized FastAPI application with Nginx reverse proxy and a version control system for easy rollbacks.

## Project Structure

```sh
project/
├── versions/              # Stores different versions of backend code
│   ├── 1.0.0/
│   │   └── backend/
│   │       └── main.py
│   └── 1.0.1/
│       └── backend/
│           └── main.py
├── docker-compose.yml     # Docker services configuration
├── nginx/                 # Nginx configuration
│   └── nginx.conf
├── backend/              # FastAPI application
│   └── main.py
└── rollback.sh          # Version control and rollback script
```

## Prerequisites

- Docker
- Docker Compose
- Bash shell
- curl (for testing)

## Installation

First, clone the repository:
`git clone <repository-url> cd <project-directory>`

Make the rollback script executable:

`chmod +x rollback.sh`

Start the services:

`docker-compose up -d`

## Version Control System

The project includes a version control system for the backend code.
The `rollback.sh` script provides the following functionality:

### Create a new version

`./rollback.sh create <version> # Example: ./rollback.sh create 1.0.0`

### List all versions

`./rollback.sh list`

### Rollback to a specific version

`./rollback.sh rollback <version> # Example: ./rollback.sh rollback 1.0.0`

## Docker Services

### Backend (FastAPI)

- Image: tiangolo/uvicorn-gunicorn-fastapi:python3.11-slim
- Replicated mode with 2 instances
- Resource limits:
  - CPU: 0.5
  - Memory: 196M
- Health checks and automatic restarts configured

### Nginx

- Image: nginx:alpine-slim
- Acts as a reverse proxy for the backend
- Resource limits:
  - CPU: 0.5
  - Memory: 16M

## Testing the Application

Check if the application is running:

`curl http://localhost:8000`

Monitor service status:

`docker-compose ps`

View logs:

`docker-compose logs -f`

## Rollback Process Example

Save current version:

`./rollback.sh create 1.0.0`

Make changes to `backend/main.py`

Save new version:

`./rollback.sh create 1.0.1`

If issues occur, rollback to previous version:

`./rollback.sh rollback 1.0.0`

## Development

### Adding New Endpoints

1. Modify `backend/main.py`
2. Create a new version using the rollback script
3. Test the new endpoint
4. If issues occur, use the rollback script to revert changes

### Modifying Nginx Configuration

1. Edit `nginx/nginx.conf`
2. Restart the nginx service:

`docker-compose restart nginx`

## Troubleshooting

### Common Issues

Service not starting:

`docker-compose ps docker-compose logs <service-name>`

Rollback script errors:

- Check if the version exists
- Ensure proper permissions
- Check service logs after rollback

### Backup Recovery

Backups are stored with timestamps when performing rollbacks. To restore from a backup:

1. Check the backup directory
2. Copy the desired backup file
3. Restart the services

## Contributing

4. Fork the repository
5. Create a feature branch
6. Commit your changes
7. Push to the branch
8. Create a Pull Request
