# Quick Start - PostgreSQL HA Demo

Practical copy-paste commands untuk testing PostgreSQL streaming replication.

> 📖 **Need Details?** Untuk konsep, arsitektur, dan implementasi details, lihat **[README.md](README.md)**

## Setup

### 1. Start Services

```bash
docker compose up -d

# Verify services
docker compose ps
# Wait until all show "Up" status (~30-60 seconds)
```

### 2. Access PostgreSQL Client

```bash
# Open psql-client terminal
docker exec -it psql-client sh

# For Podman:
podman exec -it psql-client sh
```

### 3. Verify Replication

```bash
# Di dalam psql-client terminal, run:
./test-replication.sh
```

**Check hasil:**
- ✅ Test 1: Primary shows 1 connected replica (state = streaming)
- ✅ Test 2: `pg_is_in_recovery()` → Primary: f, Replica: t
- ✅ Test 3: Insert di primary berhasil
- ✅ Test 4: Data muncul di replica dalam < 2 detik
- ✅ Test 5: Write ke replica ditolak dengan error "read-only"
- ✅ Test 6: Replication lag = 0 bytes

---

## Demo 1: Basic Replication

**Terminal: psql-client**

```bash
# Insert data on primary
psql -h postgres-primary -d demodb -c \
  "INSERT INTO users (name, email) VALUES ('Alice', 'alice@test.com') RETURNING *;"

# Read from replica1
psql -h postgres-replica1 -d demodb -c \
  "SELECT * FROM users ORDER BY id DESC LIMIT 5;"
```

**Check hasil:**
- Data yang baru di-insert muncul di replica
- Latency < 1 detik
- Replica menunjukkan data yang sama dengan primary

---

## Demo 2: Read Scaling

**Terminal: psql-client**

```bash
# Distribute read load ke replica
for i in {1..10}; do
  echo "=== Read $i ==="
  psql -h postgres-replica1 -d demodb -c "SELECT COUNT(*) FROM users;" -t
  sleep 1
done
```

**Check hasil:**
- Replica mengembalikan count yang konsisten
- Query berhasil tanpa error
- Primary tidak di-query (read load offloaded ke replica)
- Dalam production, gunakan multiple replicas dengan load balancer

---

## Demo 3: Monitor Replication Lag

**Terminal 1 (psql-client): Generate load**

```bash
./generate-load.sh 60 1
```

**Terminal 2 (psql-client): Monitor lag**

```bash
# Monitor primary replication status
watch -n1 'psql -h postgres-primary -d postgres -c "SELECT application_name, state, replay_lag FROM pg_stat_replication;"'
```

**Check hasil (Terminal 2):**
- `state` menunjukkan "streaming" untuk replica
- `replay_lag` biasanya < 100ms atau "00:00:00"
- Lag mungkin sedikit naik saat load tinggi, tapi catch up cepat
- Jika lag terus naik → ada masalah (network/disk/CPU)

---

## Demo 4: Manual Failover

**Setup - 3 Terminals:**

**Terminal 1 (psql-client):** Generate continuous writes

```bash
./generate-load.sh 300 2
```

**Terminal 2 (psql-client):** Monitor replication

```bash
watch -n1 'psql -h postgres-primary -d postgres -c "SELECT * FROM pg_stat_replication;" 2>/dev/null || echo "PRIMARY DOWN"'
```

**Terminal 3 (HOST):** Execute failover

```bash
# 1. Kill primary
docker stop postgres-primary

# Wait 5 seconds, observe Terminal 1 errors

# 2. Promote replica1 to new primary
# Switch ke Terminal 2 (psql-client), stop watch (Ctrl+C), lalu pilih salah satu:

# Method A - Using script:
./promote-replica-client.sh

# Method B - Manual SQL:
psql -h postgres-replica1 -d postgres -c "SELECT pg_promote();"
sleep 3
psql -h postgres-replica1 -d postgres -c "SELECT pg_is_in_recovery();"  # Should return 'f'
```

**Terminal 1 (psql-client):** Update connection

```bash
# Setelah promotion, stop generator (Ctrl+C)
# Verify new primary accepts writes
psql -h postgres-replica1 -d demodb -c \
  "INSERT INTO users (name, email) VALUES ('AfterFailover', 'test@example.com') RETURNING *;"

# Create replication slot di new primary (IMPORTANT!)
psql -h postgres-replica1 -d postgres -c \
  "SELECT pg_create_physical_replication_slot('replica1_slot');"
```

