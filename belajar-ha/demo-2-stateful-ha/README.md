# Demo 2: Stateful Layer High Availability

Demonstrasi High Availability pada stateful layer menggunakan PostgreSQL Streaming Replication.

## Arsitektur

```
     ┌─────────────────────────────────┐
     │       PgBouncer (Optional)      │
     │      Connection Pooler          │
     │         Port 6432               │
     └────────────┬────────────────────┘
                  │
                  │ Writes
     ┌────────────▼────────────┐
     │   PostgreSQL Primary    │  ◄───┐
     │      Read/Write         │      │
     │      Port 5432          │      │ Streaming
     └─────────────┬───────────┘      │ Replication
                   │                  │
         ┌─────────┼─────────┐        │
         │ Reads   │         │        │
         │         │         │        │
     ┌───▼────┐ ┌──▼─────┐  │        │
     │Replica1│ │Replica2│  │        │
     │  Read  │ │  Read  │──┼────────┘
     │  5433  │ │  5434  │  │
     └────────┘ └────────┘  │
                             │
                      Physical Replication
                      (WAL Streaming)
```

## Konsep HA yang Didemonstrasikan

### Core Concepts:
- **Streaming Replication**: WAL (Write-Ahead Log) streaming ke replicas
- **Hot Standby**: Replicas dapat melayani read queries
- **Replication Slots**: Prevent WAL deletion sebelum replica consume
- **Asynchronous Replication**: Replicas bisa sedikit lag behind primary
- **Read Scaling**: Distribute read load ke multiple replicas
- **Manual Failover**: Promote replica menjadi primary
- **Connection Pooling**: Efficient connection management dengan PgBouncer

### Data Durability:
- **Replication Lag**: Monitor keterlambatan replica
- **Data Loss Window**: Potential data loss saat failover
- **Recovery Point Objective (RPO)**: Target maksimal data loss
- **Recovery Time Objective (RTO)**: Target waktu recovery

---

## Prerequisites

```bash
# Install PostgreSQL client tools (for testing scripts)
# macOS
brew install postgresql

# Ubuntu/Debian
sudo apt-get install postgresql-client

# Or use Docker exec for all queries
```

---

## Setup & Startup

### 1. Start All Services

```bash
docker compose up -d
```

### 2. Wait for Initialization (Important!)

Replicas need time to clone primary and start replication:

```bash
# Watch logs
docker compose logs -f

# Check status
docker compose ps

# Wait until all services show "healthy"
watch -n2 docker compose ps
```

**Expected startup time**: 30-60 seconds

### 3. Verify Replication Setup

```bash
# Run automated test
./test-replication.sh
```

**Expected output**:
- Primary shows 2 connected replicas
- Replicas show `pg_is_in_recovery() = true`
- Data inserted on primary appears on replicas
- Write to replica fails (read-only)

---

## Demo Scenarios

### Demo 1: Basic Replication Test

**Verify replication is working:**

```bash
# Terminal 1: Insert data on primary
PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -d demodb -c \
  "INSERT INTO users (name, email) VALUES ('DemoUser', 'demo@example.com') RETURNING *;"

# Terminal 2: Read from replica1
PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -d demodb -c \
  "SELECT * FROM users ORDER BY id DESC LIMIT 5;"

# Terminal 3: Read from replica2
PGPASSWORD=postgres psql -h localhost -p 5434 -U postgres -d demodb -c \
  "SELECT * FROM users ORDER BY id DESC LIMIT 5;"
```

**Observasi**: Data muncul di replicas dalam < 1 detik

---

### Demo 2: Read Scaling

**Scenario**: Distribute read load ke replicas untuk performance.

```bash
# Create load on replicas (read-only queries)
for i in {1..20}; do
  echo "Read $i from replica1:"
  PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -d demodb -c \
    "SELECT COUNT(*) FROM users;" -t

  echo "Read $i from replica2:"
  PGPASSWORD=postgres psql -h localhost -p 5434 -U postgres -d demodb -c \
    "SELECT COUNT(*) FROM users;" -t

  sleep 0.5
done
```

**Production pattern**: Application directs:
- Writes → Primary (5432)
- Reads → Replicas (5433, 5434) dengan load balancing

---

### Demo 3: Replication Lag Monitoring

**Monitor lag real-time:**

```bash
# Terminal 1: Generate continuous writes
./generate-load.sh 120 2

# Terminal 2: Monitor replication lag
watch -n1 'docker exec postgres-primary psql -U postgres -c "SELECT application_name, state, sync_state, replay_lag FROM pg_stat_replication;"'

# Terminal 3: Monitor replica lag from replica side
watch -n1 'docker exec postgres-replica1 psql -U postgres -c "SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag;"'
```

**Observasi**:
- Lag biasanya < 100ms dalam kondisi normal
- Lag increases jika replica overloaded atau network slow
- `sync_state = async` (asynchronous replication)

---

### Demo 4: Primary Failure - Manual Failover

**Scenario**: Primary mati, promote replica1 menjadi primary baru.

**Setup:**

