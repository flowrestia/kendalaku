import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/error_mapper.dart';
import '../../core/utils/web_download.dart';
import '../../providers/app_providers.dart';
import '../widgets/error_view.dart';

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
            content: Text(ErrorMapper.getMessage(e)),
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

    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rekap & Laporan',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.getTextMain(context),
                          ),
                        ),
                        Text(
                          'Analitik berkala dan performa operasional',
                          style: TextStyle(fontSize: 12, color: AppColors.getTextMuted(context)),
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
                    color: AppColors.getCardColor(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.getCardBorder(context)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.date_range_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Rentang Waktu Laporan', style: TextStyle(fontSize: 11, color: AppColors.getTextMuted(context))),
                            Text(
                              rangeState.from != null && rangeState.to != null
                                  ? '${DateFormat('dd MMM yyyy').format(rangeState.from!)} - ${DateFormat('dd MMM yyyy').format(rangeState.to!)}'
                                  : 'Semua Periode (Keseluruhan Data)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.getTextMain(context)),
                            ),
                          ],
                        ),
                      ),
                      if (rangeState.from != null)
                        IconButton(
                          icon: Icon(Icons.clear_rounded, size: 18, color: AppColors.getTextMuted(context)),
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
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                                  : [const Color(0xFF0F172A), const Color(0xFF1E293B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.getCardBorder(context)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
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
                        Text(
                          'Ringkasan Status Penanganan',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.getTextMain(context)),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _buildMiniStatusCard('Baru', recap.rekapStatus.baru, AppColors.statusNew, isDark ? AppColors.statusNew.withValues(alpha: 0.15) : AppColors.statusNewBg),
                            const SizedBox(width: 8),
                            _buildMiniStatusCard('Proses', recap.rekapStatus.sedangDiproses, AppColors.statusProcessing, isDark ? AppColors.statusProcessing.withValues(alpha: 0.15) : AppColors.statusProcessingBg),
                            const SizedBox(width: 8),
                            _buildMiniStatusCard('Menunggu', recap.rekapStatus.menungguInformasi, AppColors.statusWaiting, isDark ? AppColors.statusWaiting.withValues(alpha: 0.15) : AppColors.statusWaitingBg),
                            const SizedBox(width: 8),
                            _buildMiniStatusCard('Selesai', recap.rekapStatus.selesai, AppColors.statusResolved, isDark ? AppColors.statusResolved.withValues(alpha: 0.15) : AppColors.statusResolvedBg),
                            const SizedBox(width: 8),
                            _buildMiniStatusCard('Ditolak', recap.rekapStatus.ditolak, AppColors.statusRejected, isDark ? AppColors.statusRejected.withValues(alpha: 0.15) : AppColors.statusRejectedBg),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Rincian per Kategori
                        Text(
                          'Rincian per Kategori Masalah',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.getTextMain(context)),
                        ),
                        const SizedBox(height: 10),

                        if (recap.perKategori.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text('Tidak ada data pada periode ini', style: TextStyle(color: AppColors.getTextMuted(context))),
                            ),
                          )
                        else
                          ...recap.perKategori.map((kat) {
                            final color = AppColors.fromHex(kat.warnaHex);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.getCardColor(context),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.getCardBorder(context)),
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
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: AppColors.getTextMain(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${kat.total} Kasus',
                                          style: TextStyle(
                                            color: isDark ? Colors.white : color,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Baru: ${kat.status.baru}', style: TextStyle(fontSize: 11, color: AppColors.getTextMuted(context))),
                                      Text('Diproses: ${kat.status.sedangDiproses}', style: TextStyle(fontSize: 11, color: AppColors.getTextMuted(context))),
                                      Text('Menunggu: ${kat.status.menungguInformasi}', style: TextStyle(fontSize: 11, color: AppColors.getTextMuted(context))),
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
                  error: (err, _) => ErrorView.fromException(
                    error: err,
                    onRetry: () => ref.invalidate(reportRecapProvider),
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
