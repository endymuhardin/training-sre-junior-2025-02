# Demo 1: Stateless Layer High Availability

Demonstrasi High Availability pada stateless layer menggunakan HAProxy dan Nginx.

## Arsitektur

### Part 1: Application Layer HA (docker-compose-1.yml)
```
     ┌─────────────────────┐
     │   HAProxy (Single)  │
     │   Port 8080         │
     └──────────┬──────────┘
                │
        ┌───────┼───────┐
        │       │       │
     ┌──▼──┐ ┌──▼──┐ ┌──▼──┐
     │Nginx│ │Nginx│ │Nginx│
     │  1  │ │  2  │ │  3  │
     └─────┘ └─────┘ └─────┘
```

### Part 2: Full Stack HA (docker-compose-2.yml)
```
     ┌──────────────────────────────┐
     │    Virtual IP (172.20.0.100) │
     │         Keepalived           │
     └───────────────┬──────────────┘
                     │
          ┌──────────┴──────────┐
          │                     │
     ┌────▼────┐          ┌────▼────┐
     │HAProxy 1│          │HAProxy 2│
     │ MASTER  │          │ BACKUP  │
     └────┬────┘          └────┬────┘
          │                     │
          └──────────┬──────────┘
                     │
             ┌───────┼───────┐
             │       │       │
          ┌──▼──┐ ┌──▼──┐ ┌──▼──┐
          │Nginx│ │Nginx│ │Nginx│
          │  1  │ │  2  │ │  3  │
          └─────┘ └─────┘ └─────┘
```

## Konsep HA yang Didemonstrasikan

### Part 1:
- **Load Balancing**: Distribusi traffic ke multiple backends
- **Health Checks**: Deteksi otomatis instance yang gagal
- **Automatic Failover**: Traffic dialihkan saat instance down
- **Round Robin**: Algoritma distribusi sederhana

### Part 2:
- **Virtual IP (VIP)**: Single entry point yang dapat berpindah
- **VRRP Protocol**: Virtual Router Redundancy Protocol
- **Active-Passive HA**: Master/Backup configuration
- **Automatic Promotion**: Backup menjadi master saat master down
- **Split-Brain Prevention**: Authentication dan priority

---

## Part 1: Application Layer HA

### 1. Jalankan Environment

```bash
docker compose -f docker-compose-1.yml up -d
```

### 2. Verifikasi Services

```bash
# Check container status
docker ps

# Check HAProxy stats
open http://localhost:8404

# Test application
curl http://localhost:8080
```

### 3. Demo: Load Balancing

**Terminal 1**: Monitor HAProxy logs
```bash
docker logs -f haproxy
```

**Terminal 2**: Generate load
```bash
# Run load test
./load-test.sh http://localhost:8080 30 0.3

# Or manual curl loop
for i in {1..10}; do
    curl -s http://localhost:8080 | grep "NGINX Instance"
    sleep 0.5
done
```

**Browser**: Refresh http://localhost:8080 multiple times dan perhatikan pergantian instance (warna berbeda).

### 4. Demo: Health Check & Failover

**Scenario**: Kill satu instance dan lihat traffic redistribution.

**Terminal 1**: Monitor HAProxy
```bash
watch -n1 'docker ps --format "table {{.Names}}\t{{.Status}}"'
```

**Terminal 2**: Generate continuous load
```bash
./load-test.sh http://localhost:8080 100 0.5
```

**Terminal 3**: Kill instances
```bash
# Kill nginx1
docker stop nginx1
# Tunggu 5-10 detik, perhatikan HAProxy marks it DOWN

# Kill nginx2 juga
docker stop nginx2
# Sekarang semua traffic ke nginx3

# Restore nginx1
docker start nginx1
# HAProxy automatically adds it back

# Restore nginx2
docker start nginx2
```

