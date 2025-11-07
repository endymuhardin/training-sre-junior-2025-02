# High Availability Workshop - Command Cheat Sheet

Quick reference for common commands used in the workshop.

## General Docker Commands

```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# View logs
docker compose logs -f
docker logs <container_name>

# Check status
docker compose ps
docker ps

# Execute command in container
docker exec -it <container_name> <command>

# Restart container
docker restart <container_name>

# Stop container
docker stop <container_name>

# Start container
docker start <container_name>

# Remove all containers and volumes
docker compose down -v
```

---

## Demo 1: Stateless HA

### Start/Stop

```bash
cd demo-1-stateless-ha

# Part 1: Single HAProxy
docker compose -f docker-compose-1.yml up -d
docker compose -f docker-compose-1.yml down

# Part 2: HA HAProxy with Keepalived
docker compose -f docker-compose-2.yml up -d
docker compose -f docker-compose-2.yml down
```

### Testing

```bash
# Access application
curl http://localhost:8080
open http://localhost:8080

# HAProxy stats
open http://localhost:8404

# Load test
./load-test.sh http://localhost:8080 50 0.5

# Continuous curl
while true; do curl -s http://localhost:8080 | grep "Instance"; sleep 0.5; done
```

### Monitoring

```bash
# Watch container status
watch -n1 docker compose ps

# Watch HAProxy logs
docker logs -f haproxy

# Check which HAProxy has VIP
docker exec haproxy1 ip addr show eth0 | grep 172.20.0.100
docker exec haproxy2 ip addr show eth0 | grep 172.20.0.100

# Monitor VIP ownership
watch -n1 "docker exec haproxy1 ip addr show eth0 | grep '172.20.0' && docker exec haproxy2 ip addr show eth0 | grep '172.20.0'"
```

### Failure Simulation

```bash
# Kill Nginx instances
docker stop nginx1
docker stop nginx2
docker stop nginx3

# Restart Nginx instances
docker start nginx1
docker start nginx2
docker start nginx3

# Kill HAProxy (Part 2 only)
docker stop haproxy1
docker stop haproxy2

# Kill HAProxy process (not container)
docker exec haproxy1 pkill haproxy
```

---

## Demo 2: Stateful HA (PostgreSQL)

### Start/Stop

```bash
cd demo-2-stateful-ha

# Start all services
docker compose up -d

# Stop all services
docker compose down

# Clean data (WARNING: deletes all data)
docker compose down -v
rm -rf primary-data replica1-data replica2-data
```

### Quick Tests

```bash
# Automated test suite
./test-replication.sh

# Generate load
./generate-load.sh 60 2

# Promote replica
./promote-replica.sh postgres-replica1
```

### PostgreSQL Client Commands

```bash
# Connect to Primary
PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -d demodb

# Connect to Replica1
PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -d demodb

# Connect to Replica2
PGPASSWORD=postgres psql -h localhost -p 5434 -U postgres -d demodb

# Execute single query
PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -d demodb -c "SELECT * FROM users;"
```

### Useful SQL Queries

```sql
-- Check if primary or replica
SELECT pg_is_in_recovery();

-- View replication status (primary)
SELECT * FROM pg_stat_replication;

-- View replication lag (primary)
SELECT
    application_name,
    state,
    sync_state,
    replay_lag
FROM pg_stat_replication;

-- View replication lag (replica)
SELECT now() - pg_last_xact_replay_timestamp() AS replication_lag;

-- Check replication slots
SELECT * FROM pg_replication_slots;

-- View all users
SELECT * FROM users ORDER BY id DESC LIMIT 10;

-- Insert test data
INSERT INTO users (name, email) VALUES ('TestUser', 'test@example.com');

-- Count users
SELECT COUNT(*) FROM users;

-- Database size
SELECT pg_size_pretty(pg_database_size('demodb'));

-- Active connections
SELECT count(*) FROM pg_stat_activity;
```

### Monitoring

```bash
# Watch replication status
watch -n1 'docker exec postgres-primary psql -U postgres -c "SELECT * FROM pg_stat_replication;"'

# Watch replica lag
watch -n1 'docker exec postgres-replica1 psql -U postgres -c "SELECT now() - pg_last_xact_replay_timestamp() AS lag;"'

# Watch container status
watch -n1 docker compose ps

# View logs
docker logs -f postgres-primary
docker logs -f postgres-replica1
```

### Failure Simulation

```bash
# Kill primary
docker stop postgres-primary

# Kill replica
docker stop postgres-replica1
docker stop postgres-replica2

# Restart primary
docker start postgres-primary

# Promote replica to primary
./promote-replica.sh postgres-replica1

# Manual promotion
docker exec postgres-replica1 pg_ctl promote -D /var/lib/postgresql/data
```

---

## Multi-Terminal Setup Recommendations

### Demo 1: Stateless HA

**Terminal 1 (Top Left)**: Monitoring
```bash
watch -n1 docker compose ps
```

**Terminal 2 (Top Right)**: HAProxy Logs
```bash
docker logs -f haproxy
```

**Terminal 3 (Bottom Left)**: Load Generation
```bash
./load-test.sh http://localhost:8080 200 0.5
```

**Terminal 4 (Bottom Right)**: Control (failure injection)
```bash
# Execute docker stop/start commands
```

### Demo 2: Stateful HA

**Terminal 1 (Top Left)**: Replication Status
```bash
watch -n1 'docker exec postgres-primary psql -U postgres -c "SELECT * FROM pg_stat_replication;"'
```

