# High Availability Workshop Demos

Demonstrasi hands-on untuk memahami konsep, prinsip, dan teknik High Availability dalam sistem production.

## Overview

Workshop ini mencakup 3 demo komprehensif yang mendemonstrasikan HA di berbagai layer aplikasi:

1. **Demo 1**: Stateless Layer HA (HAProxy + Nginx)
2. **Demo 2**: Stateful Layer HA (PostgreSQL Replication)
3. **Demo 3**: Full Stack HA End-to-End (Complete integration)

## Workshop Structure

### Demo 1: Stateless Layer High Availability
📁 `demo-1-stateless-ha/`

**Konsep yang dipelajari**:
- Load balancing dengan HAProxy
- Health checks dan automatic failover
- Virtual IP dengan Keepalived (VRRP)
- Active-passive redundancy
- Split-brain prevention

**Technology Stack**:
- HAProxy 2.9
- Nginx Alpine
- Keepalived
- Docker Compose

**Duration**: 60-90 minutes

**Progression**:
1. **Part 1**: Single HAProxy → Multiple Nginx (app-level HA)
2. **Part 2**: HA HAProxy pair (with Keepalived) → Multiple Nginx (full stateless stack HA)

[📖 Full Documentation](demo-1-stateless-ha/README.md)

---

### Demo 2: Stateful Layer High Availability
📁 `demo-2-stateful-ha/`

**Konsep yang dipelajari**:
- PostgreSQL streaming replication
- Primary-replica architecture
- Read scaling strategies
- Replication lag monitoring
- Manual failover procedures
- Data durability vs performance trade-offs
- Split-brain scenarios

**Technology Stack**:
- PostgreSQL 16
- PgBouncer (connection pooling)
- Docker Compose

**Duration**: 90-120 minutes

**Key Demos**:
1. Basic replication setup
2. Read scaling with replicas
3. Primary failure & manual failover
4. Replication lag under load
5. Split-brain prevention

[📖 Full Documentation](demo-2-stateful-ha/README.md)

---

### Demo 3: Full Stack High Availability (End-to-End)
📁 `demo-3-full-stack-ha/`

**Konsep yang dipelajari**:
- Complete multi-tier HA architecture
- Load balancer redundancy (HAProxy + Keepalived)
- Application layer redundancy with health checks
- Database replication with read/write splitting
- End-to-end failover scenarios
- Cascade failure handling
- Production-ready patterns

**Technology Stack**:
- HAProxy 2.9 (HA pair with Keepalived)
- Python Flask (Custom REST API)
- PostgreSQL 16 (Primary + Replica)
- Docker Compose

**Duration**: 120-150 minutes

**Key Features**:
1. Virtual IP failover for load balancers
2. Automatic application instance detection
3. Database connection management with fallback
4. Read/write splitting (writes to primary, reads from replica)
5. Comprehensive health checks at every layer
6. Interactive web interface with real-time stats
7. Automated chaos testing scenarios

**Demo Scenarios**:
1. Normal operation - load distribution
2. Application instance failure
3. Load balancer failover (VIP migration)
4. Database replica failure (automatic fallback)
5. Database primary failure (manual promotion)
6. Cascade failures (multi-layer)
7. Complete recovery procedures

[📖 Full Documentation](demo-3-full-stack-ha/README.md)

---

## Quick Start

### Prerequisites

```bash
# Required
- Docker Desktop atau Podman
- Docker Compose
- 8GB RAM minimum
- 20GB free disk space

# Optional (for testing)
- PostgreSQL client tools
- curl, wget
- watch command
```

### Setup

```bash
# Clone repository
cd belajar-ha

# Demo 1: Stateless HA
cd demo-1-stateless-ha
docker compose -f docker-compose-1.yml up -d
open http://localhost:8080
open http://localhost:8404  # HAProxy stats

# Demo 2: Stateful HA
cd ../demo-2-stateful-ha
docker compose up -d
./test-replication.sh

# Demo 3: Full Stack HA
cd ../demo-3-full-stack-ha
docker compose up -d --build
sleep 60  # Wait for initialization
./test-fullstack.sh
open http://localhost:8080
```

