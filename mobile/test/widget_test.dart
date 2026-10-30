import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/date_util.dart';
import 'package:mobile/core/utils/icon_util.dart';
import 'package:mobile/data/models/models.dart';
import 'package:mobile/providers/app_providers.dart';
import 'package:mobile/core/utils/whatsapp_util.dart';
import 'package:mobile/views/categories/manage_categories_screen.dart';
import 'package:mobile/views/dashboard/dashboard_screen.dart';
import 'package:mobile/views/issues/issue_detail_screen.dart';
import 'package:mobile/views/issues/issue_wizard_screen.dart';
import 'package:mobile/views/issues/issues_list_screen.dart';
import 'package:mobile/views/settings/settings_screen.dart';
import 'package:mobile/views/widgets/status_transition_modal.dart';
import 'package:mobile/views/widgets/whatsapp_preview_sheet.dart';

class _MockAuthNotifier extends AuthNotifier {
  final User? initialUser;
  _MockAuthNotifier([this.initialUser]);

  @override
  AuthState build() => AuthState(
        isAuthenticated: initialUser != null,
        user: initialUser,
      );

  @override
  Future<void> checkInitialAuth() async {
    // No-op for tests to prevent overriding mock state or async timer leaks
  }
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
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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
      await tester.ensureVisible(find.text('Simpan Perubahan Status'));
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
        jatuhTempoSegera: 3,
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
            dueSoonIssuesProvider.overrideWith((ref) => dummyIssues),
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
      expect(find.text('Barang Rusak Berat'), findsWidgets);
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

