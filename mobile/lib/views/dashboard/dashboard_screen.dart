import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/icon_util.dart';
import '../../data/models/models.dart';
import '../../providers/app_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final categoriesAsync = ref.watch(dashboardCategoryStatsProvider);
    final trendAsync = ref.watch(dashboardTrendProvider);
    final trendPeriod = ref.watch(dashboardTrendPeriodProvider);
    final issuesAsync = ref.watch(issuesListProvider);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.backgroundGradientStart,
              AppColors.backgroundLight,
              AppColors.backgroundGradientEnd,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardSummaryProvider);
              ref.invalidate(dashboardCategoryStatsProvider);
              ref.invalidate(dashboardTrendProvider);
              ref.invalidate(issuesListProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header Gradient dengan Sapaan Personal & Perhatian
                  _buildHeader(context, authState.user, summaryAsync),

                  const SizedBox(height: 16),

                  // 2. Kartu Ringkasan Status & Metrik
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: summaryAsync.when(
                      data: (summary) => _buildSummaryCards(context, summary),
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (err, _) => _buildErrorCard(
                        'Gagal memuat ringkasan',
                        () => ref.invalidate(dashboardSummaryProvider),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Donut Chart Distribusi Kategori
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildCategoryDistributionCard(context, categoriesAsync),
                  ),

                  const SizedBox(height: 24),

                  // 4. Grafik Tren Masuk vs Selesai (7d, 30d, 12m)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildTrendChartCard(context, ref, trendAsync, trendPeriod),
                  ),

                  const SizedBox(height: 24),

                  // 5. Daftar Perlu Perhatian (Terlambat & Kritis)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildAttentionListCard(context, issuesAsync),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, User? user, AsyncValue<DashboardSummary> summaryAsync) {
    final attentionCount = summaryAsync.maybeWhen(
      data: (s) => s.terlambat + s.baru,
      orElse: () => 0,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3730A3), Color(0xFF4F46E5), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Dekoratif Pattern Bulatan Abstrak
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -30,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentCyan.withValues(alpha: 0.12),
              ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Beranda KendalaKu',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            user != null ? 'Selamat bertugas, ${user.nama} (${user.role})' : 'Pusat Kontrol Penanganan Kendala',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Attention Banner Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.accentAmber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        attentionCount > 0
                            ? '$attentionCount kendala butuh perhatian segera (terlambat / baru).'
                            : 'Operasional lancar! Tidak ada kendala mendesak.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, DashboardSummary summary) {
    return Column(
      children: [
        // Baris 1: Total & Terlambat
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Total Kendala',
                value: summary.total,
                icon: Icons.layers_rounded,
                accentColor: AppColors.primary,
                bgColor: AppColors.primaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                title: 'Terlambat SLA',
                value: summary.terlambat,
                icon: Icons.alarm_rounded,
                accentColor: AppColors.statusRejected,
                bgColor: AppColors.statusRejectedBg,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Baris 2: Baru, Diproses, Selesai
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Baru',
                value: summary.baru,
                icon: Icons.fiber_new_rounded,
                accentColor: AppColors.statusNew,
                bgColor: AppColors.statusNewBg,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                title: 'Diproses',
                value: summary.sedangDiproses,
                icon: Icons.autorenew_rounded,
                accentColor: AppColors.statusProcessing,
                bgColor: AppColors.statusProcessingBg,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricCard(
                title: 'Selesai',
                value: summary.selesai,
                icon: Icons.check_circle_rounded,
                accentColor: AppColors.statusResolved,
                bgColor: AppColors.statusResolvedBg,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Baris 3: Efisiensi (Rata-rata waktu & Tingkat Selesai)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  const Text('Rata-rata Penyelesaian', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined, size: 18, color: AppColors.accentTeal),
                      const SizedBox(width: 6),
                      Text(
                        '${summary.rataRataWaktuJam.toStringAsFixed(1)} Jam',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textMain),
                      ),
                    ],
                  ),
                ],
              ),
              Container(width: 1, height: 36, color: AppColors.cardBorder),
              Column(
                children: [
                  const Text('Tingkat Terselesaikan', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pie_chart_outline_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${summary.persentaseSelesai.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required int value,
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Animasi Angka Naik
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 900),
                  tween: Tween(begin: 0.0, end: value.toDouble()),
                  curve: Curves.easeOutQuart,
                  builder: (context, val, _) {
                    return Text(
                      val.toInt().toString(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        letterSpacing: -0.5,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDistributionCard(BuildContext context, AsyncValue<List<CategoryStat>> categoriesAsync) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Distribusi Kategori Kendala',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textMain),
              ),
              Icon(Icons.pie_chart_rounded, size: 20, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 16),
          categoriesAsync.when(
            data: (cats) {
              if (cats.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Belum ada data kategori', style: TextStyle(color: AppColors.textMuted)),
                  ),
                );
              }

              final sections = cats.map((c) {
                final color = AppColors.fromHex(c.warnaHex);
                return PieChartSectionData(
                  color: color,
                  value: c.total.toDouble(),
                  title: '${c.persentase.toStringAsFixed(0)}%',
                  radius: 40,
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList();

              return Column(
                children: [
                  SizedBox(
                    height: 160,
                    child: PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 40,
                        sectionsSpace: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: cats.map((c) {
                      final color = AppColors.fromHex(c.warnaHex);
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${c.nama} (${c.total})',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMain),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              );
            },
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (err, _) => Center(child: Text('Gagal memuat kategori: $err', style: const TextStyle(color: AppColors.statusRejected))),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChartCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<TrendPoint>> trendAsync,
    String period,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tren Kendala',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textMain),
                  ),
                  Text('Masuk vs Terselesaikan', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
              // Segmented Button Pilihan Periode
              Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: ['7d', '30d', '12m'].map((p) {
                    final isSel = period == p;
                    final label = p == '7d' ? '7 Hari' : (p == '30d' ? '30 Hari' : '12 Bln');
                    return InkWell(
                      onTap: () => ref.read(dashboardTrendPeriodProvider.notifier).setPeriod(p),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isSel ? Colors.white : AppColors.textMuted,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          trendAsync.when(
            data: (trend) {
              if (trend.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Data tren belum tersedia', style: TextStyle(color: AppColors.textMuted)),
                  ),
                );
              }

              final masukSpots = <FlSpot>[];
              final selesaiSpots = <FlSpot>[];
              double maxY = 5.0;

              for (var i = 0; i < trend.length; i++) {
                final pt = trend[i];
                final ym = pt.totalMasuk.toDouble();
                final ys = pt.totalSelesai.toDouble();
                masukSpots.add(FlSpot(i.toDouble(), ym));
                selesaiSpots.add(FlSpot(i.toDouble(), ys));
                if (ym > maxY) maxY = ym;
                if (ys > maxY) maxY = ys;
              }

              return Column(
                children: [
                  SizedBox(
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        maxY: maxY + 2,
                        minY: 0,
                        gridData: const FlGridData(show: true, drawVerticalLine: false),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
                              getTitlesWidget: (val, meta) {
                                final idx = val.toInt();
                                if (idx >= 0 && idx < trend.length) {
                                  // Tampilkan label interval agar tidak berhimpitan
                                  if (trend.length <= 7 || idx % 2 == 0) {
                                    final raw = trend[idx].label;
                                    final parts = raw.split('-');
                                    final short = parts.length >= 3 ? '${parts[2]}/${parts[1]}' : raw;
                                    return Text(short, style: const TextStyle(fontSize: 9, color: AppColors.textMuted));
                                  }
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: masukSpots,
                            isCurved: true,
                            color: AppColors.primary,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                          ),
                          LineChartBarData(
                            spots: selesaiSpots,
                            isCurved: true,
                            color: AppColors.statusResolved,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 12, height: 3, color: AppColors.primary),
                      const SizedBox(width: 6),
                      const Text('Total Masuk', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                      const SizedBox(width: 20),
                      Container(width: 12, height: 3, color: AppColors.statusResolved),
                      const SizedBox(width: 6),
                      const Text('Total Selesai', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                    ],
                  ),
                ],
              );
            },
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (err, _) => Center(child: Text('Gagal: $err', style: const TextStyle(color: AppColors.statusRejected))),
          ),
        ],
      ),
    );
  }

  Widget _buildAttentionListCard(BuildContext context, AsyncValue<Map<String, dynamic>> issuesAsync) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.priority_high_rounded, color: AppColors.priorityCritical, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Perlu Perhatian (Terlambat & Kritis)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textMain),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => context.go('/issues'),
                child: const Text('Lihat Semua', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          issuesAsync.when(
            data: (res) {
              final all = res['items'] as List<OrderIssue>? ?? [];
              final urgent = all.where((it) => it.isOverdue || it.prioritas == 'kritis' || it.prioritas == 'tinggi').take(4).toList();

              if (urgent.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  child: const Text(
                    'Tidak ada kendala yang melewati tenggat atau berkategori kritis.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return Column(
                children: urgent.map((issue) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: issue.isOverdue
                            ? AppColors.statusRejected.withValues(alpha: 0.3)
                            : AppColors.cardBorder,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        title: Text(
                          issue.judul,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${issue.kodeKendala} • ${issue.namaPelanggan}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                        trailing: issue.isOverdue
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.statusRejectedBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'TERLAMBAT',
                                  style: TextStyle(
                                    color: AppColors.statusRejected,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.priorityCritical.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  IconUtil.getPriorityLabel(issue.prioritas),
                                  style: const TextStyle(
                                    color: AppColors.priorityCritical,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                        onTap: () => context.push('/issues/${issue.id}'),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (err, _) => Text('Gagal: $err', style: const TextStyle(color: AppColors.statusRejected)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String msg, VoidCallback onRetry) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.statusRejected.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.statusRejected, size: 36),
          const SizedBox(height: 8),
          Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.statusRejected)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }
}