**Metrics:**
- Downtime: ~10-30 seconds
- RPO: ~1-5 seconds (replication lag)
- RTO: ~30 seconds (manual)

**Check hasil:**
```bash
# Verify new primary tidak in recovery
psql -h postgres-replica1 -d postgres -c "SELECT pg_is_in_recovery();"
# Expected: f (false = primary)

# Verify replication slot created
psql -h postgres-replica1 -d postgres -c "SELECT slot_name, active FROM pg_replication_slots;"
# Expected: replica1_slot (active = f for now, will be active after old primary rejoins)

# Test write
psql -h postgres-replica1 -d demodb -c "SELECT COUNT(*) FROM users;"
```

---

## Demo 4b: Re-join Old Primary as Replica

**Konsep Role Reversal:**

Setelah failover di Demo 4, topology cluster sudah berubah:

```
SEBELUM Failover:
  postgres-primary (PRIMARY - Read/Write)
    └─> postgres-replica1 (REPLICA - Read Only)

SETELAH Failover:
  postgres-replica1 (PRIMARY - Read/Write) ← NEW PRIMARY!
    └─> [postgres-primary offline]

SETELAH Re-join:
  postgres-replica1 (PRIMARY - Read/Write) ← Masih primary
    └─> postgres-primary (REPLICA - Read Only) ← OLD PRIMARY, sekarang replica!
```

**PENTING:**
- Nama container **TIDAK BERUBAH** (masih postgres-primary dan postgres-replica1)
- Yang berubah adalah **ROLE-nya** (primary ↔ replica)
- Insert/Update/Delete sekarang ke **postgres-replica1**
- **postgres-primary** sekarang hanya read-only

**WARNING:** Primary lama harus di-stop dulu, jangan start 2 primary sekaligus (split-brain)!

**Terminal 1 (HOST): Verify old primary sudah stopped**

```bash
docker ps | grep postgres-primary
# Seharusnya tidak muncul (sudah di-stop di Demo 4)

# Jika masih running, stop dulu:
docker stop postgres-primary
```

**Terminal 2 (psql-client): Exit terminal**

```bash
# Exit dari psql-client terminal
exit
```

**Terminal 2 (HOST): Rebuild primary sebagai replica**

```bash
# Remove old primary data
rm -rf data/primary/*

# Manual approach - Clone dari new primary (replica1)
docker run --rm --network demo-2-stateful-ha_postgres-net \
  -v $(pwd)/data/primary:/var/lib/postgresql/data \
  -e PGPASSWORD=replicator123 \
  postgres:17-alpine \
  pg_basebackup -h postgres-replica1 -D /var/lib/postgresql/data \
  -U replicator -v -P -W -R -X stream

# Set standby config
docker run --rm -v $(pwd)/data/primary:/data postgres:17-alpine sh -c \
  'touch /data/standby.signal && \
   echo "primary_conninfo = '\''host=postgres-replica1 port=5432 user=replicator password=replicator123'\''" >> /data/postgresql.auto.conf && \
   echo "hot_standby = on" >> /data/postgresql.auto.conf'

# Start old primary sebagai replica
docker start postgres-primary
```

**Check hasil:**

