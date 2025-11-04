const express = require('express');
const app = express();
const port = 3000;

// Fungsi CPU-Intensive sederhana: Menghitung faktorial dari bilangan besar
function calculateFactorial(n) {
  // Loop yang sangat panjang untuk mensimulasikan beban CPU
  // Angka 10.000.000.000 (10 miliar) hanya contoh, sesuaikan dengan performa CPU Anda
  // Jika terlalu besar, server akan sangat lama merespons atau timeout.
  // Ganti dengan angka yang lebih kecil jika pengujian pada lingkungan terbatas.
  let result = 1n; // Menggunakan BigInt untuk menangani angka besar
  for (let i = 1n; i <= n; i++) {
    result *= i;
  }
  return result;
}

// Endpoint yang CPU-Intensive
app.get('/cpu-intensive', (req, res) => {
  console.log('Permintaan /cpu-intensive diterima.');
  
  // Menentukan batas perhitungan (misalnya 10.000)
  const limit = 10000000; 

  // PENTING: Perhitungan ini akan memblokir event loop
  const factorialResult = calculateFactorial(BigInt(limit));

  // Setelah selesai, kirim respons
  res.send(`Perhitungan faktorial ${limit} selesai. Hasil: ${factorialResult.toString().substring(0, 100)}...`);
});

// Endpoint Non-Blocking (untuk perbandingan)
app.get('/non-blocking', (req, res) => {
  console.log('Permintaan /non-blocking diterima.');
  res.send('Ini adalah endpoint non-blocking. Respon cepat!');
});

app.listen(port, () => {
  console.log(`Server berjalan di http://localhost:${port}`);
});
