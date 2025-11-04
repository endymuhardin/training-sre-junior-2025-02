# 🌐 Simulasi Web Blocking Network I/O (Node.js/Express)

Aplikasi ini adalah contoh minimalis dari server Node.js yang menggunakan operasi **Network I/O Sinkron (Blocking)**, yang menyebabkan **seluruh server menjadi lumpuh (unresponsive)** selama operasi I/O berlangsung.

Simulasi ini menggunakan *library* `sync-request` untuk memaksa *HTTP request* agar memblokir *Event Loop* utama Node.js.

## 🎯 Tujuan Simulasi

Tujuan utama simulasi ini adalah untuk menunjukkan bagaimana satu *request* I/O yang *blocking* dapat memengaruhi konkurensi dan latensi server, yang dapat dimonitor menggunakan *tools* seperti **Apache Bench (`ab`)**.

## ⚙️ Persiapan dan Instalasi

### 1\. Kebutuhan Sistem

Pastikan Anda memiliki:

  * Node.js dan npm terinstal.
  * *Tools* CLI Linux untuk pengujian: **`curl`** dan **`ab` (Apache Bench)**.

### 2\. Instalasi Dependensi

Instal `express` dan `sync-request`:

```bash
npm install express sync-request
```

### 3\. Kode Aplikasi (`app.js`)

Kode ini mengatur *request* sinkron berulang kali ke layanan eksternal yang sengaja memberikan *delay* $5$ detik.

```javascript
const express = require('express');
const request = require('sync-request'); 
const app = express();
const PORT = 3001; 

const DELAY_URL = 'http://httpstat.us/200?sleep=5000'; // Delay 5 detik
const REPEAT_COUNT = 30; // Total Blocking: 30 x 5 detik = ~150 detik (2.5 menit)

// Fungsi Blocking I/O (Network Request Sinkron)
function performHeavyBlockingIO() {
    
    const startTime = Date.now();
    let totalRequests = 0;
    
    console.log(`[${new Date().toLocaleTimeString()}] Mulai Blocking Network I/O (${DELAY_URL}, diulang ${REPEAT_COUNT} kali)...`);
    
    // --- Loop Blocking Network ---
    for (let i = 0; i < REPEAT_COUNT; i++) {
        try {
            // request.get() adalah operasi SINKRON. Ini memblokir Event Loop.
            const res = request('GET', DELAY_URL);
            if (res.statusCode === 200) {
                totalRequests++;
            }
        } catch (error) {
            console.error('Terjadi error Network:', error.message);
            break; 
        }
    }
    // ----------------------------

    const endTime = Date.now();
    const duration = (endTime - startTime) / 1000;

    console.log(`[${new Date().toLocaleTimeString()}] Selesai Blocking I/O. Durasi: ${duration.toFixed(2)}s`);
    return `Selesai ${totalRequests} request Network. Total Durasi Blocking: ${duration.toFixed(2)} detik.`;
}

// Endpoint Normal (Non-Blocking)
app.get('/', (req, res) => {
    res.send('Server aktif. Cek latensi (latency) saya di /latency.');
});

// Endpoint untuk memicu Blocking I/O
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

## ▶️ Petunjuk Pengujian dan Analisis

Pengujian ini harus dilakukan secara **paralel** di dua terminal terpisah untuk melihat dampak *blocking*.

### Langkah 1: Jalankan Server

Buka **Terminal A** dan jalankan aplikasi:

```bash
node app.js
```

### Langkah 2: Uji *Baseline* (Server Responsif)

Di **Terminal B**, uji responsivitas *endpoint* normal (`/`) menggunakan `ab`. Server seharusnya merespons dengan cepat.

```bash
ab -n 50 -c 5 http://localhost:3001/
```

**Hasil Diharapkan:** *Requests per second* **Tinggi** (misalnya \> 500 req/s).

### Langkah 3: Memicu Blocking dan Uji Konkurensi

Lakukan *request* ke `/block` (Terminal C) dan segera uji *endpoint* normal (`/`) secara bersamaan (Terminal D).

1.  **Terminal C (Pemicu Blocking):** Jalankan di *background* untuk segera memblokir server.

    ```bash
    curl http://localhost:3001/block & 
    ```

2.  **Terminal D (Pengujian Paralel):** Segera setelah Terminal C, uji latensi *endpoint* normal (`/`).

    ```bash
    # Uji 10 request, 5 konkurensi
    ab -n 10 -c 5 http://localhost:3001/
    ```

### Hasil Analisis (Bukti Blocking)

| Metrik | Skenario Normal (`ab /`) | Skenario Blocking (`ab /` saat `/block` aktif) | Makna |
| :--- | :--- | :--- | :--- |
| **Time taken for tests** | Sangat Cepat ($< 1$ detik) | **Sangat Lama** ($\approx 150$ detik) | *Request* normal harus menunggu *blocking request* selesai. |
| **Requests per second** | Tinggi | **Mendekati Nol** ($\approx 0.06$ req/s) | *Throughput* server jatuh karena *Event Loop* lumpuh. |
| **Time per request (mean)** | Sangat Rendah | **Sangat Tinggi** ($\approx 150$ detik) | Latensi server sangat buruk karena **tidak dapat memproses *request* baru** saat *blocking* terjadi. |

Ini membuktikan bahwa di lingkungan *single-threaded* seperti Node.js, I/O sinkron yang lama akan memblokir semua pekerjaan, termasuk merespons *request* sederhana.

-----

## 🛑 Cara Menghentikan

Untuk menghentikan server, tekan `Ctrl + C` di **Terminal A**.