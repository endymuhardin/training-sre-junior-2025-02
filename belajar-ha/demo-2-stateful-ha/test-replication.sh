#!/bin/bash

# Script to test PostgreSQL replication

echo "=========================================="
echo "PostgreSQL Replication Test"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to run query on a specific host
run_query() {
    local host=$1
    local port=$2
    local query=$3
    local label=$4

    echo -e "${YELLOW}[$label]${NC} $host"
    psql -h "$host" -d demodb -c "$query" 2>&1
    echo ""
}

# Test 1: Check replication status
echo "=========================================="
echo "Test 1: Replication Status"
echo "=========================================="

run_query "postgres-primary" "5432" "SELECT client_addr, application_name, state, sync_state FROM pg_stat_replication;" "PRIMARY"

# Test 2: Check if replicas are in recovery mode
echo "=========================================="
echo "Test 2: Recovery Status"
echo "=========================================="

run_query "postgres-primary" "5432" "SELECT pg_is_in_recovery();" "PRIMARY"
run_query "postgres-replica1" "5432" "SELECT pg_is_in_recovery();" "REPLICA1"
run_query "postgres-replica2" "5432" "SELECT pg_is_in_recovery();" "REPLICA2"

# Test 3: Insert data on primary
echo "=========================================="
echo "Test 3: Write to Primary"
echo "=========================================="

NEW_NAME="User_$(date +%s)"
run_query "postgres-primary" "5432" "INSERT INTO users (name, email) VALUES ('$NEW_NAME', '$NEW_NAME@example.com'); SELECT * FROM users ORDER BY id DESC LIMIT 1;" "PRIMARY"

# Test 4: Read from replicas (should see new data)
echo "=========================================="
echo "Test 4: Read from Replicas (Lag Check)"
echo "=========================================="

sleep 2  # Give replication time to catch up

run_query "postgres-replica1" "5432" "SELECT COUNT(*) as total_users, MAX(created_at) as latest_user FROM users;" "REPLICA1"
run_query "postgres-replica2" "5432" "SELECT COUNT(*) as total_users, MAX(created_at) as latest_user FROM users;" "REPLICA2"

# Test 5: Try to write to replica (should fail)
echo "=========================================="
echo "Test 5: Write to Replica (Should Fail)"
echo "=========================================="

echo -e "${YELLOW}[REPLICA1]${NC} Attempting write (expected to fail)..."
psql -h postgres-replica1 -d demodb -c "INSERT INTO users (name, email) VALUES ('BadWrite', 'bad@example.com');" 2>&1 | grep -i "read-only" && echo -e "${GREEN}✓ Correctly rejected (read-only)${NC}" || echo -e "${RED}✗ Unexpected result${NC}"
echo ""

# Test 6: Replication lag
echo "=========================================="
echo "Test 6: Replication Lag"
echo "=========================================="

run_query "postgres-primary" "5432" "SELECT slot_name, active, pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS lag FROM pg_replication_slots;" "PRIMARY"

echo "=========================================="
echo "Test completed!"
echo "=========================================="
