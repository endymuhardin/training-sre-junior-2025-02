#!/bin/bash

# Comprehensive full-stack HA test

echo "=========================================="
echo "Full Stack HA Test Suite"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

BASE_URL="http://localhost:8080"

echo "1. Testing Application Accessibility..."
echo "========================================"
response=$(curl -s -w "%{http_code}" -o /dev/null $BASE_URL)
if [ "$response" = "200" ]; then
    echo -e "${GREEN}✓ Application is accessible${NC}"
else
    echo -e "${RED}✗ Application not accessible (HTTP $response)${NC}"
fi
echo ""

echo "2. Testing Health Endpoints..."
echo "========================================"
health=$(curl -s $BASE_URL/health)
echo "$health" | python3 -m json.tool 2>/dev/null || echo "$health"
echo ""

echo "3. Testing Database Statistics..."
echo "========================================"
stats=$(curl -s $BASE_URL/api/stats)
echo "$stats" | python3 -m json.tool 2>/dev/null || echo "$stats"
echo ""

echo "4. Testing User List (Read from Replica)..."
echo "========================================"
users=$(curl -s $BASE_URL/api/users)
echo "$users" | python3 -m json.tool 2>/dev/null | head -20
echo ""

echo "5. Testing User Creation (Write to Primary)..."
echo "========================================"
timestamp=$(date +%s)
new_user=$(curl -s -X POST $BASE_URL/api/users \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"TestUser_$timestamp\",\"email\":\"test_$timestamp@example.com\"}")
echo "$new_user" | python3 -m json.tool 2>/dev/null || echo "$new_user"
echo ""

echo "6. Verifying PostgreSQL Replication..."
echo "========================================"
echo "Primary status:"
docker exec postgres-primary psql -U postgres -c "SELECT application_name, state, sync_state FROM pg_stat_replication;" 2>/dev/null || echo "Primary not accessible"
echo ""

echo "Replica status:"
docker exec postgres-replica1 psql -U postgres -c "SELECT pg_is_in_recovery(), now() - pg_last_xact_replay_timestamp() AS lag;" 2>/dev/null || echo "Replica not accessible"
echo ""

echo "7. Checking HAProxy Status..."
echo "========================================"
echo "VIP ownership:"
haproxy1_vip=$(docker exec haproxy1 ip addr show eth0 2>/dev/null | grep -c "172.30.0.100")
haproxy2_vip=$(docker exec haproxy2 ip addr show eth0 2>/dev/null | grep -c "172.30.0.100")

if [ "$haproxy1_vip" -gt 0 ]; then
    echo -e "${GREEN}✓ haproxy1 owns VIP (MASTER)${NC}"
elif [ "$haproxy2_vip" -gt 0 ]; then
    echo -e "${GREEN}✓ haproxy2 owns VIP (MASTER)${NC}"
else
    echo -e "${RED}✗ No HAProxy owns VIP!${NC}"
fi
echo ""

echo "8. Testing Load Distribution..."
echo "========================================"
echo "Making 10 requests to see load distribution..."
declare -A counts
for i in {1..10}; do
    instance=$(curl -s $BASE_URL/api/stats | python3 -c "import sys, json; print(json.load(sys.stdin)['app_instance'])" 2>/dev/null)
    if [ -n "$instance" ]; then
        counts[$instance]=$((${counts[$instance]:-0} + 1))
        echo "Request $i: $instance"
    fi
    sleep 0.2
done
echo ""
echo "Distribution:"
for instance in "${!counts[@]}"; do
    echo "  $instance: ${counts[$instance]} requests"
done
echo ""

echo "=========================================="
echo "Test Suite Complete!"
echo "=========================================="
echo ""
echo "Quick access URLs:"
echo "  Application: $BASE_URL"
echo "  HAProxy Stats: http://localhost:8404"
echo ""
