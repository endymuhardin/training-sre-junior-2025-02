import re
import sys
import datetime
from collections import defaultdict

def get_day_of_week_name(date_str):
    """Mengubah string tanggal menjadi nama hari (Senin, Selasa, dst.) dalam Bahasa Indonesia."""
    try:
        date_obj = datetime.datetime.strptime(date_str, '%Y-%m-%d')
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
    daily_error_stats = defaultdict(lambda: {'total': 0, 'errors': 0})

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
            
            # Logika untuk Per-Operation dan Error Breakdown
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

# --- Fungsi untuk membuat laporan dalam format MARKDOWN ---
def generate_markdown_report(file_name, total, success, op_counts, error_types, daily_stats):
    """Mencetak laporan SLI dalam format Markdown yang kompatibel dengan GitHub."""
    
    report = []
    
    # Header
    report.append(f"# Laporan SLI dari File: `{file_name}`")
    report.append("\n---\n")

    # 1. Ketersediaan Global (Overall Availability)
    report.append("## 📊 Ketersediaan Transaksi Global")
    
    success_rate = (success / total * 100) if total > 0 else 0
    error_rate = 100 - success_rate
    
    report.append(f"* Total Entri Log: **{total}**")
    report.append(f"* Total Transaksi Berhasil: **{success}**")
    report.append(f"* Total Transaksi Gagal (Error): **{total - success}**")
    report.append(f"* SLI 1: Overall Success Rate: **{success_rate:.2f}%**")
    report.append(f"* Overall Error Rate: **{error_rate:.2f}%**")
    
    report.append("\n---\n")

    # 2. Analisis Error Berdasarkan Hari (Tabel Markdown)
    report.append("## 📅 Analisis Error Berdasarkan Hari")
    
    day_order = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"]
    
    # Header Tabel
    report.append("| Hari | Total Transaksi | Total Error | Error Rate (Harian) |")
    report.append("| :--- | :-------------: | :---------: | :-----------------: |")
    
    for day in day_order:
        stats = daily_stats.get(day)
        if stats and stats['total'] > 0:
            daily_rate = (stats['errors'] / stats['total'] * 100)
            # Isi Baris Tabel
            report.append(f"| {day} | {stats['total']} | {stats['errors']} | **{daily_rate:.2f}%** |")
        else:
            report.append(f"| {day} | 0 | 0 | 0.00% |")
            
    report.append("\n")

    # 3. Ketersediaan Per-Operasi (Tabel Markdown)
    report.append("## 📈 Success Rate Berdasarkan Jenis Operasi")
    
    # Header Tabel
    report.append("| Operasi | Total | Success Rate |")
    report.append("| :--- | :---: | :----------: |")
    
    for op, data in op_counts.items():
        if op in ['TRANSFER', 'WITHDRAW', 'BALANCE']:
            rate = (data['success'] / data['total'] * 100) if data['total'] > 0 else 0
            # Isi Baris Tabel
            report.append(f"| {op} | {data['total']} | {rate:.2f}% |")
            
    report.append("\n---\n")

    # 4. Metrik Kegagalan Spesifik (Tabel Markdown)
    report.append("## 🚨 Tingkat Kegagalan Utama (Error Breakdown)")
    
    # Header Tabel
    report.append("| Jenis Error | Jumlah | Persentase Total |")
    report.append("| :--- | :---: | :-------------: |")
    
    valid_errors = {k: v for k, v in error_types.items() if v > 0 and k not in ['TRANSFER', 'WITHDRAW', 'BALANCE']}
    for error, count in sorted(valid_errors.items(), key=lambda item: item[1], reverse=True):
        rate = (count / total * 100) if total > 0 else 0
        # Isi Baris Tabel
        report.append(f"| {error} | {count} | {rate:.2f}% |")
        
    report.append("\n")
    
    return "\n".join(report)

# --- Eksekusi Utama ---
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Penggunaan: python sli_report_markdown.py <nama_file_log>")
        sys.exit(1)

    file_name = sys.argv[1]
    
    try:
        with open(file_name, 'r') as f:
            log_content = f.read()
            
        total, success, op_counts, error_types, daily_stats = analyze_log_data(log_content)
        
        if total == 0:
            print(f"Error: File '{file_name}' tidak berisi entri log yang valid.")
            sys.exit(1)

        markdown_output = generate_markdown_report(file_name, total, success, op_counts, error_types, daily_stats)
        
        # Cetak output Markdown ke konsol
        print(markdown_output)
        
        # Pilihan: Simpan output ke file .md
        # with open(f'{file_name}_sli_report.md', 'w') as f_out:
        #     f_out.write(markdown_output)
        # print(f"\nLaporan juga telah disimpan ke file '{file_name}_sli_report.md'")

    except FileNotFoundError:
        print(f"Error: File '{file_name}' tidak ditemukan.")
        sys.exit(1)
    except Exception as e:
        print(f"Terjadi error saat memproses file: {e}")
        sys.exit(1)