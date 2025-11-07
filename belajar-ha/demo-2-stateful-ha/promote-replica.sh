#!/bin/bash

# Script to promote a replica to primary (manual failover)
# Run this from HOST terminal (not psql-client)

REPLICA_NAME=${1:-postgres-replica1}
CONTAINER_RUNTIME=${CONTAINER_RUNTIME:-docker}

# Detect if using podman
if command -v podman &> /dev/null; then
    CONTAINER_RUNTIME=podman
fi

if [ "$REPLICA_NAME" != "postgres-replica1" ] && [ "$REPLICA_NAME" != "postgres-replica2" ]; then
    echo "Usage: $0 [postgres-replica1|postgres-replica2]"
    exit 1
fi

echo "=========================================="
echo "Manual Failover: Promote $REPLICA_NAME"
echo "=========================================="
echo "Using container runtime: $CONTAINER_RUNTIME"
echo ""

echo "Step 1: Verify replica is ready..."
$CONTAINER_RUNTIME exec $REPLICA_NAME pg_isready -U postgres
if [ $? -ne 0 ]; then
    echo "ERROR: Replica is not ready!"
    exit 1
fi

echo ""
echo "Step 2: Check replication lag..."
$CONTAINER_RUNTIME exec $REPLICA_NAME psql -U postgres -d postgres -c "SELECT pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn(), pg_last_wal_receive_lsn() = pg_last_wal_replay_lsn() AS synced;"

echo ""
echo "Step 3: Promote replica to primary using pg_promote()..."
$CONTAINER_RUNTIME exec $REPLICA_NAME psql -U postgres -d postgres -c "SELECT pg_promote();"

echo ""
echo "Waiting for promotion to complete..."
sleep 3

echo ""
echo "Step 4: Verify promotion..."
$CONTAINER_RUNTIME exec $REPLICA_NAME psql -U postgres -d postgres -c "SELECT pg_is_in_recovery();"

echo ""
echo "Step 5: Test write capability..."
$CONTAINER_RUNTIME exec $REPLICA_NAME psql -U postgres -d demodb -c "INSERT INTO users (name, email) VALUES ('AfterFailover_$(date +%s)', 'failover@example.com') RETURNING id, name, created_at;"

echo ""
echo "Step 6: Create replication slots..."
$CONTAINER_RUNTIME exec $REPLICA_NAME psql -U postgres -d postgres -c "SELECT pg_create_physical_replication_slot('replica1_slot');" 2>/dev/null || echo "replica1_slot already exists"
$CONTAINER_RUNTIME exec $REPLICA_NAME psql -U postgres -d postgres -c "SELECT pg_create_physical_replication_slot('replica2_slot');" 2>/dev/null || echo "replica2_slot already exists"

echo ""
echo "Step 7: Verify replication slots..."
$CONTAINER_RUNTIME exec $REPLICA_NAME psql -U postgres -d postgres -c "SELECT slot_name, active FROM pg_replication_slots;"

echo ""
echo "=========================================="
echo "Failover Complete!"
echo "=========================================="
echo ""
echo "Replication slots created for future replicas"
echo ""
echo "IMPORTANT: You need to:"
echo "1. Stop old primary if still running"
echo "2. Reconfigure other replicas to follow new primary"
echo "3. Update application connection strings"
echo ""
echo "Commands:"
echo "  $CONTAINER_RUNTIME stop postgres-primary"
echo ""
