#!/bin/bash
set -e

# Create replication user
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD 'replicator123';

    -- Create demo table
    CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100),
        email VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- Insert sample data
    INSERT INTO users (name, email) VALUES
        ('Alice', 'alice@example.com'),
        ('Bob', 'bob@example.com'),
        ('Charlie', 'charlie@example.com');

    -- Create replication slot for replica
    SELECT pg_create_physical_replication_slot('replica1_slot');

    GRANT ALL PRIVILEGES ON DATABASE demodb TO postgres;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;

    -- Display initial data
    SELECT 'Primary initialized with ' || COUNT(*) || ' users' FROM users;
EOSQL

echo "Primary database initialized successfully"
