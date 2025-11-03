import datetime
import random

# ==========================================================
# PARAMETER & KONFIGURASI LOG
# ==========================================================

# Nama file output log
OUTPUT_FILENAME = "big_atm_log.txt"

# Total Transaksi yang Diinginkan
TOTAL_TRANSACTIONS = 500000

# Rentang Waktu Log (30 Hari)
START_DATE = datetime.datetime(2025, 11, 1, 0, 0, 0)
DAYS_IN_MONTH = 30 # Contoh: November memiliki 30 hari

# Target Error Rate (Contoh: 5%)
ERROR_RATE = 0.05

# Daftar Operasi & Nilai Transaksi
OPERATIONS = {
    "TRANSFER": (100000, 5000000),  # Min, Max Amount
    "WITHDRAW": (50000, 1500000),
    "BALANCE": (0, 0) # Tidak ada nilai yang ditransfer/ditarik
}

# Daftar Kemungkinan Penyebab Error
ERROR_MESSAGES = [
    "INSUFFICIENT_FUNDS",
    "TRANSFER TIMEOUT",
    "CONNECTION_LOST",
    "CARD_BLOCKED",
    "LIMIT_EXCEEDED",
    "INVALID_ACCOUNT",
    "SYSTEM_MAINTENANCE"
]

# ID ATM (Daftar ID yang mungkin)
ATM_IDS = [f"ATM{i:05d}" for i in range(100, 150)] # 50 ID ATM berbeda

# ==========================================================
# FUNGIONALITAS GENERASI LOG
# ==========================================================

def generate_log():
    """Menghasilkan log transaksi dan menyimpannya ke file."""
    
    # Hitung rata-rata transaksi per hari
    avg_tx_per_day = TOTAL_TRANSACTIONS / DAYS_IN_MONTH
    
    # Inisialisasi penghitung
    current_datetime = START_DATE
    transaction_count = 0
    ref_counter = 100000

    print(f"Memulai generasi log ke file: {OUTPUT_FILENAME}")
    print(f"Target: {TOTAL_TRANSACTIONS} transaksi dalam {DAYS_IN_MONTH} hari.")

    with open(OUTPUT_FILENAME, 'w') as f:
        for day in range(DAYS_IN_MONTH):
            # Sesuaikan jumlah transaksi hari ini agar total mendekati target
            # Tambahkan variasi random +/- 10%
            daily_tx_count = int(avg_tx_per_day * (1 + random.uniform(-0.1, 0.1)))
            
            # Distribusikan transaksi secara acak sepanjang 24 jam hari itu
            daily_seconds = [random.randint(0, 86399) for _ in range(daily_tx_count)]
            daily_seconds.sort() # Urutkan agar log berurutan waktu

            for second in daily_seconds:
                # Dapatkan timestamp
                current_timestamp = current_datetime + datetime.timedelta(seconds=second)
                
                # Pilih operasi dan ID ATM
                atm_id = random.choice(ATM_IDS)
                operation = random.choice(list(OPERATIONS.keys()))
                
                # Tentukan status (ERROR atau SUCCESS)
                is_error = random.random() < ERROR_RATE
                
                # Format entri log
                status = "ERROR" if is_error else "SUCCESS"
                ref_id = f"REF{ref_counter:06d}"

                log_entry = f"{current_timestamp.strftime('%Y-%m-%d %H:%M:%S')} [{status}] {atm_id} {operation}"
                
                if status == "SUCCESS":
                    min_amount, max_amount = OPERATIONS[operation]
                    amount = random.randrange(min_amount, max_amount, 50000) if operation != "BALANCE" else 0
                    
                    if operation == "BALANCE":
                        description = "0" # Nilai 0 menunjukkan hanya cek saldo
                    else:
                        description = f"{amount}"
                    
                    log_entry += f" {description} {ref_id}"
                
                else: # Status ERROR
                    error_msg = random.choice(ERROR_MESSAGES)
                    
                    # Beberapa error tidak memerlukan detail ATM/Operasi di depan
                    if error_msg == "CONNECTION_LOST" or error_msg == "SYSTEM_MAINTENANCE":
                        log_entry = f"{current_timestamp.strftime('%Y-%m-%d %H:%M:%S')} [{status}] {error_msg} {ref_id}"
                    else:
                        # Tambahkan pesan error spesifik setelah operasi
                        log_entry += f" {error_msg} {ref_id}"

                f.write(log_entry + '\n')
                transaction_count += 1
                ref_counter += 1

            # Pindah ke hari berikutnya
            current_datetime = current_datetime + datetime.timedelta(days=1)
    
    print(f"\nGenerasi Selesai.")
    print(f"Total entri yang dihasilkan: {transaction_count}")
    print(f"Error Rate Aktual (Perkiraan): {round((TOTAL_TRANSACTIONS * ERROR_RATE) / transaction_count * 100, 2)}%")

# --- EKSEKUSI UTAMA ---
if __name__ == "__main__":
    generate_log()