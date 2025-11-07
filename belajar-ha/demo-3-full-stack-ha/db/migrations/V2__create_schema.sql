-- Create demo table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert initial sample data
INSERT INTO users (name, email) VALUES
    ('Alice Admin', 'alice@example.com'),
    ('Bob Builder', 'bob@example.com'),
    ('Charlie Chef', 'charlie@example.com'),
    ('Diana Developer', 'diana@example.com'),
    ('Eve Engineer', 'eve@example.com');

-- Grant permissions to app_user on demodb
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO app_user;
GRANT USAGE, CREATE ON SCHEMA public TO app_user;

-- Set default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO app_user;
