# Contoh Strategi Deployment Kubernetes

Directory ini berisi contoh konfigurasi untuk berbagai strategi deployment Kubernetes.

## Overview Strategi

### 1. Rolling Update (Default)
**File**: `rolling-update.yml`

Update pods secara bertahap tanpa downtime. Pods baru dibuat sebelum yang lama dihapus.

**Gunakan saat**:
- Zero downtime dibutuhkan
- Resources terbatas
- Aplikasi stateless

**Commands**:
```bash
kubectl apply -f rolling-update.yml
kubectl set image deployment/app-belajar app=endymuhardin/belajar-container:v2
kubectl rollout status deployment/app-belajar
kubectl rollout undo deployment/app-belajar  # Rollback
```

### 2. Recreate
**File**: `recreate.yml`

Hapus semua pods lama sebelum create yang baru. Ada downtime.

**Gunakan saat**:
- Tidak bisa run 2 versi bersamaan
- Database migration breaking changes
- Environment dev/test

**Commands**:
```bash
kubectl apply -f recreate.yml
kubectl get pods -w  # Watch termination dan recreation
```

### 3. Blue-Green Deployment
**Directory**: `blue-green/`

Dua environment identik. Switch traffic instant dari blue ke green.

**Gunakan saat**:
- Butuh instant rollback
- Punya 2x resources
- Perlu full production testing

**Commands**:
```bash
cd blue-green/
kubectl apply -f 01-blue-deployment.yml
kubectl apply -f 02-green-deployment.yml
kubectl apply -f 03-service.yml

# Switch to green
kubectl patch service app-belajar -p '{"spec":{"selector":{"version":"green"}}}'

# Rollback to blue
kubectl patch service app-belajar -p '{"spec":{"selector":{"version":"blue"}}}'
```

### 4. Canary Deployment
**Directory**: `canary/`

Rollout bertahap ke subset user. Mulai dengan percentage kecil, increase jika stable.

**Gunakan saat**:
- Aplikasi user-facing
- Ingin gradual rollout
- Perlu real production testing

**Commands**:
```bash
cd canary/
kubectl apply -f 01-stable-deployment.yml
kubectl apply -f 02-canary-deployment.yml
kubectl apply -f 03-service.yml

# Increase canary traffic
kubectl scale deployment app-belajar-v2 --replicas=3
kubectl scale deployment app-belajar-v1 --replicas=7

# Complete rollout
kubectl scale deployment app-belajar-v2 --replicas=10
kubectl scale deployment app-belajar-v1 --replicas=0
```

## Matriks Perbandingan

| Strategi | Downtime | Kompleksitas | Biaya Resource | Kecepatan Rollback | Risk | Terbaik Untuk |
|----------|----------|--------------|----------------|-------------------|------|---------------|
| **Rolling Update** | Tidak ada | Rendah | Rendah | Sedang | Rendah-Sedang | Kebanyakan apps |
| **Recreate** | Ada | Sangat Rendah | Rendah | Lambat | Tinggi | Dev/Test |
| **Blue-Green** | Tidak ada | Sedang | Tinggi (2x) | Instant | Rendah | Apps kritikal |
| **Canary** | Tidak ada | Tinggi | Sedang | Cepat | Sangat Rendah | Apps user-facing |

## Testing Deployments

### Monitor Rollout
```bash
# Watch deployment progress
kubectl rollout status deployment/app-belajar

# Watch pods
kubectl get pods -w

# Check rollout history
kubectl rollout history deployment/app-belajar
```

### Generate Load Saat Deployment
```bash
# Dari dalam cluster
kubectl run load-test --image=busybox --rm -it --restart=Never -- sh
while true; do wget -q -O- http://app-belajar:8080/api/product; sleep 0.5; done

# Dari luar (jika exposed)
while true; do curl http://localhost:30001/api/product; sleep 0.5; done
```

### Monitor Distribusi Traffic
```bash
# Watch which pods handle requests
kubectl logs -f -l app=belajar-app --prefix=true --max-log-requests=1000

# Check service endpoints
kubectl get endpoints app-belajar -o yaml

# Resource usage
kubectl top pods -l app=belajar-app
```

## Advanced: With Argo Rollouts

For automated canary with metrics-based decisions:

```bash
# Install Argo Rollouts
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Install kubectl plugin
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-darwin-amd64
chmod +x kubectl-argo-rollouts-darwin-amd64
sudo mv kubectl-argo-rollouts-darwin-amd64 /usr/local/bin/kubectl-argo-rollouts

# Use Rollout instead of Deployment
kubectl argo rollouts get rollout app-belajar
kubectl argo rollouts promote app-belajar
kubectl argo rollouts abort app-belajar
```

## Best Practices

1. **Selalu gunakan readiness probes**: Cegah traffic ke pods yang unhealthy
2. **Set resource requests/limits**: Cegah resource starvation
3. **Test di staging dulu**: Gunakan strategi yang sama dengan production
4. **Monitor metrics**: CPU, memory, error rates saat rollout
5. **Punya rollback plan**: Test prosedur rollback
6. **Gradual rollouts untuk apps kritikal**: Mulai dengan canary
7. **Gunakan labels konsisten**: Untuk traffic management
8. **Dokumentasikan prosedur deployment**: Untuk konsistensi team

## Cleanup

```bash
# Hapus semua deployments
kubectl delete deployment --all

# Atau hapus strategi spesifik
kubectl delete -f rolling-update.yml
kubectl delete -f blue-green/
kubectl delete -f canary/
```

## Referensi

- [Dokumentasi Kubernetes Deployment](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Argo Rollouts](https://argoproj.github.io/rollouts/)
- [Flagger](https://flagger.app/)
