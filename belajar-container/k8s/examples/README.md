# Example Configurations

Folder ini berisi contoh konfigurasi alternatif untuk berbagai environment Kubernetes.

## Webapp Service Variants

### 06-webapp-loadbalancer.yml

Gunakan file ini untuk environment yang support LoadBalancer:
- **Docker Desktop Kubernetes**: LoadBalancer langsung exposed di `localhost`
- **Minikube**: Perlu `minikube tunnel` command
- **K3s**: ServiceLB (Klipper) sudah built-in

**Cara pakai:**
```bash
# Copy file ini sebagai 06-webapp.yml
cp examples/06-webapp-loadbalancer.yml 06-webapp.yml

# Deploy
kubectl apply -f k8s/
```

### 06-webapp-clusterip.yml

Gunakan file ini untuk:
- Development dengan `kubectl port-forward`
- Production-like setup dengan Ingress (K3s + Traefik)

**Cara pakai dengan port-forward:**
```bash
# Copy file ini sebagai 06-webapp.yml
cp examples/06-webapp-clusterip.yml 06-webapp.yml

# Deploy
kubectl apply -f k8s/

# Port-forward
kubectl port-forward service/app-belajar 8080:8080
```

**Cara pakai dengan Ingress (K3s):**
```bash
# Copy file ini sebagai 06-webapp.yml
cp examples/06-webapp-clusterip.yml 06-webapp.yml

# Deploy termasuk Ingress
kubectl apply -f k8s/
kubectl apply -f k8s/07-ingress.yml

# Tambah hosts entry
echo "127.0.0.1 belajar.local" | sudo tee -a /etc/hosts

# Akses
curl http://belajar.local/api/product
```

## Ingress Configuration

### 07-ingress.yml

Konfigurasi Ingress untuk K3s (Traefik).

**Cara pakai:**
```bash
# Pastikan service type adalah ClusterIP
kubectl apply -f k8s/07-ingress.yml

# Tambah hosts entry
echo "127.0.0.1 belajar.local" | sudo tee -a /etc/hosts

# Test
curl http://belajar.local/api/product
```

## Kind Cluster Configuration

### kind-config.yaml

Konfigurasi untuk membuat Kind cluster dengan port mapping ke NodePort.

**Cara pakai:**
```bash
# Create cluster dengan config
kind create cluster --config kind-config.yaml

# Deploy aplikasi (gunakan default 06-webapp.yml dengan NodePort)
kubectl apply -f k8s/

# Akses aplikasi
curl http://localhost:8080/api/product
```

Port mapping yang dikonfigurasi:
- containerPort: 30001 (NodePort di dalam cluster)
- hostPort: 8080 (Port di host machine)

## HPA Configuration

### hpa.yml

HorizontalPodAutoscaler configuration untuk auto-scaling berdasarkan CPU dan memory.

**Features:**
- Min replicas: 1, Max replicas: 10
- Target CPU: 50%, Target memory: 80%
- Smart scale-up (immediate) dan scale-down (5 min stabilization)

**Cara pakai:**
```bash
# Pastikan metrics-server sudah terinstall
kubectl top nodes

# Apply HPA
kubectl apply -f examples/hpa.yml

# Monitor HPA
kubectl get hpa -w
```

## Load Testing

### load-generator.yml

Deployment untuk generate continuous HTTP traffic ke aplikasi untuk testing HPA.

**Cara pakai:**
```bash
# Deploy load generator
kubectl apply -f examples/load-generator.yml

# Watch HPA dan pods scaling
watch 'kubectl get hpa && echo && kubectl get pods'

# Cleanup
kubectl delete -f examples/load-generator.yml
```

**Catatan**: Sesuaikan `replicas` di load-generator.yml untuk mengatur intensitas load.

## Quick Reference

| File | Service Type | Environment | Access Method |
|------|-------------|-------------|---------------|
| Default `06-webapp.yml` | NodePort | Kind | `localhost:8080` (dengan kind-config) |
| `06-webapp-loadbalancer.yml` | LoadBalancer | Docker Desktop K8s | `localhost:8080` |
| `06-webapp-loadbalancer.yml` | LoadBalancer | Minikube | `minikube tunnel` required |
| `06-webapp-loadbalancer.yml` | LoadBalancer | K3s | Auto via ServiceLB |
| `06-webapp-clusterip.yml` | ClusterIP | Any | `kubectl port-forward` |
| `06-webapp-clusterip.yml` + `07-ingress.yml` | ClusterIP | K3s | `http://belajar.local` |
| `hpa.yml` | - | Any (with metrics-server) | Auto-scaling config |
| `load-generator.yml` | - | Any | Load testing tool |

**Note**: Semua webapp example files sudah include resource requests/limits yang required untuk HPA.

## Deployment Strategies

Folder `deployment-strategies/` berisi contoh berbagai strategi deployment:

### Rolling Update
**File**: `deployment-strategies/rolling-update.yml`

Strategi default Kubernetes. Update pods bertahap tanpa downtime.

**Cara pakai:**
```bash
kubectl apply -f deployment-strategies/rolling-update.yml
kubectl set image deployment/app-belajar app=endymuhardin/belajar-container:v2
kubectl rollout status deployment/app-belajar
```

### Recreate
**File**: `deployment-strategies/recreate.yml`

Hapus semua pods lama, buat semua pods baru. Ada downtime.

### Blue-Green
**Folder**: `deployment-strategies/blue-green/`

Maintain 2 environment. Switch traffic instant dari blue ke green.

**Cara pakai:**
```bash
cd deployment-strategies/blue-green/
kubectl apply -f 01-blue-deployment.yml
kubectl apply -f 02-green-deployment.yml
kubectl apply -f 03-service.yml

# Switch ke green
kubectl patch service app-belajar -p '{"spec":{"selector":{"version":"green"}}}'
```

### Canary
**Folder**: `deployment-strategies/canary/`

Rollout bertahap ke subset user. Control percentage dengan replica count.

**Cara pakai:**
```bash
cd deployment-strategies/canary/
kubectl apply -f 01-stable-deployment.yml
kubectl apply -f 02-canary-deployment.yml
kubectl apply -f 03-service.yml

# Increase canary traffic ke 25%
kubectl scale deployment app-belajar-v2 --replicas=3
kubectl scale deployment app-belajar-v1 --replicas=9
```

Lihat [deployment-strategies/README.md](deployment-strategies/README.md) untuk detail lengkap.
