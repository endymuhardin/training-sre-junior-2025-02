# 🚫 Simulasi Web Blocking I/O (Node.js)

Aplikasi sederhana ini mendemonstrasikan perilaku **Blocking I/O** (Input/Output) pada server Node.js. Ketika *endpoint* khusus diakses, server secara sinkron akan membaca file besar berulang kali, yang akan **memblokir** Event Loop dan memicu kondisi **I/O Wait** pada sistem operasi Linux.

## 🎯 Tujuan Simulasi

Untuk melihat secara visual kondisi **I/O Wait** pada sistem Linux, yang ditandai dengan:

1.  Nilai **`wa`** (Wait) yang tinggi pada `vmstat`.
2.  Nilai **`IO%`** yang tinggi dan **`CPU%`** yang rendah pada proses Node.js di `iotop`.
3.  Server web yang **tidak responsif** terhadap *request* lain selama operasi I/O berlangsung.

-----

## ⚙️ Persiapan dan Instalasi

### 1\. Kebutuhan Sistem

Pastikan Anda memiliki:

  * Node.js dan npm terinstal.
  * Linux CLI *tools*: `vmstat`, `iotop`, `dd`, `curl`.

### 2\. Instalasi Dependensi

```bash
# Instal Express.js
npm install express
```

### 3\. Konfigurasi File Dummy

Buat file *dummy* berukuran **500 MB** yang akan digunakan untuk operasi I/O intensif.

```bash
# Membuat file dummy berukuran 500 MB (Pastikan ruang disk cukup!)
dd if=/dev/zero of=large_dummy_file.dat bs=1M count=500
```

### 4\. Kode Aplikasi (`app.js`)

Gunakan kode aplikasi yang sudah dimodifikasi dengan konfigurasi repetisi $10$ kali.

> **Catatan:** Pastikan kapasitas RAM Anda cukup untuk menampung $500 \text{ MB} \times 10 = 5 \text{ GB}$ alokasi memori secara bertahap. Jika terjadi error `Killed`, kurangi `REPEAT_COUNT` atau ukuran file.

```javascript
const express = require('express');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = 3001; // Menggunakan port 3001 untuk contoh ini
const LARGE_FILE = 'large_dummy_file.dat'; 
const REPEAT_COUNT = 10; // Repetisi disetel 10 kali

// Fungsi Blocking I/O (Membaca file besar BERULANG KALI)
function performHeavyBlockingIO() {
    const filePath = path.join(__dirname, LARGE_FILE);

    if (!fs.existsSync(filePath)) {
        return `Error: File ${LARGE_FILE} tidak ditemukan. Jalankan perintah 'dd' untuk membuatnya!`;
    }
    
    const startTime = Date.now();
    let totalBytesRead = 0;
    
    console.log(`[${new Date().toLocaleTimeString()}] Mulai Blocking I/O (membaca ${LARGE_FILE}, diulang ${REPEAT_COUNT} kali)...`);
    
    // --- Loop Blocking ---
    for (let i = 0; i < REPEAT_COUNT; i++) {
        try {
            // Operasi SINKRON yang memblokir Event Loop
            const data = fs.readFileSync(filePath);
            totalBytesRead += data.length;
        } catch (error) {
            console.error('Error saat membaca file:', error);
            return 'Gagal membaca file besar pada pengulangan.';
        }
    }
    // ----------------------

    const endTime = Date.now();
    const duration = (endTime - startTime) / 1000;
    const totalSizeMB = (totalBytesRead / (1024 * 1024)).toFixed(2);

    console.log(`[${new Date().toLocaleTimeString()}] Selesai Blocking I/O. Durasi: ${duration.toFixed(2)}s`);
    return `Selesai membaca total ${totalSizeMB} MB dalam ${REPEAT_COUNT} kali pengulangan. Durasi Blocking: ${duration.toFixed(2)} detik.`;
}

// Endpoint Normal
app.get('/', (req, res) => {
    res.send('Server aktif. Akses /block untuk memicu I/O Wait yang lama.');
});

// Endpoint Blocking I/O Intensif
app.get('/block', (req, res) => {
    const result = performHeavyBlockingIO();
    res.send(result);
});

// Jalankan Server
app.listen(PORT, () => {
    console.log(`Server berjalan di http://localhost:${PORT}`);
    console.log(`Endpoint Blocking: http://localhost:${PORT}/block`);
});
```

-----

## ▶️ Petunjuk Penggunaan dan Monitoring

Jalankan server dan siapkan terminal monitoring sebelum memicu *blocking*.

### Langkah 1: Jalankan Server

Buka **Terminal A** dan jalankan aplikasi:

```bash
node app.js
```

### Langkah 2: Siapkan Monitor

Buka **Terminal B** dan **Terminal C** untuk monitoring.

**Terminal B (vmstat)**: Monitor I/O Wait CPU

```bash
vmstat 1
```

> **Fokus:** Kolom **`wa`** (Wait) di bagian `cpu`.

**Terminal C (iotop)**: Monitor I/O Disk per Proses

```bash
sudo iotop -o
```

> **Fokus:** Proses **`node`**. Perhatikan **`IO%`** (tinggi) dan **`CPU%`** (rendah).

### Langkah 3: Pemicu Blocking

Buka **Terminal D** (atau gunakan *browser*) untuk memanggil *endpoint* blocking:

```bash
curl http://localhost:3001/block
```

### Hasil yang Diharapkan

  * **Terminal D (curl):** Akan terlihat diam/terhenti selama $\approx 5-15$ detik (tergantung kecepatan disk).
  * **Terminal B (vmstat):** Kolom **`wa`** akan melonjak drastis ($\sim 50\%$ hingga $90\%$). Ini adalah bukti bahwa CPU sedang **menganggur menunggu Disk I/O**.
  * **Terminal C (iotop):** Baris proses `node` akan menunjukkan nilai **`IO%` yang sangat tinggi** (mendekati $100\%$) tetapi nilai `CPU%` proses tersebut akan **rendah** (misalnya $<10\%$).

Setelah proses selesai, `vmstat` `wa` akan kembali normal, `iotop` akan tenang, dan `curl` akan menampilkan respons server.