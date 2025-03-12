#!/bin/bash

# Add the app directory to Python path
export PYTHONPATH=$PYTHONPATH:/app

# Parse command line arguments
MIGRATIONS_ONLY=false

for arg in "$@"; do
	case $arg in
	--migrations)
		MIGRATIONS_ONLY=true
		shift # Remove --migrations from processing
		;;
	*)
		# Unknown option
		;;
	esac
done

# Function to check if running as root
is_root() {
	[ "$(id -u)" -eq 0 ]
}

# Function to check if the database is accessible
check_database_connection() {
	echo "Waiting for database connection to ${DB_HOST}:${DB_PORT}..."

	if [ "$DB_TYPE" = "postgresql" ]; then
		until PGPASSWORD=${DB_PASSWORD} psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT 1" >/dev/null 2>&1; do
			echo "Waiting for PostgreSQL connection..."
			sleep 2
		done
	else
		echo "Error: Unsupported database type (${DB_TYPE})"
		exit 1
	fi

	echo "Database is available"
}

# Function to run database migrations (requires root privileges)
run_migrations() {
	if is_root; then
		if [ -d "/app/alembic" ] && command -v alembic &>/dev/null; then
			echo "Running Alembic migrations as root..."
			cd /app
			alembic upgrade head
			if [ $? -eq 0 ]; then
				echo "Migrations completed successfully"
			else
				echo "Migrations failed, falling back to SQLAlchemy table creation"
				create_tables_with_sqlalchemy
			fi
		else
			echo "Alembic not found or not configured, creating tables with SQLAlchemy..."
			create_tables_with_sqlalchemy
		fi
	else
		echo "Not running as root, skipping migrations (will use existing database schema)"
		# We can still check if tables exist using SQLAlchemy without creating them
		python -c "
from app.database import engine
from sqlalchemy import inspect
inspector = inspect(engine)
tables = inspector.get_table_names()
print(f'Found {len(tables)} tables in the database')
"
	fi
}

# Function to create database tables using SQLAlchemy
create_tables_with_sqlalchemy() {
	python -c "
from app.database import Base, engine
Base.metadata.create_all(bind=engine)
print('Database tables created successfully')
"
}

# Function to start the FastAPI server
start_fastapi_server() {
	echo "Starting FastAPI server..."
	cd /app

	if is_root; then
		echo "Switching from root to appuser for running the application"
		exec su -s /bin/bash appuser -c "cd /app && PYTHONPATH=$PYTHONPATH uvicorn main:app --host 0.0.0.0 --port 8000 --reload"
	else
		exec uvicorn main:app --host 0.0.0.0 --port 8000 --reload
	fi
}

# Main function to orchestrate the startup process
main() {
	# Check if environment variables are set
	if [ -z "${DB_HOST}" ] || [ -z "${DB_PORT}" ] || [ -z "${DB_NAME}" ] || [ -z "${DB_USER}" ] || [ -z "${DB_PASSWORD}" ]; then
		echo "Error: One or more database settings are not defined!"
		exit 1
	fi

	# Run the startup sequence
	check_database_connection
	run_migrations

	# If --migrations flag is provided, exit after migrations
	if [ "$MIGRATIONS_ONLY" = true ]; then
		echo "Migrations completed. Exiting without starting the server (--migrations flag detected)."
		exit 0
	fi

	# Otherwise continue with server startup
	start_fastapi_server
}

# Execute the main function
main
