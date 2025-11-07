#!/bin/bash
# Trigger manual failover in pg_auto_failover cluster
# Run this from the host machine

set -e

echo "==================================="
echo "Manual Failover Trigger"
echo "==================================="
echo

# Show current state
echo "📊 Current cluster state:"
docker exec psql-client pg_autoctl show state \
    --monitor 'postgres://autoctl_node@pg-monitor:5432/pg_auto_failover'

echo
echo "⚠️  Initiating manual failover..."
echo "    This will promote the standby to primary"
echo

# Trigger failover by performing maintenance on current primary
CURRENT_PRIMARY=$(docker exec psql-client psql \
    -h pg-monitor \
    -U autoctl_node \
    -d pg_auto_failover \
    -t -c "SELECT node_name FROM pgautofailover.node WHERE reported_state = 'primary';" | tr -d ' ')

echo "📍 Current primary: $CURRENT_PRIMARY"
echo "🔄 Performing failover..."

# Enable maintenance mode on current primary (triggers failover)
docker exec psql-client pg_autoctl enable maintenance \
    --pgdata /var/lib/postgresql/data \
    --monitor 'postgres://autoctl_node@pg-monitor:5432/pg_auto_failover' \
    --allow-failover

echo
echo "⏳ Waiting for failover to complete (30 seconds)..."
sleep 30

echo
echo "📊 New cluster state:"
docker exec psql-client pg_autoctl show state \
    --monitor 'postgres://autoctl_node@pg-monitor:5432/pg_auto_failover'

echo
echo "✅ Failover completed!"
echo
echo "To disable maintenance mode on old primary:"
echo "  docker exec psql-client pg_autoctl disable maintenance \\"
echo "    --pgdata /var/lib/postgresql/data \\"
echo "    --monitor 'postgres://autoctl_node@pg-monitor:5432/pg_auto_failover'"
