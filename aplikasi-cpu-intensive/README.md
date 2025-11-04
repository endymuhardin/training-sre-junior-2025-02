# ⚙️ Simulasi Bottleneck CPU (CPU Intensive Web App)

Aplikasi web sederhana ini dibuat menggunakan **Node.js dan Express** untuk mensimulasikan beban kerja (workload) yang intensif pada CPU. Tujuannya adalah untuk mengamati dan menganalisis fenomena **Bottleneck CPU**, khususnya bagaimana tugas yang memblokir (*blocking tasks*) dapat melumpuhkan *event loop* Node.js, sehingga meningkatkan latensi (waktu respons) secara drastis bahkan untuk *endpoint* yang ringan.

-----

## 🎯 Tujuan

  * Mensimulasikan beban kerja **CPU-Intensive** yang memblokir *event loop* Node.js (aplikasi *single-threaded*).
  * Menyediakan *endpoint* yang lambat dan cepat untuk perbandingan kinerja di bawah beban.
  * Digunakan sebagai target untuk *tool* **Load Testing** (seperti Apache JMeter, k6, atau Gatling).
  * Memvisualisasikan *bottleneck* CPU pada sistem *monitoring*.

-----

## 🚀 Cara Menjalankan Aplikasi

Aplikasi ini memerlukan **Node.js** terinstal di sistem Anda.

### 1\. Prasyarat

Pastikan Anda berada di direktori proyek dan telah menginstal dependensi:

```bash
# Inisialisasi proyek (jika belum dilakukan)
npm init -y

# Instal Express
npm install express
```

### 2\. Struktur File

Pastikan kode server berada dalam file `server.js`:

```
.
├── node_modules/
├── package.json
├── package-lock.json
└── server.js 👈 File utama
```

### 3\. Jalankan Server

Gunakan perintah `node` untuk menjalankan aplikasi:

```bash
node server.js
# Server akan berjalan di http://localhost:3000
```

-----

## 🌐 Endpoint Aplikasi

Aplikasi menyediakan dua *endpoint* utama untuk pengujian:

### 1\. `/cpu-intensive`

  * **Tipe Beban:** **CPU-Intensive (Blocking)**
  * **Aksi:** Menjalankan fungsi perhitungan faktorial yang memakan waktu lama.
  * **Efek:** **Memblokir** *event loop*. Ketika banyak permintaan tiba secara bersamaan, semua permintaan berikutnya (termasuk yang non-blocking) akan tertunda hingga perhitungan selesai. Ini mensimulasikan **bottleneck CPU**.

### 2\. `/non-blocking`

  * **Tipe Beban:** **I/O-Intensive (Non-Blocking)**
  * **Aksi:** Segera merespons dengan pesan sederhana.
  * **Efek:** *Endpoint* ini harusnya memiliki latensi yang sangat rendah. Namun, jika ada permintaan `/cpu-intensive` yang sedang berjalan, *endpoint* ini juga akan **terpengaruh** dan mengalami peningkatan latensi.

-----

## 🔬 Cara Menguji Bottleneck

### A. Pengujian Manual

1.  Akses `http://localhost:3000/cpu-intensive`. Amati proses *loading* yang lama.
2.  **Saat tab pertama masih *loading***, buka tab *browser* baru dan akses `http://localhost:3000/non-blocking`.
3.  **Observasi:** Anda akan melihat bahwa respons untuk `/non-blocking` juga tertunda. Ini membuktikan bahwa *single thread* Node.js sedang disibukkan oleh tugas CPU-intensif.

### B. Pengujian dengan Load Testing Tool (Direkomendasikan)

Untuk hasil yang lebih akurat, gunakan *tool* seperti k6 atau JMeter untuk mengirim banyak *Virtual Users* (VU) ke *endpoint* `/cpu-intensive`.

  * **Metrik Kunci yang Diamati:**
      * **Pemanfaatan CPU Server:** Akan melonjak hingga 100% pada satu *core* CPU.
      * **Latensi (Waktu Respons):** Akan meningkat tajam (misalnya, dari \< 50ms menjadi \> 5000ms).
      * **Throughput (RPS):** Akan menurun secara signifikan.

-----

## ⚠️ Peringatan

  * Aplikasi ini sengaja dibuat untuk menggunakan sumber daya CPU secara intensif.
  * **JANGAN** jalankan *load test* dengan volume yang terlalu tinggi pada mesin produksi atau mesin yang penting. Gunakan lingkungan pengujian yang terisolasi.
  * Fungsi perhitungan (`calculateFactorial` dalam `server.js`) dapat disesuaikan (misalnya, mengubah batas angka) untuk mengontrol durasi dan intensitas beban CPU.