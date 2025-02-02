#!/bin/bash

# Constants
readonly VERSION_DIR="versions"
readonly ENV_FILE=".env"

# Load and export environment variables
if [[ -f "${ENV_FILE}" ]]; then
	set -a # automatically export all variables
	# shellcheck source=/dev/null
	source "${ENV_FILE}"
	set +a # stop automatically exporting
else
	echo "Error: .env file not found"
	exit 1
fi

# Docker compose with project name and env file
readonly DOCKER_COMPOSE="docker compose --env-file ${ENV_FILE} -p ${STACK_NAME}"

function create_version() {
	local new_version="$1"

	# Create new version directory
	if [[ -d "${VERSION_DIR}/${new_version}" ]]; then
		echo "Error: Version ${new_version} already exists"
		exit 1
	fi

	mkdir -p "${VERSION_DIR}/${new_version}/backend"
	cp backend/main.py "${VERSION_DIR}/${new_version}/backend/"

	# Update .env file
	sed -i "s/STACK_VERSION=.*/STACK_VERSION=${new_version}/" "${ENV_FILE}"

	echo "Created new version ${new_version}"
}

function set_version() {
	local target_version="$1"

	# Check if version exists
	if [[ ! -d "${VERSION_DIR}/${target_version}" ]]; then
		echo "Error: Version ${target_version} not found"
		exit 1
	fi

	# Create backup of current files
	local timestamp
	timestamp="$(date +%Y%m%d_%H%M%S)"

	# Backup main.py if exists
	if [[ -f "backend/main.py" ]]; then
		echo "Creating backup of current files..."
		cp backend/main.py "backend/main.py.${timestamp}.bak"
	fi

	# Copy files from version directory
	echo "Copying files from version ${target_version}..."
	cp -r "${VERSION_DIR}/${target_version}/backend/"* backend/

	# Update .env file
	sed -i "s/STACK_VERSION=.*/STACK_VERSION=${target_version}/" "${ENV_FILE}"

	echo "Current version set to ${target_version}"
	echo "Backup created: main.py.${timestamp}.bak"
}

function rollback() {
	local target_version="$1"

	if [[ ! -d "${VERSION_DIR}/${target_version}" ]]; then
		echo "Error: Version ${target_version} not found"
		exit 1
	fi

	# Backup current version
	local timestamp
	timestamp="$(date +%Y%m%d_%H%M%S)"
	cp backend/main.py "backend/main.py.${timestamp}.bak"

	# Copy target version files
	cp "${VERSION_DIR}/${target_version}/backend/main.py" backend/main.py

	# Update .env file
	sed -i "s/STACK_VERSION=.*/STACK_VERSION=${target_version}/" "${ENV_FILE}"

	# Restart services
	${DOCKER_COMPOSE} down backend
	${DOCKER_COMPOSE} up -d backend

	echo "Rolled back to version ${target_version}"
}

function check_health() {
	echo "Checking services health..."
	${DOCKER_COMPOSE} ps

	# Wait for services to be healthy
	local attempts=0
	local -r max_attempts=12

	while [[ ${attempts} -lt ${max_attempts} ]]; do
		if curl -s "http://localhost:${APP_PORT}/health" >/dev/null; then
			echo "Services are healthy"
			return 0
		fi
		attempts=$((attempts + 1))
		echo "Waiting for services to be healthy... (${attempts}/${max_attempts})"
		sleep 5
	done

	echo "Services health check failed"
	return 1
}

function restart_service() {
	local service_name="$1"
	echo "Restarting service: ${service_name}..."
	${DOCKER_COMPOSE} restart "${service_name}"
	echo "Service ${service_name} restarted"
	check_health
}

# Script usage
case "$1" in
"create")
	if [[ -z "$2" ]]; then
		echo "Usage: $0 create <version>"
		exit 1
	fi
	create_version "$2"
	;;
"set")
	if [[ -z "$2" ]]; then
		echo "Usage: $0 set <version>"
		exit 1
	fi
	set_version "$2"
	;;
"rollback")
	if [[ -z "$2" ]]; then
		echo "Usage: $0 rollback <version>"
		exit 1
	fi
	rollback "$2"
	check_health
	;;
"restart")
	if [[ -z "$2" ]]; then
		echo "Restarting backend service..."
		restart_service "backend"
	else
		restart_service "$2"
	fi
	;;
"list")
	echo "Available versions:"
	find "${VERSION_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -V
	echo "Current version: ${STACK_VERSION}"
	echo "Stack name: ${STACK_NAME}"
	;;
"ps")
	${DOCKER_COMPOSE} ps
	;;
"logs")
	${DOCKER_COMPOSE} logs -f
	;;
*)
	echo "Usage: $0 {create|set|rollback|restart|list|ps|logs} [version]"
	exit 1
	;;
esac
