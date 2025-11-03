# 🧩 Instalasi WordPress di RHEL 9 dengan Nginx, PHP-FPM, dan MariaDB

Playbook Ansible ini digunakan untuk mengotomatisasi proses instalasi dan konfigurasi **WordPress** dengan **Nginx**, **PHP-FPM**, dan **MariaDB** pada **Red Hat Enterprise Linux 9** atau distro turunan seperti **Rocky Linux 9** dan **AlmaLinux 9**.

Playbook ini akan melakukan langkah-langkah berikut secara otomatis:
- Menginstal semua paket yang dibutuhkan
- Mengonfigurasi Nginx, PHP-FPM, dan MariaDB
- Membuat database dan user untuk WordPress
- Mengunduh dan mengekstrak WordPress versi terbaru
- Membuat file `wp-config.php` secara otomatis
- Menyelesaikan instalasi WordPress menggunakan **WP-CLI**
- Membuka port HTTP (80) dan HTTPS (443) di firewall

---

## 📁 Struktur Folder

```
wordpress-ansible/
├── inventory
├── install_wordpress_nginx.yml
├── templates/
│   └── wp-config.php.j2
└── README.md
```

---

## ⚙️ Persyaratan

- Node kontrol dengan **Ansible versi 2.13 atau lebih baru**
- Server target menjalankan **RHEL 9 / AlmaLinux 9 / Rocky Linux 9**
- Akses SSH dengan hak `sudo`
- Server target memiliki akses internet

---

## 📦 Koleksi Ansible yang Diperlukan

Sebelum menjalankan playbook, instal koleksi berikut:

```bash
ansible-galaxy collection install community.mysql ansible.posix
```

---

## 🧠 Variabel Utama

Semua variabel dapat diubah pada bagian atas file `install_wordpress_nginx.yml`.

| Variabel | Keterangan | Nilai Bawaan |
|-----------|-------------|--------------|
| `wp_db_name` | Nama database untuk WordPress | `wordpress` |
| `wp_db_user` | Nama pengguna database | `wpuser` |
| `wp_db_password` | Kata sandi database | `passwordku` |
| `wp_root` | Lokasi instalasi WordPress | `/usr/share/nginx/html` |
| `server_name` | Domain atau alamat IP server | `your_domain_or_ip` |
| `wp_admin_user` | Nama pengguna admin WordPress | `admin` |
| `wp_admin_password` | Kata sandi admin WordPress | `admin12345` |
| `wp_admin_email` | Email admin | `admin@example.com` |
| `wp_site_title` | Judul situs | `My WordPress Site` |

> 🔐 Untuk keamanan, gunakan **Ansible Vault** untuk mengenkripsi kata sandi:
> ```bash
> ansible-vault encrypt_string 'passwordku' --name 'wp_db_password'
> ```

---

## 🖥️ Contoh File Inventory

Buat file bernama `inventory`:

```ini
[webservers]
192.168.1.100 ansible_user=ec2-user ansible_become=true
```

Ubah IP dan nama pengguna sesuai dengan server target Anda.

---

## 🚀 Menjalankan Playbook

Jalankan perintah berikut untuk memulai instalasi:

```bash
ansible-playbook -i inventory install_wordpress_nginx.yml
```

---

## 🌐 Setelah Instalasi

Setelah playbook selesai dijalankan:
- Akses situs melalui: **http://your_domain_or_ip**
- WordPress sudah terinstal dan siap digunakan
- Kredensial admin:
  - **Username:** `admin`
  - **Password:** `admin12345`
- File konfigurasi Nginx: `/etc/nginx/conf.d/wordpress.conf`
- Direktori WordPress: `/usr/share/nginx/html`

---

## 🔒 Firewall

Playbook ini secara otomatis membuka port **HTTP (80)** dan **HTTPS (443)**:

```bash
sudo firewall-cmd --list-all
```

---

## 🧱 Tambahan SSL (Opsional)

Jika Anda memiliki domain aktif dan ingin menambahkan HTTPS:

```bash
sudo dnf install -y certbot python3-certbot-nginx
sudo certbot --nginx -d nama_domain_anda
```

---

## 🧰 Pemeriksaan dan Pemecahan Masalah

Beberapa perintah untuk memeriksa layanan:

```bash
systemctl status nginx
systemctl status php-fpm
systemctl status mariadb
tail -f /var/log/nginx/error.log
```

---

## 🧩 Lisensi

Proyek ini menggunakan lisensi **MIT License**  
© 2025 Nama Anda / Organisasi Anda

---

## 🏁 Ringkasan

| Komponen | Terpasang | Dikonfigurasi | Status |
|-----------|------------|---------------|---------|
| Nginx | ✅ | ✅ | Aktif otomatis |
| PHP-FPM | ✅ | ✅ | Aktif otomatis |
| MariaDB | ✅ | ✅ | Aktif otomatis |
| WordPress | ✅ | ✅ | Siap digunakan |

---

💡 *Playbook ini memudahkan penerapan WordPress secara cepat, otomatis, dan konsisten pada server berbasis RHEL 9.*