---

## Learning Path

### Recommended Workshop Flow

#### Session 1: Stateless HA Basics (45 min)
1. Introduction to HA concepts
2. Demo 1 Part 1: HAProxy load balancing
3. Hands-on: Kill Nginx instances, observe failover
4. Exercise: Modify health check parameters

#### Session 2: Complete Stateless HA (45 min)
1. Introduction to VRRP and Virtual IPs
2. Demo 1 Part 2: Keepalived + HAProxy
3. Hands-on: Kill HAProxy instances, observe VIP failover
4. Discussion: Split-brain scenarios

#### Break (15 min)

#### Session 3: Stateful HA Introduction (60 min)
1. Challenges of stateful HA
2. CAP Theorem basics
3. Demo 2: PostgreSQL replication setup
4. Hands-on: Test replication, monitor lag
5. Exercise: Generate load, observe behavior

#### Session 4: Failover & Advanced Topics (60 min)
1. Manual failover procedures
2. Demo 2: Primary failure scenario
3. Split-brain in databases
4. Production considerations
5. Discussion: Automatic failover tools

#### Wrap-up (15 min)
- Q&A
- Best practices summary
- Next steps (Patroni, Kubernetes, Cloud HA)

---

## Architecture Overview

### Complete HA Stack

```
┌─────────────────────────────────────────────────┐
│            USERS / CLIENTS                      │
└─────────────────┬───────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────┐
│         STATELESS LAYER HA (Demo 1)             │
│                                                  │
│    VIP (172.20.0.100) - Keepalived VRRP        │
│           │                                      │
│    ┌──────┴───────┐                            │
│    │              │                             │
│ ┌──▼────┐    ┌───▼────┐                        │
│ │HAProxy│    │HAProxy │  (Active-Passive)      │
│ │Master │    │Backup  │                         │
│ └──┬────┘    └───┬────┘                        │
│    │             │                               │
│    └──────┬──────┘                              │
│           │                                      │
│    ┌──────┼──────┐                              │
│    │      │      │                              │
│ ┌──▼─┐ ┌─▼──┐ ┌─▼──┐                           │
│ │Nginx│ │Nginx│ │Nginx│ (Stateless Apps)       │
│ └──┬─┘ └─┬──┘ └─┬──┘                           │
└────┼─────┼─────┼───────────────────────────────┘
     │     │     │
     └─────┼─────┘
           │
┌──────────▼──────────────────────────────────────┐
│        STATEFUL LAYER HA (Demo 2)               │
│                                                  │
│         ┌──────────────┐                        │
│         │  PostgreSQL  │                        │
│         │   Primary    │  (Read/Write)          │
│         └──────┬───────┘                        │
│                │                                 │
│        ┌───────┼───────┐                        │
│        │               │                        │
│   ┌────▼────┐    ┌────▼────┐                   │
│   │PostgreSQL│   │PostgreSQL│ (Read-Only)      │
│   │ Replica1 │   │ Replica2 │                   │
│   └──────────┘   └──────────┘                   │
│                                                  │
│   Streaming Replication (Async)                 │
└──────────────────────────────────────────────────┘
```

---

## Key Concepts Covered

### 1. High Availability Fundamentals
- **Redundancy**: Multiple instances of each component
- **Failover**: Automatic switching to backup
- **Health Checks**: Detecting failures
- **Load Distribution**: Spreading work across instances
- **Single Point of Failure (SPOF)**: Eliminating bottlenecks

### 2. Stateless vs Stateful HA

| Aspect | Stateless | Stateful |
|--------|-----------|----------|
| **Complexity** | Low | High |
| **Failover Time** | Fast (< 3s) | Slower (30-60s) |
| **Data Loss Risk** | None | Possible |
| **Scaling** | Easy (add instances) | Complex (replication) |
| **State Management** | No local state | Must sync state |
| **Example** | Web servers, API gateways | Databases, caches |

### 3. CAP Theorem (Database Context)
- **Consistency**: All nodes see same data
- **Availability**: System responds to requests
- **Partition Tolerance**: Works despite network issues

