# 🚀 DigitalOcean, AWS, & GCP HAProxy Cluster

## 📖 Deskripsi Proyek

Proyek ini menyediakan arsitektur aplikasi web berdaya tahan tinggi (High Availability/HA) menggunakan **Terraform** di tiga penyedia *cloud* berbeda: **DigitalOcean**, **Amazon Web Services (AWS)**, dan **Google Cloud Platform (GCP)**.

Tujuan utamanya adalah merealisasikan topologi berikut menggunakan **Droplet/VM (Virtual Machine)** untuk semua komponen, memastikan isolasi jaringan, dan hanya mengekspos Load Balancer ke publik.

### **Topologi Inti**

| Komponen | Jumlah | Role | Eksposur IP |
| :--- | :--- | :--- | :--- |
| **Load Balancer** | 1 Droplet/VM | HAProxy (Titik masuk publik) | **Publik & Privat** |
| **Aplikasi Web** | 3 Droplet/VM | Node Web Server (Nginx) | Hanya **Privat** (VPC/VPC Network) |
| **Database** | 2 Droplet/VM | Primary & Secondary (Replikasi Manual) | Hanya **Privat** (VPC/VPC Network) |

-----

## 💾 Struktur Proyek

Proyek ini memiliki tiga file konfigurasi Terraform yang terpisah, masing-masing spesifik untuk satu *cloud provider*:

| File Terraform | Cloud Provider | Keterangan |
| :--- | :--- | :--- |
| `main.tf` | **DigitalOcean** | Menggunakan **Droplet** dan **VPC** DigitalOcean. |
| `main-aws.tf` | **AWS** | Menggunakan **EC2**, **VPC**, **Subnet**, dan **Security Groups**. |
| `main-gcp.tf` | **GCP** | Menggunakan **Compute Engine**, **VPC Network**, dan **Firewall Rules**. |

-----

## ⚙️ Persyaratan dan Pra-Syarat

Pastikan Anda memiliki:

1.  **Terraform CLI** terinstal.
2.  **Kunci SSH** publik (`~/.ssh/id_rsa.pub`) di mesin lokal Anda (atau sesuaikan jalurnya di setiap skrip).
3.  Kredensial API yang sesuai untuk *provider* yang ingin Anda *deploy*:

| Cloud Provider | Variabel Lingkungan / Kredensial |
| :--- | :--- |
| **DigitalOcean** | `export DIGITALOCEAN_TOKEN="YOUR_DO_TOKEN"` |
| **AWS** | `export AWS_ACCESS_KEY_ID="..."` dan `export AWS_SECRET_ACCESS_KEY="..."` |
| **GCP** | File Kunci Akun Layanan (`service account key file`) dan setel `gcloud auth application-default login` atau konfigurasi kredensial. Jangan lupa ganti `project` ID di `main-gcp.tf`. |

-----

## 🛠️ Cara Menggunakan

Untuk setiap *provider*, ikuti langkah-langkah berikut:

### 1. Inisialisasi

Pilih file yang ingin Anda gunakan dan salin ke direktori kerja Anda (atau gunakan nama file yang sama).

```bash
# Contoh: Untuk DigitalOcean
terraform init
```

*(Ulangi langkah ini jika Anda berpindah ke direktori atau file provider lain.)*

### 2. Rencana dan Terapkan

Periksa rencana eksekusi dan terapkan konfigurasi:

```bash
terraform plan -var-file="vars-example.tfvars" # Gunakan jika Anda menggunakan variabel
terraform apply
```

**Catatan Khusus:**

  * **AWS:** Pastikan Anda telah mengganti `your-key-pair-name` dan `ami-id` di `main-aws.tf` dengan nilai yang valid untuk *region* Anda.
  * **GCP:** Pastikan `project = "your-gcp-project-id"` di `main-gcp.tf` telah diganti.

### 3. Akses

Setelah `apply` selesai, Terraform akan menampilkan IP Publik dari Load Balancer:

| Cloud Provider | Output Utama |
| :--- | :--- |
| **DigitalOcean** | `haproxy_public_ip` |
| **AWS** | `haproxy_public_ip_aws` |
| **GCP** | `haproxy_public_ip_gcp` |

### 4. Pembersihan

Untuk menghapus semua sumber daya yang dibuat, jalankan:

```bash
terraform destroy
```

-----

## 📝 Catatan Penting Mengenai Isolasi

Semua skrip mengandalkan fitur jaringan pribadi *cloud provider* untuk memastikan node Aplikasi Web dan Database terisolasi:

  * **DigitalOcean:** Menggunakan **VPC** tanpa `access_config` publik pada node internal.
  * **AWS:** Menggunakan **Private Subnet** dan **Security Groups** untuk membatasi lalu lintas hanya dari Load Balancer dan antar node internal.
  * **GCP:** Menggunakan **VPC Network** dan **Firewall Rules** yang menargetkan VM berdasarkan *tags*, memastikan Port 80 dari internet hanya terbuka pada VM HAProxy.

Semua komunikasi internal (misalnya, aplikasi ke database) menggunakan **IP Privat** masing-masing VM/EC2/Droplet.