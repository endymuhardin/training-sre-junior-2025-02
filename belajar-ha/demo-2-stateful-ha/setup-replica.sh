#!/bin/bash
set -e

# This script runs when replica container starts
# It uses pg_basebackup to create a replica from primary

REPLICA_SLOT="replica1_slot"

# Wait for primary to be ready
until pg_isready -h postgres-primary -U postgres; do
    echo "Waiting for primary to be ready..."
    sleep 2
done

echo "Primary is ready. Setting up replica..."

# Check if this is already a replica (has standby.signal)
if [ -f "$PGDATA/standby.signal" ]; then
    echo "Already configured as replica, skipping setup"
    exit 0
fi

# Remove existing data directory and create base backup from primary
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