  group('WhatsApp Feature Tests (Fase 6B)', () {
    test('WhatsAppUtil: Normalisasi nomor telepon ke format internasional', () {
      expect(WhatsAppUtil.normalizePhoneNumber('0812-3456-7890'), equals('6281234567890'));
      expect(WhatsAppUtil.normalizePhoneNumber('0812 3456 789'), equals('628123456789'));
      expect(WhatsAppUtil.normalizePhoneNumber('+62 812-3456-7890'), equals('6281234567890'));
      expect(WhatsAppUtil.normalizePhoneNumber('628123456789'), equals('628123456789'));
      expect(WhatsAppUtil.normalizePhoneNumber(''), equals(''));
    });

    test('WhatsAppUtil: Pembentukan URL wa.me dengan teks ter-encode', () {
      const text = 'Halo *Admin* & Petugas!';
      final urlTanpaNomor = WhatsAppUtil.buildWhatsAppUrl(text: text);
      expect(urlTanpaNomor, startsWith('https://wa.me/?text='));
      expect(urlTanpaNomor, contains(Uri.encodeComponent(text)));

      final urlDenganNomor = WhatsAppUtil.buildWhatsAppUrl(phone: '08123456789', text: text);
      expect(urlDenganNomor, startsWith('https://wa.me/628123456789?text='));
      expect(urlDenganNomor, contains(Uri.encodeComponent(text)));
    });

    test('WhatsAppUtil: Deteksi peringatan teks terlalu panjang (> 1800 karakter)', () {
      final shortText = 'Teks pendek aman';
      expect(WhatsAppUtil.isTextTooLongForUrl(shortText), isFalse);

      final longText = 'A' * 2000;
      expect(WhatsAppUtil.isTextTooLongForUrl(longText), isTrue);
    });

    testWidgets('WhatsAppPreviewSheet: Pratinjau teks single issue, switch nama pelanggan, dan tombol salin/buka', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dummyIssue = OrderIssue(
        id: 1,
        kodeKendala: 'KND-999',
        orderId: 101,
        categoryId: 1,
        judul: 'Barang Rusak Pengiriman',
        deskripsi: 'Kotak robek dan remuk',
        prioritas: 'kritis',
        status: 'baru',
        tenggatAt: '2026-10-27T18:00:00Z',
        assignedTo: 1,
        assignedNama: 'Sonny Petugas',
        createdByNama: 'Admin',
        isArchived: false,
        createdBy: 2,
        createdAt: '2026-10-27T10:00:00Z',
        updatedAt: '2026-10-27T10:00:00Z',
        categoryNama: 'Kerusakan Barang',
        categoryWarnaHex: '#EF4444',
        categoryIkon: 'broken_image',
        kodePesanan: 'ORD-888',
        namaPelanggan: 'Dewi Lestari',
        isOverdue: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: WhatsAppPreviewSheet(
                singleIssue: dummyIssue,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verifikasi Header Modal
      expect(find.text('Kirim ke WhatsApp'), findsOneWidget);
      expect(find.text('Ringkasan 1 Kendala'), findsOneWidget);

      // 2. Verifikasi Konten Teks Awal Memuat Nama Pelanggan (default Switch ON)
      expect(find.text('Sertakan Nama Pelanggan'), findsOneWidget);
      final textFieldFinder = find.byType(TextField).last;
      expect(textFieldFinder, findsOneWidget);
      final initialText = tester.widget<TextField>(textFieldFinder).controller!.text;
      expect(initialText, contains('ORD-888 (Dewi Lestari)'));
      expect(initialText, contains('*[KND-999]*'));
      expect(initialText, contains('*[KRITIS]*'));

      // 3. Verifikasi Switch Nama Pelanggan dimatikan -> Nama pelanggan disembunyikan
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      final updatedText = tester.widget<TextField>(textFieldFinder).controller!.text;
      expect(updatedText, contains('Pesanan: ORD-888'));
      expect(updatedText, isNot(contains('Dewi Lestari')));

      // 4. Verifikasi Tombol Aksi Bawah
      expect(find.text('Salin Teks'), findsOneWidget);
      expect(find.text('Buka WhatsApp'), findsOneWidget);

      // 5. Verifikasi Input Nomor WhatsApp
      final phoneField = find.widgetWithText(TextField, 'Nomor WhatsApp Tujuan (Opsional)');
      expect(phoneField, findsOneWidget);
      await tester.enterText(phoneField, '08123456789');
      await tester.pumpAndSettle();
      expect(find.text('08123456789'), findsOneWidget);
    });

    testWidgets('IssuesListScreen: Mode pilih checkbox dan aksi Kirim ke WhatsApp', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dummyIssues = [
        OrderIssue(
          id: 10,
          kodeKendala: 'KND-010',
          orderId: 1,
          categoryId: 1,
          judul: 'Keterlambatan Kurir',
          deskripsi: 'Kurir mogok',
          prioritas: 'sedang',
          status: 'baru',
          tenggatAt: '2026-10-27T10:00:00Z',
          assignedTo: 1,
          assignedNama: 'Petugas',
          createdByNama: 'Admin',
          isArchived: false,
          createdBy: 1,
          createdAt: '2026-10-26T10:00:00Z',
          updatedAt: '2026-10-26T10:00:00Z',
          categoryNama: 'Pengiriman',
          categoryWarnaHex: '#3B82F6',
          categoryIkon: 'local_shipping',
          kodePesanan: 'ORD-010',
          namaPelanggan: 'Budi Santoso',
          isOverdue: false,
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

      // Tombol WhatsApp di AppBar harus ada
      final waButton = find.byTooltip('Kirim ke WhatsApp');
      expect(waButton, findsOneWidget);

      // Long press pada kartu untuk mengaktifkan mode pilih
      await tester.longPress(find.text('Keterlambatan Kurir'));
      await tester.pumpAndSettle();

      // Mode pilih harus aktif: ada tombol 'Batal Pilih Semua' / 'Pilih Semua'
      expect(find.text('Pilih Semua'), findsNothing);
      expect(find.text('Batal Pilih Semua'), findsOneWidget);
      expect(find.text('(1 dipilih)'), findsOneWidget);

      // Checkbox harus tampil dan tercentang
      final checkbox = find.byType(Checkbox);
      expect(checkbox, findsOneWidget);
      expect(tester.widget<Checkbox>(checkbox).value, isTrue);

      // Tekan tombol Batal untuk keluar dari mode pilih
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(find.text('Batal Pilih Semua'), findsNothing);
    });

    testWidgets('Settings: Sheet Daftar Petugas dengan JSON asli (termasuk user tanpa email) dan Sheet Riwayat Aktivitas (status_sebelumnya kosong)', (tester) async {
      // 1. JSON Asli Users (user id 2 tanpa email)
      final rawUsersJson = [
        {
          "id": 3,
          "nama": "Budi Penanganan",
          "email": "petugas2@kendalaku.com",
          "role": "petugas",
          "created_at": "2026-10-26T08:16:21Z"
        },
        {
          "id": 2,
          "nama": "Rina Petugas",
          // email tidak ada / hilang
          "role": "petugas",
          "created_at": "2026-10-26T08:16:21Z"
        },
        {
          "id": 1,
          "nama": "Sonny (Admin Operasional)",
          "email": "admin@kendalaku.com",
          "role": "admin",
          "created_at": "2026-10-26T08:16:21Z"
        }
      ];

      final usersList = rawUsersJson.map((e) => User.fromJson(e)).toList();

      // 2. JSON Asli Activities (entri baru memiliki status_sebelumnya "")
      final rawActivitiesJson = [
        {
          "id": 63,
          "issue_id": 36,
          "kode_kendala": "KDL-202610-0036",
          "judul_kendala": "Resi pengiriman tidak dapat dilacak di kurir",
          "status_sebelumnya": "baru",
          "status_baru": "ditolak",
          "catatan_tindakan": "Pembaruan status operasional penanganan kendala",
          "oleh_user_id": 3,
          "oleh_user_nama": "Budi Penanganan",
          "created_at": "2026-09-25T13:16:21Z"
        },
        {
          "id": 62,
          "issue_id": 36,
          "kode_kendala": "KDL-202610-0036",
          "judul_kendala": "Resi pengiriman tidak dapat dilacak di kurir",
          "status_sebelumnya": "", // Kosong untuk laporan dibuat
          "status_baru": "baru",
          "catatan_tindakan": "Kendala dilaporkan ke sistem KendalaKu",
          "oleh_user_id": 1,
          "oleh_user_nama": "Sonny (Admin Operasional)",
          "created_at": "2026-09-25T11:16:21Z"
        }
      ];

      final activitiesList = rawActivitiesJson.map((e) => ActivityLogItem.fromJson(e)).toList();

      final adminUser = User(
        id: 1,
        nama: 'Sonny (Admin Operasional)',
        email: 'admin@kendalaku.com',
        role: 'admin',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier(adminUser)),
            usersListProvider.overrideWith((ref) => usersList),
            activitiesListProvider.overrideWith((ref) => activitiesList),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Buka bottom sheet Daftar Petugas
      await tester.tap(find.text('Daftar Petugas Lapangan'));
      await tester.pumpAndSettle();

      expect(find.text('Daftar Petugas Lapangan & Admin'), findsOneWidget);
      expect(find.text('Budi Penanganan'), findsOneWidget);
      expect(find.text('Rina Petugas'), findsOneWidget);
      // Rina Petugas tidak memiliki email, harus tampil 'Tidak ada email' tanpa crash/exception
      expect(find.text('Tidak ada email • Role: PETUGAS'), findsOneWidget);

      // Tutup sheet
      final navigatorState = Navigator.of(tester.element(find.text('Daftar Petugas Lapangan & Admin')), rootNavigator: true);
      navigatorState.pop();
      await tester.pumpAndSettle();

      // Buka bottom sheet Riwayat Aktivitas
      await tester.tap(find.text('Riwayat Aktivitas Tim'));
      await tester.pumpAndSettle();

      expect(find.text('Riwayat Aktivitas & Audit Trail Tim'), findsOneWidget);
      expect(find.text('KDL-202610-0036'), findsNWidgets(2));
      // Status sebelumnya kosong harus dipetakan ke 'Laporan Dibuat'
      expect(find.text('Laporan Dibuat'), findsOneWidget);
      expect(find.text('Baru'), findsNWidgets(2)); // status_sebelumnya "baru" pada entri 63 dan status_baru "baru" pada entri 62
      expect(find.text('Ditolak'), findsOneWidget);

      // Tutup sheet
      final navigatorState2 = Navigator.of(tester.element(find.text('Riwayat Aktivitas & Audit Trail Tim')), rootNavigator: true);
      navigatorState2.pop();
      await tester.pumpAndSettle();
    });

    testWidgets('Settings: Sheet menampilkan pesan error dan tombol Coba Lagi saat fetch gagal', (tester) async {
      final adminUser = User(
        id: 1,
        nama: 'Sonny (Admin Operasional)',
        email: 'admin@kendalaku.com',
        role: 'admin',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier(adminUser)),
            usersListProvider.overrideWith((ref) => Future<List<User>>.error(Exception('Koneksi timeout'))),
            activitiesListProvider.overrideWith((ref) => Future<List<ActivityLogItem>>.error(Exception('Server error 500'))),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Buka bottom sheet Petugas saat error
      await tester.tap(find.text('Daftar Petugas Lapangan'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Gagal memuat petugas'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Coba Lagi'), findsOneWidget);

      // Tutup sheet
      final nav1 = Navigator.of(tester.element(find.text('Daftar Petugas Lapangan & Admin')), rootNavigator: true);
      nav1.pop();
      await tester.pumpAndSettle();

      // Buka bottom sheet Aktivitas saat error
      await tester.tap(find.text('Riwayat Aktivitas Tim'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Gagal memuat riwayat aktivitas'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Coba Lagi'), findsOneWidget);

      // Tutup sheet
      final nav2 = Navigator.of(tester.element(find.text('Riwayat Aktivitas & Audit Trail Tim')), rootNavigator: true);
      nav2.pop();
      await tester.pumpAndSettle();
    });
  });

  // ---------------- WIDGET TESTS FASE 6 ----------------
  group('Fase 6 Teamwork & Roles Tests', () {
    final sampleIssueForReassign = OrderIssue(
      id: 99,
      kodeKendala: 'KND-99',
      orderId: 10,
      categoryId: 1,
      judul: 'Paket salah alamat pengiriman',
      deskripsi: 'Alamat tujuan tidak ditemukan kurir',
      prioritas: 'tinggi',
      status: 'sedang_diproses',
      tenggatAt: '2026-10-28T10:00:00Z',
      assignedTo: 2,
      isArchived: false,
      createdBy: 1,
      createdAt: '2026-10-27T08:00:00Z',
      updatedAt: '2026-10-27T08:00:00Z',
      kodePesanan: 'ORD-99',
      namaPelanggan: 'Budi Santoso',
      categoryNama: 'Pengiriman',
      categoryWarnaHex: '#3B82F6',
      categoryIkon: 'local_shipping_rounded',
      assignedNama: 'Rina Petugas',
      createdByNama: 'Admin',
      isOverdue: false,
    );

    testWidgets('13A-1: Tombol reassign tersembunyi untuk Petugas', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Render sebagai Petugas (ID 3, bukan pemilik ID 2)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier(
                  User(id: 3, nama: 'Doni Petugas', email: 'doni@kendalaku.com', role: 'petugas'),
                )),
            issueDetailProvider(99).overrideWith((ref) => sampleIssueForReassign),
            issueTransitionsProvider(99).overrideWith((ref) => []),
            issueCommentsProvider(99).overrideWith((ref) => []),
            usersListProvider.overrideWith((ref) => []),
          ],
          child: const MaterialApp(
            home: IssueDetailScreen(issueId: 99),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tombol reassign (tooltip: 'Pindahkan ke Petugas Lain') tidak boleh ada
      expect(find.byTooltip('Pindahkan ke Petugas Lain'), findsNothing);
      expect(find.text('Pindahkan'), findsNothing);
    });

    testWidgets('13A-2: Tombol reassign muncul untuk Admin', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Render sebagai Admin (ID 1)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier(
                  User(id: 1, nama: 'Admin Super', email: 'admin@kendalaku.com', role: 'admin'),
                )),
            issueDetailProvider(99).overrideWith((ref) => sampleIssueForReassign),
            issueTransitionsProvider(99).overrideWith((ref) => []),
            issueCommentsProvider(99).overrideWith((ref) => []),
            usersListProvider.overrideWith((ref) => []),
          ],
          child: const MaterialApp(
            home: IssueDetailScreen(issueId: 99),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tombol reassign harus muncul untuk Admin
      expect(find.byTooltip('Pindahkan ke Petugas Lain'), findsOneWidget);
    });

