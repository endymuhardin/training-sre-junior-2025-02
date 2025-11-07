# Full Stack HA - Panduan Quick Start

Panduan praktis untuk menjalankan demo dan testing scenarios.

## Prerequisites

- Docker atau Podman dengan Docker Compose
- 4GB RAM minimum
- Ports tersedia: 8080, 8404, 5430, 5432, 5433, 6432, 6433
- (Optional) `jq` untuk parsing JSON output
- (Optional) `watch` untuk monitoring real-time

### Build Custom PostgreSQL 17 Image

**IMPORTANT:** Demo ini membutuhkan custom build image karena official images hanya tersedia sampai PostgreSQL 15.

```bash
# Quick build (recommended)
./scripts/build-pg-image.sh

# Atau manual
cd /tmp
git clone --depth 1 https://github.com/citusdata/pg_auto_failover.git
cd pg_auto_failover
podman build --platform linux/amd64 -t pg_auto_failover:pg17 -f Dockerfile .
```

**Build time:** 5-10 menit (compile PostgreSQL 17 from source)

---

## Setup

### 1. Start All Services

```bash
cd demo-3-full-stack-ha

# Start semua containers
docker compose up -d

# Monitor startup progress
docker compose logs -f
```

**Tunggu initialization messages (2-3 menit):**
```
pg-monitor     | ... monitor is now running
postgres-primary   | ... node registered to the monitor
postgres-replica1  | ... node registered to the monitor
haproxy1          | ... Proxy app_backend started
haproxy1          | ... Proxy postgres_primary started
```

### 2. Verify All Services

```bash
# Check all containers running
docker compose ps

# Expected: 9 containers running
# pg-monitor, postgres-primary, postgres-replica1, psql-client
# app1, app2, haproxy1, haproxy2, vip-access
```

### 3. Check Cluster State

```bash
# Gunakan helper script
./scripts/check-cluster.sh

# Atau manual dari psql-client
docker exec psql-client pg_autoctl show state \
  --monitor 'postgres://autoctl_node@pg-monitor:5432/pg_auto_failover'
```

**Expected output:**
```
  Name               | Node | Host:Port                  | State
--------------------+------+----------------------------+-----------
 postgres-primary   |    1 | postgres-primary:5432      | primary
 postgres-replica1  |    2 | postgres-replica1:5432     | secondary
```

### 4. Akses Aplikasi

**Web Interface:**
```bash
# Buka di browser
open http://localhost:8080/

# Atau test via curl
curl http://localhost:8080/
```

**HAProxy Statistics Dashboard:**
```bash
open http://localhost:8404/
```

**API Endpoints:**
```bash
# Get application stats
curl http://localhost:8080/api/stats | jq

# List users
curl http://localhost:8080/api/users | jq

# Create new user
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com"}'
```

---

## Demo Scenarios

### Demo 1: Verifikasi Konfigurasi Cluster

**Objective:** Memahami topologi cluster dan verifikasi replication working.

**1a. Check pg_auto_failover Formation**

```bash
# Dari HOST
docker exec psql-client pg_autoctl show state \
  --monitor 'postgres://autoctl_node@pg-monitor:5432/pg_auto_failover'
```

**1b. Check PostgreSQL Replication**

```bash
# Dari psql-client
docker exec -it psql-client sh

# Connect ke primary
psql -h postgres-primary -U postgres -d demodb

# Check replication status
SELECT
    application_name,
    client_addr,
    state,
    sync_state,
    replay_lag
FROM pg_stat_replication;

# Exit
\q
```

**Expected:** Satu standby (postgres-replica1) streaming dari primary.

**1c. Verifikasi Read/Write Splitting**

```bash
# Dari psql-client

# Connect ke WRITE endpoint (via HAProxy)
PGPASSWORD=app_password psql -h haproxy1 -p 6432 -U app_user -d demodb

# Check node mana yang terkoneksi
SELECT inet_server_addr(), inet_server_port(), pg_is_in_recovery();
-- Should show: postgres-primary IP, false (not in recovery = primary)

\q

# Connect ke READ endpoint (via HAProxy)
PGPASSWORD=app_password psql -h haproxy1 -p 6433 -U app_user -d demodb

# Check node mana yang terkoneksi (bisa salah satu node)
SELECT inet_server_addr(), inet_server_port(), pg_is_in_recovery();

\q
```

**1d. Insert Test Data**

```bash
# Insert via application (write endpoint)
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Demo User","email":"demo@workshop.test"}'

# Verify replication (dari psql-client)
psql -h postgres-replica1 -U postgres -d demodb -c \
  "SELECT * FROM users ORDER BY id DESC LIMIT 1;"

# Data harus muncul di replica (replicated!)
```

