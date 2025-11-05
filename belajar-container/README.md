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