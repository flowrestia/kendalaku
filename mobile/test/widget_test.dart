import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/date_util.dart';
import 'package:mobile/core/utils/icon_util.dart';
import 'package:mobile/data/models/models.dart';
import 'package:mobile/providers/app_providers.dart';
import 'package:mobile/views/categories/manage_categories_screen.dart';
import 'package:mobile/views/dashboard/dashboard_screen.dart';
import 'package:mobile/views/issues/issue_wizard_screen.dart';
import 'package:mobile/views/issues/issues_list_screen.dart';
import 'package:mobile/views/widgets/status_transition_modal.dart';

class _MockAuthNotifier extends AuthNotifier {
  final User? initialUser;
  _MockAuthNotifier([this.initialUser]);

  @override
  AuthState build() => AuthState(
        isAuthenticated: initialUser != null,
        user: initialUser,
      );
}

void main() {
  group('UI/UX Unit Tests KendalaKu (Fase 4)', () {
    test('State Machine: Transisi valid dari status "baru"', () {
      final nextStatuses = StatusTransitionModal.getValidNextStatuses('baru');
      expect(nextStatuses, contains('sedang_diproses'));
      expect(nextStatuses, contains('ditolak'));
      expect(nextStatuses, isNot(contains('selesai')));
      expect(nextStatuses, isNot(contains('menunggu_informasi')));
    });

    test('State Machine: Transisi valid dari status "sedang_diproses"', () {
      final nextStatuses = StatusTransitionModal.getValidNextStatuses('sedang_diproses');
      expect(nextStatuses, contains('menunggu_informasi'));
      expect(nextStatuses, contains('selesai'));
      expect(nextStatuses, contains('ditolak'));
      expect(nextStatuses, isNot(contains('baru')));
    });

    test('State Machine: Transisi valid dari status "menunggu_informasi"', () {
      final nextStatuses = StatusTransitionModal.getValidNextStatuses('menunggu_informasi');
      expect(nextStatuses, equals(['sedang_diproses']));
      expect(nextStatuses, isNot(contains('selesai')));
      expect(nextStatuses, isNot(contains('ditolak')));
    });

    test('State Machine: Status akhir "selesai" dan "ditolak" tidak dapat diubah lagi', () {
      expect(StatusTransitionModal.getValidNextStatuses('selesai'), isEmpty);
      expect(StatusTransitionModal.getValidNextStatuses('ditolak'), isEmpty);
    });

    test('DateUtil: Konversi string UTC ke Waktu Lokal dengan format WIB', () {
      const utcString = '2026-10-24T16:31:57Z';
      final formatted = DateUtil.formatFull(utcString);
      expect(formatted, contains('WIB'));
      expect(formatted, contains('2026'));
    });

    test('DateUtil: Format SLA relatif untuk kendala yang melewati batas', () {
      final pastTime = DateTime.now().toUtc().subtract(const Duration(hours: 3));
      final relative = DateUtil.formatRelativeSLA(pastTime.toIso8601String(), isCompleted: false);
      expect(relative, startsWith('Terlambat'));
    });

    test('IconUtil: Pemetaan nama status dan ikon material', () {
      expect(IconUtil.getStatusLabel('baru'), equals('Baru'));
      expect(IconUtil.getStatusLabel('sedang_diproses'), equals('Sedang Diproses'));
      expect(IconUtil.getStatusLabel('menunggu_informasi'), equals('Menunggu Info'));
      expect(IconUtil.getStatusLabel('selesai'), equals('Selesai'));
      expect(IconUtil.getStatusLabel('ditolak'), equals('Ditolak'));
    });

    test('IconUtil & AppColors: Pemetaan prioritas backend (rendah, sedang, tinggi, kritis)', () {
      expect(IconUtil.getPriorityLabel('rendah'), equals('Rendah'));
      expect(IconUtil.getPriorityLabel('sedang'), equals('Sedang'));
      expect(IconUtil.getPriorityLabel('tinggi'), equals('Tinggi'));
      expect(IconUtil.getPriorityLabel('kritis'), equals('Kritis'));
    });
  });

  group('Modal Transisi Status Widget Tests', () {
    testWidgets('Hanya opsi valid yang ditampilkan saat currentStatus = baru', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusTransitionModal(
              currentStatus: 'baru',
              onSubmit: (_, _, _) async {},
            ),
          ),
        ),
      );

      // Opsi valid untuk 'baru': sedang_diproses ('Sedang Diproses') dan ditolak ('Ditolak')
      expect(find.text('Sedang Diproses'), findsOneWidget);
      expect(find.text('Ditolak'), findsOneWidget);

      // Opsi tidak valid untuk 'baru': selesai ('Selesai') dan menunggu_informasi ('Menunggu Info')
      expect(find.text('Selesai'), findsNothing);
      expect(find.text('Menunggu Info'), findsNothing);
    });

    testWidgets('Hanya opsi valid yang ditampilkan saat currentStatus = menunggu_informasi', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusTransitionModal(
              currentStatus: 'menunggu_informasi',
              onSubmit: (_, _, _) async {},
            ),
          ),
        ),
      );

      // Opsi tombol transisi valid untuk 'menunggu_informasi' hanya sedang_diproses ('Sedang Diproses')
      expect(find.widgetWithText(InkWell, 'Sedang Diproses'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Selesai'), findsNothing);
      expect(find.widgetWithText(InkWell, 'Ditolak'), findsNothing);
      expect(find.widgetWithText(InkWell, 'Menunggu Info'), findsNothing);
    });

    testWidgets('Status akhir (selesai / ditolak) menampilkan informasi tidak dapat ditransisikan', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusTransitionModal(
              currentStatus: 'selesai',
              onSubmit: (_, _, _) async {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Kendala telah berada pada status akhir'), findsOneWidget);
      expect(find.text('Simpan Perubahan Status'), findsNothing);
    });

    testWidgets('Catatan penyelesaian hanya muncul dan wajib diisi jika status = selesai', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatusTransitionModal(
              currentStatus: 'sedang_diproses',
              onSubmit: (_, _, _) async {},
            ),
          ),
        ),
      );

      // Status 'sedang_diproses' punya opsi: Menunggu Info, Selesai, Ditolak. Default terpilih pertama (menunggu_informasi).
      expect(find.text('Catatan Penyelesaian *'), findsNothing);

      // Pilih status 'Selesai'
      await tester.tap(find.text('Selesai'));
      await tester.pumpAndSettle();

      // Input catatan penyelesaian harus tampil
      expect(find.text('Catatan Penyelesaian *'), findsOneWidget);
      expect(find.text('Aturan Wajib: Catatan Penyelesaian'), findsOneWidget);

      // Coba simpan saat input kosong
      await tester.tap(find.text('Simpan Perubahan Status'));
      await tester.pumpAndSettle();

      // Verifikasi pesan validasi muncul
      expect(find.text('Catatan tindakan wajib diisi'), findsOneWidget);
      expect(find.text('Catatan penyelesaian wajib diisi jika status selesai'), findsOneWidget);
    });
  });

  group('Issue Wizard Screen Widget Tests', () {
    testWidgets('Wizard langkah 3 menampilkan semua pilihan prioritas sesuai backend', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dummyOrders = [
        Order(id: 1, kodePesanan: 'ORD-001', namaPelanggan: 'Sonny', produk: 'Kopi Arabika', jumlah: 2),
      ];
      final dummyCategories = [
        ProblemCategory(id: 1, nama: 'Barang Rusak', warnaHex: '#EF4444', ikon: 'broken_image', tenggatJam: 12, aktif: true),
      ];
      final dummyUsers = [
        User(id: 10, nama: 'Budi Petugas', email: 'budi@test.com', role: 'petugas'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ordersProvider.overrideWith((ref) => dummyOrders),
            categoriesProvider.overrideWith((ref) => dummyCategories),
            usersListProvider.overrideWith((ref) => dummyUsers),
          ],
          child: const MaterialApp(
            home: IssueWizardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Step 1: Pilih pesanan
      expect(find.text('ORD-001'), findsOneWidget);
      await tester.tap(find.text('ORD-001'));
      await tester.pumpAndSettle();

      // Klik Lanjutkan ke Step 2
      await tester.tap(find.text('Lanjutkan'));
      await tester.pumpAndSettle();

      // Step 2: Pilih kategori & isi form
      expect(find.text('Barang Rusak'), findsOneWidget);
      await tester.tap(find.text('Barang Rusak'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Kemasan Sobek');
      await tester.enterText(textFields.at(1), 'Diterima dalam keadaan robek dan isi tercecer');
      await tester.pumpAndSettle();

      // Klik Lanjutkan ke Step 3
      await tester.tap(find.text('Lanjutkan'));
      await tester.pumpAndSettle();

      // Step 3: Pastikan semua 4 prioritas backend tersedia di UI
      expect(find.text('Rendah'), findsOneWidget);
      expect(find.text('Sedang'), findsOneWidget);
      expect(find.text('Tinggi'), findsOneWidget);
      expect(find.text('Kritis'), findsOneWidget);

      // Pastikan tidak ada "Darurat"
      expect(find.text('Darurat'), findsNothing);

      // Uji seleksi prioritas Kritis
      await tester.tap(find.text('Kritis'));
      await tester.pumpAndSettle();

      // Ringkasan harus menampilkan Prioritas: Kritis
      expect(find.text('• Prioritas: Kritis'), findsOneWidget);
    });
  });

  group('Issues List Screen Quick Filter Chips (Fase 5)', () {
    testWidgets('Menampilkan chip filter cepat: Semua, Terlambat, Prioritas Tinggi/Kritis, Milik Saya', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dummyIssues = [
        OrderIssue(
          id: 1,
          kodeKendala: 'KND-001',
          orderId: 1,
          categoryId: 1,
          judul: 'Barang pecah saat pengiriman',
          deskripsi: 'Pecah berantakan',
          prioritas: 'kritis',
          status: 'baru',
          tenggatAt: '2026-10-25T10:00:00Z',
          assignedTo: 10,
          assignedNama: 'Budi Petugas',
          createdByNama: 'Admin',
          isArchived: false,
          createdBy: 1,
          createdAt: '2026-10-24T10:00:00Z',
          updatedAt: '2026-10-24T10:00:00Z',
          categoryNama: 'Pecah Belah',
          categoryWarnaHex: '#DC2626',
          categoryIkon: 'broken_image',
          kodePesanan: 'ORD-101',
          namaPelanggan: 'Budi Santoso',
          isOverdue: true,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            issuesListProvider.overrideWith((ref) => {
              'items': dummyIssues,
              'total': 1,
            }),
          ],
          child: const MaterialApp(
            home: IssuesListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Pastikan keempat chip filter cepat hadir di layar
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Terlambat'), findsOneWidget);
      expect(find.text('Prioritas Tinggi/Kritis'), findsOneWidget);
      expect(find.text('Milik Saya'), findsOneWidget);

      // Verifikasi tap pada chip 'Terlambat'
      await tester.tap(find.text('Terlambat'));
      await tester.pumpAndSettle();

      // Verifikasi tap pada chip 'Prioritas Tinggi/Kritis'
      await tester.tap(find.text('Prioritas Tinggi/Kritis'));
      await tester.pumpAndSettle();
    });
  });

  group('Dashboard Screen Widget Tests (Fase 5)', () {
    testWidgets('Menampilkan sapaan, kartu ringkasan, donat kategori, dan bagian perhatian', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dummySummary = DashboardSummary(
        total: 42,
        baru: 10,
        sedangDiproses: 12,
        menungguInformasi: 5,
        selesai: 15,
        ditolak: 0,
        terlambat: 4,
        rataRataWaktuJam: 3.5,
        persentaseSelesai: 35.7,
      );

      final dummyCategoryStats = <CategoryStat>[
        CategoryStat(
          categoryId: 1,
          nama: 'Kerusakan Barang',
          warnaHex: '#EF4444',
          ikon: 'broken_image',
          total: 25,
          persentase: 59.5,
        ),
        CategoryStat(
          categoryId: 2,
          nama: 'Keterlambatan Kirim',
          warnaHex: '#3B82F6',
          ikon: 'local_shipping',
          total: 17,
          persentase: 40.5,
        ),
      ];

      final dummyTrend = <TrendPoint>[
        TrendPoint(label: '20 Okt', tanggal: '2026-10-20', totalMasuk: 5, totalSelesai: 2),
        TrendPoint(label: '21 Okt', tanggal: '2026-10-21', totalMasuk: 8, totalSelesai: 5),
      ];

      final dummyIssues = [
        OrderIssue(
          id: 99,
          kodeKendala: 'KND-999',
          orderId: 101,
          categoryId: 1,
          judul: 'Barang Rusak Berat',
          deskripsi: 'Pecah saat handling ekspedisi',
          prioritas: 'kritis',
          status: 'baru',
          tenggatAt: '2026-10-20T10:00:00Z',
          assignedTo: 1,
          assignedNama: 'Sonny Admin',
          createdByNama: 'Budi',
          isArchived: false,
          createdBy: 2,
          createdAt: '2026-10-20T08:00:00Z',
          updatedAt: '2026-10-20T08:00:00Z',
          categoryNama: 'Kerusakan Barang',
          categoryWarnaHex: '#EF4444',
          categoryIkon: 'broken_image',
          kodePesanan: 'ORD-999',
          namaPelanggan: 'Ibu Rahma',
          isOverdue: true,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier(User(
              id: 1,
              nama: 'Sonny',
              email: 'sonny@kendalaku.id',
              role: 'admin',
            ))),
            dashboardSummaryProvider.overrideWith((ref) => dummySummary),
            dashboardCategoryStatsProvider.overrideWith((ref) => dummyCategoryStats),
            dashboardTrendProvider.overrideWith((ref) => dummyTrend),
            issuesListProvider.overrideWith((ref) => {
              'items': dummyIssues,
              'total': 1,
            }),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      // Settle animations
      await tester.pumpAndSettle();

      // 1. Verifikasi Header Gradient & Sapaan
      expect(find.text('Beranda KendalaKu'), findsOneWidget);
      expect(find.textContaining('Selamat bertugas, Sonny (admin)'), findsOneWidget);
      expect(find.textContaining('butuh perhatian segera'), findsOneWidget);

      // 2. Verifikasi Kartu Metrik Ringkasan
      expect(find.text('Total Kendala'), findsOneWidget);
      expect(find.text('Terlambat SLA'), findsOneWidget);
      expect(find.text('Baru'), findsWidgets);
      expect(find.text('Selesai'), findsWidgets);

      // 3. Verifikasi Donut Kategori & Distribusi
      expect(find.text('Distribusi Kategori Kendala'), findsOneWidget);
      expect(find.textContaining('Kerusakan Barang'), findsWidgets);
      expect(find.textContaining('Keterlambatan Kirim'), findsWidgets);

      // 4. Verifikasi Trend Line & Pilihan Periode
      expect(find.text('Tren Kendala'), findsOneWidget);
      expect(find.text('7 Hari'), findsOneWidget);
      expect(find.text('30 Hari'), findsOneWidget);
      expect(find.text('12 Bln'), findsOneWidget);

      // 5. Verifikasi Efisiensi Penyelesaian
      expect(find.text('Rata-rata Penyelesaian'), findsOneWidget);
      expect(find.text('3.5 Jam'), findsOneWidget);
      expect(find.text('35.7%'), findsOneWidget);

      // 6. Verifikasi List "Perlu Perhatian"
      expect(find.text('Perlu Perhatian (Terlambat & Kritis)'), findsOneWidget);
      expect(find.text('Barang Rusak Berat'), findsOneWidget);
    });
  });

  group('Kelola Kategori Widget Tests (Fase 5)', () {
    testWidgets('Menampilkan daftar kategori, SLA, dan dapat membuka dialog tambah kategori', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dummyCategories = [
        ProblemCategory(
          id: 1,
          nama: 'Kerusakan Barang',
          warnaHex: '#EF4444',
          ikon: 'broken_image',
          tenggatJam: 12,
          aktif: true,
        ),
        ProblemCategory(
          id: 2,
          nama: 'Salah Alamat Kirim',
          warnaHex: '#3B82F6',
          ikon: 'location_off',
          tenggatJam: 24,
          aktif: true,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) => dummyCategories),
          ],
          child: const MaterialApp(
            home: ManageCategoriesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verifikasi Judul & Daftar Kategori
      expect(find.text('Kelola Kategori Kendala'), findsOneWidget);
      expect(find.text('Kerusakan Barang'), findsOneWidget);
      expect(find.text('Salah Alamat Kirim'), findsOneWidget);
      expect(find.textContaining('SLA: 12 Jam'), findsOneWidget);
      expect(find.textContaining('SLA: 24 Jam'), findsOneWidget);

      // 2. Verifikasi Tombol Tambah Kategori di AppBar
      final addBtn = find.byTooltip('Tambah Kategori');
      expect(addBtn, findsOneWidget);

      // 3. Tekan tombol Tambah untuk membuka modal tambah kategori
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // 4. Verifikasi Dialog Terbuka
      expect(find.text('Tambah Kategori Baru'), findsOneWidget);
      expect(find.text('Nama Kategori *'), findsOneWidget);
      expect(find.text('Tenggat Waktu SLA (Jam) *'), findsOneWidget);
      expect(find.text('Pilihan Warna Aksen'), findsOneWidget);
      expect(find.text('Pilihan Ikon'), findsOneWidget);
      expect(find.text('Simpan'), findsOneWidget);

      // 5. Tutup dialog dengan tombol Batal
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(find.text('Tambah Kategori Baru'), findsNothing);
    });
  });
}