---

### Demo 2: Automatic PostgreSQL Failover

**Objective:** Test automatic failover ketika primary PostgreSQL fails.

**2a. Baseline - Catat Current State**

```bash
# Check current primary
docker exec psql-client pg_autoctl show state \
  --monitor 'postgres://autoctl_node@pg-monitor:5432/pg_auto_failover'

# Perhatikan node mana yang primary (harusnya postgres-primary)

# Check HAProxy stats
curl -s http://localhost:8404/ | grep -A 3 "postgres_primary"
```

**2b. Insert Test Data Sebelum Failover**

```bash
# Via application API
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Before Failover","email":"before@failover.test"}'

# Hitung users
docker exec psql-client psql -h haproxy1 -p 6432 -U postgres -d demodb -t -c \
  "SELECT COUNT(*) FROM users;"
```

**2c. Stop Primary (Simulasi Failure)**

```bash
# Stop postgres-primary container
docker stop postgres-primary

# Application harus tetap serving reads dari replica
curl http://localhost:8080/api/stats
```

**2d. Monitor Automatic Failover**

```bash
# Watch cluster state change (jalankan di terminal terpisah)
watch -n 2 'docker exec psql-client pg_autoctl show state \
  --monitor "postgres://autoctl_node@pg-monitor:5432/pg_auto_failover"'

# Timeline:
# T+0s:  postgres-primary: primary → (unreachable)
# T+10s: postgres-replica1: secondary → prepare_promotion
# T+20s: postgres-replica1: prepare_promotion → wait_primary → primary
# T+30s: Failover selesai
```

**Expected output progression:**
```
# Awalnya:
postgres-primary   | primary      | (kemudian hilang)
postgres-replica1  | secondary

# Setelah ~10s:
postgres-replica1  | prepare_promotion

# Setelah ~20s:
postgres-replica1  | primary   ← PRIMARY BARU!
```

**2e. Verifikasi Aplikasi Tetap Jalan**

```bash
# Test write ke PRIMARY baru
curl -X POST http://localhost:8080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"After Failover","email":"after@failover.test"}'

# Harus sukses! App automatically menggunakan primary baru via HAProxy

# Verifikasi data
curl http://localhost:8080/api/users | jq '.users[] | select(.name | contains("Failover"))'
```

**2f. Restart Old Primary (Automatic Rejoin)**

```bash
# Restart postgres-primary
docker start postgres-primary

# Watch otomatis rejoin sebagai STANDBY
watch -n 2 'docker exec psql-client pg_autoctl show state \
  --monitor "postgres://autoctl_node@pg-monitor:5432/pg_auto_failover"'

# Timeline:
# T+0s:  postgres-primary starts
# T+10s: postgres-primary: rejoin
# T+30s: postgres-primary: catchingup
# T+60s: postgres-primary: secondary   ← Rejoin sebagai standby!
```

**2g. Verifikasi Role Reversal**

```bash
# Check node mana yang primary sekarang
docker exec psql-client psql -h postgres-primary -U postgres -d postgres -t -c \
  "SELECT pg_is_in_recovery();"
# Output: t (true = sekarang REPLICA!)

docker exec psql-client psql -h postgres-replica1 -U postgres -d postgres -t -c \
  "SELECT pg_is_in_recovery();"
# Output: f (false = sekarang PRIMARY!)

# Role reversal selesai!
# Nama container sama, tapi role bertukar
```

---

### Demo 3: Manual Failover (Switchover)

**Objective:** Trigger planned switchover untuk maintenance.

**3a. Check Current State**

```bash
./scripts/check-cluster.sh
```

**3b. Lakukan Graceful Switchover**

```bash
# Gunakan helper script
./scripts/manual-failover.sh

# Atau manual:
docker exec psql-client pg_autoctl perform switchover \
  --monitor 'postgres://autoctl_node@pg-monitor:5432/pg_auto_failover'
```

**Yang terjadi:**
1. Current primary masuk `draining` state
2. Tunggu replica catch up (synchronous)
3. Promote replica ke primary
4. Old primary jadi secondary
5. **Zero data loss** (synchronous switchover)

**3c. Verifikasi Switchover Selesai**

```bash
# Check state baru
./scripts/check-cluster.sh

# Application tetap jalan
curl http://localhost:8080/api/stats
```

---

### Demo 4: HAProxy Failover

**Objective:** Test Keepalived VIP failover.

**4a. Identifikasi HAProxy Master Saat Ini**

