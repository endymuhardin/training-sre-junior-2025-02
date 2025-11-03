# 📈 Laporan SLI ATM (Service Level Indicator)

## Pendahuluan

Script Python ini (`sli_report.py`) berfungsi untuk menganalisis file log transaksi ATM dan menghasilkan laporan Service Level Indicator (SLI) yang komprehensif. Laporan ini disajikan dalam format **Markdown** yang rapi, memastikan tampilan yang konsisten dan terstruktur saat dilihat di GitHub atau platform rendering Markdown lainnya.

## 🎯 Metrik Utama yang Dihitung

Script ini menyediakan analisis mendalam pada tiga area utama:

1.  **Ketersediaan Global:** Persentase transaksi sukses secara keseluruhan.
2.  **Ketersediaan Per-Operasi:** Persentase sukses untuk setiap jenis transaksi (TRANSFER, WITHDRAW, BALANCE).
3.  **Analisis Error Harian:** Tingkat error (Error Rate) yang dihitung per hari (Senin - Minggu) untuk mengidentifikasi pola atau hari dengan beban/isu stabilitas tertinggi.
4.  **Error Breakdown:** Rincian spesifik penyebab kegagalan (TIMEOUT, CONNECTION_LOST, dll.).

## 📋 Prasyarat

Untuk menjalankan *script* ini, Anda hanya memerlukan:

* **Python 3.x** terinstal.
* File log transaksi yang sesuai dengan format yang ditentukan.

## 💾 Format File Log

Script ini dirancang untuk membaca log dengan format berikut. Pastikan setiap entri log mengikuti pola ini:

```log
YYYY-MM-DD HH:MM:SS [STATUS] ATMID OPERASI KETERANGAN REFENSI
# Contoh Sukses:
2024-01-01 09:01:01 [SUCCESS] ATM10001 TRANSFER 500000 REF001
# Contoh Error:
2024-01-02 11:18:25 [ERROR] CONNECTION_LOST REF016
2024-01-03 14:33:05 [ERROR] ATM10025 TRANSFER TIMEOUT REF026
````

Contoh file log bisa dilihat pada file [contoh.log](./contoh.log)

## 🚀 Cara Penggunaan

Script ini menerima **nama file log** sebagai argumen saat dieksekusi dari terminal.

### 1. Simpan Script

Pastikan Anda menyimpan kode Python ke dalam file bernama `sli_report.py`.

### 2. Jalankan Script

Buka terminal (*Command Prompt* / *Terminal* / *PowerShell*) dan jalankan perintah berikut, ganti `nama_file_log.txt` dengan nama file log Anda:

```bash
python sli_report.py nama_file_log.txt
```

### 3. Output

Laporan SLI yang dihasilkan akan dicetak langsung ke konsol (*stdout*) dalam format Markdown.

#### Contoh Output

```markdown
# Laporan SLI dari File: `contoh.log`
...
## 📅 Analisis Error Berdasarkan Hari
| Hari | Total Transaksi | Total Error | Error Rate (Harian) |
| :--- | :-------------: | :---------: | :-----------------: |
| Senin | 10 | 1 | **10.00%** |
| Selasa | 10 | 1 | **10.00%** |
| Minggu | 10 | 2 | **20.00%** |
...
```

### 4. Menyimpan ke File Markdown

Untuk menyimpan output langsung ke file Markdown (misalnya, `report.md`), Anda dapat menggunakan *redirection* output standar shell:

```bash
python sli_report.py contoh.log > laporan.md
```

File [`laporan.md`](./laporan.md) inilah yang dapat Anda unggah atau lihat di GitHub untuk pemformatan tabel yang sempurna.
