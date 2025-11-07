#!/bin/bash
set -e

REPLICA_SLOT=""
if [ "$HOSTNAME" = "postgres-replica1" ]; then
    REPLICA_SLOT="replica1_slot"
elif [ "$HOSTNAME" = "postgres-replica2" ]; then
    REPLICA_SLOT="replica2_slot"
fi

# Check if already configured as replica
if [ -f "$PGDATA/standby.signal" ]; then
    echo "Already configured as replica, starting PostgreSQL..."
    chown -R postgres:postgres $PGDATA
    exec gosu postgres postgres -c hba_file=/etc/postgresql/pg_hba.conf
fi

# Wait for primary
until pg_isready -h postgres-primary -U postgres; do
    echo "Waiting for primary..."
    sleep 2
done

echo "Setting up replica from primary..."

# Clone from primary
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

# Create standby signal
touch $PGDATA/standby.signal

# Configure connection
cat >> $PGDATA/postgresql.auto.conf <<EOF
primary_conninfo = 'host=postgres-primary port=5432 user=replicator password=replicator123 application_name=$HOSTNAME'
primary_slot_name = '$REPLICA_SLOT'
hot_standby = on
EOF

echo "Replica setup completed, starting PostgreSQL..."
chmod 700 $PGDATA
chown -R postgres:postgres $PGDATA
exec gosu postgres postgres -c hba_file=/etc/postgresql/pg_hba.conf
