const express = require('express');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = 3001;
const LARGE_FILE = 'large_dummy_file.dat'; // File dummy 1 GB atau lebih

// Tetapkan berapa kali operasi I/O harus diulang.
// Misal, jika 1 kali baca butuh 1.5 detik, 5 kali ulang butuh ~7.5 detik blocking.
const REPEAT_COUNT = 10; 

// Fungsi Blocking I/O (Membaca file besar BERULANG KALI)
function performHeavyBlockingIO() {
    const filePath = path.join(__dirname, LARGE_FILE);

    if (!fs.existsSync(filePath)) {
        return `Error: File ${LARGE_FILE} tidak ditemukan. Buat file dummy dulu!`;
    }
    
    const startTime = Date.now();
    let totalBytesRead = 0;
    
    console.log(`[${new Date().toLocaleTimeString()}] Mulai Blocking I/O (membaca ${LARGE_FILE}, diulang ${REPEAT_COUNT} kali)...`);
    
    // --- Peningkatan Blok I/O ---
    for (let i = 0; i < REPEAT_COUNT; i++) {
        try {
            // fs.readFileSync akan memblokir Event Loop berulang kali
            const data = fs.readFileSync(filePath);
            totalBytesRead += data.length;
        } catch (error) {
            console.error('Error saat membaca file:', error);
            return 'Gagal membaca file besar pada pengulangan.';
        }
    }
    // ----------------------------

    const endTime = Date.now();
    const duration = (endTime - startTime) / 1000;
    const totalSizeMB = (totalBytesRead / (1024 * 1024)).toFixed(2);

    console.log(`[${new Date().toLocaleTimeString()}] Selesai Blocking I/O. Durasi: ${duration.toFixed(2)}s`);
    return `Selesai membaca total ${totalSizeMB} MB dalam ${REPEAT_COUNT} kali pengulangan. Durasi Blocking: ${duration.toFixed(2)} detik.`;
}

// Endpoint 1: Normal
app.get('/', (req, res) => {
    res.send('Server aktif. Akses /block untuk memicu I/O Wait yang lama.');
});

// Endpoint 2: Blocking I/O Intensif
app.get('/block', (req, res) => {
    const result = performHeavyBlockingIO();
    res.send(result);
});

// Jalankan Server
app.listen(PORT, () => {
    console.log(`Server berjalan di http://localhost:${PORT}`);
});
