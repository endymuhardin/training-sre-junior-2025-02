#!/bin/sh

# Script to promote a replica to primary (manual failover)
# Run this from INSIDE psql-client container

REPLICA_NAME=${1:-postgres-replica1}

if [ "$REPLICA_NAME" != "postgres-replica1" ] && [ "$REPLICA_NAME" != "postgres-replica2" ]; then
    echo "Usage: $0 [postgres-replica1|postgres-replica2]"
    exit 1
fi

echo "=========================================="
echo "Manual Failover: Promote $REPLICA_NAME"
echo "=========================================="
echo ""

echo "Step 1: Verify replica is ready..."
pg_isready -h $REPLICA_NAME -U postgres
if [ $? -ne 0 ]; then
    echo "ERROR: Replica is not ready!"
    exit 1
fi

echo ""
echo "Step 2: Check replication lag..."
psql -h $REPLICA_NAME -d postgres -c "SELECT pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn(), pg_last_wal_receive_lsn() = pg_last_wal_replay_lsn() AS synced;"

echo ""
echo "Step 3: Promote replica to primary using pg_promote()..."
psql -h $REPLICA_NAME -d postgres -c "SELECT pg_promote();"

echo ""
echo "Waiting for promotion to complete..."
sleep 3

echo ""
echo "Step 4: Verify promotion..."
psql -h $REPLICA_NAME -d postgres -c "SELECT pg_is_in_recovery();"

echo ""
echo "Step 5: Test write capability..."
psql -h $REPLICA_NAME -d demodb -c "INSERT INTO users (name, email) VALUES ('AfterFailover_$(date +%s)', 'failover@example.com') RETURNING id, name, created_at;"

echo ""
echo "Step 6: Create replication slots..."
psql -h $REPLICA_NAME -d postgres -c "SELECT pg_create_physical_replication_slot('replica1_slot');" 2>/dev/null || echo "replica1_slot already exists"
psql -h $REPLICA_NAME -d postgres -c "SELECT pg_create_physical_replication_slot('replica2_slot');" 2>/dev/null || echo "replica2_slot already exists"

echo ""
echo "Step 7: Verify replication slots..."
psql -h $REPLICA_NAME -d postgres -c "SELECT slot_name, active FROM pg_replication_slots;"

echo ""
echo "=========================================="
echo "Failover Complete!"
echo "=========================================="
echo ""
echo "IMPORTANT: Update application to connect to new primary"
echo "New primary hostname: $REPLICA_NAME"
echo ""
echo "Replication slots created for future replicas"
echo ""