```bash
# Masuk psql-client
docker exec -it psql-client sh

# === CHECK 1: Verify Role Reversal ===
echo "=== CHECK 1: Role Verification ==="

# postgres-replica1 sekarang PRIMARY (pg_is_in_recovery = false)
psql -h postgres-replica1 -d postgres -c "SELECT pg_is_in_recovery();"
# Expected: f (false = PRIMARY sekarang!)

# postgres-primary sekarang REPLICA (pg_is_in_recovery = true)
psql -h postgres-primary -d postgres -c "SELECT pg_is_in_recovery();"
# Expected: t (true = REPLICA sekarang!)

# === CHECK 2: Verify Replication Connection ===
echo "=== CHECK 2: Replication Status ==="

# Check dari new primary: postgres-primary sekarang streaming dari replica1
psql -h postgres-replica1 -d postgres -c "SELECT application_name, state, sync_state FROM pg_stat_replication;"
# Expected: application_name 'walreceiver', state 'streaming', sync_state 'async'
# Note: 'walreceiver' adalah postgres-primary yang rejoin

# Verify replication slot active
psql -h postgres-replica1 -d postgres -c "SELECT slot_name, active FROM pg_replication_slots WHERE slot_name='replica1_slot';"
# Expected: active = t (true)

# === CHECK 3: Verify Write Direction ===
echo "=== CHECK 3: Write/Read Direction ==="

# Write HANYA bisa di postgres-replica1 (new primary)
psql -h postgres-replica1 -d demodb -c \
  "INSERT INTO users (name, email) VALUES ('AfterRejoin', 'rejoin@test.com') RETURNING *;"
# Expected: INSERT berhasil ✅

sleep 1  # Wait for replication

# Read dari postgres-primary (old primary, now replica) - data replicated
psql -h postgres-primary -d demodb -c \
  "SELECT * FROM users WHERE name='AfterRejoin';"
# Expected: Data muncul (replicated dari postgres-replica1) ✅

# Write ke postgres-primary AKAN DITOLAK (read-only sekarang)
psql -h postgres-primary -d demodb -c \
  "INSERT INTO users (name, email) VALUES ('ShouldFail', 'fail@test.com');" 2>&1 | grep -i "read-only"
# Expected: ERROR "cannot execute INSERT in a read-only transaction" ✅
```

**Kesimpulan:**
- ✅ postgres-replica1 = PRIMARY (accept writes)
- ✅ postgres-primary = REPLICA (read-only, mengikuti postgres-replica1)
- ✅ Replication berfungsi dari replica1 → primary
- ✅ Role sudah TERBALIK! Aplikasi harus connect ke postgres-replica1 untuk writes

---

## Demo 5: Check Replication Lag Under Load

**Terminal 1 (psql-client):**

```bash
# Heavy write load
for i in {1..100}; do
  psql -h postgres-primary -d demodb -c \
    "INSERT INTO users (name, email) SELECT 'bulk_'||generate_series, 'bulk@test.com' FROM generate_series(1, 100);" &

  if [ $((i % 10)) -eq 0 ]; then wait; fi
done
wait
```

**Terminal 2 (psql-client):**

```bash
# Monitor lag
watch -n0.5 'psql -h postgres-primary -d postgres -c "SELECT application_name, pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag FROM pg_stat_replication;"'
```

**Check hasil (Terminal 2):**
- Lag akan naik saat heavy load (beberapa KB atau MB)
- Setelah load selesai, lag turun kembali ke 0 bytes
- Replica catch up otomatis
- Time to catch up bergantung pada disk I/O dan network

---

## Useful Queries

**Check Replication Status (Primary):**

```bash
psql -h postgres-primary -d postgres -c \
  "SELECT application_name, state, sync_state, replay_lag FROM pg_stat_replication;"
```

**Check if Primary or Replica:**

```bash
# Primary returns: f
# Replica returns: t
psql -h postgres-primary -d postgres -c "SELECT pg_is_in_recovery();"
psql -h postgres-replica1 -d postgres -c "SELECT pg_is_in_recovery();"
```

**Check Replication Lag (from Replica):**

```bash
psql -h postgres-replica1 -d postgres -c \
  "SELECT now() - pg_last_xact_replay_timestamp() AS lag;"
```

**Count Users:**

```bash
psql -h postgres-primary -d demodb -c "SELECT COUNT(*) FROM users;"
```

---

## Troubleshooting

**Replica not connected:**

```bash
# Check logs
docker logs postgres-replica1 --tail 50

# Check from psql-client
pg_isready -h postgres-replica1
```

**Reset entire setup:**

```bash
# Exit psql-client terminal
exit

# Stop and clean
docker compose down
rm -rf data/

# Restart
docker compose up -d
sleep 60  # Wait for initialization
```

---

## Cleanup

```bash
# Exit psql-client (if inside)
exit

# Stop services
docker compose down

# Remove all data (optional)
rm -rf data/
```

---

## Summary

| Scenario | Command Location | Expected Result |
|----------|-----------------|-----------------|
| Basic queries | psql-client | Instant replication |
| Failover | HOST + psql-client | 10-30s downtime |
| Read scaling | psql-client | Load distributed |
| Monitor lag | psql-client | < 100ms typical |

**Next:** See `README.md` for concepts, architecture, and production best practices.
