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

Aplikasi ini bisa di-deploy ke Kubernetes menggunakan StatefulSet untuk database dan Deployment untuk aplikasi web.

**Lihat dokumentasi lengkap di [k8s/README.md](k8s/README.md)** yang mencakup:

* StatefulSet untuk PostgreSQL dengan headless service
* ConfigMap dan Secret management
* PersistentVolume dan PersistentVolumeClaim
* Service architecture dan request flow
* Scaling, troubleshooting, dan best practices

### Quick Start ###

```bash
# Deploy semua resource
kubectl apply -f k8s/

# Cek status
kubectl get pods
kubectl get svc

# Akses aplikasi via port forward
kubectl port-forward service/app-belajar 10001:8080
```

Akses aplikasi di [http://localhost:10001/api/product](http://localhost:10001/api/product)

### Cleanup ###

```bash
kubectl delete -f k8s/
```