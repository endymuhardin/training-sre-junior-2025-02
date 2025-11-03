import re
import sys
from collections import defaultdict

def analyze_log_data(log_content):
    """Menganalisis konten log dan menghitung metrik SLI."""
    
    total_entries = 0
    success_entries = 0
    operation_counts = defaultdict(lambda: {'total': 0, 'success': 0})
    error_types = defaultdict(int)

    # Regex untuk memecah baris log: [STATUS] (?:ATM ID) (OPERASI) (KETERANGAN ERROR)
    log_pattern = re.compile(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \[(SUCCESS|ERROR)\] (?:ATM\d+ )?([A-Z_]+)(?:.*?)?$')
    
    for line in log_content.strip().split('\n'):
        line = line.strip()
        if not line or line.startswith('---'):
            continue

        match = log_pattern.match(line)
        if not match:
            continue
            
        status = match.group(1)
        detail = match.group(2) # Bisa berupa TRANSFER, WITHDRAW, BALANCE, atau CONNECTION_LOST
        
        total_entries += 1
        
        if status == 'SUCCESS':
            success_entries += 1
            op = detail
            operation_counts[op]['total'] += 1
            operation_counts[op]['success'] += 1
        else: # ERROR
            # Menentukan Operasi yang Gagal (untuk menghitung Success Rate per Operasi)
            if detail in ['TRANSFER', 'WITHDRAW', 'BALANCE']:
                op = detail
            elif detail == 'CONNECTION_LOST':
                op = 'SYSTEM'
            else:
                op = 'UNKNOWN_OP'

            operation_counts[op]['total'] += 1

            # Mengidentifikasi Jenis Error Spesifik (untuk Error Breakdown)
            # Ambil seluruh sisa baris setelah STATUS dan ID ATM (jika ada)
            error_msg_part = line.split(f'[{status}]')[1].strip()
            # Coba ambil kata pertama atau kedua yang spesifik setelah Operasi
            
            error_detail = None
            if op in ['TRANSFER', 'WITHDRAW', 'BALANCE']:
                # Contoh: ATM10025 TRANSFER TIMEOUT REF026 -> Ambil TIMEOUT
                parts = error_msg_part.split(op)
                if len(parts) > 1:
                    error_detail = parts[1].strip().split(' ')[0]
            
            if error_detail in ['', 'REF']:
                # Jika tidak ada detail spesifik, gunakan detail utama (misalnya CONNECTION_LOST)
                error_detail = detail
            elif error_detail is None:
                # Kasus error tanpa operasi spesifik di awal (misalnya [ERROR] CONNECTION_LOST)
                error_detail = detail

            if error_detail:
                error_types[error_detail] += 1
            
    return total_entries, success_entries, operation_counts, error_types

# --- Fungsi untuk membuat laporan ---
def generate_report(file_name, total, success, op_counts, error_types):
    """Mencetak laporan SLI yang terstruktur."""
    
    print("=" * 60)
    print(f"       LAPORAN SLI DARI FILE: {file_name}")
    print("=" * 60)
    
    # 1. Ketersediaan Global (Overall Availability)
    print("## 📊 Ketersediaan Transaksi Global")
    print("-" * 45)
    
    success_rate = (success / total * 100) if total > 0 else 0
    error_rate = 100 - success_rate
    
    print(f"Total Entri Log: {total}")
    print(f"Total Transaksi Berhasil: {success}")
    print(f"Total Transaksi Gagal (Error): {total - success}")
    print(f"SLI 1: Overall Success Rate: **{success_rate:.2f}%**")
    print(f"Overall Error Rate: **{error_rate:.2f}%**")
    print("-" * 45)

    # 2. Ketersediaan Per-Operasi (Per-Operation Availability)
    print("\n## 📈 Success Rate Berdasarkan Jenis Operasi")
    print("-" * 45)
    
    print(f"{'Operasi':<15} | {'Total':<8} | {'Success Rate':<15}")
    print("-" * 45)
    
    for op, data in op_counts.items():
        if op in ['TRANSFER', 'WITHDRAW', 'BALANCE']:
            rate = (data['success'] / data['total'] * 100) if data['total'] > 0 else 0
            print(f"{op:<15} | {data['total']:<8} | {rate:.2f}%")
            
    print("-" * 45)

    # 3. Metrik Kegagalan Spesifik (Specific Failure Rates)
    print("\n## 🚨 Tingkat Kegagalan Utama (Error Breakdown)")
    print("-" * 40)
    
    print(f"{'Jenis Error':<20} | {'Jumlah':<8} | {'Persentase Total'}")
    print("-" * 40)
    
    # Menghindari error yang mungkin muncul dari operasi yang tidak teridentifikasi
    valid_errors = {k: v for k, v in error_types.items() if v > 0 and k not in ['TRANSFER', 'WITHDRAW', 'BALANCE']}
    
    for error, count in sorted(valid_errors.items(), key=lambda item: item[1], reverse=True):
        rate = (count / total * 100) if total > 0 else 0
        print(f"{error:<20} | {count:<8} | {rate:.2f}%")
        
    print("-" * 40)
    print("=" * 60)

# --- Eksekusi Utama ---
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Penggunaan: python sli_report.py <nama_file_log>")
        sys.exit(1)

    file_name = sys.argv[1]
    
    try:
        with open(file_name, 'r') as f:
            log_content = f.read()
            
        total, success, op_counts, error_types = analyze_log_data(log_content)
        
        if total == 0:
            print(f"Error: File '{file_name}' tidak berisi entri log yang valid.")
            sys.exit(1)

        generate_report(file_name, total, success, op_counts, error_types)
        
    except FileNotFoundError:
        print(f"Error: File '{file_name}' tidak ditemukan.")
        sys.exit(1)
    except Exception as e:
        print(f"Terjadi error saat memproses file: {e}")
        sys.exit(1)