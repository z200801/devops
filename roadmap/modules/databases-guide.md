# SQL та Бази Даних

## Основи SQL

### CREATE та ALTER
```sql
-- Створення бази даних
CREATE DATABASE shop;

-- Створення таблиці
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Модифікація таблиці
ALTER TABLE products ADD COLUMN category VARCHAR(50);
ALTER TABLE products ALTER COLUMN price TYPE NUMERIC(12,2);
```

### SELECT та JOIN
```sql
-- Базовий select
SELECT * FROM products WHERE price > 100;

-- JOIN операції
SELECT o.id, p.name, o.quantity
FROM orders o
INNER JOIN products p ON o.product_id = p.id;

-- Групування та агрегація
SELECT category, COUNT(*), AVG(price)
FROM products
GROUP BY category
HAVING COUNT(*) > 5;
```

### INSERT, UPDATE, DELETE
```sql
-- Вставка даних
INSERT INTO products (name, price) VALUES ('Phone', 999.99);

-- Оновлення
UPDATE products SET price = price * 1.1 WHERE category = 'Electronics';

-- Видалення
DELETE FROM products WHERE price < 10;
```

## MySQL vs PostgreSQL

### MySQL особливості
```sql
-- Auto Increment
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100)
);

-- Типи даних
CREATE TABLE events (
    id INT AUTO_INCREMENT PRIMARY KEY,
    data JSON,
    created DATETIME
);
```

### PostgreSQL особливості
```sql
-- Наслідування таблиць
CREATE TABLE cities (
    name TEXT,
    population INTEGER
);

CREATE TABLE capitals (
    country TEXT
) INHERITS (cities);

-- JSON операції
CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    data JSONB,
    created_at TIMESTAMPTZ
);

SELECT data->>'name' FROM events;
```

## Адміністрування

### Backup та Restore
```bash
# MySQL
mysqldump -u user -p database > backup.sql
mysql -u user -p database < backup.sql

# PostgreSQL
pg_dump -U user database > backup.sql
psql -U user database < backup.sql
```

### Користувачі та Права
```sql
-- MySQL
CREATE USER 'app_user'@'localhost' IDENTIFIED BY 'password';
GRANT SELECT, INSERT ON database.* TO 'app_user'@'localhost';

-- PostgreSQL
CREATE USER app_user WITH PASSWORD 'password';
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA public TO app_user;
```

## Оптимізація

### Індекси
```sql
-- Створення індексів
CREATE INDEX idx_name ON products(name);
CREATE INDEX idx_price_category ON products(price, category);

-- Аналіз запитів
EXPLAIN SELECT * FROM products WHERE price > 100;
```

### Партиціонування
```sql
-- MySQL
CREATE TABLE orders (
    id INT,
    created_at DATE
) PARTITION BY RANGE (YEAR(created_at)) (
    PARTITION p2020 VALUES LESS THAN (2021),
    PARTITION p2021 VALUES LESS THAN (2022)
);

-- PostgreSQL
CREATE TABLE orders (
    id SERIAL,
    created_at DATE
) PARTITION BY RANGE (created_at);

CREATE TABLE orders_2020 PARTITION OF orders
    FOR VALUES FROM ('2020-01-01') TO ('2021-01-01');
```

## Практичні завдання

### 1. Проектування
- Створити схему бази даних
- Налаштувати зв'язки
- Оптимізувати структуру
- Створити індекси

### 2. Адміністрування
- Налаштувати бекапи
- Керувати користувачами
- Моніторити продуктивність
- Оптимізувати запити

### 3. Міграції
- Створити міграції
- Версіонування схеми
- Автоматизація оновлень
- Відкат змін