```bash
# Terminal 1: Generate continuous load (will fail when primary dies)
./generate-load.sh 300 2

# Terminal 2: Monitor replication status
watch -n1 'docker exec postgres-primary psql -U postgres -c "SELECT * FROM pg_stat_replication;" 2>/dev/null || echo "PRIMARY DOWN"'

# Terminal 3: Execute failover steps
```

**Failover Steps (Terminal 3):**

```bash
# 1. Simulate primary failure
docker stop postgres-primary

# 2. Wait 5 seconds, observe load generator errors

# 3. Promote replica1 to primary
./promote-replica.sh postgres-replica1

# 4. Verify replica1 is now accepting writes
PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -d demodb -c \
  "INSERT INTO users (name, email) VALUES ('AfterFailover', 'after@example.com') RETURNING *;"

# 5. Update application to connect to new primary (port 5433)
# In production: Update DNS, load balancer, or connection string
```

**Observasi**:
- Downtime: ~10-30 seconds (time to detect + promote)
- Data loss: Transactions yang belum replicated (RPO = replication lag)
- Manual intervention required

**Recovery Point Objective (RPO)**: ~1-5 seconds (replication lag)
**Recovery Time Objective (RTO)**: ~30 seconds (manual process)

---

### Demo 5: Replication Lag Under Load

**Scenario**: Stress test replication dengan heavy writes.

```bash
# Terminal 1: Heavy write load
for i in {1..1000}; do
  PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -d demodb -c \
    "INSERT INTO users (name, email) SELECT 'bulk_'||generate_series, 'bulk_'||generate_series||'@example.com' FROM generate_series(1, 100);" &

  if [ $((i % 10)) -eq 0 ]; then wait; fi
done
wait

# Terminal 2: Monitor lag continuously
watch -n0.5 'docker exec postgres-primary psql -U postgres -c "SELECT application_name, pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag FROM pg_stat_replication;"'
```

**Observasi**: Lag increases during heavy load, catches up after load decreases.

---

### Demo 6: Split-Brain Prevention

**Scenario**: Demonstrate why we need fencing.

```bash
# 1. Start with healthy cluster
docker compose ps

# 2. Stop primary (simulating network partition)
docker stop postgres-primary

# 3. Promote replica1
./promote-replica.sh postgres-replica1

# 4. Restart old primary (DON'T DO THIS IN PRODUCTION!)
docker start postgres-primary

# 5. Now you have TWO primaries (split-brain scenario)
# Old primary thinks it's still primary
# New primary (replica1) is accepting writes

# Check both:
PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -c "SELECT pg_is_in_recovery();"  # old primary
PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -c "SELECT pg_is_in_recovery();"  # new primary

# Both return 'false' = PROBLEM!
```

**Solution**: STONITH (Shoot The Other Node In The Head)
- Ensure old primary is truly dead before promotion
- Use fencing mechanisms (network isolation, power off)
- Automatic failover tools (Patroni, repmgr) handle this

---

### Demo 7: Connection Pooling with PgBouncer

**Scenario**: Efficient connection management.

```bash
# Connect via PgBouncer
PGPASSWORD=postgres psql -h localhost -p 6432 -U postgres -d demodb -c \
  "SELECT * FROM users LIMIT 5;"

# Show PgBouncer stats
PGPASSWORD=postgres psql -h localhost -p 6432 -U postgres -p postgres pgbouncer -c \
  "SHOW POOLS;"

PGPASSWORD=postgres psql -h localhost -p 6432 -U postgres -p postgres pgbouncer -c \
  "SHOW STATS;"
```

**Benefits**:
- Reduce connection overhead
- Connection reuse
- Limit max connections to database

---

## Monitoring Queries

### Replication Status (Primary)
```sql
SELECT
    application_name,
    client_addr,
    state,
    sync_state,
    replay_lag,
    pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag_bytes
FROM pg_stat_replication;
```

### Replication Lag (Replica)
```sql
SELECT
    now() - pg_last_xact_replay_timestamp() AS replication_lag,
    pg_is_in_recovery() AS is_replica;
```

### Check if Primary or Replica
```sql
SELECT pg_is_in_recovery();  -- true = replica, false = primary
```

### Replication Slot Status (Primary)
```sql
SELECT
    slot_name,
    active,
    pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn)) AS retained_wal
FROM pg_replication_slots;
```

### Database Size & Activity
```sql
-- Database size
SELECT pg_size_pretty(pg_database_size('demodb'));

-- Table size
SELECT pg_size_pretty(pg_total_relation_size('users'));

-- Active connections
SELECT count(*) FROM pg_stat_activity WHERE state = 'active';
```

---

## Troubleshooting

### Replica not connecting

```bash
# Check replica logs
docker logs postgres-replica1

# Check primary allows connections
docker exec postgres-primary cat /etc/postgresql/pg_hba.conf

# Test network connectivity
docker exec postgres-replica1 pg_isready -h postgres-primary -U replicator
```

### Replication lag too high

```bash
# Check WAL generation rate (primary)
docker exec postgres-primary psql -U postgres -c \
  "SELECT pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), '0/0')) AS total_wal_generated;"

# Check disk I/O on replica
docker stats postgres-replica1

# Increase replica resources or reduce primary load
```

