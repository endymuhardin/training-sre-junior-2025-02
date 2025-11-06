# Kubernetes Deployment Configuration

## File Order

Aplikasikan file YAML dalam urutan berikut:

```bash
kubectl apply -f 01-configmap.yml
kubectl apply -f 02-secret.yml
kubectl apply -f 03-pv.yml
kubectl apply -f 04-pvc.yml  # tidak digunakan lagi oleh StatefulSet, tapi tetap ada untuk referensi
kubectl apply -f 05-database.yml
kubectl apply -f 06-webapp.yml
```

## StatefulSet untuk Database

### Kenapa Database Menggunakan StatefulSet?

Database PostgreSQL menggunakan **StatefulSet** bukan Deployment karena:

1. **Stable Network Identity**
   - Setiap pod mendapat hostname yang konsisten: `db-belajar-0`, `db-belajar-1`, dst
   - Hostname tidak berubah meskipun pod restart

2. **Ordered Deployment/Scaling**
   - Pod dibuat dan dihapus secara berurutan
   - Pod `db-belajar-1` hanya dibuat setelah `db-belajar-0` ready
   - Saat scale down, pod dengan index tertinggi dihapus terlebih dahulu

3. **Automatic PVC Management**
   - StatefulSet membuat PVC otomatis via `volumeClaimTemplates`
   - Setiap pod mendapat PVC sendiri: `postgres-storage-db-belajar-0`
   - PVC tidak otomatis terhapus saat pod dihapus (data protection)

### Service Architecture

File `05-database.yml` mendefinisikan 2 service:

1. **db-belajar-headless** (Headless Service)
   ```yaml
   clusterIP: None
   ```
   - Untuk internal StatefulSet management
   - Menyediakan DNS untuk setiap pod: `db-belajar-0.db-belajar-headless.default.svc.cluster.local`

2. **db-belajar** (Normal ClusterIP Service)
   ```yaml
   type: ClusterIP
   ```
   - Untuk koneksi dari aplikasi
   - Load balancing ke semua postgres pod
   - Endpoint: `db-belajar:5432`

### Volume Management

StatefulSet menggunakan `volumeClaimTemplates`:

```yaml
volumeClaimTemplates:
- metadata:
    name: postgres-storage
  spec:
    accessModes: [ "ReadWriteOnce" ]
    storageClassName: manual
    resources:
      requests:
        storage: 1Gi
```

PVC yang dibuat: `postgres-storage-db-belajar-0`

### PostgreSQL PGDATA Configuration

```yaml
env:
- name: PGDATA
  value: /var/lib/postgresql/data/pgdata
```

PostgreSQL memerlukan subdirectory dalam volume mount untuk menghindari error saat volume tidak kosong.

## Deployment vs StatefulSet

| Aspek | Deployment | StatefulSet |
|-------|-----------|-------------|
| Pod Name | random suffix | ordered index |
| Network Identity | tidak stabil | stabil |
| Volume | manual PVC | volumeClaimTemplates |
| Scaling | parallel | ordered |
| Use Case | stateless apps | stateful apps (DB, queue) |

## Cleanup

Untuk menghapus semua resource:

```bash
kubectl delete -f 06-webapp.yml
kubectl delete -f 05-database.yml
kubectl delete pvc postgres-storage-db-belajar-0  # PVC StatefulSet tidak auto-delete
kubectl delete -f 04-pvc.yml
kubectl delete -f 03-pv.yml
kubectl delete -f 02-secret.yml
kubectl delete -f 01-configmap.yml
```

**Catatan**: PVC yang dibuat oleh StatefulSet **tidak otomatis terhapus** saat StatefulSet dihapus, untuk mencegah kehilangan data.
