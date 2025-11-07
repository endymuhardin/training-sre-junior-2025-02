#!/bin/bash
# Check pg_auto_failover cluster state
# Run this from psql-client container

set -e

echo "==================================="
echo "pg_auto_failover Cluster Status"
echo "==================================="
echo

# Check cluster state from monitor
echo "📊 Cluster State (from monitor):"
docker exec psql-client pg_autoctl show state \
    --monitor 'postgres://autoctl_node@pg-monitor:5432/pg_auto_failover'

echo
echo "🔍 Detailed Node Information:"
docker exec psql-client pg_autoctl show state \
    --monitor 'postgres://autoctl_node@pg-monitor:5432/pg_auto_failover' \
    --json | python3 -m json.tool

echo
echo "💊 Node Health:"
for node in postgres-primary postgres-replica1; do
    echo -n "  $node: "
    if docker exec $node pg_isready -U postgres -q; then
        echo "✅ HEALTHY"
    else
        echo "❌ UNHEALTHY"
    fi
done

echo
echo "📡 HAProxy PostgreSQL Backends:"
echo "Write backend (port 6432):"
curl -s http://localhost:8404 | grep -A 5 "postgres_primary" || echo "  HAProxy stats not available"

echo
echo "Read backend (port 6433):"
curl -s http://localhost:8404 | grep -A 5 "postgres_replicas" || echo "  HAProxy stats not available"