**PostgreSQL choice**: CP (Consistency + Partition Tolerance)
- Prioritizes data consistency
- May sacrifice availability during network partitions

### 4. Failure Scenarios
- **Process crash**: Application dies
- **Host failure**: Server hardware/OS crash
- **Network partition**: Connectivity loss
- **Cascading failure**: One failure triggers others
- **Split-brain**: Multiple nodes think they're primary

### 5. Metrics & SLOs
- **Uptime**: Percentage of time system is available
- **MTBF**: Mean Time Between Failures
- **MTTR**: Mean Time To Recovery
- **RPO**: Recovery Point Objective (data loss)
- **RTO**: Recovery Time Objective (downtime)

---

## Troubleshooting Guide

### Common Issues

#### Port Already in Use
```bash
# Check what's using the port
lsof -i :8080

# Kill the process or change port in docker-compose.yml
```

#### Docker Out of Memory
```bash
# Increase Docker Desktop memory allocation
# Docker Desktop → Settings → Resources → Memory → 8GB minimum
```

#### Containers Not Starting
```bash
# Check logs
docker compose logs

# Rebuild images
docker compose down
docker compose up -d --build
```

#### Scripts Permission Denied
```bash
# Make scripts executable
chmod +x *.sh
```

#### PostgreSQL Replication Not Working
```bash
# Check logs
docker logs postgres-replica1

# Verify primary is healthy
docker exec postgres-primary pg_isready

# Check replication status
docker exec postgres-primary psql -U postgres -c "SELECT * FROM pg_stat_replication;"
```

---

## Best Practices for Workshop Facilitators

### Preparation (1 day before)
- [ ] Test all demos on clean Docker environment
- [ ] Prepare backup slides explaining concepts
- [ ] Setup projector/screen sharing
- [ ] Print command cheat sheets for participants
- [ ] Verify internet connectivity (for image pulls)

### During Workshop
- [ ] Start each demo from scratch (no pre-built containers)
- [ ] Encourage participants to experiment and break things
- [ ] Use separate terminals for monitoring vs control
- [ ] Pause after each failure scenario for discussion
- [ ] Take questions after each section

### Tips
- Use `watch` command for continuous monitoring
- Open HAProxy stats dashboard on big screen
- Show both success and failure scenarios
- Emphasize "break things to learn" mentality
- Compare costs (resources, complexity) vs benefits

---

## Advanced Topics (Optional)

### After completing both demos, consider exploring:

#### Automatic Failover Tools
- **Patroni**: PostgreSQL HA with automatic failover
- **Consul**: Service discovery and health checking
- **etcd**: Distributed configuration store

#### Cloud HA Solutions
- AWS: RDS Multi-AZ, ALB, Auto Scaling
- GCP: Cloud SQL HA, Cloud Load Balancing
- DigitalOcean: Managed Databases, Load Balancers

#### Kubernetes HA
- ReplicaSets for stateless apps
- StatefulSets for stateful apps
- Service mesh (Istio, Linkerd)

#### Monitoring & Alerting
- Prometheus + Grafana
- ELK Stack
- PagerDuty integration

---

## Production Checklist

When implementing HA in production:

### Infrastructure
- [ ] Multiple availability zones/regions
- [ ] Automated backups
- [ ] Disaster recovery plan
- [ ] Network redundancy
- [ ] Power redundancy

### Application
- [ ] Health check endpoints
- [ ] Graceful shutdown
- [ ] Connection retry logic
- [ ] Circuit breakers
- [ ] Timeout configurations

### Database
- [ ] Replication lag monitoring
- [ ] Automated failover testing
- [ ] Backup verification
- [ ] Data corruption detection
- [ ] Point-in-time recovery capability

### Monitoring
- [ ] Uptime monitoring
- [ ] Performance metrics
- [ ] Error rate tracking
- [ ] Capacity planning
- [ ] Alert escalation policies

### Procedures
- [ ] Runbooks for common failures
- [ ] Regular failover drills
- [ ] Incident response plan
- [ ] Post-mortem process
- [ ] Documentation updates

---

## Cost Considerations

