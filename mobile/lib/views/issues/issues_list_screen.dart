import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';
import '../../providers/app_providers.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/issue_card.dart';
import '../widgets/status_transition_modal.dart';

class IssuesListScreen extends ConsumerStatefulWidget {
  const IssuesListScreen({super.key});

  @override
  ConsumerState<IssuesListScreen> createState() => _IssuesListScreenState();
}

class _IssuesListScreenState extends ConsumerState<IssuesListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FilterBottomSheet(),
    );
  }

  void _openTransitionModal(OrderIssue issue) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatusTransitionModal(
        currentStatus: issue.status,
        onSubmit: (nextStatus, tindakan, penyelesaian) async {
          final repo = ref.read(repositoryProvider);
          await repo.transitionStatus(
            id: issue.id,
            statusBaru: nextStatus,
            catatanTindakan: tindakan,
            catatanPenyelesaian: penyelesaian,
          );
          ref.invalidate(issuesListProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Status kendala ${issue.kodeKendala} berhasil diubah ke $nextStatus'),
                backgroundColor: AppColors.statusResolved,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final issuesAsync = ref.watch(issuesListProvider);
    final filter = ref.watch(issueFilterProvider);
    final authState = ref.watch(authProvider);

    final hasActiveFilters = filter.status != null ||
        filter.prioritas != null ||
        filter.categoryId != null ||
        (filter.isOverdue ?? false);

    final userId = authState.user?.id;
    final isSemuaActive = filter.status == null &&
        filter.prioritas == null &&
        (filter.isOverdue == null || filter.isOverdue == false) &&
        filter.assignedTo == null;
    final isOverdueActive = filter.isOverdue == true;
    final isHighPriorityActive = filter.prioritas == 'tinggi,kritis';
    final isMyIssuesActive = userId != null && filter.assignedTo == userId;

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
              ref.invalidate(issuesListProvider);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header dengan Elemen Dekoratif Halus (Blob / Pola Lembut)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorder.withValues(alpha: 0.7)),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Dekorasi Blob Aksen Halus di Latar Belakang Header
                      Positioned(
                        right: -10,
                        top: -10,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.primaryLight.withValues(alpha: 0.12),
                                AppColors.accentCyan.withValues(alpha: 0.04),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 45,
                        bottom: -15,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.accentAmber.withValues(alpha: 0.12),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
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
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [AppColors.primary, AppColors.primaryLight],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(alpha: 0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.assignment_late_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'KendalaKu',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18,
                                          color: AppColors.primaryDark,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      Text(
                                        authState.user != null ? 'Halo, ${authState.user!.nama}' : 'Daftar Kendala Pesanan',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: hasActiveFilters
                                          ? AppColors.primaryContainer
                                          : AppColors.backgroundLight,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Icon(
                                          Icons.tune_rounded,
                                          size: 20,
                                          color: hasActiveFilters ? AppColors.primary : AppColors.textMain,
                                        ),
                                        if (hasActiveFilters)
                                          Positioned(
                                            right: -2,
                                            top: -2,
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: AppColors.accentAmber,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    tooltip: 'Filter Detail',
                                    onPressed: _openFilter,
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppColors.backgroundLight,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.logout_rounded, size: 20, color: AppColors.textMuted),
                                    tooltip: 'Keluar',
                                    onPressed: () async {
                                      await ref.read(authProvider.notifier).logout();
                                      if (context.mounted) context.go('/login');
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Search Bar
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Cari kode, judul, atau invoice...',
                              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
                              fillColor: AppColors.backgroundLight,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        ref.read(issueFilterProvider.notifier).updateFilter((s) => s.copyWith(search: ''));
                                      },
                                    )
                                  : null,
                            ),
                            onSubmitted: (val) {
                              ref.read(issueFilterProvider.notifier).updateFilter((s) => s.copyWith(search: val.trim()));
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Chip Filter Cepat di Bawah Kolom Pencarian
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildQuickFilterChip(
                        label: 'Semua',
                        icon: Icons.grid_view_rounded,
                        isSelected: isSemuaActive,
                        onTap: () {
                          ref.read(issueFilterProvider.notifier).reset();
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildQuickFilterChip(
                        label: 'Terlambat',
                        icon: Icons.alarm_rounded,
                        accentColor: AppColors.statusRejected,
                        isSelected: isOverdueActive,
                        onTap: () {
                          if (isOverdueActive) {
                            ref.read(issueFilterProvider.notifier).updateFilter((s) => s.copyWith(clearOverdue: true));
                          } else {
                            ref.read(issueFilterProvider.notifier).updateFilter((s) => s.copyWith(isOverdue: true));
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildQuickFilterChip(
                        label: 'Prioritas Tinggi/Kritis',
                        icon: Icons.local_fire_department_rounded,
                        accentColor: AppColors.priorityCritical,
                        isSelected: isHighPriorityActive,
                        onTap: () {
                          if (isHighPriorityActive) {
                            ref.read(issueFilterProvider.notifier).updateFilter((s) => s.copyWith(clearPrioritas: true));
                          } else {
                            ref.read(issueFilterProvider.notifier).updateFilter((s) => s.copyWith(prioritas: 'tinggi,kritis'));
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildQuickFilterChip(
                        label: 'Milik Saya',
                        icon: Icons.person_rounded,
                        accentColor: AppColors.accentTeal,
                        isSelected: isMyIssuesActive,
                        onTap: () {
                          if (userId == null) return;
                          if (isMyIssuesActive) {
                            ref.read(issueFilterProvider.notifier).updateFilter((s) => s.copyWith(clearAssigned: true));
                          } else {
                            ref.read(issueFilterProvider.notifier).updateFilter((s) => s.copyWith(assignedTo: userId));
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // Active Filters Secondary Bar (jika filter detail spesifik aktif)
                if (hasActiveFilters && !isSemuaActive) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        if (filter.status != null)
                          _buildFilterChip('Status: ${filter.status}', () {
                            ref.read(issueFilterProvider.notifier).updateFilter((s) => s.copyWith(clearStatus: true));
                          }),
                        if (filter.prioritas != null && filter.prioritas != 'tinggi,kritis')
                          _buildFilterChip('Prioritas: ${filter.prioritas}', () {
                            ref.read(issueFilterProvider.notifier).updateFilter((s) => s.copyWith(clearPrioritas: true));
                          }),
                        if (filter.categoryId != null)
                          _buildFilterChip('Kategori Terpilih', () {
                            ref.read(issueFilterProvider.notifier).updateFilter((s) => s.copyWith(clearCategory: true));
                          }),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 6),

                // Issues List Content
                Expanded(
                  child: issuesAsync.when(
                    data: (res) {
                      final items = res['items'] as List<OrderIssue>;
                      final total = res['total'] as int? ?? items.length;

                      if (items.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.inbox_rounded, size: 40, color: AppColors.primary),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Tidak Ada Kendala',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textMain),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Tidak ada data kendala yang sesuai dengan filter atau kata kunci pencarian Anda.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Menampilkan $total Kendala',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const Text(
                                  'Geser / tekan lama untuk aksi cepat',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final issue = items[index];
                                final delayMs = (index * 40).clamp(0, 400);

                                return TweenAnimationBuilder<double>(
                                  duration: Duration(milliseconds: 300 + delayMs),
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, value, child) {
                                    return Opacity(
                                      opacity: value,
                                      child: Transform.translate(
                                        offset: Offset(0, 16 * (1 - value)),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: IssueCard(
                                    issue: issue,
                                    onTap: () {
                                      context.push('/issues/${issue.id}');
                                    },
                                    onQuickAction: () {
                                      _openTransitionModal(issue);
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.statusRejected, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'Gagal Memuat Kendala: $err',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.statusRejected),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => ref.invalidate(issuesListProvider),
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('+ Lapor Kendala', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          context.push('/issues/create');
        },
      ),
    );
  }

  Widget _buildQuickFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    Color accentColor = AppColors.primary,
  }) {
    final bgActive = accentColor;
    final fgActive = Colors.white;
    final bgInactive = Colors.white;
    final fgInactive = AppColors.textMain;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? bgActive : bgInactive,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? accentColor : AppColors.cardBorder.withValues(alpha: 0.8),
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? fgActive : accentColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? fgActive : fgInactive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        deleteIcon: const Icon(Icons.close, size: 14),
        onDeleted: onRemove,
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}
