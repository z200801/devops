# FastAPI Application with Version Control System

A containerized FastAPI application with Nginx reverse proxy and built-in version control system.

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
├── .env                  # Environment variables
├── .env.example          # Example environment file
└── rollback.sh          # Version control and rollback script
```

## Prerequisites

* Docker
* Docker Compose
* Bash shell
* curl (for testing)

## Installation and Setup

1. Clone the repository:

```bash
git clone <repository-url>
cd <project-directory>
```

2. Configure environment:

```bash
cp .env.example .env
# Edit .env file according to your needs
```

3. Make the rollback script executable:

```bash
chmod +x rollback.sh
```

4. Create initial version:

```bash
./rollback.sh create 1.0.0
```

5. Start the application:

```bash
export STACK_NAME=$(grep -E '^STACK_NAME=' .env | cut -d '=' -f2-)
docker compose --env-file .env -p ${STACK_NAME} up -d
```

## Version Control System Usage

### Available Commands

1. Create a new version:

```bash
./rollback.sh create <version>
```

2. Set current version (without restart):

```bash
./rollback.sh set <version>
```

3. Rollback to specific version:

```bash
./rollback.sh rollback <version>
```

4. Restart services:

```bash
# Restart backend
./rollback.sh restart

# Restart specific service
./rollback.sh restart nginx
```

5. List versions:

```bash
./rollback.sh list
```

6. Check services status:

```bash
./rollback.sh ps
```

7. View logs:

```bash
./rollback.sh logs
```

## Environment Variables

Example of `.env` file:

```env
# Stack configuration
STACK_NAME=myapp
STACK_VERSION=1.0.0

# Images versions
NGINX_VERSION=alpine-slim
BACKEND_VERSION=python3.11-slim

# Application settings
APP_PORT=8000
BACKEND_HOST=0.0.0.0
BACKEND_PORT=80

# Resource limits
NGINX_CPU_LIMIT=0.5
NGINX_MEM_LIMIT=16M
NGINX_CPU_RESERVATION=0.25
NGINX_MEM_RESERVATION=8M

BACKEND_CPU_LIMIT=0.5
BACKEND_MEM_LIMIT=196M
BACKEND_CPU_RESERVATION=0.25
BACKEND_MEM_RESERVATION=128M

# Scale settings
BACKEND_REPLICAS=2
```

## API Endpoints

### Root Endpoint

```bash
curl http://localhost:8000/
```

Response:

```json
{
    "message": "Hello from Backend!",
    "hostname": "container-id",
    "version": "1.0.0"
}
```

### Health Check

```bash
curl http://localhost:8000/health
```

Response:

```json
{
    "status": "ok",
    "version": "1.0.0"
}
```

## Development Workflow

1. Create initial version:

```bash
./rollback.sh create 1.0.0
```

2. Make changes to `backend/main.py`

3. Create new version:

```bash
./rollback.sh create 1.0.1
```

4. Test changes:

```bash
curl http://localhost:8000/
```

5. If something goes wrong, rollback:

```bash
./rollback.sh rollback 1.0.0
```

## Troubleshooting

### Common Issues

1. Permission denied:

```bash
chmod +x rollback.sh
```

2. Services not starting:

```bash
./rollback.sh ps
./rollback.sh logs
```

3. Version not found:

```bash
./rollback.sh list  # Check available versions
```

### Backup Recovery

Backups are created automatically during rollback operations and stored with timestamps in the format `main.py.YYYYMMDD_HHMMSS.bak`.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

[Your Name]
[Your Email]
[Your Website/Github]
