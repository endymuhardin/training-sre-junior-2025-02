#!/bin/bash
set -e

# This script runs when replica container starts
# It uses pg_basebackup to create a replica from primary

REPLICA_SLOT=""
if [ "$HOSTNAME" = "postgres-replica1" ]; then
    REPLICA_SLOT="replica1_slot"
elif [ "$HOSTNAME" = "postgres-replica2" ]; then
    REPLICA_SLOT="replica2_slot"
fi

# Wait for primary to be ready
until pg_isready -h postgres-primary -U postgres; do
    echo "Waiting for primary to be ready..."
    sleep 2
done

echo "Primary is ready. Setting up replica..."

# Remove existing data directory if it exists
if [ -d "$PGDATA" ] && [ "$(ls -A $PGDATA)" ]; then
    echo "Data directory not empty, assuming already configured"
    exit 0
fi

# Create base backup from primary
echo "Creating base backup from primary..."
rm -rf $PGDATA/*

PGPASSWORD=postgres pg_basebackup \
    -h postgres-primary \
    -D $PGDATA \
    -U postgres \
    -v \
    -P \
    -W \
    -R \
    -X stream \
    -C \
    -S $REPLICA_SLOT

# Create standby.signal file
touch $PGDATA/standby.signal

# Configure primary connection info
cat >> $PGDATA/postgresql.auto.conf <<EOF
primary_conninfo = 'host=postgres-primary port=5432 user=replicator password=replicator123 application_name=$HOSTNAME'
primary_slot_name = '$REPLICA_SLOT'
hot_standby = on
EOF

echo "Replica setup completed for $HOSTNAME"
