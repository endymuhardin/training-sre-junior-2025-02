const express = require('express');
const request = require('sync-request'); // Modul untuk request HTTP sinkron
const app = express();
const PORT = 3002; 

// URL API yang akan dipanggil. Kita bisa menggunakan JSONPlaceholder yang memiliki endpoint delay.
// Jika ingin delay lebih lama, bisa menggunakan layanan seperti httpstat.us/200?sleep=5000
const DELAY_URL = 'http://httpstat.us/200?sleep=5000'; // Delay 5 detik
const REPEAT_COUNT = 30; // 30 kali ulangan * 5 detik = 150 detik (2.5 menit)

// Fungsi Blocking I/O (Network Request Sinkron)
function performHeavyBlockingIO() {
    
    const startTime = Date.now();
    let totalRequests = 0;
    
    console.log(`[${new Date().toLocaleTimeString()}] Mulai Blocking Network I/O (${DELAY_URL}, diulang ${REPEAT_COUNT} kali)...`);
    
    // --- Loop Blocking Network ---
    for (let i = 0; i < REPEAT_COUNT; i++) {
        try {
            // request.get() adalah operasi SINKRON. 
            // Setiap panggilan akan memblokir Node.js selama 5 detik penuh.
            const res = request('GET', DELAY_URL);
            
            // Verifikasi respons
            if (res.statusCode === 200) {
                totalRequests++;
            } else {
                console.error(`Request gagal pada iterasi ${i}: Status ${res.statusCode}`);
            }
        } catch (error) {
            console.error('Terjadi error Network:', error.message);
            // Hentikan loop jika terjadi kegagalan jaringan
            break; 
        }
    }
    // ----------------------------

    const endTime = Date.now();
    const duration = (endTime - startTime) / 1000;

    console.log(`[${new Date().toLocaleTimeString()}] Selesai Blocking I/O. Durasi: ${duration.toFixed(2)}s`);
    return `Selesai ${totalRequests} request Network. Total Durasi Blocking: ${duration.toFixed(2)} detik (~${(duration / REPEAT_COUNT).toFixed(2)}s per request).`;
}

// Endpoint Normal
app.get('/', (req, res) => {
    res.send('Server aktif. Akses /block untuk memicu Network I/O Wait.');
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
