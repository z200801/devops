#!/bin/bash

VERSION_DIR="versions"
CURRENT_VERSION=$(readlink ${VERSION_DIR}/current)

function create_version() {
    local new_version=$1
    
    # Перевірка наявності версії
    if [ -d "${VERSION_DIR}/${new_version}" ]; then
        echo "Error: Version ${new_version} already exists"
        exit 1
    fi
    
    # Створення нової версії
    mkdir -p "${VERSION_DIR}/${new_version}/backend"
    cp backend/main.py "${VERSION_DIR}/${new_version}/backend/"
    
    # Оновлення символічного посилання
    ln -sf "${new_version}" "${VERSION_DIR}/current"
    
    echo "Created new version ${new_version}"
}

function rollback() {
    local target_version=$1
    
    # Перевірка існування версії
    if [ ! -d "${VERSION_DIR}/${target_version}" ]; then
        echo "Error: Version ${target_version} not found"
        exit 1
    fi
    
    # Зберігаємо поточний стан
    local timestamp=$(date +%Y%m%d_%H%M%S)
    cp backend/main.py "backend/main.py.${timestamp}.bak"
    
    # Копіюємо файл потрібної версії
    cp "${VERSION_DIR}/${target_version}/backend/main.py" backend/main.py
    
    # Оновлюємо символічне посилання
    ln -sf "${target_version}" "${VERSION_DIR}/current"
    
    # Перезапускаємо сервіси
     docker compose down backend
     docker compose up -d backend
    
    echo "Rolled back to version ${target_version}"
}

# Використання скрипта
case "$1" in
    "create")
        if [ -z "$2" ]; then
            echo "Usage: $0 create <version>"
            exit 1
        fi
        create_version "$2"
        ;;
    "rollback")
        if [ -z "$2" ]; then
            echo "Usage: $0 rollback <version>"
            exit 1
        fi
        rollback "$2"
        ;;
    "list")
        echo "Available versions:"
        ls -l ${VERSION_DIR} | grep '^d' | awk '{print $9}'
        echo "Current version: ${CURRENT_VERSION}"
        ;;
    *)
        echo "Usage: $0 {create|rollback|list} [version]"
        exit 1
        ;;
esac

