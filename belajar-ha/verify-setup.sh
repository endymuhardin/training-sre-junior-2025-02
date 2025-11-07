#!/bin/bash

# Pre-workshop verification script
# Run this before the workshop to ensure everything is ready

set -e

echo "=========================================="
echo "High Availability Workshop Setup Verification"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

passed=0
failed=0

check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
        ((passed++))
    else
        echo -e "${RED}✗ $1${NC}"
        ((failed++))
    fi
}

# Check 1: Docker installed
echo "Checking prerequisites..."
echo ""

docker --version > /dev/null 2>&1
check "Docker installed"

docker compose version > /dev/null 2>&1
check "Docker Compose installed"

# Check 2: Docker daemon running
docker ps > /dev/null 2>&1
check "Docker daemon running"

# Check 3: Required ports available
ports=(8080 8404 5432 5433 5434 6432)
for port in "${ports[@]}"; do
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${RED}✗ Port $port is in use${NC}"
        ((failed++))
    else
        echo -e "${GREEN}✓ Port $port available${NC}"
        ((passed++))
    fi
done

# Check 4: Required files exist
echo ""
echo "Checking demo files..."
echo ""

files=(
    "demo-1-stateless-ha/docker-compose-1.yml"
    "demo-1-stateless-ha/docker-compose-2.yml"
    "demo-1-stateless-ha/haproxy.cfg"
    "demo-1-stateless-ha/load-test.sh"
    "demo-2-stateful-ha/docker-compose.yml"
    "demo-2-stateful-ha/test-replication.sh"
    "demo-2-stateful-ha/generate-load.sh"
)

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ $file exists${NC}"
        ((passed++))
    else
        echo -e "${RED}✗ $file missing${NC}"
        ((failed++))
    fi
done

# Check 5: Scripts are executable
echo ""
echo "Checking script permissions..."
echo ""

scripts=(
    "demo-1-stateless-ha/load-test.sh"
    "demo-2-stateful-ha/test-replication.sh"
    "demo-2-stateful-ha/generate-load.sh"
    "demo-2-stateful-ha/promote-replica.sh"
)

for script in "${scripts[@]}"; do
    if [ -x "$script" ]; then
        echo -e "${GREEN}✓ $script is executable${NC}"
        ((passed++))
    else
        echo -e "${YELLOW}⚠ $script not executable, fixing...${NC}"
        chmod +x "$script"
        ((passed++))
    fi
done

# Check 6: Docker resources
echo ""
echo "Checking Docker resources..."
echo ""

memory=$(docker system info 2>/dev/null | grep "Total Memory" | awk '{print $3}' | sed 's/GiB//')
if [ -n "$memory" ]; then
    if (( $(echo "$memory >= 4" | bc -l) )); then
        echo -e "${GREEN}✓ Docker memory: ${memory}GiB (sufficient)${NC}"
        ((passed++))
    else
        echo -e "${YELLOW}⚠ Docker memory: ${memory}GiB (recommend 4GB+)${NC}"
        ((failed++))
    fi
else
    echo -e "${YELLOW}⚠ Could not check Docker memory${NC}"
fi

# Check 7: Disk space
echo ""
echo "Checking disk space..."
echo ""

if [ "$(uname)" == "Darwin" ]; then
    free_space=$(df -g . | awk 'NR==2 {print $4}')
else
    free_space=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
fi

if [ -n "$free_space" ] && [ "$free_space" -ge 10 ]; then
    echo -e "${GREEN}✓ Disk space: ${free_space}GB available${NC}"
    ((passed++))
else
    echo -e "${YELLOW}⚠ Disk space: ${free_space}GB (recommend 10GB+)${NC}"
    ((failed++))
fi

# Check 8: Pull required images (optional)
echo ""
echo "Checking Docker images..."
echo ""

images=(
    "haproxy:2.9-alpine"
    "nginx:alpine"
    "postgres:16-alpine"
    "edoburu/pgbouncer:latest"
)

echo "Pre-pulling images (this may take a few minutes)..."
for image in "${images[@]}"; do
    if docker pull "$image" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ $image pulled${NC}"
        ((passed++))
    else
        echo -e "${RED}✗ Failed to pull $image${NC}"
        ((failed++))
    fi
done

# Summary
echo ""
echo "=========================================="
echo "Verification Summary"
echo "=========================================="
echo -e "${GREEN}Passed: $passed${NC}"
echo -e "${RED}Failed: $failed${NC}"
echo ""

if [ $failed -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Ready for workshop.${NC}"
    echo ""
    echo "Quick start commands:"
    echo "  Demo 1: cd demo-1-stateless-ha && docker compose -f docker-compose-1.yml up -d"
    echo "  Demo 2: cd demo-2-stateful-ha && docker compose up -d"
    exit 0
else
    echo -e "${YELLOW}⚠ Some checks failed. Please fix issues before workshop.${NC}"
    echo ""
    echo "Common fixes:"
    echo "  - Free up ports: lsof -i :<port> and kill process"
    echo "  - Increase Docker memory: Docker Desktop → Settings → Resources"
    echo "  - Free disk space: docker system prune -a"
    exit 1
fi
