# KendalaKu - Design System Guide

Panduan gaya visual dan komponen antarmuka KendalaKu:

## 1. Prinsip Desain
- **Vibrant & Friendly**: Menggunakan palet modern bernuansa Indigo/Violet dipadukan dengan aksen Electric Teal dan Warm Amber. Tidak steril, tidak membosankan, memiliki kepribadian ramah bagi staf dan admin operasional.
- **Glanceable Information**: Setiap status dan prioritas kendala langsung terbaca dalam 1 detik lewat kombinasi warna, ikon representatif, dan strip visual.
- **Mobile-First & Ergonomic**: Dirancang ramah zona jangkauan jempol (Thumb Zone) dengan Bottom Navigation Bar, FAB mengambang, serta Bottom Sheet interaktif untuk filter dan transisi status.
- **Adaptive Layout**: Pada layar desktop/tablet, navigasi otomatis bertransformasi menjadi Navigation Rail dengan split-view (Master-Detail).

---

## 2. Palet Warna (Color System)

| Nama Token | Hex Code | Deskripsi Penggunaan |
| :--- | :--- | :--- |
| `primary` | `#4F46E5` | Indigo Utama untuk tombol aksi, appbar gradient, dan active tab |
| `primaryLight` | `#6366F1` | Indigo cerah untuk gradien header dan hover state |
| `primaryContainer` | `#EEF2FF` | Indigo soft untuk background badge/card terpilih |
| `accentTeal` | `#0D9488` | Aksen pelengkap untuk metrik positif / efisiensi |
| `accentAmber` | `#F59E0B` | Aksen peringatan / kendala butuh perhatian |
| `statusNew` | `#2563EB` | Status **Baru** (Blue), bg: `#EFF6FF` |
| `statusProcessing` | `#EA580C` | Status **Sedang Diproses** (Orange), bg: `#FFF7ED` |
| `statusWaiting` | `#D97706` | Status **Menunggu Informasi** (Amber), bg: `#FFFBEB` |
| `statusResolved` | `#16A34A` | Status **Selesai** (Green), bg: `#F0FDF4` |
| `statusRejected` | `#DC2626` | Status **Ditolak** (Red), bg: `#FEF2F2` |
| `priorityLow` | `#64748B` | Prioritas Rendah (Slate) |
| `priorityMedium` | `#0284C7` | Prioritas Sedang (Sky Blue) |
| `priorityHigh` | `#D97706` | Prioritas Tinggi (Amber) |
| `priorityCritical` | `#E11D48` | Prioritas Kritis (Rose/Crimson, animasi denyut halus) |

---

## 3. Tipografi (Typography)
- Font: **Google Fonts Plus Jakarta Sans**
- Skala Huruf:
  - `displayLarge`: 28sp, Bold, Line Height: 1.2
  - `titleLarge`: 20sp, SemiBold, Line Height: 1.3
  - `titleMedium`: 16sp, SemiBold, Line Height: 1.4
  - `bodyMedium`: 14sp, Regular, Line Height: 1.5
  - `bodySmall`: 12sp, Regular, Line Height: 1.4
  - `labelSmall`: 11sp, SemiBold (Badge, Status, Chip)

---

## 4. Komponen Kunci (Key Components)

1. **Dashboard Greeting Card**:
   - Menggunakan gradien `LinearGradient(colors: [#4338CA, #6366F1])`.
   - Menampilkan salam personal dinamis dan jumlah kendala yang perlu perhatian hari ini.
2. **Metric Summary Card**:
   - Border radius 20px, subtle shadow berlapis.
   - Angka beranimasi naik saat halaman dimuat pertama kali.
3. **Issue List Card**:
   - Strip prioritas 4px di tepi kiri kartu.
   - Chip status berwarna kontras dengan ikon.
   - Waktu tenggat dengan label indikator relatif ("2 jam lagi", "Terlambat 1 hari").
4. **Status Transition Bottom Sheet**:
   - Menampilkan status saat ini.
   - Menampilkan hanya pilihan tombol status selanjutnya yang **VALID** sesuai state machine.
   - Jika memilih status "Selesai", field textarea catatan penyelesaian muncul secara wajib.
5. **Stepper 3-Langkah Lapor Kendala**:
   - Step 1: Cari & Pilih Pesanan Simulasi.
   - Step 2: Pilih Kategori Masalah & Isi Deskripsi.
   - Step 3: Atur Prioritas, Petugas Penanggung Jawab, & Konfirmasi SLA Otomatis.