**Observasi**:
- HAProxy stats page (http://localhost:8404) menunjukkan backend status
- Load test tetap running tanpa error
- Distribution berubah sesuai available instances

### 5. Demo: Backend Recovery

```bash
# Start with all instances down except one
docker stop nginx1 nginx2

# Generate load (all goes to nginx3)
./load-test.sh http://localhost:8080 20 0.3

# Bring instances back one by one
docker start nginx1
sleep 5
docker start nginx2

# Observe traffic redistribution
```

### 6. Cleanup Part 1

```bash
docker compose -f docker-compose-1.yml down
```

---

## Part 2: Full Stack HA (HAProxy + Keepalived)

### 1. Jalankan Environment

```bash
docker compose -f docker-compose-2.yml up -d
```

### 2. Verifikasi VIP Setup

```bash
# Check containers
docker ps

# Check which HAProxy has VIP
docker exec haproxy1 ip addr show eth0 | grep 172.20.0.100
docker exec haproxy2 ip addr show eth0 | grep 172.20.0.100

# Test via VIP (through vip-access proxy)
curl http://localhost:8080
```

### 3. Demo: HAProxy Failover

**Terminal 1**: Monitor VIP ownership
```bash
watch -n1 "echo '=== HAProxy 1 ===' && docker exec haproxy1 ip addr show eth0 | grep '172.20.0' && echo && echo '=== HAProxy 2 ===' && docker exec haproxy2 ip addr show eth0 | grep '172.20.0'"
```

**Terminal 2**: Generate continuous load
```bash
./load-test.sh http://localhost:8080 200 0.3
```

**Terminal 3**: Failover simulation
```bash
# Kill master HAProxy
docker stop haproxy1

# Observasi:
# - VIP berpindah ke haproxy2 (dalam 1-3 detik)
# - Load test continues WITHOUT interruption
# - Minimal packet loss (1-2 requests mungkin timeout)

# Tunggu 10 detik, lalu restore
docker start haproxy1

# VIP stays with haproxy2 (sekarang master)
# haproxy1 becomes backup

# Kill haproxy2 (current master)
docker stop haproxy2

# VIP kembali ke haproxy1
```

**Expected Results**:
- Failover time: 1-3 seconds
- Lost requests during failover: 0-2 requests
- Automatic recovery tanpa manual intervention

### 4. Demo: Kill HAProxy Process (Not Container)

Ini lebih realistis karena simulate process crash.

```bash
# Kill haproxy process di container
docker exec haproxy1 pkill haproxy

# Keepalived detects and triggers failover
# VIP moves to haproxy2

# Note: Container masih running, hanya process haproxy yang dead
```

### 5. Demo: Network Partition Simulation

```bash
# Disconnect haproxy1 dari network
docker network disconnect demo-1-stateless-ha_ha-net haproxy1

# VIP immediately fails over to haproxy2

# Reconnect
docker network connect demo-1-stateless-ha_ha-net haproxy1
```

### 6. Demo: Backend Failover with HA Load Balancer

Kombinasi: Kill backend PLUS kill load balancer.

```bash
# Terminal 1: Continuous monitoring
./load-test.sh http://localhost:8080 300 0.2

# Terminal 2: Chaos
docker stop nginx1        # Backend failure
sleep 5
docker stop haproxy1      # Load balancer failure
sleep 5
docker stop nginx2        # Another backend failure
sleep 5
docker start nginx1       # Recovery
docker start haproxy1
docker start nginx2

# Observe resilience at multiple layers
```

### 7. Inspect Keepalived Logs

```bash
# Check keepalived status
docker exec haproxy1 tail -f /var/log/messages 2>/dev/null || \
docker logs haproxy1 2>&1 | grep -i keepalived

docker exec haproxy2 tail -f /var/log/messages 2>/dev/null || \
docker logs haproxy2 2>&1 | grep -i keepalived
```

### 8. Check HAProxy Stats from Both Instances

```bash
# HAProxy1 stats
docker exec haproxy1 sh -c "echo 'show stat' | socat stdio /var/run/haproxy.sock"

# HAProxy2 stats
docker exec haproxy2 sh -c "echo 'show stat' | socat stdio /var/run/haproxy.sock"
```

### 9. Cleanup Part 2

```bash
docker compose -f docker-compose-2.yml down
```

---

## Workshop Exercise

### Exercise 1: Understand Health Checks
1. Modify `haproxy.cfg` - change `inter 2s` ke `inter 10s`
2. Restart dan observe slower detection
3. Change `fall 3` ke `fall 1` - observe faster failover

### Exercise 2: Load Balancing Algorithms
Edit `haproxy.cfg`, ganti `balance roundrobin` dengan:
- `leastconn` - Least connections
- `source` - Source IP hash (sticky)

Restart dan test dengan load script.

### Exercise 3: Keepalived Priority
1. Edit `keepalived-master.conf`, set priority ke 80
2. Edit `keepalived-backup.conf`, set priority ke 90
3. Restart - backup becomes master (higher priority)

### Exercise 4: Simulate Split Brain
1. Start compose-2
2. Modify both keepalived configs to state MASTER
3. Observe both try to claim VIP (Docker network prevents actual split-brain)

### Exercise 5: Monitoring Integration
Add health check endpoint ke nginx:
```bash
# Create health endpoint
echo "OK" > demo-1-stateless-ha/html/nginx1/health
echo "OK" > demo-1-stateless-ha/html/nginx2/health
echo "OK" > demo-1-stateless-ha/html/nginx3/health

# Update haproxy.cfg
option httpchk GET /health
```

---

## Troubleshooting

### VIP tidak muncul
```bash
# Check keepalived running
docker exec haproxy1 ps | grep keepalived

# Check permissions
docker exec haproxy1 ip addr show eth0
```

### HAProxy tidak start
```bash
# Validate config
docker exec haproxy1 haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg

# Check logs
docker logs haproxy1
```

### Load test errors
```bash
# Check port accessibility
curl -v http://localhost:8080

# Check HAProxy stats
curl http://localhost:8404
```

---

## Metrics to Monitor

### HAProxy Stats (http://localhost:8404)
- **scur**: Current sessions
- **qcur**: Queued requests
- **status**: Backend status (UP/DOWN)
- **weight**: Server weight
- **check**: Last health check status
- **downtime**: Total downtime

### Key Indicators
- **Failover time**: Time VIP takes to switch (target: < 3s)
- **Request success rate**: Should be > 99% during backend failure
- **Distribution**: Should be ~33% each instance when healthy

---

## Production Considerations

### HAProxy Best Practices
- Use `option redispatch` untuk retry pada server lain
- Set appropriate `timeout` values
- Enable `option http-server-close` untuk connection pooling
- Use `maxconn` untuk rate limiting

### Keepalived Best Practices
- Use unique `virtual_router_id` per VRRP instance
- Strong `auth_pass` di production
- Monitor keepalived logs
- Test failover regularly

### Monitoring
- Integrate dengan Prometheus HAProxy exporter
- Alert pada backend DOWN events
- Track VIP movements
- Monitor request latency during failover

---

## Next Steps

Lanjut ke **Demo 2: Stateful Layer HA** untuk database replication dengan PostgreSQL.

## Referensi

- [HAProxy Documentation](http://www.haproxy.org/documentation.html)
- [Keepalived Documentation](https://keepalived.readthedocs.io/)
- [VRRP Protocol RFC 5798](https://tools.ietf.org/html/rfc5798)
