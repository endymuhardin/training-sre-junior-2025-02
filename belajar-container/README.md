# Belajar Menggunakan Container #

Kebutuhan Software (pilih salah satu):

* Docker Desktop
* Podman Desktop
* Rancher Desktop

## Cara Menjalankan Container ##

1. Menjalankan image [postgresql official](https://hub.docker.com/_/postgres)

    * Menggunakan podman

        ```
        podman run -e POSTGRES_DB=belajar -e POSTGRES_USER=belajar -e POSTGRES_PASSWORD=docker -p 12345:5432 -v "/Users/endymuhardin/workspace/training/training-sre-junior-2025-02/belajar-container/db-belajar":"/var/lib/postgresql/data" postgres:17-alpine
        ```
    
    * Menggunakan docker

        ```
        docker run -e POSTGRES_DB=belajar -e POSTGRES_USER=belajar -e POSTGRES_PASSWORD=docker -p 12345:5432 -v "/Users/endymuhardin/workspace/training/training-sre-junior-2025-02/belajar-container/db-belajar":"/var/lib/postgresql/data" postgres:17-alpine
        ```

2. Connect ke running container

    * Menggunakan podman

        ```
        podman exec -it <container_name_or_id> /bin/bash
        ```

    * Menggunakan docker

        ```
        docker exec -it <container_name_or_id> /bin/bash
        ```

3. Melihat isi database (setelah connect ke running container)

    * Login 

        ```
        psql -U belajar -d belajar
        ```
    
    * Melihat daftar tabel/sequence

        ```
        \d
        ```
    
    * Melihat isi tabel `product`

        ```
        select * from product;
        ```
    
    * Keluar dari shell postgres

        ```
        \q
        ```

## Menjalankan Container dengan Compose ##

1. Buat file `compose.yml` berisi daftar container yang mau dijalankan

2. Jalankan filenya

    * Dengan Podman

        ```
        podman compose up
        ```
    
    * Dengan Docker

        ```
        docker compose up
        ```

3. Menjalankan compose di background (berguna jika kita ingin exit terminal setelahnya)

    * Dengan Podman

        ```
        podman compose up -d
        ```
    
    * Dengan Docker

        ```
        docker compose up -d
        ```

4. Cek container yang berjalan untuk mendapatkan nama container

    * Dengan Podman

        ```
        podman ps -a
        ```
    
    * Dengan Docker

        ```
        docker ps -a
        ```

5. Mematikan container yang berjalan di compose

    * Dengan Podman

        ```
        podman compose down
        ```
    
    * Dengan Docker

        ```
        docker compose down
        ```

## Menjalankan Contoh Aplikasi Spring Boot ##

1. Matikan dulu podman/docker compose

    ```
    podman compose down
    ```

    atau 

    ```
    docker compose down
    ```

2. Hapus folder volume mapping database

    ```
    rm -rf db-belajar
    ```

3. Jalankan lagi podman/docker compose

4. Jalankan aplikasi spring boot

    ```
    mvn clean spring-boot:run
    ```

5. Cek hasilnya di [http://localhost:8080/api/product](http://localhost:8080/api/product)

## Membuat Docker Image ##

1. Buat `Dockerfile`

2. Jalankan command untuk build

    ```
    podman build -t belajar-container .
    ```

    atau

    ```
    docker build -t belajar-container .
    ```

    **Jangan lupa titik di belakang, menunjukkan build context, yaitu folder saat ini (current folder)**

3. Tag untuk upload ke repository

    ```
    podman tag belajar-container docker.io/endymuhardin/belajar-container
    ```

    atau

    ```
    docker tag belajar-container endymuhardin/belajar-container
    ```

4. Login ke DockerHub

    ```
    podman login
    ```

    atau

    ```
    docker login
    ```

    Masukkan username dan password akun di [DockerHub](https://hub.docker.com)

5. Upload image

    ```
    podman push docker.io/endymuhardin/belajar-container
    ```

    atau

    ```
    docker push endymuhardin/belajar-container
    ```

6. Build docker image untuk beberapa architecture (arm64 dan amd64) sekaligus

    ```
    docker buildx build --platform linux/amd64,linux/arm64 --push -t endymuhardin/belajar-container .
    ```

    **Catatan: versi podman [terlalu ribet setupnya](https://medium.com/@guillem.riera/podman-machine-setup-for-x86-64-on-apple-silicon-run-docker-amd64-containers-on-m1-m2-m3-bf02bea38598)**

## Menjalankan di Kubernetes ##

### Prasyarat ###

* Kubernetes cluster yang sudah berjalan (minikube, kind, Docker Desktop dengan Kubernetes enabled, atau cluster lainnya)
* kubectl sudah terinstall dan terkonfigurasi

### Struktur File Kubernetes ###

Folder `k8s/` berisi file-file deployment descriptor yang sudah diurutkan sesuai urutan eksekusi:

```
k8s/
├── 01-configmap.yml    # ConfigMap untuk konfigurasi non-sensitif
├── 02-secret.yml       # Secret untuk data sensitif (password)
├── 03-pv.yml          # PersistentVolume untuk penyimpanan database
├── 04-pvc.yml         # PersistentVolumeClaim untuk request storage
├── 05-database.yml    # Deployment & Service untuk PostgreSQL
└── 06-webapp.yml      # Deployment & Service untuk aplikasi web
```

### Penjelasan Komponen ###

#### 1. ConfigMap (01-configmap.yml) ####

ConfigMap digunakan untuk menyimpan **konfigurasi yang tidak sensitif** dalam bentuk key-value pairs:

* `POSTGRES_DB` - nama database
* `POSTGRES_USER` - username database
* `SPRING_DATASOURCE_URL` - connection string aplikasi ke database

ConfigMap bersifat **plain text** dan bisa dilihat siapa saja yang punya akses ke cluster.

#### 2. Secret (02-secret.yml) ####

Secret digunakan untuk menyimpan **data sensitif** seperti password, token, atau API key:

* `POSTGRES_PASSWORD` - password database

Secret di-encode dengan base64 (bukan enkripsi). Di production, sebaiknya gunakan enkripsi at-rest dan RBAC untuk membatasi akses.

#### 3. PersistentVolume (03-pv.yml) ####

PersistentVolume (PV) adalah resource storage di cluster. Pada contoh ini:

* Kapasitas: 1Gi
* Access mode: ReadWriteOnce (hanya bisa di-mount oleh satu node)
* Storage class: manual
* Type: hostPath (menggunakan folder di node, **tidak cocok untuk production**)

#### 4. PersistentVolumeClaim (04-pvc.yml) ####

PersistentVolumeClaim (PVC) adalah request storage oleh user/pod. Pod akan menggunakan PVC untuk mendapatkan akses ke PV.

#### 5. Database Deployment & Service (05-database.yml) ####

File ini berisi dua resource:

**Deployment:**
* Menjalankan PostgreSQL 17 Alpine
* Mengambil konfigurasi dari ConfigMap dan Secret
* Mount PVC ke `/var/lib/postgresql/data`

**Service:**
* Type: ClusterIP (hanya bisa diakses dari dalam cluster)
* Port: 5432
* Nama service: `db-belajar` (digunakan oleh aplikasi untuk koneksi)

#### 6. Webapp Deployment & Service (06-webapp.yml) ####

File ini berisi dua resource:

**Deployment:**
* Menjalankan aplikasi Spring Boot
* Mengambil connection string dari ConfigMap
* Connect ke database menggunakan nama service `db-belajar`

**Service:**
* Type: NodePort (bisa diakses dari luar cluster)
* Port internal: 8080
* NodePort: 30001 (port untuk akses dari luar)

### Cara Deploy ke Kubernetes ###

#### 1. Deploy semua resource sekaligus ####

```bash
kubectl apply -f k8s/
```

Kubernetes akan memproses file-file secara alfabetis, sehingga urutan sudah benar.

#### 2. Deploy satu per satu (untuk pembelajaran) ####

```bash
# Step 1: Buat ConfigMap
kubectl apply -f k8s/01-configmap.yml

# Step 2: Buat Secret
kubectl apply -f k8s/02-secret.yml

# Step 3: Buat PersistentVolume
kubectl apply -f k8s/03-pv.yml

# Step 4: Buat PersistentVolumeClaim
kubectl apply -f k8s/04-pvc.yml

# Step 5: Deploy database
kubectl apply -f k8s/05-database.yml

# Step 6: Deploy aplikasi web
kubectl apply -f k8s/06-webapp.yml
```

### Verifikasi Deployment ###

#### 1. Cek status semua resource ####

```bash
# Cek semua pods
kubectl get pods

# Cek semua services
kubectl get svc

# Cek ConfigMap
kubectl get configmap

# Cek Secret
kubectl get secret

# Cek PV dan PVC
kubectl get pv,pvc
```

#### 2. Lihat detail pod tertentu ####

```bash
kubectl describe pod <nama-pod>
```

#### 3. Lihat log aplikasi ####

```bash
# Log database
kubectl logs deployment/db-belajar

# Log aplikasi
kubectl logs deployment/app-belajar

# Follow log (terus update)
kubectl logs -f deployment/app-belajar
```

#### 4. Lihat isi ConfigMap ####

```bash
kubectl get configmap belajar-config -o yaml
```

#### 5. Lihat isi Secret (terenkode base64) ####

```bash
kubectl get secret belajar-secret -o yaml
```

#### 6. Decode secret untuk melihat nilai asli ####

```bash
kubectl get secret belajar-secret -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d
```

### Mengakses Aplikasi ###

#### 1. Menggunakan NodePort ####

Aplikasi bisa diakses melalui NodePort 30001:

```bash
# Jika menggunakan minikube
minikube service app-belajar

# Atau akses manual
# Dapatkan IP node
kubectl get nodes -o wide

# Akses melalui browser
http://<node-ip>:30001/api/product
```

#### 2. Menggunakan Port Forward (alternatif) ####

```bash
kubectl port-forward service/app-belajar 10001:8080
```

Kemudian akses di [http://localhost:10001/api/product](http://localhost:10001/api/product)

### Troubleshooting ###

#### Pod tidak bisa start ####

```bash
# Lihat events untuk pod yang error
kubectl describe pod <nama-pod>

# Lihat log pod yang error
kubectl logs <nama-pod>
```

#### Database tidak bisa diakses dari aplikasi ####

```bash
# Cek apakah service database sudah running
kubectl get svc db-belajar

# Test koneksi dari pod aplikasi
kubectl exec -it deployment/app-belajar -- /bin/sh
# Kemudian di dalam pod:
ping db-belajar
```

#### PVC tidak bisa bind ke PV ####

```bash
# Cek status PVC
kubectl get pvc

# Cek detail PVC
kubectl describe pvc postgres-pvc

# Cek apakah ada PV yang available
kubectl get pv
```

### Update Konfigurasi ###

#### 1. Update ConfigMap ####

```bash
# Edit ConfigMap
kubectl edit configmap belajar-config

# Atau update dari file
kubectl apply -f k8s/01-configmap.yml

# Restart pod agar membaca konfigurasi baru
kubectl rollout restart deployment/app-belajar
kubectl rollout restart deployment/db-belajar
```

#### 2. Update Secret ####

```bash
# Edit Secret
kubectl edit secret belajar-secret

# Restart pod agar membaca secret baru
kubectl rollout restart deployment/db-belajar
```

### Scaling Replicas (Menambah/Mengurangi Jumlah Pod) ###

Scaling adalah proses menambah atau mengurangi jumlah replicas (pod) dari sebuah deployment. Ini berguna untuk:
* **Scale up** - menambah replicas saat traffic tinggi
* **Scale down** - mengurangi replicas saat traffic rendah
* **High availability** - menjalankan multiple replicas untuk redundancy

#### 1. Melihat Jumlah Replicas Saat Ini ####

```bash
# Lihat semua deployments dan jumlah replicasnya
kubectl get deployments

# Lihat detail deployment tertentu
kubectl describe deployment app-belajar
```

Output akan menampilkan:
```
NAME          READY   UP-TO-DATE   AVAILABLE   AGE
app-belajar   1/1     1            1           5m
```

#### 2. Scale Menggunakan Command Line (Cara Cepat) ####

```bash
# Scale aplikasi web menjadi 3 replicas
kubectl scale deployment app-belajar --replicas=3

# Verifikasi hasil scaling
kubectl get deployments
kubectl get pods

# Scale down menjadi 1 replica
kubectl scale deployment app-belajar --replicas=1

# Scale database (hati-hati dengan stateful apps!)
kubectl scale deployment db-belajar --replicas=1
```

**Catatan:** Database biasanya tidak bisa di-scale horizontal dengan mudah karena shared storage. Untuk scale database, perlu setup clustering (misal PostgreSQL dengan replication).

#### 3. Scale Dengan Edit File YAML (Cara Persistent) ####

Edit file `k8s/06-webapp.yml`:

```bash
kubectl edit deployment app-belajar
```

Atau edit file langsung, ubah bagian `replicas`:

```yaml
spec:
  replicas: 3  # Ubah dari 1 menjadi 3
  selector:
    matchLabels:
      app: belajar-app
```

Kemudian apply perubahan:

```bash
kubectl apply -f k8s/06-webapp.yml
```

#### 4. Monitoring Proses Scaling ####

```bash
# Watch pods saat scaling berlangsung
kubectl get pods -w

# Lihat events scaling
kubectl describe deployment app-belajar

# Lihat rollout status
kubectl rollout status deployment/app-belajar
```

#### 5. Load Balancing Antar Replicas ####

Service akan secara otomatis melakukan load balancing ke semua replicas yang available:

```bash
# Lihat endpoints yang di-manage oleh service
kubectl get endpoints app-belajar

# Detail endpoints
kubectl describe endpoints app-belajar
```

Output akan menampilkan IP dari semua pod replicas.

#### 6. Test Load Balancing ####

```bash
# Akses aplikasi berkali-kali
for i in {1..10}; do
  curl http://<node-ip>:30001/api/product
done

# Lihat log dari semua replicas untuk memastikan traffic terdistribusi
kubectl logs -l app=belajar-app --tail=20
```

#### 7. Auto Scaling (Horizontal Pod Autoscaler) ####

Untuk auto scaling berdasarkan CPU/memory usage:

```bash
# Setup autoscaler (min 1, max 5 replicas, target CPU 50%)
kubectl autoscale deployment app-belajar --min=1 --max=5 --cpu-percent=50

# Lihat status HPA
kubectl get hpa

# Detail HPA
kubectl describe hpa app-belajar

# Hapus autoscaler
kubectl delete hpa app-belajar
```

**Catatan:** HPA membutuhkan metrics-server yang terinstall di cluster.

#### 8. Best Practices Untuk Scaling ####

**Aplikasi Web (Stateless):**
* Aman untuk di-scale horizontal (multiple replicas)
* Pastikan aplikasi tidak menyimpan state di memory/disk lokal
* Session harus di-share (Redis, database) atau gunakan stateless auth (JWT)

**Database (Stateful):**
* **JANGAN** scale horizontal sembarangan
* Gunakan StatefulSet, bukan Deployment
* Setup replication/clustering dengan benar
* Primary-Replica atau Multi-Master architecture
* Untuk PostgreSQL: gunakan tools seperti Patroni, Stolon, atau managed database

**Contoh Setup Multi-Replica untuk Aplikasi:**

Edit `k8s/06-webapp.yml` dan update replicas menjadi 3:

```yaml
spec:
  replicas: 3
```

Apply perubahan:

```bash
kubectl apply -f k8s/06-webapp.yml

# Tunggu sampai semua pod running
kubectl get pods -w
```

Verify load balancing:

```bash
# Lihat pod mana yang handle request
kubectl logs -l app=belajar-app -f
```

### Membersihkan Resource ###

#### 1. Hapus semua resource sekaligus ####

```bash
kubectl delete -f k8s/
```

#### 2. Hapus satu per satu (reverse order) ####

```bash
kubectl delete -f k8s/06-webapp.yml
kubectl delete -f k8s/05-database.yml
kubectl delete -f k8s/04-pvc.yml
kubectl delete -f k8s/03-pv.yml
kubectl delete -f k8s/02-secret.yml
kubectl delete -f k8s/01-configmap.yml
```

### Catatan Penting ###

* **hostPath PV tidak cocok untuk production**. Gunakan storage provider yang proper seperti:
  * Cloud provider storage (AWS EBS, GCP Persistent Disk, Azure Disk)
  * Network storage (NFS, Ceph, GlusterFS)
  * Storage class dengan dynamic provisioning

* **Secret hanya di-encode, bukan di-encrypt**. Untuk production:
  * Enable encryption at rest di cluster
  * Gunakan external secret management (Vault, AWS Secrets Manager)
  * Implement RBAC untuk membatasi akses

* **Credentials hardcoded di YAML tidak aman**. Alternatif:
  * Gunakan external secret operator
  * Generate secret secara dynamic
  * Inject credentials saat runtime