    testWidgets('13B-1: Aksi ubah status disembunyikan untuk Petugas non-pemilik', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Petugas ID 3 membuka kendala milik Petugas ID 2
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier(
                  User(id: 3, nama: 'Doni Petugas', email: 'doni@kendalaku.com', role: 'petugas'),
                )),
            issueDetailProvider(99).overrideWith((ref) => sampleIssueForReassign),
            issueTransitionsProvider(99).overrideWith((ref) => []),
            issueCommentsProvider(99).overrideWith((ref) => []),
            usersListProvider.overrideWith((ref) => []),
          ],
          child: const MaterialApp(
            home: IssueDetailScreen(issueId: 99),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tombol Ubah Status di AppBar tidak boleh ada
      expect(find.text('Ubah Status'), findsNothing);

      // Teks penjelas hak akses harus tampil
      expect(find.textContaining('Anda sedang melihat kendala petugas lain'), findsOneWidget);
    });

    testWidgets('13B-2: Aksi ubah status muncul untuk Petugas pemilik kendala', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Dibuka oleh Petugas pemiliknya (ID 2), tombol Ubah Status muncul
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier(
                  User(id: 2, nama: 'Rina Petugas', email: 'rina@kendalaku.com', role: 'petugas'),
                )),
            issueDetailProvider(99).overrideWith((ref) => sampleIssueForReassign),
            issueTransitionsProvider(99).overrideWith((ref) => []),
            issueCommentsProvider(99).overrideWith((ref) => []),
            usersListProvider.overrideWith((ref) => []),
          ],
          child: const MaterialApp(
            home: IssueDetailScreen(issueId: 99),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ubah Status'), findsOneWidget);
      expect(find.textContaining('Anda sedang melihat kendala petugas lain'), findsNothing);
    });

    testWidgets('13C: Komentar terkirim dan tampil dalam timeline', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final comments = <IssueComment>[
        IssueComment(
          id: 1,
          issueId: 99,
          userId: 2,
          userNama: 'Rina Petugas',
          tipe: 'komentar',
          isi: 'Sudah dihubungi pihak kurir logistik',
          createdAt: '2026-10-27T08:30:00Z',
        ),
        IssueComment(
          id: 2,
          issueId: 99,
          userId: 1,
          userNama: 'Administrator',
          tipe: 'sistem',
          isi: 'Dipindahkan dari Rina ke Doni. Catatan: Pergantian shift',
          createdAt: '2026-10-27T09:00:00Z',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier(
                  User(id: 1, nama: 'Administrator', email: 'admin@kendalaku.com', role: 'admin'),
                )),
            issueDetailProvider(99).overrideWith((ref) => sampleIssueForReassign),
            issueTransitionsProvider(99).overrideWith((ref) => []),
            issueCommentsProvider(99).overrideWith((ref) => comments),
            usersListProvider.overrideWith((ref) => []),
          ],
          child: const MaterialApp(
            home: IssueDetailScreen(issueId: 99),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Komentar user dan sistem tampil dalam timeline
      expect(find.text('Sudah dihubungi pihak kurir logistik'), findsOneWidget);
      expect(find.text('Aktivitas Sistem'), findsOneWidget);
      expect(find.textContaining('Dipindahkan dari Rina ke Doni'), findsOneWidget);

      // Kolom input komentar di bawah ada
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);

      // Masukkan teks komentar baru
      await tester.enterText(find.byType(TextField), 'Komentar pengujian dari Flutter');
      await tester.pump();
      expect(find.text('Komentar pengujian dari Flutter'), findsOneWidget);
    });
  });

  group('Fase 7 Widget Tests (Template Catatan Penyelesaian & Mode Tema)', () {
    testWidgets('Template catatan penyelesaian muncul saat status selesai dipilih dan mengisi kolom saat di-tap', (tester) async {
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
      await tester.pumpAndSettle();

      // Pilih status 'Selesai'
      final selesaiOption = find.text('Selesai');
      expect(selesaiOption, findsOneWidget);
      await tester.tap(selesaiOption);
      await tester.pumpAndSettle();

      // Chip template cepat harus tampil
      expect(find.text('Pilihan Cepat:'), findsOneWidget);
      expect(find.text('Barang diganti'), findsOneWidget);
      expect(find.text('Alamat dikoreksi'), findsOneWidget);
      expect(find.text('Pelanggan dihubungi'), findsOneWidget);
      expect(find.text('Data pesanan diperbaiki'), findsOneWidget);
      expect(find.text('Pengiriman dijadwalkan ulang'), findsOneWidget);

      // Tap chip 'Barang diganti'
      await tester.tap(find.text('Barang diganti'));
      await tester.pumpAndSettle();

      // Field catatan penyelesaian harus terisi 'Barang diganti'
      expect(find.text('Barang diganti'), findsWidgets);

      // Verifikasi user masih bisa mengedit teksnya
      final penyelesaianField = find.widgetWithText(TextFormField, 'Barang diganti');
      expect(penyelesaianField, findsOneWidget);
      await tester.enterText(penyelesaianField, 'Barang diganti dengan unit baru');
      await tester.pumpAndSettle();
      expect(find.text('Barang diganti dengan unit baru'), findsOneWidget);
    });

    testWidgets('Pengaturan menampilkan toggle tema dan merespons pemilihan mode tema', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier(
                  User(id: 1, nama: 'Administrator', email: 'admin@kendalaku.com', role: 'admin'),
                )),
            themeModeProvider.overrideWith(() => ThemeModeNotifier()),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifikasi elemen pengaturan tema
      expect(find.text('Mode Tampilan Tema'), findsOneWidget);
      expect(find.byKey(const Key('theme_mode_segmented_button')), findsOneWidget);
      expect(find.text('Terang'), findsOneWidget);
      expect(find.text('Gelap'), findsOneWidget);
      expect(find.text('Sistem'), findsOneWidget);

      // Verifikasi opsi Ubah Kata Sandi ada di Pengaturan
      expect(find.byKey(const Key('settings_change_password_tile')), findsOneWidget);
      expect(find.text('Ubah Kata Sandi'), findsOneWidget);

      // Tap opsi 'Gelap'
      await tester.ensureVisible(find.text('Gelap'));
      await tester.tap(find.text('Gelap'));
      await tester.pumpAndSettle();

      // Tap tile 'Ubah Kata Sandi' untuk membuka modal ganti password
      await tester.ensureVisible(find.byKey(const Key('settings_change_password_tile')));
      await tester.tap(find.byKey(const Key('settings_change_password_tile')));
      await tester.pumpAndSettle();

      expect(find.text('Ubah Kata Sandi Akun'), findsOneWidget);
      expect(find.text('Kata Sandi Lama *'), findsOneWidget);
      expect(find.text('Kata Sandi Baru *'), findsOneWidget);
      expect(find.text('Konfirmasi Kata Sandi Baru *'), findsOneWidget);
      expect(find.text('Simpan Kata Sandi'), findsOneWidget);
    });

    testWidgets('Mode Gelap Konsisten: SettingsScreen Scaffold luminance rendah', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier(
                  User(id: 1, nama: 'Administrator', email: 'admin@kendalaku.com', role: 'admin'),
                )),
            themeModeProvider.overrideWith(() => ThemeModeNotifier()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cek Scaffold SettingsScreen
      final settingsScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(settingsScaffold.backgroundColor, isNotNull);
      // Luminance scaffold harus rendah (gelap < 0.15)
      expect(settingsScaffold.backgroundColor!.computeLuminance(), lessThan(0.15));
    });

    testWidgets('Mode Gelap Konsisten: IssuesListScreen Scaffold, kartu kendala & search bar gelap', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testIssue = OrderIssue(
        id: 101,
        kodeKendala: 'KDL-202610-0101',
        orderId: 1,
        kodePesanan: 'INV-202610-001',
        namaPelanggan: 'Budi Santoso',
        produkPesanan: 'Kopi Arabika 250g',
        categoryId: 1,
        categoryNama: 'Kemasan Rusak',
        categoryWarnaHex: '#F59E0B',
        categoryIkon: 'inventory_2_outlined',
        judul: 'Kemasan sobek saat pengiriman',
        deskripsi: 'Barang diterima dalam kondisi bocor halus',
        status: 'sedang_diproses',
        prioritas: 'tinggi',
        tenggatAt: DateTime.now().add(const Duration(hours: 12)).toIso8601String(),
        createdAt: DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
        createdBy: 1,
        createdByNama: 'Admin',
        assignedNama: 'Petugas Budi',
        isArchived: false,
        isOverdue: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier(
                  User(id: 1, nama: 'Administrator', email: 'admin@kendalaku.com', role: 'admin'),
                )),
            issuesListProvider.overrideWith((ref) async => {
                  'items': [testIssue],
                  'meta': {'total': 1, 'page': 1, 'limit': 10, 'total_pages': 1},
                }),
            categoriesProvider.overrideWith((ref) async => [
                  ProblemCategory(
                    id: 1,
                    nama: 'Kemasan Rusak',
                    tenggatJam: 24,
                    warnaHex: '#F59E0B',
                    ikon: 'inventory_2_outlined',
                    aktif: true,
                  ),
                ]),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const IssuesListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cek Scaffold IssuesListScreen memiliki background gelap (luminance < 0.15)
      final issuesScaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(issuesScaffold.backgroundColor, isNotNull);
      expect(issuesScaffold.backgroundColor!.computeLuminance(), lessThan(0.15));

      // Cek kolom pencarian di IssuesListScreen terisi dengan warna gelap
      final searchTextField = tester.widget<TextField>(find.byType(TextField));
      expect(searchTextField.decoration?.filled, isTrue);
      expect(searchTextField.decoration?.fillColor, isNotNull);
      expect(searchTextField.decoration!.fillColor!.computeLuminance(), lessThan(0.15));
      expect(searchTextField.decoration?.hintStyle?.color, isNotNull);

      // Cek kartu kendala ditampilkan
      expect(find.text('KDL-202610-0101'), findsOneWidget);
      expect(find.text('Kemasan sobek saat pengiriman'), findsOneWidget);
    });
  });
}



