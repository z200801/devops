# Git

## Основні команди

### Налаштування
```bash
# Глобальні налаштування
git config --global user.name "Your Name"
git config --global user.email "email@example.com"

# Ініціалізація репозиторію
git init
git clone https://github.com/user/repo.git
```

### Базові операції
```bash
# Статус та додавання файлів
git status
git add file.txt
git add .

# Коміти
git commit -m "Initial commit"
git commit -am "Add and commit"

# Історія
git log
git log --oneline --graph
```

### Гілки
```bash
# Створення та перемикання
git branch feature
git checkout feature
git checkout -b feature

# Злиття
git merge feature
git rebase master

# Видалення
git branch -d feature
git branch -D feature
```

## Робота з віддаленим репозиторієм

### Основні операції
```bash
# Додавання remote
git remote add origin https://github.com/user/repo.git
git remote -v

# Синхронізація
git fetch origin
git pull origin master
git push origin master
```

### Pull Requests
1. Fork репозиторію
2. Клонування fork
3. Створення гілки
4. Внесення змін
5. Push змін
6. Створення PR

## Git Flow

### Структура гілок
- master (production)
- develop
- feature/*
- release/*
- hotfix/*

### Приклад workflow
```bash
# Початок feature
git flow feature start my-feature

# Завершення feature
git flow feature finish my-feature

# Реліз
git flow release start 1.0.0
git flow release finish 1.0.0
```

## Практичні завдання

### 1. Базові операції
- Створити репозиторій
- Додати файли
- Створити коміти
- Переглянути історію

### 2. Гілки
- Створити feature branch
- Внести зміни
- Вирішити конфлікти
- Злити зміни

### 3. Командна робота
- Fork репозиторію
- Створити PR
- Code review
- Merge PR

### 4. Git Flow
- Налаштувати Git Flow
- Провести повний цикл
- Зробити реліз
- Виправити помилки