### Demo 1 Resources
- CPU: 2 cores
- RAM: 2GB
- Storage: 1GB
- **Cost**: ~$20/month (single DigitalOcean droplet)

### Demo 2 Resources
- CPU: 4 cores
- RAM: 4GB
- Storage: 20GB
- **Cost**: ~$40/month (single DigitalOcean droplet)

### Production HA (Typical)
- Multiple regions: 2-3x base cost
- Redundant components: 2-3x resource cost
- Monitoring infrastructure: +20% cost
- **Total multiplier**: 4-6x single instance cost

**Trade-off**: Higher cost for better availability

---

## Success Criteria

By the end of this workshop, participants should be able to:

### Understanding
- [ ] Explain difference between stateless and stateful HA
- [ ] Describe how load balancing works
- [ ] Understand replication concepts
- [ ] Identify single points of failure
- [ ] Calculate availability percentages

### Skills
- [ ] Setup basic load balancer
- [ ] Configure health checks
- [ ] Deploy PostgreSQL replication
- [ ] Perform manual failover
- [ ] Monitor system health

### Application
- [ ] Design HA architecture for simple app
- [ ] Choose appropriate HA strategy
- [ ] Estimate HA costs and benefits
- [ ] Write basic runbooks
- [ ] Plan disaster recovery

---

## Catatan Penting Container Runtime

### DHCP dan DNS Considerations

Ketika menggunakan Docker Desktop atau Podman Desktop, container yang di-restart akan mendapatkan alamat IP baru dari DHCP. Ini dapat menyebabkan masalah dengan layanan yang melakukan cache DNS resolution.

**Semua demo telah dikonfigurasi untuk menangani masalah ini**, namun penting untuk memahami:

- **HAProxy**: Memerlukan konfigurasi `resolvers` untuk DNS dinamis
- **PostgreSQL**: Menangani perubahan IP secara native (tidak perlu konfigurasi)
- **Keepalived**: Memerlukan konfigurasi keamanan script yang tepat

**📖 Dokumentasi Lengkap**: [CONTAINER-RUNTIME-NOTES-ID.md](./CONTAINER-RUNTIME-NOTES-ID.md)

Dokumentasi ini mencakup:
- ✅ Penjelasan lengkap masalah DHCP/DNS
- ✅ Analisis per demo dan solusinya
- ✅ Perbedaan Docker vs Podman
- ✅ Konfigurasi keamanan Keepalived
- ✅ Troubleshooting decision tree
- ✅ Best practices untuk production

**Baca dokumentasi ini jika**:
- Mengalami masalah backend DOWN setelah container restart
- Menggunakan Podman (perlu update IP DNS server)
- Melihat error "SECURITY VIOLATION" di log keepalived
- Ingin memahami bagaimana setiap komponen menangani perubahan IP

---

## Additional Resources

### Documentation
- [HAProxy Best Practices](http://www.haproxy.org/#docs)
- [PostgreSQL HA Documentation](https://www.postgresql.org/docs/current/high-availability.html)
- [VRRP RFC 5798](https://tools.ietf.org/html/rfc5798)

### Books
- "Site Reliability Engineering" (Google)
- "Database Reliability Engineering" (O'Reilly)
- "The Art of Capacity Planning" (O'Reilly)

### Online Courses
- Linux Academy: HA and Fault Tolerance
- Udemy: PostgreSQL High Availability
- Coursera: Cloud Computing Specialization

### Tools
- [Chaos Monkey](https://netflix.github.io/chaosmonkey/) - Failure injection
- [Locust](https://locust.io/) - Load testing
- [Grafana](https://grafana.com/) - Monitoring dashboards

---

## Feedback & Improvements

This workshop material is continuously improved. Feedback welcome:

- GitHub Issues: [Repository issues](https://github.com/your-repo)
- Email: [your-email]
- Slack: [your-slack-channel]

---

## License

These workshop materials are provided for educational purposes.

---

## Credits

Created for SRE Junior Training 2025 - Batch 2

**Author**: [Your Name]
**Last Updated**: 2025-11-07
**Version**: 1.0
