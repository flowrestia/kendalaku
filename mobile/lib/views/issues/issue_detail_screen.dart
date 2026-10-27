import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_util.dart';
import '../../core/utils/icon_util.dart';
import '../../data/models/models.dart';
import '../../providers/app_providers.dart';
import '../widgets/badges.dart';
import '../widgets/status_transition_modal.dart';
import '../widgets/whatsapp_preview_sheet.dart';

class IssueDetailScreen extends ConsumerStatefulWidget {
  final int issueId;

  const IssueDetailScreen({super.key, required this.issueId});

  @override
  ConsumerState<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends ConsumerState<IssueDetailScreen> {
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
          ref.invalidate(issueDetailProvider(widget.issueId));
          ref.invalidate(issueTransitionsProvider(widget.issueId));
          ref.invalidate(issuesListProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Status berhasil diubah menjadi: $nextStatus'),
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
    final issueAsync = ref.watch(issueDetailProvider(widget.issueId));
    final transitionsAsync = ref.watch(issueTransitionsProvider(widget.issueId));

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Detail Kendala'),
        actions: [
          issueAsync.when(
            data: (issue) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.share_rounded, color: Color(0xFF1EBE5D)),
                  tooltip: 'Bagikan ke WhatsApp',
                  onPressed: () => WhatsAppPreviewSheet.show(
                    context,
                    singleIssue: issue,
                  ),
                ),
                if (issue.status != 'selesai' && issue.status != 'ditolak')
                  TextButton.icon(
                    icon: const Icon(Icons.swap_horiz_rounded, size: 20, color: AppColors.primary),
                    label: const Text('Ubah Status', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                    onPressed: () => _openTransitionModal(issue),
                  ),
              ],
            ),
            loading: () => const SizedBox(),
            error: (_, _) => const SizedBox(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: issueAsync.when(
        data: (issue) {
          final isDone = issue.status == 'selesai' || issue.status == 'ditolak';

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(issueDetailProvider(widget.issueId));
              ref.invalidate(issueTransitionsProvider(widget.issueId));
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Main Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
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
                            Text(
                              issue.kodeKendala,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            StatusBadge(status: issue.status, fontSize: 12),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          issue.judul,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMain,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          issue.deskripsi,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textMain,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: AppColors.cardBorder),
                        const SizedBox(height: 12),

                        // Badges Row
                        Row(
                          children: [
                            PriorityBadge(prioritas: issue.prioritas),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.fromHex(issue.categoryWarnaHex).withValues(alpha: 0.12),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pelaporan & Penugasan',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                        color: AppColors.statusResolvedBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.statusResolved.withValues(alpha: 0.3)),
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
                            style: const TextStyle(fontSize: 13, color: AppColors.textMain, height: 1.4),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informasi Pesanan Terkait',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

                  // Timeline Riwayat Tindakan
                  const Text(
                    'Riwayat Transisi & Tindakan',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textMain),
                  ),
                  const SizedBox(height: 12),

                  transitionsAsync.when(
                    data: (transitions) {
                      if (transitions.isEmpty) {
                        return const Text('Belum ada riwayat tindakan.', style: TextStyle(color: AppColors.textMuted));
                      }

                      return Column(
                        children: transitions.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final t = entry.value;
                          final isLast = idx == transitions.length - 1;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: AppColors.getStatusColor(t.statusBaru),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  if (!isLast)
                                    Container(
                                      width: 2,
                                      height: 60,
                                      color: Colors.grey.shade300,
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          StatusBadge(status: t.statusBaru, fontSize: 10),
                                          Text(
                                            DateUtil.formatShort(t.createdAt),
                                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        t.catatanTindakan,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Oleh: ${t.namaUser}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const Text('Gagal memuat riwayat tindakan', style: TextStyle(color: AppColors.statusRejected)),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Gagal: $err')),
      ),
      bottomNavigationBar: issueAsync.maybeWhen(
        data: (issue) {
          final isDone = issue.status == 'selesai' || issue.status == 'ditolak';
          if (isDone) return null;

          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(top: BorderSide(color: AppColors.cardBorder)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _openTransitionModal(issue),
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text(
                    'Transisi & Tindak Lanjut Kendala',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ),
          );
        },
        orElse: () => null,
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Widget? trailing}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMain)),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
