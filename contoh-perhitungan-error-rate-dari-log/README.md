# 📈 Laporan SLI ATM (Service Level Indicator)

## Pendahuluan

Script Python ini (`sli_report.py`) berfungsi untuk menganalisis file log transaksi ATM dan menghasilkan laporan Service Level Indicator (SLI) yang komprehensif. Laporan ini disajikan dalam format **Markdown** yang rapi, memastikan tampilan yang konsisten dan terstruktur saat dilihat di GitHub atau platform rendering Markdown lainnya.

---

## 🛠️ Script Utilitas: `generate_log.py`

Selain alat pelaporan SLI, repositori ini menyertakan script utilitas untuk menghasilkan data log tiruan dalam volume besar.

### Tujuan

* Membuat file log transaksi ATM tiruan (`big_atm_log.txt`) dalam volume besar (**sekitar 500.000 transaksi**) yang didistribusikan selama satu bulan.
* Memungkinkan pengujian kinerja alat SLI dan simulasi skenario *error rate* tinggi/rendah (**default 5% error rate**).

### ⚙️ Konfigurasi (Modifikasi Mudah)

Semua parameter utama, seperti total transaksi, *error rate*, rentang tanggal, dan nama file output, dikumpulkan di bagian atas file `generate_log.py`. Anda dapat dengan mudah menyesuaikannya:

```python
# Bagian dari generate_log.py
TOTAL_TRANSACTIONS = 500000
START_DATE = datetime.datetime(2025, 11, 1, 0, 0, 0)
ERROR_RATE = 0.05
OUTPUT_FILENAME = "big_atm_log.txt"
````

### 🚀 Cara Penggunaan

1.  **Modifikasi:** Sesuaikan variabel di bagian atas `generate_log.py` sesuai kebutuhan simulasi Anda.

2.  **Jalankan Script:** Buka terminal dan jalankan perintah:

    ```bash
    python generate_log.py
    ```

3.  **Output:** Script akan mencetak ringkasan ke konsol dan membuat file log baru (misalnya, `big_atm_log.txt`) yang siap digunakan sebagai input untuk `sli_report.py`.

-----

## 🎯 Metrik Utama yang Dihitung

Script ini menyediakan analisis mendalam pada tiga area utama:

1.  **Ketersediaan Global:** Persentase transaksi sukses secara keseluruhan.
2.  **Ketersediaan Per-Operasi:** Persentase sukses untuk setiap jenis transaksi (TRANSFER, WITHDRAW, BALANCE).
3.  **Analisis Error Harian:** Tingkat error (Error Rate) yang dihitung per hari (Senin - Minggu) untuk mengidentifikasi pola atau hari dengan beban/isu stabilitas tertinggi.
4.  **Error Breakdown:** Rincian spesifik penyebab kegagalan (TIMEOUT, CONNECTION_LOST, dll.).

-----

## 📋 Prasyarat

Untuk menjalankan *script* ini, Anda hanya memerlukan:

  * **Python 3.x** terinstal.
  * File log transaksi yang sesuai dengan format yang ditentukan (Jika menggunakan `sli_report.py`).

-----

## 💾 Format File Log

Script ini dirancang untuk membaca log dengan format berikut. Pastikan setiap entri log mengikuti pola ini:

```log
YYYY-MM-DD HH:MM:SS [STATUS] ATMID OPERASI KETERANGAN REFENSI
# Contoh Sukses:
2024-01-01 09:01:01 [SUCCESS] ATM10001 TRANSFER 500000 REF001
```

-----

## 🚀 Cara Penggunaan (`sli_report.py`)

Script ini menerima **nama file log** sebagai argumen saat dieksekusi dari terminal.

### 1\. Simpan Script

Pastikan Anda menyimpan kode Python ke dalam file bernama `sli_report.py`.

### 2\. Jalankan Script

Buka terminal (*Command Prompt* / *Terminal* / *PowerShell*) dan jalankan perintah berikut, ganti `nama_file_log.txt` dengan nama file log Anda (dapat menggunakan file yang dihasilkan oleh `generate_log.py`):

```bash
python sli_report.py nama_file_log.txt
```

### 3\. Menyimpan ke File Markdown

Untuk menyimpan output langsung ke file Markdown (misalnya, `report.md`), Anda dapat menggunakan *redirection* output standar shell:

```bash
python sli_report.py nama_file_log.txt > report.md
```
