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

## Quick Reference

| File | Service Type | Environment | Access Method |
|------|-------------|-------------|---------------|
| Default `06-webapp.yml` | NodePort | Kind | `localhost:8080` (dengan kind-config) |
| `06-webapp-loadbalancer.yml` | LoadBalancer | Docker Desktop K8s | `localhost:8080` |
| `06-webapp-loadbalancer.yml` | LoadBalancer | Minikube | `minikube tunnel` required |
| `06-webapp-loadbalancer.yml` | LoadBalancer | K3s | Auto via ServiceLB |
| `06-webapp-clusterip.yml` | ClusterIP | Any | `kubectl port-forward` |
| `06-webapp-clusterip.yml` + `07-ingress.yml` | ClusterIP | K3s | `http://belajar.local` |