### Replica data diverged

```bash
# Stop replica
docker stop postgres-replica1

# Remove replica data
docker exec postgres-replica1 rm -rf /var/lib/postgresql/data/*

# Restart replica (will re-clone from primary)
docker start postgres-replica1
```

### Promote failed

```bash
# Check if replica is caught up
docker exec postgres-replica1 psql -U postgres -c \
  "SELECT pg_last_wal_receive_lsn() = pg_last_wal_replay_lsn() AS caught_up;"

# Force promote
docker exec postgres-replica1 pg_ctl promote -D /var/lib/postgresql/data
```

---

## Production Best Practices

### Replication Configuration

**Synchronous Replication** (untuk critical data):
```sql
-- On primary
ALTER SYSTEM SET synchronous_commit = 'remote_apply';
ALTER SYSTEM SET synchronous_standby_names = 'postgres-replica1';
SELECT pg_reload_conf();
```

**Trade-off**:
- ✓ Zero data loss (RPO = 0)
- ✗ Higher write latency
- ✗ Primary waits for replica acknowledgment

**Asynchronous Replication** (current demo):
- ✓ Low write latency
- ✗ Potential data loss (RPO > 0)

### Monitoring & Alerting

**Key metrics to monitor**:
```bash
# Alert if lag > 10 seconds
SELECT EXTRACT(EPOCH FROM replay_lag) > 10 FROM pg_stat_replication;

# Alert if replica disconnected
SELECT count(*) < 2 FROM pg_stat_replication WHERE state = 'streaming';

# Alert if WAL retention too high (disk space)
SELECT pg_wal_lsn_diff(pg_current_wal_lsn(), restart_lsn) > 10737418240
FROM pg_replication_slots WHERE not active;  -- 10GB
```

### Backup Strategy

Replication ≠ Backup!

```bash
# Regular backups still required
pg_basebackup -h localhost -p 5432 -U postgres -D /backup/$(date +%Y%m%d)

# Or use pg_dump for logical backup
PGPASSWORD=postgres pg_dump -h localhost -p 5432 -U postgres demodb > backup.sql
```

### Automatic Failover

For production, use automatic failover tools:
- **Patroni** (recommended): Automatic failover dengan etcd/consul
- **repmgr**: Replication manager for PostgreSQL
- **Stolon**: Cloud-native PostgreSQL HA

Example Patroni setup in future demo (optional).

---

## Cleanup

```bash
# Stop all containers
docker compose down

# Remove volumes (WARNING: deletes all data)
docker compose down -v
rm -rf primary-data replica1-data replica2-data

# Or keep data for next run
docker compose down
```

---

## Workshop Exercises

### Exercise 1: Configure Synchronous Replication

Modify primary to use synchronous replication:
1. Edit `docker-compose.yml` - add `-c synchronous_commit=on`
2. Add `-c synchronous_standby_names='postgres-replica1'`
3. Restart and test write latency difference

### Exercise 2: Cascade Replication

Make replica2 replicate from replica1 (not primary):
1. Modify `setup-replica.sh` for replica2
2. Change `primary_conninfo` to point to replica1
3. Test 3-tier replication

### Exercise 3: Delayed Replica

Create delayed replica for protection against human errors:
1. Add new replica service
2. Set `recovery_min_apply_delay = '1h'`
3. Test data recovery from delayed replica

### Exercise 4: Custom Failover Script

Write script to:
1. Detect primary failure
2. Automatically promote best replica (least lag)
3. Reconfigure other replicas
4. Update load balancer

### Exercise 5: Monitoring Dashboard

Create monitoring dashboard:
1. Collect metrics from `pg_stat_replication`
2. Graph replication lag over time
3. Alert on anomalies

---

## Comparison: Stateless vs Stateful HA

| Aspect | Stateless (Demo 1) | Stateful (Demo 2) |
|--------|-------------------|-------------------|
| **Failover Time** | < 3 seconds | 30-60 seconds |
| **Data Loss Risk** | None | Possible (RPO > 0) |
| **Complexity** | Low | High |
| **State Consistency** | Not applicable | Critical concern |
| **Automatic Failover** | Easy (Keepalived) | Complex (needs coordination) |
| **Split-Brain Risk** | Low | High |
| **Scale Out** | Easy | Harder |

---

## Next Steps

- Explore **Patroni** for automatic PostgreSQL failover
- Learn **pgBackRest** for advanced backup/restore
- Study **Logical Replication** for multi-master scenarios
- Implement **Connection Pooling** strategies
- Setup **Monitoring with Prometheus + Grafana**

---

## Referensi

- [PostgreSQL Replication Documentation](https://www.postgresql.org/docs/current/runtime-config-replication.html)
- [PostgreSQL High Availability](https://www.postgresql.org/docs/current/high-availability.html)
- [Patroni Documentation](https://patroni.readthedocs.io/)
- [PgBouncer Documentation](https://www.pgbouncer.org/)
- [Understanding WAL](https://www.postgresql.org/docs/current/wal-intro.html)
