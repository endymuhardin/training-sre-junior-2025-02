#!/bin/bash
# Build custom pg_auto_failover image with PostgreSQL 17
# This is required because official Docker images only go up to PostgreSQL 15

set -e

echo "=============================================="
echo "Building pg_auto_failover with PostgreSQL 17"
echo "=============================================="
echo

# Clone the repository
if [ ! -d "/tmp/pg_auto_failover" ]; then
    echo "📥 Cloning pg_auto_failover repository..."
    cd /tmp
    git clone --depth 1 https://github.com/citusdata/pg_auto_failover.git
else
    echo "✅ Repository already cloned"
fi

# Build the image
echo
echo "🔨 Building Docker image (this may take 5-10 minutes)..."
cd /tmp/pg_auto_failover

# Create git-version.h if it doesn't exist (required for build)
if [ ! -f "src/bin/pg_autoctl/git-version.h" ]; then
    echo "📝 Creating git-version.h..."
    echo '#define GIT_VERSION "unknown"' > src/bin/pg_autoctl/git-version.h
fi

podman build --platform linux/amd64 -t pg_auto_failover:pg17 -f Dockerfile .

echo
echo "✅ Build complete!"
echo "Image: pg_auto_failover:pg17"
echo
echo "You can now run: podman compose up -d"
