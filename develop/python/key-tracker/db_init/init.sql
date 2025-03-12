CREATE USER user_key WITH PASSWORD 'user_key_password';
ALTER ROLE user_key SET client_encoding TO 'utf8';
ALTER ROLE user_key SET default_transaction_isolation TO 'read committed';
ALTER ROLE user_key SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE db_keys TO user_key;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO user_key;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO user_key;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA public TO user_key;
GRANT CREATE ON DATABASE db_keys TO user_key;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO user_key;


GRANT ALL PRIVILEGES ON SCHEMA public TO user_key;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO user_key;
ALTER USER user_key WITH CREATEDB;