```bash
# Check HAProxy mana yang punya VIP
docker exec haproxy1 ip addr show eth0 | grep 172.30.0.100
docker exec haproxy2 ip addr show eth0 | grep 172.30.0.100

# Salah satu harus punya VIP (master), yang lain tidak (backup)
```

**4b. Stop HAProxy Master**

```bash
# Asumsikan haproxy1 adalah master
docker stop haproxy1

# VIP harus pindah ke haproxy2 dalam 3-5 detik
```

**4c. Verifikasi VIP Pindah**

```bash
# Check haproxy2 sekarang punya VIP
docker exec haproxy2 ip addr show eth0 | grep 172.30.0.100

# Application masih accessible
curl http://localhost:8080/
curl http://localhost:8404/  # HAProxy stats
```

**4d. Restart Old Master**

```bash
# Restart haproxy1
docker start haproxy1

# Jadi backup, VIP tetap di haproxy2
# (atau VIP pindah kembali tergantung Keepalived priority)
```

---

### Demo 5: Application Instance Failure

**Objective:** Test application layer redundancy.

**5a. Generate Load**

```bash
# Di satu terminal, jalankan load generator
./scripts/generate-load.sh &

# Watch HAProxy stats
watch -n 1 'curl -s http://localhost:8404/ | grep -A 3 "app_backend"'
```

**5b. Stop Satu App Instance**

```bash
# Stop app1
docker stop app1

# HAProxy otomatis detect dan remove dari pool
# Semua traffic ke app2
# Tidak ada downtime!
```

**5c. Verifikasi Traffic Tetap Jalan**

```bash
# Application masih responsif
curl http://localhost:8080/api/stats

# Check HAProxy - app1 harus DOWN
curl http://localhost:8404/ | grep app1
```

**5d. Restart App Instance**

```bash
# Restart app1
docker start app1

# Tunggu health check (5-10 detik)
# HAProxy otomatis tambah kembali ke pool
```

---

### Demo 6: Monitoring dan Observability

**Objective:** Monitor cluster health dan metrics.

**6a. Watch Cluster State**

```bash
# Continuous monitoring
watch -n 2 './scripts/check-cluster.sh'
```

**6b. Check Replication Lag**

```bash
# Dari psql-client
docker exec psql-client psql -h postgres-primary -U postgres -d postgres -c \
  "SELECT
     application_name,
     client_addr,
     state,
     sync_state,
     pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag_bytes,
     replay_lag
   FROM pg_stat_replication;"
```

**6c. Lihat Failover History**

```bash
# Show semua events
docker exec psql-client pg_autoctl show events \
  --monitor 'postgres://autoctl_node@pg-monitor:5432/pg_auto_failover' \
  --count 20

# Filter by type
docker exec psql-client pg_autoctl show events \
  --monitor 'postgres://autoctl_node@pg-monitor:5432/pg_auto_failover' \
  --count 20 | grep -i failover
```

**6d. Application Metrics**

```bash
# Real-time stats dari application
watch -n 1 'curl -s http://localhost:8080/api/stats | jq'

# Menampilkan:
# - App instance mana yang serve request
# - Database endpoint mana yang digunakan
# - Database role (primary/replica)
# - Replication lag
```

**6e. HAProxy Metrics**

```bash
# Stats via socket
echo "show stat" | docker exec -i haproxy1 socat stdio /var/run/haproxy.sock | \
  column -t -s ','

# Backend health
echo "show servers state" | docker exec -i haproxy1 socat stdio /var/run/haproxy.sock
```

---

### Demo 7: Full Chaos Test

**Objective:** Comprehensive failure testing.

**7a. Jalankan Chaos Test Script**

```bash
# Script ini test multiple failure scenarios
./scripts/chaos-test.sh
```

**Atau manual:**

**7b. Simultaneous Failures**

```bash
# Stop kedua PostgreSQL nodes (extreme scenario)
docker stop postgres-primary postgres-replica1

# Application menampilkan error (tidak ada database available)
curl http://localhost:8080/api/stats

# Restart replica dulu
docker start postgres-replica1

# Tunggu pg_auto_failover promote (30s)
# Application recover

# Restart old primary
docker start postgres-primary

# Otomatis rejoin sebagai standby
```

**7c. Simulasi Network Partition**

```bash
# Pause primary (simulasi network partition)
docker pause postgres-primary

# Monitor detect failure, promote replica
# Application tetap jalan

# Unpause
docker unpause postgres-primary

# Primary rejoin sebagai standby
```

---

## Troubleshooting Commands

### Check Service Health

