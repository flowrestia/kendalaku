import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_util.dart';
import '../../core/utils/icon_util.dart';
import '../../core/utils/error_mapper.dart';
import '../../data/models/models.dart';
import '../../providers/app_providers.dart';
import '../widgets/badges.dart';
import '../widgets/error_view.dart';
import '../widgets/reassign_modal.dart';
import '../widgets/status_transition_modal.dart';
import '../widgets/whatsapp_preview_sheet.dart';

class IssueDetailScreen extends ConsumerStatefulWidget {
  final int issueId;

  const IssueDetailScreen({super.key, required this.issueId});

  @override
  ConsumerState<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends ConsumerState<IssueDetailScreen> {
  final _commentController = TextEditingController();
  bool _isSendingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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
          try {
            await repo.transitionStatus(
              id: issue.id,
              statusBaru: nextStatus,
              catatanTindakan: tindakan,
              catatanPenyelesaian: penyelesaian,
            );
            ref.invalidate(issueDetailProvider(widget.issueId));
            ref.invalidate(issueTransitionsProvider(widget.issueId));
            ref.invalidate(issueCommentsProvider(widget.issueId));
            ref.invalidate(issuesListProvider);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Status berhasil diubah menjadi: $nextStatus'),
                  backgroundColor: AppColors.statusResolved,
                ),
              );
            }
          } catch (err) {
            final msg = ErrorMapper.getMessage(err);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(msg),
                  backgroundColor: AppColors.statusRejected,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _openReassignModal(OrderIssue issue) {
    ReassignModal.show(
      context,
      issue: issue,
      onSuccess: () {
        ref.invalidate(issueDetailProvider(widget.issueId));
        ref.invalidate(issueCommentsProvider(widget.issueId));
        ref.invalidate(issuesListProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kendala berhasil dialihkan ke petugas lain'),
            backgroundColor: AppColors.statusResolved,
          ),
        );
      },
    );
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSendingComment = true);
    try {
      final repo = ref.read(repositoryProvider);
      await repo.addComment(widget.issueId, text);
      _commentController.clear();
      ref.invalidate(issueCommentsProvider(widget.issueId));
      if (mounted) {
        FocusScope.of(context).unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Komentar berhasil ditambahkan'),
            backgroundColor: AppColors.statusResolved,
            duration: Duration(seconds: 2),
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
      if (mounted) {
        setState(() => _isSendingComment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final issueAsync = ref.watch(issueDetailProvider(widget.issueId));
    final transitionsAsync = ref.watch(issueTransitionsProvider(widget.issueId));
    final commentsAsync = ref.watch(issueCommentsProvider(widget.issueId));
    final authState = ref.watch(authProvider);
    final currentUser = authState.user;
    final isAdmin = currentUser?.role == 'admin';

    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Detail Kendala'),
        actions: [
          issueAsync.when(
            data: (issue) {
              final isAssignedToMe = currentUser != null && issue.assignedTo == currentUser.id;
              final canModify = isAdmin || isAssignedToMe;
              final isDone = issue.status == 'selesai' || issue.status == 'ditolak';

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tombol WhatsApp
                  IconButton(
                    icon: const Icon(Icons.share_rounded, color: Color(0xFF1EBE5D)),
                    tooltip: 'Bagikan ke WhatsApp',
                    onPressed: () => WhatsAppPreviewSheet.show(
                      context,
                      singleIssue: issue,
                    ),
                  ),
                  // Tombol Pindahkan ke Petugas Lain (Khusus Admin)
                  if (isAdmin && !isDone)
                    IconButton(
                      icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary),
                      tooltip: 'Pindahkan ke Petugas Lain',
                      onPressed: () => _openReassignModal(issue),
                    ),
                  // Tombol Ubah Status
                  if (!isDone && canModify)
                    TextButton.icon(
                      icon: const Icon(Icons.swap_horiz_rounded, size: 20, color: AppColors.primary),
                      label: const Text('Ubah Status', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      onPressed: () => _openTransitionModal(issue),
                    ),
                ],
              );
            },
            loading: () => const SizedBox(),
            error: (_, _) => const SizedBox(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: issueAsync.when(
        data: (issue) {
          final isDone = issue.status == 'selesai' || issue.status == 'ditolak';
          final isAssignedToMe = currentUser != null && issue.assignedTo == currentUser.id;
          final canModify = isAdmin || isAssignedToMe;

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(issueDetailProvider(widget.issueId));
                    ref.invalidate(issueTransitionsProvider(widget.issueId));
                    ref.invalidate(issueCommentsProvider(widget.issueId));
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Banner Peringatan Hak Akses Petugas jika kendala bukan miliknya
                        if (!canModify && !isDone) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lock_outline_rounded, color: Color(0xFFF59E0B), size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Anda sedang melihat kendala petugas lain. Aksi ubah status dinonaktifkan.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Header Status & Judul
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.getCardColor(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.getCardBorder(context)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    issue.kodeKendala,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  StatusBadge(status: issue.status),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                issue.judul,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.getTextMain(context),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                issue.deskripsi,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.getTextMuted(context),
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Divider(color: AppColors.getCardBorder(context)),
                              const SizedBox(height: 12),

                              // Badges Row
                              Row(
                                children: [
                                  PriorityBadge(prioritas: issue.prioritas),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.fromHex(issue.categoryWarnaHex).withValues(alpha: isDark ? 0.22 : 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          IconUtil.getIcon(issue.categoryIkon),
                                          size: 13,
                                          color: AppColors.fromHex(issue.categoryWarnaHex),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          issue.categoryNama,
                                          style: TextStyle(
                                            color: AppColors.fromHex(issue.categoryWarnaHex),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // SLA & Assigned Petugas Card
                        Container(
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
                                  Text(
                                    'Pelaporan & Penugasan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.getTextMain(context),
                                    ),
                                  ),
                                  if (isAdmin && !isDone)
                                    InkWell(
                                      onTap: () => _openReassignModal(issue),
                                      borderRadius: BorderRadius.circular(6),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        child: Text(
                                          'Pindahkan',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildDetailRow(
                                Icons.person_outline_rounded,
                                'Petugas Ditugaskan',
                                issue.assignedNama,
                              ),
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                Icons.account_circle_outlined,
                                'Dilaporkan Oleh',
                                issue.createdByNama,
                              ),
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                Icons.schedule_rounded,
                                'Waktu Pelaporan',
                                DateUtil.formatFull(issue.createdAt),
                              ),
                              const SizedBox(height: 8),
                              _buildDetailRow(
                                Icons.alarm_rounded,
                                'Tenggat SLA',
                                DateUtil.formatFull(issue.tenggatAt),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: issue.isOverdue
                                        ? AppColors.statusRejected.withValues(alpha: 0.15)
                                        : AppColors.accentTeal.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    DateUtil.formatRelativeSLA(issue.tenggatAt, isCompleted: isDone),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: issue.isOverdue ? AppColors.statusRejected : AppColors.accentTeal,
                                    ),
                                  ),
                                ),
                              ),
                              if (issue.resolvedAt != null) ...[
                                const SizedBox(height: 8),
                                _buildDetailRow(
                                  Icons.check_circle_outline_rounded,
                                  'Waktu Selesai',
                                  DateUtil.formatFull(issue.resolvedAt),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Catatan Penyelesaian (Jika ada)
                        if (issue.catatanPenyelesaian != null && issue.catatanPenyelesaian!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : AppColors.statusResolvedBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.statusResolved.withValues(alpha: isDark ? 0.4 : 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.assignment_turned_in_rounded, size: 18, color: AppColors.statusResolved),
                                    SizedBox(width: 8),
                                    Text(
                                      'Catatan Penyelesaian Akhir',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.statusResolved,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  issue.catatanPenyelesaian!,
                                  style: TextStyle(fontSize: 13, color: AppColors.getTextMain(context), height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Pesanan Terkait Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.getCardColor(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.getCardBorder(context)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Informasi Pesanan Terkait',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.getTextMain(context),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildDetailRow(Icons.receipt_rounded, 'Nomor Pesanan', issue.kodePesanan),
                              const SizedBox(height: 8),
                              _buildDetailRow(Icons.badge_outlined, 'Nama Pelanggan', issue.namaPelanggan),
                              if (issue.produkPesanan != null && issue.produkPesanan!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _buildDetailRow(Icons.inventory_2_outlined, 'Produk', issue.produkPesanan!),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Riwayat & Diskusi (Gabungan Transisi Status & Komentar)
                        Text(
                          'Riwayat & Diskusi Tim',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.getTextMain(context),
                          ),
                        ),
                        const SizedBox(height: 12),

                        _buildCombinedTimeline(transitionsAsync, commentsAsync),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),

              // Sticky Bottom Comment Bar (Kolom Tulis Komentar)
              _buildBottomCommentBar(),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorView.fromException(
          error: err,
          onRetry: () => ref.invalidate(issueDetailProvider(widget.issueId)),
          onHome: () => context.go('/issues'),
        ),
      ),
    );
  }

  // Gabungan Timeline Transisi Status & Komentar
  Widget _buildCombinedTimeline(
    AsyncValue<List<IssueTransaction>> transitionsAsync,
    AsyncValue<List<IssueComment>> commentsAsync,
  ) {
    if (transitionsAsync.isLoading || commentsAsync.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final transitions = transitionsAsync.value ?? [];
    final comments = commentsAsync.value ?? [];

    // Gabungkan ke model item timeline bersatu
    final items = <_TimelineItem>[];

    for (final t in transitions) {
      items.add(_TimelineItem(
        id: 't_${t.id}',
        time: DateTime.tryParse(t.createdAt) ?? DateTime(2000),
        rawTimeStr: t.createdAt,
        type: _TimelineItemType.transition,
        title: 'Status: ${IconUtil.getStatusLabel(t.statusBaru)}',
        content: t.catatanTindakan,
        author: t.namaUser,
        statusBaru: t.statusBaru,
      ));
    }

    for (final c in comments) {
      items.add(_TimelineItem(
        id: 'c_${c.id}',
        time: DateTime.tryParse(c.createdAt) ?? DateTime(2000),
        rawTimeStr: c.createdAt,
        type: c.isSistem ? _TimelineItemType.systemComment : _TimelineItemType.userComment,
        title: c.isSistem ? 'Aktivitas Sistem' : c.userNama,
        content: c.isi,
        author: c.userNama,
      ));
    }

    // Urutkan kronologis naik (waktu lama ke baru)
    items.sort((a, b) => a.time.compareTo(b.time));

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.getCardBorder(context)),
        ),
        child: Center(
          child: Text('Belum ada riwayat aktivitas atau komentar.', style: TextStyle(color: AppColors.getTextMuted(context))),
        ),
      );
    }

    final isDark = AppColors.isDark(context);

    return Column(
      children: items.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        final isLast = idx == items.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                _buildTimelineIcon(item),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 52,
                    color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildTimelineContent(item),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildTimelineIcon(_TimelineItem item) {
    switch (item.type) {
      case _TimelineItemType.transition:
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.getStatusColor(item.statusBaru ?? ''),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.getCardColor(context), width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.getStatusColor(item.statusBaru ?? '').withValues(alpha: 0.3),
                blurRadius: 4,
              ),
            ],
          ),
        );
      case _TimelineItemType.systemComment:
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.getCardColor(context), width: 2),
          ),
          child: const Icon(Icons.sync_alt_rounded, color: Colors.white, size: 10),
        );
      case _TimelineItemType.userComment:
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.getCardColor(context), width: 2),
          ),
          child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 9),
        );
    }
  }

  Widget _buildTimelineContent(_TimelineItem item) {
    final isDark = AppColors.isDark(context);

    if (item.type == _TimelineItemType.systemComment) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF3730A3) : const Color(0xFFC7D2FE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF818CF8)),
                    const SizedBox(width: 6),
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4338CA),
                      ),
                    ),
                  ],
                ),
                Text(
                  DateUtil.formatShort(item.rawTimeStr),
                  style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.content,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? const Color(0xFFE0E7FF) : const Color(0xFF312E81),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (item.type == _TimelineItemType.userComment) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.getCardBorder(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.author,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                Text(
                  DateUtil.formatShort(item.rawTimeStr),
                  style: TextStyle(fontSize: 10, color: AppColors.getTextMuted(context)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.content,
              style: TextStyle(fontSize: 13, color: AppColors.getTextMain(context)),
            ),
          ],
        ),
      );
    }

    // Status transition
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getCardBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              StatusBadge(status: item.statusBaru ?? '', fontSize: 10),
              Text(
                DateUtil.formatShort(item.rawTimeStr),
                style: TextStyle(fontSize: 11, color: AppColors.getTextMuted(context)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.content,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.getTextMain(context)),
          ),
          const SizedBox(height: 2),
          Text(
            'Oleh: ${item.author}',
            style: TextStyle(fontSize: 11, color: AppColors.getTextMuted(context)),
          ),
        ],
      ),
    );
  }

  // Kolom Tulis Komentar Menempel di Bawah (Sticky Comment Bar)
  Widget _buildBottomCommentBar() {
    final isDark = AppColors.isDark(context);

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? MediaQuery.of(context).viewInsets.bottom + 10
            : MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        border: Border(top: BorderSide(color: AppColors.getCardBorder(context))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131D31) : AppColors.backgroundLight,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.getCardBorder(context)),
                ),
                child: TextField(
                  controller: _commentController,
                  maxLines: 3,
                  minLines: 1,
                  maxLength: 1000,
                  style: TextStyle(fontSize: 13, color: AppColors.getTextMain(context)),
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  decoration: InputDecoration(
                    hintText: 'Tulis komentar atau update...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : AppColors.textMuted,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isSendingComment
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                tooltip: 'Kirim Komentar',
                onPressed: _isSendingComment ? null : _submitComment,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Widget? trailing}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppColors.getTextMuted(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: AppColors.getTextMuted(context))),
              Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.getTextMain(context))),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

enum _TimelineItemType {
  transition,
  systemComment,
  userComment,
}

class _TimelineItem {
  final String id;
  final DateTime time;
  final String rawTimeStr;
  final _TimelineItemType type;
  final String title;
  final String content;
  final String author;
  final String? statusBaru;

  _TimelineItem({
    required this.id,
    required this.time,
    required this.rawTimeStr,
    required this.type,
    required this.title,
    required this.content,
    required this.author,
    this.statusBaru,
  });
}
