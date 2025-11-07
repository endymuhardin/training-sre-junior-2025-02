-- Create app_user jika belum ada, atau update password jika sudah ada
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'app_user') THEN
        CREATE USER app_user WITH PASSWORD 'app_password';
    ELSE
        ALTER USER app_user WITH PASSWORD 'app_password';
    END IF;
END
$$;

-- Grant permissions ke app_user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO app_user;
GRANT USAGE, CREATE ON SCHEMA public TO app_user;

-- Set default privileges untuk tabel yang akan dibuat
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO app_user;
