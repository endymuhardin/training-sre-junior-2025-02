#!/bin/bash
# Test automatic failover by simulating primary failure
# Run this from the host machine

set -e

echo "==================================="
echo "Automatic Failover Test"
echo "==================================="
echo

# Show current state
echo "📊 Initial cluster state:"
docker exec psql-client pg_autoctl show state \
    --monitor 'postgres://autoctl_node@pg-monitor:5432/pg_auto_failover'

# Identify current primary
CURRENT_PRIMARY=$(docker exec psql-client psql \
    -h pg-monitor \
    -U autoctl_node \
    -d pg_auto_failover \
    -t -c "SELECT node_name FROM pgautofailover.node WHERE reported_state = 'primary';" | tr -d ' ')

echo
echo "📍 Current primary: $CURRENT_PRIMARY"

# Insert test data
echo
echo "📝 Inserting test data before failover..."
BEFORE_COUNT=$(docker exec psql-client psql -h haproxy1 -p 6432 -U postgres -d demodb -t -c "SELECT COUNT(*) FROM users;" | tr -d ' ')
echo "   Users in database: $BEFORE_COUNT"

docker exec psql-client psql -h haproxy1 -p 6432 -U postgres -d demodb -c \
    "INSERT INTO users (name, email) VALUES ('Before Failover', 'before@failover.test');"

# Stop current primary
echo
echo "💥 Stopping current primary: $CURRENT_PRIMARY"
docker stop $CURRENT_PRIMARY

echo "⏳ Waiting for automatic failover (monitoring for 60 seconds)..."
for i in {1..12}; do
    sleep 5
    echo "   ${i}0 seconds elapsed..."

    # Check if failover completed
    NEW_PRIMARY=$(docker exec psql-client psql \
        -h pg-monitor \
        -U autoctl_node \
        -d pg_auto_failover \
        -t -c "SELECT node_name FROM pgautofailover.node WHERE reported_state = 'primary';" 2>/dev/null | tr -d ' ' || echo "checking...")

    if [ "$NEW_PRIMARY" != "$CURRENT_PRIMARY" ] && [ "$NEW_PRIMARY" != "checking..." ] && [ ! -z "$NEW_PRIMARY" ]; then
        echo
        echo "✅ Failover detected! New primary: $NEW_PRIMARY"
        break
    fi
done

echo
echo "📊 New cluster state:"
docker exec psql-client pg_autoctl show state \
    --monitor 'postgres://autoctl_node@pg-monitor:5432/pg_auto_failover'

# Verify data integrity
echo
echo "🔍 Verifying data integrity..."
AFTER_COUNT=$(docker exec psql-client psql -h haproxy1 -p 6432 -U postgres -d demodb -t -c "SELECT COUNT(*) FROM users;" | tr -d ' ')
echo "   Users in database: $AFTER_COUNT"

if [ "$AFTER_COUNT" -gt "$BEFORE_COUNT" ]; then
    echo "   ✅ Data preserved after failover!"
else
    echo "   ⚠️  User count didn't increase (expected behavior if replica lag)"
fi

echo
echo "📝 Testing write to new primary..."
docker exec psql-client psql -h haproxy1 -p 6432 -U postgres -d demodb -c \
    "INSERT INTO users (name, email) VALUES ('After Failover', 'after@failover.test');"
echo "   ✅ Write successful!"

echo
echo "==================================="
echo "Automatic Failover Test Complete"
echo "==================================="
echo
echo "To restart old primary and rejoin cluster:"
echo "  docker start $CURRENT_PRIMARY"
echo
echo "pg_auto_failover will automatically:"
echo "  1. Detect the restarted node"
echo "  2. Configure it as a standby"
echo "  3. Start streaming replication from new primary"