```bash
# Semua containers
docker compose ps

# Logs
docker logs pg-monitor
docker logs postgres-primary
docker logs postgres-replica1
docker logs haproxy1

# Health checks
docker inspect postgres-primary | jq '.[0].State.Health'
```

### Reset Semua

```bash
# Stop semua services dan hapus volumes (WARNING: hapus semua data!)
docker compose down -v

# Restart fresh
docker compose up -d
```

### Database Direct Access

```bash
# Connect langsung ke primary (bypass HAProxy)
docker exec -it psql-client psql -h postgres-primary -U postgres -d demodb

# Connect langsung ke replica
docker exec -it psql-client psql -h postgres-replica1 -U postgres -d demodb

# Connect ke monitor
docker exec -it psql-client psql -h pg-monitor -U autoctl_node -d pg_auto_failover
```

### Force Failover

```bash
# Emergency failover
docker exec psql-client pg_autoctl perform failover \
  --monitor 'postgres://autoctl_node@pg-monitor:5432/pg_auto_failover'
```

### Enable Maintenance Mode

```bash
# Masukkan node ke maintenance (trigger failover jika primary)
docker exec postgres-primary pg_autoctl enable maintenance \
  --pgdata /var/lib/postgresql/data

# Disable maintenance
docker exec postgres-primary pg_autoctl disable maintenance \
  --pgdata /var/lib/postgresql/data
```

---

## Referensi Informasi Koneksi

### Akses External (dari laptop/host)

| Service | URL/Endpoint | Tujuan |
|---------|-------------|---------|
| Web App | http://localhost:8080/ | Application UI |
| HAProxy Stats | http://localhost:8404/ | Monitoring dashboard |
| PostgreSQL Write | localhost:6432 | Database writes (via HAProxy VIP) |
| PostgreSQL Read | localhost:6433 | Database reads (via HAProxy VIP) |
| PostgreSQL Primary | localhost:5432 | Direct access (debug) |
| PostgreSQL Replica | localhost:5433 | Direct access (debug) |
| Monitor | localhost:5430 | pg_auto_failover monitor (debug) |

### Akses Internal (antar containers)

```bash
# HAProxy VIP (Keepalived)
172.30.0.100:80      # HTTP
172.30.0.100:6432    # PostgreSQL write
172.30.0.100:6433    # PostgreSQL read
172.30.0.100:8404    # Stats

# Direct container access
haproxy1:80, haproxy1:6432, haproxy1:6433    # HAProxy 1
haproxy2:80, haproxy2:6432, haproxy2:6433    # HAProxy 2
postgres-primary:5432                         # PostgreSQL primary
postgres-replica1:5432                        # PostgreSQL replica
pg-monitor:5432                               # Monitor
app1:5000, app2:5000                         # Applications
```

---

## Cleanup

```bash
# Stop semua services (keep volumes/data)
docker compose down

# Stop dan hapus semua data (volumes)
docker compose down -v

# Hapus generated files
rm -f *.log
```

---

## Referensi Cepat: pg_autoctl Commands

```bash
# Show cluster state
pg_autoctl show state --monitor 'postgres://autoctl_node@pg-monitor:5432/pg_auto_failover'

# Show events/history
pg_autoctl show events --monitor 'postgres://autoctl_node@pg-monitor:5432/pg_auto_failover'

# Perform failover
pg_autoctl perform failover --monitor 'postgres://autoctl_node@pg-monitor:5432/pg_auto_failover'

# Perform switchover (graceful)
pg_autoctl perform switchover --monitor 'postgres://autoctl_node@pg-monitor:5432/pg_auto_failover'

# Enable maintenance
pg_autoctl enable maintenance --pgdata /var/lib/postgresql/data

# Disable maintenance
pg_autoctl disable maintenance --pgdata /var/lib/postgresql/data

# Show settings
pg_autoctl show settings --pgdata /var/lib/postgresql/data
```

---

## Success Criteria

Setelah menyelesaikan demo-demo ini, Anda harus observasi:

✅ **Demo 1:** Cluster healthy, replication working, data muncul di replica
✅ **Demo 2:** Automatic failover < 30s, zero manual intervention, automatic rejoin
✅ **Demo 3:** Graceful switchover, zero data loss, minimal disruption
✅ **Demo 4:** VIP failover < 5s, application tetap jalan
✅ **Demo 5:** Application redundancy, zero downtime saat instance failure
✅ **Demo 6:** Monitoring working, metrics tersedia, observability jelas
✅ **Demo 7:** Recovery dari multiple failures, system self-healing

---

**Last Updated:** 2025-11-07
**Tested with:** Docker 24.x, Podman 4.x, PostgreSQL 17, pg_auto_failover 2.1
