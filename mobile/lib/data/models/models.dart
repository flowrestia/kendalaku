class User {
  final int id;
  final String nama;
  final String? email;
  final String role;
  final String? createdAt;

  User({
    required this.id,
    required this.nama,
    this.email,
    required this.role,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int? ?? 0,
      nama: json['nama'] as String? ?? '',
      email: json['email'] as String?,
      role: json['role'] as String? ?? 'petugas',
      createdAt: json['created_at'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nama': nama,
    'email': email,
    'role': role,
    'created_at': createdAt,
  };

  bool get isAdmin => role.toLowerCase() == 'admin';
}

class ProblemCategory {
  final int id;
  final String nama;
  final String warnaHex;
  final String ikon;
  final int tenggatJam;
  final bool aktif;

  ProblemCategory({
    required this.id,
    required this.nama,
    required this.warnaHex,
    required this.ikon,
    required this.tenggatJam,
    required this.aktif,
  });

  factory ProblemCategory.fromJson(Map<String, dynamic> json) {
    return ProblemCategory(
      id: json['id'] as int? ?? 0,
      nama: json['nama'] as String? ?? '',
      warnaHex: json['warna_hex'] as String? ?? '#4F46E5',
      ikon: json['ikon'] as String? ?? 'warning_amber_rounded',
      tenggatJam: json['tenggat_jam'] as int? ?? 24,
      aktif: json['aktif'] as bool? ?? true,
    );
  }
}

class Order {
  final int id;
  final String kodePesanan;
  final String namaPelanggan;
  final String produk;
  final int jumlah;

  Order({
    required this.id,
    required this.kodePesanan,
    required this.namaPelanggan,
    required this.produk,
    required this.jumlah,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as int? ?? 0,
      kodePesanan: json['kode_pesanan'] as String? ?? '',
      namaPelanggan: json['nama_pelanggan'] as String? ?? '',
      produk: json['produk'] as String? ?? '',
      jumlah: json['jumlah'] as int? ?? 1,
    );
  }
}

class OrderIssue {
  final int id;
  final String kodeKendala;
  final int orderId;
  final int categoryId;
  final String judul;
  final String deskripsi;
  final String prioritas;
  final String status;
  final String tenggatAt;
  final int? assignedTo;
  final String? catatanPenyelesaian;
  final bool isArchived;
  final int createdBy;
  final String createdAt;
  final String updatedAt;
  final String? resolvedAt;

  // Relation fields
  final String kodePesanan;
  final String namaPelanggan;
  final String? produkPesanan;
  final String categoryNama;
  final String categoryWarnaHex;
  final String categoryIkon;
  final String assignedNama;
  final String createdByNama;
  final bool isOverdue;

  OrderIssue({
    required this.id,
    required this.kodeKendala,
    required this.orderId,
    required this.categoryId,
    required this.judul,
    required this.deskripsi,
    required this.prioritas,
    required this.status,
    required this.tenggatAt,
    this.assignedTo,
    this.catatanPenyelesaian,
    required this.isArchived,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    required this.kodePesanan,
    required this.namaPelanggan,
    this.produkPesanan,
    required this.categoryNama,
    required this.categoryWarnaHex,
    required this.categoryIkon,
    required this.assignedNama,
    required this.createdByNama,
    required this.isOverdue,
  });

  factory OrderIssue.fromJson(Map<String, dynamic> json) {
    return OrderIssue(
      id: json['id'] as int? ?? 0,
      kodeKendala: json['kode_kendala'] as String? ?? '',
      orderId: json['order_id'] as int? ?? 0,
      categoryId: json['category_id'] as int? ?? 0,
      judul: json['judul'] as String? ?? '',
      deskripsi: json['deskripsi'] as String? ?? '',
      prioritas: json['prioritas'] as String? ?? 'sedang',
      status: json['status'] as String? ?? 'baru',
      tenggatAt: json['tenggat_at'] as String? ?? '',
      assignedTo: json['assigned_to'] as int?,
      catatanPenyelesaian: json['catatan_penyelesaian'] as String?,
      isArchived: json['is_archived'] as bool? ?? false,
      createdBy: json['created_by'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
      resolvedAt: json['resolved_at'] as String?,
      kodePesanan: json['kode_pesanan'] as String? ?? '',
      namaPelanggan: json['nama_pelanggan'] as String? ?? '',
      produkPesanan: json['produk_pesanan'] as String?,
      categoryNama: json['category_nama'] as String? ?? 'Umum',
      categoryWarnaHex: json['category_warna_hex'] as String? ?? '#4F46E5',
      categoryIkon: json['category_ikon'] as String? ?? 'warning_amber_rounded',
      assignedNama: json['assigned_nama'] as String? ?? '-',
      createdByNama: json['created_by_nama'] as String? ?? '-',
      isOverdue: json['is_overdue'] as bool? ?? false,
    );
  }
}

class IssueTransaction {
  final int id;
  final int issueId;
  final String statusSebelumnya;
  final String statusBaru;
  final String catatanTindakan;
  final int olehUserId;
  final String namaUser;
  final String createdAt;

  IssueTransaction({
    required this.id,
    required this.issueId,
    required this.statusSebelumnya,
    required this.statusBaru,
    required this.catatanTindakan,
    required this.olehUserId,
    required this.namaUser,
    required this.createdAt,
  });

  factory IssueTransaction.fromJson(Map<String, dynamic> json) {
    return IssueTransaction(
      id: json['id'] as int? ?? 0,
      issueId: json['issue_id'] as int? ?? 0,
      statusSebelumnya: json['status_sebelumnya'] as String? ?? '',
      statusBaru: json['status_baru'] as String? ?? '',
      catatanTindakan: json['catatan_tindakan'] as String? ?? '',
      olehUserId: json['oleh_user_id'] as int? ?? 0,
      namaUser: json['nama_user'] as String? ?? 'Sistem',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

// ---------------- MODEL FASE 5: DASHBOARD, LAPORAN & AKTIVITAS ----------------

class DashboardSummary {
  final int total;
  final int baru;
  final int sedangDiproses;
  final int menungguInformasi;
  final int selesai;
  final int ditolak;
  final int terlambat;
  final double rataRataWaktuJam;
  final double persentaseSelesai;

  DashboardSummary({
    required this.total,
    required this.baru,
    required this.sedangDiproses,
    required this.menungguInformasi,
    required this.selesai,
    required this.ditolak,
    required this.terlambat,
    required this.rataRataWaktuJam,
    required this.persentaseSelesai,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      total: json['total'] as int? ?? 0,
      baru: json['baru'] as int? ?? 0,
      sedangDiproses: json['sedang_diproses'] as int? ?? 0,
      menungguInformasi: json['menunggu_informasi'] as int? ?? 0,
      selesai: json['selesai'] as int? ?? 0,
      ditolak: json['ditolak'] as int? ?? 0,
      terlambat: json['terlambat'] as int? ?? 0,
      rataRataWaktuJam: (json['rata_rata_waktu_jam'] as num?)?.toDouble() ?? 0.0,
      persentaseSelesai: (json['persentase_selesai'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CategoryStat {
  final int categoryId;
  final String nama;
  final String warnaHex;
  final String ikon;
  final int total;
  final double persentase;

  CategoryStat({
    required this.categoryId,
    required this.nama,
    required this.warnaHex,
    required this.ikon,
    required this.total,
    required this.persentase,
  });

  factory CategoryStat.fromJson(Map<String, dynamic> json) {
    return CategoryStat(
      categoryId: json['category_id'] as int? ?? 0,
      nama: json['nama'] as String? ?? '',
      warnaHex: json['warna_hex'] as String? ?? '#4F46E5',
      ikon: json['ikon'] as String? ?? 'warning_amber_rounded',
      total: json['total'] as int? ?? 0,
      persentase: (json['persentase'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TrendPoint {
  final String label;
  final String tanggal;
  final int totalMasuk;
  final int totalSelesai;

  TrendPoint({
    required this.label,
    required this.tanggal,
    required this.totalMasuk,
    required this.totalSelesai,
  });

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      label: json['label'] as String? ?? '',
      tanggal: json['tanggal'] as String? ?? '',
      totalMasuk: json['total_masuk'] as int? ?? 0,
      totalSelesai: json['total_selesai'] as int? ?? 0,
    );
  }
}

class StatusBreakdown {
  final int baru;
  final int sedangDiproses;
  final int menungguInformasi;
  final int selesai;
  final int ditolak;

  StatusBreakdown({
    required this.baru,
    required this.sedangDiproses,
    required this.menungguInformasi,
    required this.selesai,
    required this.ditolak,
  });

  factory StatusBreakdown.fromJson(Map<String, dynamic> json) {
    return StatusBreakdown(
      baru: json['baru'] as int? ?? 0,
      sedangDiproses: json['sedang_diproses'] as int? ?? 0,
      menungguInformasi: json['menunggu_informasi'] as int? ?? 0,
      selesai: json['selesai'] as int? ?? 0,
      ditolak: json['ditolak'] as int? ?? 0,
    );
  }
}

class CategoryRecapItem {
  final int categoryId;
  final String nama;
  final String warnaHex;
  final int total;
  final StatusBreakdown status;

  CategoryRecapItem({
    required this.categoryId,
    required this.nama,
    required this.warnaHex,
    required this.total,
    required this.status,
  });

  factory CategoryRecapItem.fromJson(Map<String, dynamic> json) {
    return CategoryRecapItem(
      categoryId: json['category_id'] as int? ?? 0,
      nama: json['nama'] as String? ?? '',
      warnaHex: json['warna_hex'] as String? ?? '#4F46E5',
      total: json['total'] as int? ?? 0,
      status: StatusBreakdown.fromJson(json['status'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class ReportRecap {
  final int totalKendala;
  final String? kategoriPalingSering;
  final StatusBreakdown rekapStatus;
  final List<CategoryRecapItem> perKategori;

  ReportRecap({
    required this.totalKendala,
    this.kategoriPalingSering,
    required this.rekapStatus,
    required this.perKategori,
  });

  factory ReportRecap.fromJson(Map<String, dynamic> json) {
    final perKatList = json['per_kategori'] as List? ?? [];
    return ReportRecap(
      totalKendala: json['total_kendala'] as int? ?? 0,
      kategoriPalingSering: json['kategori_paling_sering'] as String?,
      rekapStatus: StatusBreakdown.fromJson(json['rekap_status'] as Map<String, dynamic>? ?? {}),
      perKategori: perKatList.map((e) => CategoryRecapItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class ActivityLogItem {
  final int id;
  final int issueId;
  final String kodeKendala;
  final String judulKendala;
  final String statusSebelumnya;
  final String statusBaru;
  final String catatanTindakan;
  final int olehUserId;
  final String olehUserNama;
  final String createdAt;

  ActivityLogItem({
    required this.id,
    required this.issueId,
    required this.kodeKendala,
    required this.judulKendala,
    required this.statusSebelumnya,
    required this.statusBaru,
    required this.catatanTindakan,
    required this.olehUserId,
    required this.olehUserNama,
    required this.createdAt,
  });

  factory ActivityLogItem.fromJson(Map<String, dynamic> json) {
    return ActivityLogItem(
      id: json['id'] as int? ?? 0,
      issueId: json['issue_id'] as int? ?? 0,
      kodeKendala: json['kode_kendala'] as String? ?? '',
      judulKendala: json['judul_kendala'] as String? ?? '',
      statusSebelumnya: json['status_sebelumnya'] as String? ?? '',
      statusBaru: json['status_baru'] as String? ?? '',
      catatanTindakan: json['catatan_tindakan'] as String? ?? '',
      olehUserId: json['oleh_user_id'] as int? ?? 0,
      olehUserNama: json['oleh_user_nama'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

// Model Response Share Text WhatsApp (Fase 6B)
class ShareTextResult {
  final String text;
  final int count;
  final bool truncated;

  ShareTextResult({
    required this.text,
    required this.count,
    required this.truncated,
  });

  factory ShareTextResult.fromJson(Map<String, dynamic> json) {
    return ShareTextResult(
      text: json['text'] as String? ?? '',
      count: json['count'] as int? ?? 0,
      truncated: json['truncated'] as bool? ?? false,
    );
  }
}
