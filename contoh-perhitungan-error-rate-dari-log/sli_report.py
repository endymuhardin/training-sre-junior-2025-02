import re
import sys
import datetime
from collections import defaultdict

def get_day_of_week_name(date_str):
    """Mengubah string tanggal menjadi nama hari (Senin, Selasa, dst.) dalam Bahasa Indonesia."""
    try:
        # Format log: YYYY-MM-DD
        date_obj = datetime.datetime.strptime(date_str, '%Y-%m-%d')
        # date_obj.weekday() mengembalikan 0=Senin, 6=Minggu
        days = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"]
        return days[date_obj.weekday()]
    except ValueError:
        return "TIDAK VALID"

def analyze_log_data(log_content):
    """Menganalisis konten log dan menghitung metrik SLI, termasuk metrik harian."""
    
    total_entries = 0
    success_entries = 0
    operation_counts = defaultdict(lambda: {'total': 0, 'success': 0})
    error_types = defaultdict(int)
    
    # Penghitung baru untuk analisis harian
    daily_error_stats = defaultdict(lambda: {'total': 0, 'errors': 0})

    # Regex untuk memecah baris log
    log_pattern = re.compile(r'^(\d{4}-\d{2}-\d{2}) \d{2}:\d{2}:\d{2} \[(SUCCESS|ERROR)\] (?:ATM\d+ )?([A-Z_]+)(?:.*?)?$')
    
    for line in log_content.strip().split('\n'):
        line = line.strip()
        if not line or line.startswith('---'):
            continue

        match = log_pattern.match(line)
        if not match:
            continue
            
        date_str = match.group(1)
        status = match.group(2)
        detail = match.group(3)
        
        # --- Penghitungan Harian ---
        day_name = get_day_of_week_name(date_str)
        daily_error_stats[day_name]['total'] += 1
        
        total_entries += 1
        
        if status == 'SUCCESS':
            success_entries += 1
            op = detail
            operation_counts[op]['total'] += 1
            operation_counts[op]['success'] += 1
        else: # ERROR
            daily_error_stats[day_name]['errors'] += 1
            
            # Logika untuk Per-Operation dan Error Breakdown (Sama seperti sebelumnya)
            if detail in ['TRANSFER', 'WITHDRAW', 'BALANCE']:
                op = detail
            elif detail == 'CONNECTION_LOST':
                op = 'SYSTEM'
            else:
                op = 'UNKNOWN_OP'

            operation_counts[op]['total'] += 1

            error_detail = None
            if op in ['TRANSFER', 'WITHDRAW', 'BALANCE']:
                parts = line.split(op)
                if len(parts) > 1:
                    error_detail = parts[1].strip().split(' ')[0]
            
            if error_detail in ['', 'REF'] or error_detail is None:
                error_detail = detail

            if error_detail:
                error_types[error_detail] += 1
            
    return total_entries, success_entries, operation_counts, error_types, daily_error_stats

# --- Fungsi untuk membuat laporan ---
def generate_report(file_name, total, success, op_counts, error_types, daily_stats):
    """Mencetak laporan SLI yang terstruktur."""
    
    # ... (Bagian Ketersediaan Global dan Per-Operasi sama seperti sebelumnya) ...
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
    print("-" * 45)

    # 2. Analisis Error Berdasarkan Hari (Fitur Baru)
    print("\n## 📅 Analisis Error Berdasarkan Hari (Pencarian Pola)")
    print("-" * 50)
    
    # Urutan hari yang benar
    day_order = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"]
    
    print(f"{'Hari':<10} | {'Total Transaksi':<15} | {'Total Error':<11} | {'Error Rate (Harian)'}")
    print("-" * 50)
    
    for day in day_order:
        stats = daily_stats.get(day)
        if stats and stats['total'] > 0:
            daily_rate = (stats['errors'] / stats['total'] * 100)
            print(f"{day:<10} | {stats['total']:<15} | {stats['errors']:<11} | **{daily_rate:.2f}%**")
        else:
            print(f"{day:<10} | {0:<15} | {0:<11} | 0.00%")
            
    print("-" * 50)

    # 3. Ketersediaan Per-Operasi (Sama seperti sebelumnya)
    print("\n## 📈 Success Rate Berdasarkan Jenis Operasi")
    print("-" * 45)
    print(f"{'Operasi':<15} | {'Total':<8} | {'Success Rate':<15}")
    print("-" * 45)
    for op, data in op_counts.items():
        if op in ['TRANSFER', 'WITHDRAW', 'BALANCE']:
            rate = (data['success'] / data['total'] * 100) if data['total'] > 0 else 0
            print(f"{op:<15} | {data['total']:<8} | {rate:.2f}%")
    print("-" * 45)
    
    # 4. Metrik Kegagalan Spesifik (Sama seperti sebelumnya)
    print("\n## 🚨 Tingkat Kegagalan Utama (Error Breakdown)")
    print("-" * 40)
    print(f"{'Jenis Error':<20} | {'Jumlah':<8} | {'Persentase Total'}")
    print("-" * 40)
    valid_errors = {k: v for k, v in error_types.items() if v > 0 and k not in ['TRANSFER', 'WITHDRAW', 'BALANCE']}
    for error, count in sorted(valid_errors.items(), key=lambda item: item[1], reverse=True):
        rate = (count / total * 100) if total > 0 else 0
        print(f"{error:<20} | {count:<8} | {rate:.2f}%")
    print("-" * 40)
    print("=" * 60)

# --- Eksekusi Utama ---
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Penggunaan: python sli_report_daily.py <nama_file_log>")
        sys.exit(1)

    file_name = sys.argv[1]
    
    try:
        with open(file_name, 'r') as f:
            log_content = f.read()
            
        total, success, op_counts, error_types, daily_stats = analyze_log_data(log_content)
        
        if total == 0:
            print(f"Error: File '{file_name}' tidak berisi entri log yang valid.")
            sys.exit(1)

        generate_report(file_name, total, success, op_counts, error_types, daily_stats)
        
    except FileNotFoundError:
        print(f"Error: File '{file_name}' tidak ditemukan.")
        sys.exit(1)
    except Exception as e:
        print(f"Terjadi error saat memproses file: {e}")
        sys.exit(1)