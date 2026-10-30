import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/models.dart';
import '../../providers/app_providers.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/issue_card.dart';
import '../widgets/status_transition_modal.dart';
import '../widgets/whatsapp_preview_sheet.dart';
import '../widgets/error_view.dart';

class IssuesListScreen extends ConsumerStatefulWidget {
  const IssuesListScreen({super.key});

  @override
  ConsumerState<IssuesListScreen> createState() => _IssuesListScreenState();
}

class _IssuesListScreenState extends ConsumerState<IssuesListScreen> {
  final _searchController = TextEditingController();
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};
  int? _lastSelectedIndex;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openWhatsAppShare() {
    final activeFilter = ref.read(issueFilterProvider);
    WhatsAppPreviewSheet.show(
      context,
      selectedIds: _isSelectionMode && _selectedIds.isNotEmpty ? _selectedIds.toList() : null,
      activeFilter: activeFilter,
    );
  }

  void _toggleSelectAll(List<OrderIssue> items) {
    setState(() {
      if (_selectedIds.length == items.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(items.map((e) => e.id));
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
      _lastSelectedIndex = null;
    });
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
    final isMyIssuesActive = filter.assignedTo == 'me' || (userId != null && filter.assignedTo == userId);

    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            if (_isSelectionMode) {
              _exitSelectionMode();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: AppColors.getBackgroundGradient(context),
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
                    color: AppColors.getCardColor(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.getCardBorder(context).withValues(alpha: 0.7)),
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
                                      Text(
                                        'KendalaKu',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18,
                                          color: isDark ? Colors.white : AppColors.primaryDark,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      Text(
                                        authState.user != null ? 'Halo, ${authState.user!.nama}' : 'Daftar Kendala Pesanan',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.getTextMuted(context),
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
                                      backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.share_rounded, size: 20, color: Color(0xFF1EBE5D)),
                                    tooltip: 'Kirim ke WhatsApp',
                                    onPressed: _openWhatsAppShare,
                                  ),
                                  const SizedBox(width: 6),
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
                                      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.backgroundLight,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: Icon(Icons.logout_rounded, size: 20, color: AppColors.getTextMuted(context)),
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
                            style: TextStyle(color: AppColors.getTextMain(context)),
                            decoration: InputDecoration(
                              hintText: 'Cari kode, judul, atau invoice...',
                              hintStyle: TextStyle(
                                color: isDark ? Colors.white54 : AppColors.textMuted,
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                size: 20,
                                color: isDark ? Colors.white70 : AppColors.textMuted,
                              ),
                              fillColor: isDark ? const Color(0xFF131D31) : AppColors.backgroundLight,
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear_rounded,
                                        size: 18,
                                        color: isDark ? Colors.white70 : AppColors.textMuted,
                                      ),
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
                          if (isMyIssuesActive) {
                            ref.read(issueFilterProvider.notifier).updateFilter((s) => s.copyWith(clearAssigned: true));
                          } else {
                            ref.read(issueFilterProvider.notifier).updateFilter((s) => s.copyWith(assignedTo: 'me'));
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
                      final items = (res['items'] as List<OrderIssue>?) ?? const [];
                      final total = res['total'] as int? ?? items.length;

                      if (items.isEmpty) {
                        final emptyText = isMyIssuesActive
                            ? 'Belum ada kendala yang ditugaskan kepadamu.'
                            : 'Belum ada kendala yang cocok dengan filter ini';

                        return Center(
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
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
                                Text(
                                  emptyText,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.getTextMain(context),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(issueFilterProvider.notifier).reset();
                                  },
                                  icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                                  label: const Text('Reset Filter'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(color: AppColors.primary),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final isWebOrDesktop = kIsWeb ||
                          defaultTargetPlatform == TargetPlatform.windows ||
                          defaultTargetPlatform == TargetPlatform.macOS ||
                          defaultTargetPlatform == TargetPlatform.linux;

                      final hintText = isWebOrDesktop
                          ? "Klik 'Pilih' untuk memilih beberapa kendala"
                          : "Tekan lama untuk mode pilih";

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (_isSelectionMode)
                                  Row(
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _toggleSelectAll(items),
                                        icon: Icon(
                                          _selectedIds.length == items.length && items.isNotEmpty
                                              ? Icons.check_box_rounded
                                              : Icons.check_box_outline_blank_rounded,
                                          size: 18,
                                          color: AppColors.primary,
                                        ),
                                        label: Text(
                                          _selectedIds.length == items.length && items.isNotEmpty
                                              ? 'Batal Pilih Semua'
                                              : 'Pilih Semua',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Text(
                                        '(${_selectedIds.length} dipilih)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    children: [
                                      Text(
                                        'Menampilkan $total Kendala',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _isSelectionMode = true;
                                          });
                                        },
                                        icon: const Icon(Icons.checklist_rounded, size: 16),
                                        label: const Text('Pilih'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          minimumSize: const Size(0, 32),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (_isSelectionMode)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextButton(
                                        onPressed: _exitSelectionMode,
                                        child: const Text('Batal', style: TextStyle(fontSize: 12, color: AppColors.statusRejected)),
                                      ),
                                      const SizedBox(width: 4),
                                      FilledButton.icon(
                                        onPressed: _exitSelectionMode,
                                        icon: const Icon(Icons.check_rounded, size: 14),
                                        label: const Text('Selesai'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          minimumSize: const Size(0, 32),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Flexible(
                                    child: Text(
                                      hintText,
                                      textAlign: TextAlign.end,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                        fontStyle: FontStyle.italic,
                                      ),
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
                                final isSelected = _selectedIds.contains(issue.id);
                                final currentUser = authState.user;
                                final isAdmin = currentUser?.role == 'admin';
                                final isAssignedToMe = currentUser != null && issue.assignedTo == currentUser.id;
                                final canModify = isAdmin || isAssignedToMe;

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
                                    isSelectionMode: _isSelectionMode,
                                    isSelected: isSelected,
                                    canModify: canModify,
                                    onToggleSelect: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _isSelectionMode = true;
                                          _selectedIds.add(issue.id);
                                        } else {
                                          _selectedIds.remove(issue.id);
                                        }
                                      });
                                    },
                                    onTap: () {
                                      if (_isSelectionMode) {
                                        final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
                                        setState(() {
                                          if (isShiftPressed && _lastSelectedIndex != null) {
                                            final start = _lastSelectedIndex! < index ? _lastSelectedIndex! : index;
                                            final end = _lastSelectedIndex! > index ? _lastSelectedIndex! : index;
                                            for (int i = start; i <= end; i++) {
                                              _selectedIds.add(items[i].id);
                                            }
                                          } else {
                                            if (isSelected) {
                                              _selectedIds.remove(issue.id);
                                            } else {
                                              _selectedIds.add(issue.id);
                                            }
                                          }
                                          _lastSelectedIndex = index;
                                        });
                                      } else {
                                        context.push('/issues/${issue.id}');
                                      }
                                    },
                                    onQuickAction: () {
                                      if (!_isSelectionMode) {
                                        setState(() {
                                          _isSelectionMode = true;
                                          _selectedIds.add(issue.id);
                                        });
                                      } else {
                                        _openTransitionModal(issue);
                                      }
                                    },
                                    onOpenTransitionModal: () => _openTransitionModal(issue),
                                    onViewOrder: () => context.push('/issues/${issue.id}'),
                                    onShareWhatsApp: () => WhatsAppPreviewSheet.show(
                                      context,
                                      singleIssue: issue,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => ErrorView.fromException(
                      error: err,
                      onRetry: () => ref.invalidate(issuesListProvider),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
      bottomNavigationBar: _isSelectionMode
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.getCardColor(context),
                border: Border(
                  top: BorderSide(
                    color: AppColors.getCardBorder(context).withValues(alpha: 0.8),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _openWhatsAppShare,
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: Text(
                          _selectedIds.isNotEmpty
                              ? 'Kirim ${_selectedIds.length} terpilih'
                              : 'Kirim hasil filter',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1EBE5D),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton.extended(
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
    final isDark = AppColors.isDark(context);
    final bgActive = accentColor;
    final fgActive = Colors.white;
    final bgInactive = AppColors.getCardColor(context);
    final fgInactive = AppColors.getTextMain(context);

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
              color: isSelected ? accentColor : AppColors.getCardBorder(context).withValues(alpha: 0.8),
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
                color: isSelected ? fgActive : (isDark ? Colors.white70 : accentColor),
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
