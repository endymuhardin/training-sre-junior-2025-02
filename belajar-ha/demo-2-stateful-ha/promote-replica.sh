#!/bin/bash

# Script to promote a replica to primary (manual failover)

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
docker exec $REPLICA_NAME pg_isready -U postgres
if [ $? -ne 0 ]; then
    echo "ERROR: Replica is not ready!"
    exit 1
fi

echo ""
echo "Step 2: Check replication lag..."
docker exec $REPLICA_NAME psql -U postgres -c "SELECT pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn(), pg_last_wal_receive_lsn() = pg_last_wal_replay_lsn() AS synced;"

echo ""
echo "Step 3: Promote replica to primary..."
docker exec $REPLICA_NAME pg_ctl promote -D /var/lib/postgresql/data

echo ""
echo "Waiting for promotion to complete..."
sleep 3

echo ""
echo "Step 4: Verify promotion..."
docker exec $REPLICA_NAME psql -U postgres -c "SELECT pg_is_in_recovery();"

echo ""
echo "Step 5: Test write capability..."
docker exec $REPLICA_NAME psql -U postgres -d demodb -c "INSERT INTO users (name, email) VALUES ('AfterFailover_$(date +%s)', 'failover@example.com') RETURNING id, name, created_at;"

echo ""
echo "=========================================="
echo "Failover Complete!"
echo "=========================================="
echo ""
echo "IMPORTANT: You need to:"
echo "1. Stop old primary if still running"
echo "2. Reconfigure other replicas to follow new primary"
echo "3. Update application connection strings"
echo ""
echo "To stop old primary:"
echo "  docker stop postgres-primary"
echo ""
echo "To reconfigure remaining replicas (manual process):"
echo "  docker exec postgres-replica2 sh -c 'echo \"primary_conninfo = \\\"host=$REPLICA_NAME port=5432 user=replicator password=replicator123\\\"\" >> /var/lib/postgresql/data/postgresql.auto.conf'"
echo "  docker restart postgres-replica2"
echo ""