**Terminal 2 (Top Right)**: Replica Lag
```bash
watch -n1 'docker exec postgres-replica1 psql -U postgres -c "SELECT now() - pg_last_xact_replay_timestamp();"'
```

**Terminal 3 (Bottom Left)**: Load Generation
```bash
./generate-load.sh 300 2
```

**Terminal 4 (Bottom Right)**: Control
```bash
# Execute failover commands
```

---

## Useful Monitoring Commands

### System Resources

```bash
# Container resource usage
docker stats

# Specific container stats
docker stats postgres-primary postgres-replica1 postgres-replica2

# Disk usage
docker system df

# Network inspection
docker network inspect <network_name>
```

### Health Checks

```bash
# Check if PostgreSQL is ready
docker exec postgres-primary pg_isready -U postgres

# Check HAProxy config
docker exec haproxy haproxy -c -f /usr/local/etc/haproxy/haproxy.cfg

# Test HTTP endpoint
curl -I http://localhost:8080
```

---

## Troubleshooting Commands

### Port Issues

```bash
# Find what's using a port (macOS/Linux)
lsof -i :8080
lsof -i :5432

# Kill process using port
kill -9 <PID>
```

### Container Issues

```bash
# Inspect container
docker inspect <container_name>

# View container processes
docker top <container_name>

# Container logs with tail
docker logs --tail 50 <container_name>

# Follow logs from specific time
docker logs --since 5m -f <container_name>
```

### Network Issues

```bash
# List networks
docker network ls

# Inspect network
docker network inspect <network_name>

# Test connectivity between containers
docker exec <container1> ping <container2>

# Test DNS resolution
docker exec <container> nslookup <hostname>
```

### Data/Volume Issues

```bash
# List volumes
docker volume ls

# Inspect volume
docker volume inspect <volume_name>

# Remove unused volumes
docker volume prune

# Remove specific volume
docker volume rm <volume_name>
```

---

## Emergency Recovery

### Demo 1: Stateless HA

```bash
# Complete reset
docker compose -f docker-compose-1.yml down
docker compose -f docker-compose-2.yml down
docker system prune -f
docker compose -f docker-compose-1.yml up -d
```

### Demo 2: Stateful HA

```bash
# Stop everything
docker compose down

# Remove data directories
rm -rf primary-data replica1-data replica2-data

# Start fresh
docker compose up -d

# Wait for initialization
sleep 30
./test-replication.sh
```

---

## Performance Testing

### HTTP Load Testing

```bash
# Using ab (ApacheBench)
ab -n 1000 -c 10 http://localhost:8080/

# Using hey
hey -n 1000 -c 10 http://localhost:8080/

# Using curl in loop (simple)
for i in {1..100}; do curl -s http://localhost:8080/ > /dev/null; done
```

### Database Load Testing

```bash
# Using pgbench (must install postgresql)
pgbench -i -h localhost -p 5432 -U postgres demodb
pgbench -c 10 -t 1000 -h localhost -p 5432 -U postgres demodb

# Simple insert loop
for i in {1..100}; do
  PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -d demodb \
    -c "INSERT INTO users (name, email) VALUES ('User$i', 'user$i@example.com');"
done
```

---

## Useful Aliases (Optional)

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
# Docker shortcuts
alias dc='docker compose'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dlogs='docker compose logs -f'
alias dstop='docker compose down'

# PostgreSQL shortcuts
alias pgprimary='PGPASSWORD=postgres psql -h localhost -p 5432 -U postgres -d demodb'
alias pgreplica1='PGPASSWORD=postgres psql -h localhost -p 5433 -U postgres -d demodb'
alias pgreplica2='PGPASSWORD=postgres psql -h localhost -p 5434 -U postgres -d demodb'

# Monitoring shortcuts
alias watchdocker='watch -n1 docker ps'
alias watchha='watch -n1 "curl -s http://localhost:8404 | grep -A20 nginx"'
```

---

## Quick Reference URLs

### Demo 1
- Application: http://localhost:8080
- HAProxy Stats: http://localhost:8404

### Demo 2
- Primary: localhost:5432
- Replica1: localhost:5433
- Replica2: localhost:5434
- PgBouncer: localhost:6432

---

## Common Pitfalls & Solutions

### "Port already in use"
```bash
# Find and kill process
lsof -i :<port> | grep LISTEN | awk '{print $2}' | xargs kill -9
```

### "Cannot connect to Docker daemon"
```bash
# Start Docker Desktop (macOS)
open -a Docker

# Or restart Docker service (Linux)
sudo systemctl restart docker
```

### "No space left on device"
```bash
# Clean up Docker
docker system prune -a --volumes
```

### Replication lag too high
```bash
# Check primary load
docker stats postgres-primary

# Check replica resources
docker stats postgres-replica1

# Restart replica to re-sync
docker restart postgres-replica1
```

---

## Workshop Flow Quick Guide

1. **Setup** (5 min): Clone repo, start Docker
2. **Demo 1 Part 1** (20 min): Basic load balancing
3. **Demo 1 Part 2** (25 min): HAProxy HA with Keepalived
4. **Break** (10 min)
5. **Demo 2 Setup** (15 min): PostgreSQL replication
6. **Demo 2 Testing** (30 min): Replication tests & failover
7. **Wrap-up** (15 min): Discussion & Q&A

**Total**: ~2 hours

---

## Need Help?

- Check logs: `docker compose logs`
- Check README: `cat README.md`
- Restart fresh: `docker compose down -v && docker compose up -d`
- Review specific demo: `cat demo-*/README.md`
