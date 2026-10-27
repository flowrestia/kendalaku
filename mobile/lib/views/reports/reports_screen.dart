import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/web_download.dart';
import '../../providers/app_providers.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _isExporting = false;

  Future<void> _pickDateRange(BuildContext context) async {
    final rangeState = ref.read(reportDateRangeProvider);
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: rangeState.from != null && rangeState.to != null
          ? DateTimeRange(start: rangeState.from!, end: rangeState.to!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textMain,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(reportDateRangeProvider.notifier).setRange(picked.start, picked.end);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _isExporting = true);
    try {
      final range = ref.read(reportDateRangeProvider);
      final fromStr = range.from != null ? DateFormat('yyyy-MM-dd').format(range.from!) : null;
      final toStr = range.to != null ? DateFormat('yyyy-MM-dd').format(range.to!) : null;

      final repo = ref.read(repositoryProvider);
      final csvContent = await repo.exportReportCsv(from: fromStr, to: toStr);

      if (kIsWeb) {
        downloadCsvWeb(csvContent, 'laporan_kendala.csv');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Laporan CSV berhasil diunduh'),
            backgroundColor: AppColors.statusResolved,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor CSV: $e'),
            backgroundColor: AppColors.statusRejected,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(reportRecapProvider);
    final rangeState = ref.watch(reportDateRangeProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(reportRecapProvider);
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rekap & Laporan',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textMain),
                        ),
                        Text(
                          'Analitik berkala dan performa operasional',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _isExporting ? null : _exportCsv,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Ekspor CSV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Date Range Picker Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.date_range_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Rentang Waktu Laporan', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            Text(
                              rangeState.from != null && rangeState.to != null
                                  ? '${DateFormat('dd MMM yyyy').format(rangeState.from!)} - ${DateFormat('dd MMM yyyy').format(rangeState.to!)}'
                                  : 'Semua Periode (Keseluruhan Data)',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMain),
                            ),
                          ],
                        ),
                      ),
                      if (rangeState.from != null)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textMuted),
                          onPressed: () {
                            ref.read(reportDateRangeProvider.notifier).clear();
                          },
                        ),
                      OutlinedButton(
                        onPressed: () => _pickDateRange(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          side: const BorderSide(color: AppColors.primary),
                        ),
                        child: const Text('Ubah', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                reportAsync.when(
                  data: (recap) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Highlight Card Kategori Paling Sering
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.accentAmber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.trending_up_rounded, color: AppColors.accentAmber, size: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Kategori Masalah Paling Sering',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      recap.kategoriPalingSering ?? 'Tidak Ada',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Total Kasus', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                  Text(
                                    recap.totalKendala.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Rekap Status Global
                        const Text(
                          'Ringkasan Status Penanganan',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textMain),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildMiniStatusCard('Baru', recap.rekapStatus.baru, AppColors.statusNew, AppColors.statusNewBg),
                            const SizedBox(width: 8),
                            _buildMiniStatusCard('Proses', recap.rekapStatus.sedangDiproses, AppColors.statusProcessing, AppColors.statusProcessingBg),
                            const SizedBox(width: 8),
                            _buildMiniStatusCard('Menunggu', recap.rekapStatus.menungguInformasi, AppColors.statusWaiting, AppColors.statusWaitingBg),
                            const SizedBox(width: 8),
                            _buildMiniStatusCard('Selesai', recap.rekapStatus.selesai, AppColors.statusResolved, AppColors.statusResolvedBg),
                            const SizedBox(width: 8),
                            _buildMiniStatusCard('Ditolak', recap.rekapStatus.ditolak, AppColors.statusRejected, AppColors.statusRejectedBg),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Rincian per Kategori
                        const Text(
                          'Rincian per Kategori Masalah',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textMain),
                        ),
                        const SizedBox(height: 10),

                        if (recap.perKategori.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text('Tidak ada data pada periode ini'),
                            ),
                          )
                        else
                          ...recap.perKategori.map((kat) {
                            final color = AppColors.fromHex(kat.warnaHex);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.cardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 12,
                                            height: 12,
                                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            kat.nama,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${kat.total} Kasus',
                                          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Baru: ${kat.status.baru}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                      Text('Diproses: ${kat.status.sedangDiproses}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                      Text('Menunggu: ${kat.status.menungguInformasi}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                      Text('Selesai: ${kat.status.selesai}', style: const TextStyle(fontSize: 11, color: AppColors.statusResolved, fontWeight: FontWeight.bold)),
                                      Text('Ditolak: ${kat.status.ditolak}', style: const TextStyle(fontSize: 11, color: AppColors.statusRejected)),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.statusRejected),
                          const SizedBox(height: 10),
                          Text('Gagal memuat laporan: $err', style: const TextStyle(color: AppColors.statusRejected)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => ref.invalidate(reportRecapProvider),
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStatusCard(String label, int val, Color fg, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fg.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
            const SizedBox(height: 4),
            Text(val.toString(), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg)),
          ],
        ),
      ),
    );
  }
}
