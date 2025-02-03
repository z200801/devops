# SQL Basic Commands Reference

## DDL (Data Definition Language)

### CREATE

```sql
-- База даних
CREATE DATABASE shop;

-- Таблиця
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    price DECIMAL(10,2),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Індекс
CREATE INDEX idx_name ON products(name);

-- View
CREATE VIEW expensive_products AS
SELECT * FROM products WHERE price > 1000;
```

### ALTER

```sql
-- Додати колонку
ALTER TABLE products ADD COLUMN category VARCHAR(50);

-- Змінити тип
ALTER TABLE products ALTER COLUMN price TYPE NUMERIC(12,2);

-- Додати обмеження
ALTER TABLE products ADD CONSTRAINT price_positive CHECK (price > 0);
```

### DROP

```sql
DROP TABLE products;
DROP DATABASE shop;
DROP INDEX idx_name;
```

## DML (Data Manipulation Language)

### SELECT

```sql
-- Базовий select
SELECT * FROM products;

-- З умовою
SELECT name, price FROM products WHERE price > 100;

-- Сортування
SELECT * FROM products ORDER BY price DESC;

-- Групування
SELECT category, COUNT(*), AVG(price)
FROM products
GROUP BY category
HAVING COUNT(*) > 5;

-- Joins
SELECT o.id, p.name, o.quantity
FROM orders o
INNER JOIN products p ON o.product_id = p.id;
```

### INSERT

```sql
-- Один запис
INSERT INTO products (name, price) VALUES ('Phone', 999.99);

-- Множинний insert
INSERT INTO products (name, price) VALUES 
    ('Laptop', 1299.99),
    ('Mouse', 49.99);

-- Insert з select
INSERT INTO premium_products
SELECT * FROM products WHERE price > 1000;
```

### UPDATE

```sql
-- Простий update
UPDATE products SET price = 899.99 WHERE id = 1;

-- Множинний update
UPDATE products 
SET price = price * 1.1
WHERE category = 'Electronics';
```

### DELETE

```sql
-- Видалити записи
DELETE FROM products WHERE price < 10;

-- Очистити таблицю
TRUNCATE TABLE products;
```

## DCL (Data Control Language)

### Користувачі та права

```sql
-- Створити користувача
CREATE USER 'shop_admin'@'localhost' IDENTIFIED BY 'password';

-- Надати права
GRANT SELECT, INSERT ON shop.products TO 'shop_admin'@'localhost';

-- Забрати права
REVOKE INSERT ON shop.products FROM 'shop_admin'@'localhost';
```

## TCL (Transaction Control Language)

### Транзакції

```sql
-- Почати транзакцію
BEGIN TRANSACTION;

-- Зберегти зміни
COMMIT;

-- Відкатити зміни
ROLLBACK;

-- Створити точку збереження
SAVEPOINT my_savepoint;
ROLLBACK TO my_savepoint;
```

## Корисні функції

### Агрегація

```sql
SELECT 
    COUNT(*) as total_count,
    SUM(price) as total_price,
    AVG(price) as avg_price,
    MIN(price) as min_price,
    MAX(price) as max_price
FROM products;
```

### Строкові функції

```sql
SELECT 
    UPPER(name),
    LOWER(name),
    LENGTH(name),
    SUBSTRING(name, 1, 3),
    CONCAT(name, ' - ', category)
FROM products;
```

### Дата і час

```sql
SELECT 
    CURRENT_DATE,
    CURRENT_TIMESTAMP,
    DATE_TRUNC('month', created_at),
    EXTRACT(YEAR FROM created_at)
FROM orders;
```
