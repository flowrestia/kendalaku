import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/utils/error_mapper.dart';
import 'package:mobile/data/models/models.dart';
import 'package:mobile/providers/app_providers.dart';
import 'package:mobile/views/error/error_screens.dart';
import 'package:mobile/views/issues/issues_list_screen.dart';
import 'package:mobile/views/widgets/error_view.dart';

class _MockAuthNotifier extends AuthNotifier {
  final User? initialUser;
  _MockAuthNotifier([this.initialUser]);

  @override
  AuthState build() => AuthState(
        isAuthenticated: initialUser != null,
        user: initialUser,
      );

  @override
  Future<void> checkInitialAuth() async {}
}

void main() {
  group('ErrorMapper Unit Tests (Bagian B.1 & B.11)', () {
    test('Koneksi timeout / putus menghasilkan pesan manusiawi tanpa nama kelas exception', () {
      final reqOptions = RequestOptions(path: '/issues');

      // 1. Connection Timeout
      final timeoutErr = DioException(
        requestOptions: reqOptions,
        type: DioExceptionType.connectionTimeout,
      );
      final timeoutAppErr = ErrorMapper.map(timeoutErr);
      expect(timeoutAppErr.type, equals(ErrorType.noConnection));
      expect(timeoutAppErr.message, equals('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.'));
      expect(timeoutAppErr.message, isNot(contains('DioException')));

      // 2. Connection Error
      final connErr = DioException(
        requestOptions: reqOptions,
        type: DioExceptionType.connectionError,
      );
      final connAppErr = ErrorMapper.map(connErr);
      expect(connAppErr.type, equals(ErrorType.noConnection));
      expect(connAppErr.message, equals('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.'));
      expect(connAppErr.message, isNot(contains('DioException')));

      // 3. SocketException / TimeoutException
      const socketErr = SocketException('Connection refused');
      expect(ErrorMapper.getMessage(socketErr), equals('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.'));
      expect(ErrorMapper.getMessage(socketErr), isNot(contains('SocketException')));

      final timeErr = TimeoutException('Timeout occurred');
      expect(ErrorMapper.getMessage(timeErr), equals('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.'));
      expect(ErrorMapper.getMessage(timeErr), isNot(contains('TimeoutException')));
    });

    test('401 Unauthorized menghasilkan pesan sesi berakhir dan tidak memuat nama kelas exception', () {
      final reqOptions = RequestOptions(path: '/auth/me');
      final err401 = DioException(
        requestOptions: reqOptions,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 401,
          data: {'error': {'message': 'Unauthorized'}},
        ),
      );

      final appErr = ErrorMapper.map(err401);
      expect(appErr.type, equals(ErrorType.unauthorized));
      expect(appErr.message, equals('Sesi berakhir, silakan masuk lagi'));
      expect(appErr.message, isNot(contains('DioException')));
    });

    test('403 Forbidden menghasilkan pesan akses ditolak dan tidak memuat nama kelas exception', () {
      final reqOptions = RequestOptions(path: '/categories');
      final err403 = DioException(
        requestOptions: reqOptions,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 403,
          data: {'error': {'message': 'Forbidden'}},
        ),
      );

      final appErr = ErrorMapper.map(err403);
      expect(appErr.type, equals(ErrorType.forbidden));
      expect(appErr.message, equals('Kamu tidak punya akses untuk aksi ini'));
      expect(appErr.message, isNot(contains('DioException')));
    });

    test('404 Not Found menghasilkan pesan data tidak ditemukan dan tidak memuat nama kelas exception', () {
      final reqOptions = RequestOptions(path: '/issues/999');
      final err404 = DioException(
        requestOptions: reqOptions,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 404,
        ),
      );

      final appErr = ErrorMapper.map(err404);
      expect(appErr.type, equals(ErrorType.notFound));
      expect(appErr.message, equals('Data tidak ditemukan'));
      expect(appErr.message, isNot(contains('DioException')));
    });

    test('422/400 Validation Error menggunakan pesan ramah dari server', () {
      final reqOptions = RequestOptions(path: '/auth/password');
      final err422 = DioException(
        requestOptions: reqOptions,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 422,
          data: {
            'success': false,
            'error': {
              'code': 'VALIDATION_ERROR',
              'message': 'Kata sandi baru minimal 8 karakter',
            },
          },
        ),
      );

      final appErr = ErrorMapper.map(err422);
      expect(appErr.type, equals(ErrorType.validation));
      expect(appErr.message, equals('Kata sandi baru minimal 8 karakter'));
      expect(appErr.message, isNot(contains('DioException')));
      expect(appErr.message, isNot(contains('Key:')));
    });

    test('5xx Server Error menghasilkan pesan gangguan server dan tidak memuat nama kelas exception', () {
      final reqOptions = RequestOptions(path: '/dashboard/summary');
      final err500 = DioException(
        requestOptions: reqOptions,
        response: Response(
          requestOptions: reqOptions,
          statusCode: 500,
        ),
      );

      final appErr = ErrorMapper.map(err500);
      expect(appErr.type, equals(ErrorType.serverError));
      expect(appErr.message, equals('Terjadi gangguan di server. Coba beberapa saat lagi.'));
      expect(appErr.message, isNot(contains('DioException')));
    });

    test('TypeError, FormatException, dan Exception tak terduga menghasilkan pesan ramah tak terduga', () {
      // TypeError simulasi (null is not a subtype of List)
      try {
        final Map<String, dynamic> fakeJson = {'items': null};
        // ignore: unused_local_variable
        final List<dynamic> list = fakeJson['items'] as List<dynamic>;
      } catch (typeErr) {
        final appErr = ErrorMapper.map(typeErr);
        expect(appErr.type, equals(ErrorType.unexpected));
        expect(appErr.message, equals('Terjadi kesalahan tak terduga.'));
        expect(appErr.message, isNot(contains('TypeError')));
      }

      // FormatException
      const formatErr = FormatException('Invalid JSON format');
      final formatAppErr = ErrorMapper.map(formatErr);
      expect(formatAppErr.type, equals(ErrorType.unexpected));
      expect(formatAppErr.message, equals('Terjadi kesalahan tak terduga.'));
      expect(formatAppErr.message, isNot(contains('FormatException')));

      // Exception umum
      final genErr = Exception('Database driver internal error');
      final genAppErr = ErrorMapper.map(genErr);
      expect(genAppErr.type, equals(ErrorType.unexpected));
      expect(genAppErr.message, equals('Terjadi kesalahan tak terduga.'));
      expect(genAppErr.message, isNot(contains('Exception')));
    });
  });

  group('ErrorView Widget Tests (Bagian B.2 & B.11)', () {
    testWidgets('ErrorView menampilkan judul, penjelasan, dan tombol coba lagi yang merespons tap', (tester) async {
      bool retried = false;
      bool homeTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(
              variant: ErrorType.noConnection,
              title: 'Koneksi Terputus',
              message: 'Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.',
              onRetry: () => retried = true,
              onHome: () => homeTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Koneksi Terputus'), findsOneWidget);
      expect(find.text('Tidak dapat terhubung ke server. Periksa koneksi lalu coba lagi.'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);
      expect(find.text('Kembali ke Beranda'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

      await tester.tap(find.text('Coba Lagi'));
      expect(retried, isTrue);

      await tester.tap(find.text('Kembali ke Beranda'));
      expect(homeTapped, isTrue);
    });

    testWidgets('ErrorView.fromException memetakan exception secara otomatis ke varian yang tepat', (tester) async {
      final reqOptions = RequestOptions(path: '/users');
      final dioErr = DioException(
        requestOptions: reqOptions,
        response: Response(requestOptions: reqOptions, statusCode: 500),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView.fromException(
              error: dioErr,
            ),
          ),
        ),
      );

      expect(find.text('Gangguan Server'), findsOneWidget);
      expect(find.text('Terjadi gangguan di server. Coba beberapa saat lagi.'), findsOneWidget);
      expect(find.byIcon(Icons.dns_rounded), findsOneWidget);
    });
  });

  group('NotFoundScreen (404 Page) & Error Screens Tests', () {
    testWidgets('Halaman 404 (NotFoundScreen) menampilkan judul tanpa ganda, FilledButton beranda >= 48dp', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NotFoundScreen(),
        ),
      );

      // Judul Halaman Tidak Ditemukan hanya muncul satu kali (tidak ganda dengan AppBar)
      expect(find.text('Halaman Tidak Ditemukan'), findsOneWidget);
      expect(find.text('KendalaKu'), findsOneWidget);

      // Tombol Kembali ke Beranda berupa FilledButton dengan ikon rumah & ukuran sentuh minimal 48dp
      final homeBtn = find.widgetWithText(FilledButton, 'Kembali ke Beranda');
      expect(homeBtn, findsOneWidget);
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(tester.getSize(homeBtn).height, greaterThanOrEqualTo(48.0));
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);

      // Cek kontras teks penjelasan di mode terang (WCAG AA: Color 0xFF334155)
      final explanationText = tester.widget<Text>(find.text('Halaman yang kamu tuju tidak ditemukan atau alamat URL keliru.'));
      expect(explanationText.style?.color, equals(const Color(0xFF334155)));
    });

    testWidgets('ForbiddenScreen dan ServerErrorScreen konsisten (judul tunggal & FilledButton)', (tester) async {
      // ForbiddenScreen
      await tester.pumpWidget(
        const MaterialApp(
          home: ForbiddenScreen(),
        ),
      );
      expect(find.text('Akses Ditolak'), findsOneWidget);
      expect(find.text('KendalaKu'), findsOneWidget);
      final forbiddenHomeBtn = find.widgetWithText(FilledButton, 'Kembali ke Beranda');
      expect(forbiddenHomeBtn, findsOneWidget);
      expect(tester.getSize(forbiddenHomeBtn).height, greaterThanOrEqualTo(48.0));

      // ServerErrorScreen
      await tester.pumpWidget(
        const MaterialApp(
          home: ServerErrorScreen(),
        ),
      );
      expect(find.text('Gangguan Server'), findsOneWidget);
      expect(find.text('KendalaKu'), findsOneWidget);
      final serverHomeBtn = find.widgetWithText(FilledButton, 'Kembali ke Beranda');
      expect(serverHomeBtn, findsOneWidget);
      expect(tester.getSize(serverHomeBtn).height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('Teks penjelasan ErrorView di mode gelap memenuhi kontras WCAG AA (0xFFCBD5E1)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: NotFoundScreen(),
          ),
        ),
      );

      final darkExplanation = tester.widget<Text>(find.text('Halaman yang kamu tuju tidak ditemukan atau alamat URL keliru.'));
      expect(darkExplanation.style?.color, equals(const Color(0xFFCBD5E1)));
    });
  });

  group('IssuesListScreen Empty State Tests (Bagian A.2, A.3, A.4)', () {
    final adminUser = User(
      id: 1,
      nama: 'Sonny (Admin)',
      email: 'admin@kendalaku.com',
      role: 'admin',
    );

    testWidgets('Respons items kosong [] menampilkan empty state ramah & tombol Reset Filter', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier(adminUser)),
            issuesListProvider.overrideWith((ref) => {
                  'items': <OrderIssue>[],
                  'total': 0,
                }),
          ],
          child: const MaterialApp(
            home: IssuesListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Memastikan teks empty state ramah hadir
      expect(find.text('Belum ada kendala yang cocok dengan filter ini'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_rounded), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Reset Filter'), findsOneWidget);
    });

    testWidgets('Respons filter "Milik Saya" kosong menampilkan pesan khusus', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier(adminUser)),
            issueFilterProvider.overrideWith(IssueFilterNotifier.new),
            issuesListProvider.overrideWith((ref) => {
                  'items': <OrderIssue>[],
                  'total': 0,
                }),
          ],
          child: const MaterialApp(
            home: IssuesListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap chip 'Milik Saya'
      await tester.tap(find.text('Milik Saya'));
      await tester.pumpAndSettle();

      // Memastikan teks khusus "Belum ada kendala yang ditugaskan kepadamu." tampil
      expect(find.text('Belum ada kendala yang ditugaskan kepadamu.'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Reset Filter'), findsOneWidget);
    });

    testWidgets('Respons items null dan [] sama-sama menampilkan empty state, bukan error', (tester) async {
      // 1. Uji respons items: null
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier(adminUser)),
            issuesListProvider.overrideWith((ref) => {
                  'items': null,
                  'total': 0,
                }),
          ],
          child: const MaterialApp(
            home: IssuesListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tidak melempar TypeError, tetap menampilkan empty state
      expect(find.text('Belum ada kendala yang cocok dengan filter ini'), findsOneWidget);
      expect(find.byType(ErrorView), findsNothing);
      expect(find.textContaining('TypeError'), findsNothing);
      expect(find.textContaining('Gagal'), findsNothing);
    });
  });

  group('Mode Pilih & Menu Cepat IssuesListScreen Tests (Permintaan Mode Pilih)', () {
    final adminUser = User(
      id: 1,
      nama: 'Sonny (Admin)',
      email: 'admin@kendalaku.com',
      role: 'admin',
    );

    final petugasUserOther = User(
      id: 3,
      nama: 'Budi Petugas (Non-Pemilik)',
      email: 'budi@kendalaku.com',
      role: 'petugas',
    );

    final testIssue1 = OrderIssue(
      id: 101,
      kodeKendala: 'ISS-001',
      judul: 'Paket rusak dalam perjalanan',
      deskripsi: 'Barang pecah belah retak',
      status: 'baru',
      prioritas: 'tinggi',
      tenggatAt: '2026-10-29T16:00:00Z',
      orderId: 1,
      kodePesanan: 'ORD-101',
      namaPelanggan: 'Budi Santoso',
      categoryId: 1,
      categoryNama: 'Pengiriman',
      categoryWarnaHex: '#2563EB',
      categoryIkon: 'local_shipping',
      assignedTo: 2, // Ditugaskan ke ID 2
      assignedNama: 'Rina Petugas',
      createdBy: 1,
      createdByNama: 'Sonny (Admin)',
      isArchived: false,
      createdAt: '2026-10-29T10:00:00Z',
      updatedAt: '2026-10-29T10:00:00Z',
      isOverdue: false,
    );

    final testIssue2 = OrderIssue(
      id: 102,
      kodeKendala: 'ISS-002',
      judul: 'Salah kirim varian',
      deskripsi: 'Warna barang tidak sesuai pesanan',
      status: 'proses',
      prioritas: 'sedang',
      tenggatAt: '2026-10-29T20:00:00Z',
      orderId: 2,
      kodePesanan: 'ORD-102',
      namaPelanggan: 'Siti Rahma',
      categoryId: 2,
      categoryNama: 'Produk',
      categoryWarnaHex: '#10B981',
      categoryIkon: 'inventory_2',
      assignedTo: 2,
      assignedNama: 'Rina Petugas',
      createdBy: 1,
      createdByNama: 'Sonny (Admin)',
      isArchived: false,
      createdAt: '2026-10-29T10:00:00Z',
      updatedAt: '2026-10-29T10:00:00Z',
      isOverdue: false,
    );

    testWidgets('1. Tombol "Pilih" mengaktifkan mode pilih tanpa long-press & berubah jadi "Selesai"', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier(adminUser)),
            issuesListProvider.overrideWith((ref) => {
                  'items': [testIssue1, testIssue2],
                  'total': 2,
                }),
          ],
          child: const MaterialApp(
            home: IssuesListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tombol Pilih hadir di baris Menampilkan N Kendala
      final pilihBtn = find.widgetWithText(TextButton, 'Pilih');
      expect(pilihBtn, findsOneWidget);
      expect(find.byIcon(Icons.checklist_rounded), findsOneWidget);
      expect(find.text('Menampilkan 2 Kendala'), findsOneWidget);

      // Tap tombol Pilih
      await tester.tap(pilihBtn);
      await tester.pumpAndSettle();

      // Mode pilih aktif: Tombol berubah jadi 'Selesai', ada tombol 'Pilih Semua', dan 'Batal'
      expect(find.widgetWithText(FilledButton, 'Selesai'), findsOneWidget);
      expect(find.text('Pilih Semua'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      expect(find.byType(Checkbox), findsWidgets);

      // Tap tombol Selesai untuk keluar dari mode pilih
      await tester.tap(find.widgetWithText(FilledButton, 'Selesai'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Selesai'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Pilih'), findsOneWidget);
    });

    testWidgets('2. Teks petunjuk menyesuaikan platform (Web/Desktop vs Mobile)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Platform Web/Desktop
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(() => _MockAuthNotifier(adminUser)),
              issuesListProvider.overrideWith((ref) => {
                    'items': [testIssue1],
                    'total': 1,
                  }),
            ],
            child: const MaterialApp(
              home: IssuesListScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text("Klik 'Pilih' untuk memilih beberapa kendala"), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }

      // Platform Mobile (Android)
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(() => _MockAuthNotifier(adminUser)),
              issuesListProvider.overrideWith((ref) => {
                    'items': [testIssue1],
                    'total': 1,
                  }),
            ],
            child: const MaterialApp(
              home: IssuesListScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text("Tekan lama untuk mode pilih"), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('3. Menu titik tiga muncul dan membuka menu cepat (admin melihat Ubah status, Pilih, Lihat pesanan, Bagikan)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier(adminUser)),
            issuesListProvider.overrideWith((ref) => {
                  'items': [testIssue1],
                  'total': 1,
                }),
          ],
          child: const MaterialApp(
            home: IssuesListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ikon titik tiga ada pada kartu
      final moreBtn = find.byTooltip('Menu Cepat');
      expect(moreBtn, findsOneWidget);

      await tester.tap(moreBtn);
      await tester.pumpAndSettle();

      // Menu cepat terbuka dengan semua aksi untuk admin
      expect(find.text('Ubah status'), findsOneWidget);
      expect(find.widgetWithText(PopupMenuItem<String>, 'Pilih'), findsOneWidget);
      expect(find.text('Lihat pesanan'), findsOneWidget);
      expect(find.text('Bagikan ke WhatsApp'), findsOneWidget);
    });

    testWidgets('4. Petugas non-pemilik TIDAK melihat "Ubah status" di menu titik tiga', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Petugas ID 3 membuka daftar yang memuat kendala milik Petugas ID 2
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier(petugasUserOther)),
            issuesListProvider.overrideWith((ref) => {
                  'items': [testIssue1],
                  'total': 1,
                }),
          ],
          child: const MaterialApp(
            home: IssuesListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Buka menu titik tiga
      final moreBtn = find.byTooltip('Menu Cepat');
      expect(moreBtn, findsOneWidget);
      await tester.tap(moreBtn);
      await tester.pumpAndSettle();

      // Aksi Ubah status tidak boleh muncul untuk petugas non-pemilik
      expect(find.text('Ubah status'), findsNothing);

      // Aksi lainnya tetap dapat diakses
      expect(find.widgetWithText(PopupMenuItem<String>, 'Pilih'), findsOneWidget);
      expect(find.text('Lihat pesanan'), findsOneWidget);
      expect(find.text('Bagikan ke WhatsApp'), findsOneWidget);
    });

    testWidgets('5. Tombol WhatsApp berlabel "Kirim hasil filter" saat kosong, dan "Kirim N terpilih" saat ada pilihan', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier(adminUser)),
            issuesListProvider.overrideWith((ref) => {
                  'items': [testIssue1, testIssue2],
                  'total': 2,
                }),
          ],
          child: const MaterialApp(
            home: IssuesListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Aktifkan mode pilih lewat tombol Pilih
      await tester.tap(find.widgetWithText(TextButton, 'Pilih'));
      await tester.pumpAndSettle();

      // Saat belum ada item terpilih: tombol berlabel "Kirim hasil filter"
      expect(find.text('Kirim hasil filter'), findsOneWidget);

      // Centang 1 item lewat kartu
      await tester.tap(find.text('Paket rusak dalam perjalanan'));
      await tester.pumpAndSettle();

      // Label berubah menjadi "Kirim 1 terpilih"
      expect(find.text('Kirim 1 terpilih'), findsOneWidget);
      expect(find.text('Kirim hasil filter'), findsNothing);

      // Centang item kedua
      await tester.tap(find.text('Salah kirim varian'));
      await tester.pumpAndSettle();

      // Label berubah menjadi "Kirim 2 terpilih"
      expect(find.text('Kirim 2 terpilih'), findsOneWidget);
    });

    testWidgets('6. Mode pilih dapat dikeluarkan dengan tombol Esc', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier(adminUser)),
            issuesListProvider.overrideWith((ref) => {
                  'items': [testIssue1],
                  'total': 1,
                }),
          ],
          child: const MaterialApp(
            home: IssuesListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Masuk ke mode pilih
      await tester.tap(find.widgetWithText(TextButton, 'Pilih'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Selesai'), findsOneWidget);

      // Kirim tombol Esc keyboard
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Mode pilih tertutup
      expect(find.widgetWithText(FilledButton, 'Selesai'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Pilih'), findsOneWidget);
    });

    testWidgets('7. Di Web/Desktop: checkbox muncul saat hover pada kartu, dan klik checkbox langsung mengaktifkan mode pilih', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(() => _MockAuthNotifier(adminUser)),
              issuesListProvider.overrideWith((ref) => {
                    'items': [testIssue1],
                    'total': 1,
                  }),
            ],
            child: const MaterialApp(
              home: IssuesListScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Sebelum hover: tidak ada checkbox
        expect(find.byType(Checkbox), findsNothing);

        // Arahkan kursor (hover) ke kartu
        final cardGesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await cardGesture.addPointer(location: Offset.zero);
        addTearDown(cardGesture.removePointer);
        await cardGesture.moveTo(tester.getCenter(find.text('Paket rusak dalam perjalanan')));
        await tester.pumpAndSettle();

        // Checkbox muncul karena hover pada web/desktop
        expect(find.byType(Checkbox), findsOneWidget);

        // Klik checkbox langsung mengaktifkan mode pilih dan mencentang kartu
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        // Mode pilih aktif dan kartu tercentang
        expect(find.widgetWithText(FilledButton, 'Selesai'), findsOneWidget);
        expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);
        expect(find.text('Kirim 1 terpilih'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
