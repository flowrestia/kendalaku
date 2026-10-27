import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_util.dart';
import '../../core/utils/icon_util.dart';
import '../../data/models/models.dart';
import 'badges.dart';

class IssueCard extends StatelessWidget {
  final OrderIssue issue;
  final VoidCallback onTap;
  final VoidCallback? onQuickAction;

  const IssueCard({
    super.key,
    required this.issue,
    required this.onTap,
    this.onQuickAction,
  });

  @override
  Widget build(BuildContext context) {
    final priorityColor = AppColors.getPriorityColor(issue.prioritas);
    final isDone = issue.status == 'selesai' || issue.status == 'ditolak';

    return Dismissible(
      key: Key('issue_${issue.id}'),
      direction: isDone ? DismissDirection.none : DismissDirection.startToEnd,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        child: const Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 28),
            SizedBox(width: 8),
            Text(
              'Ubah Status',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (onQuickAction != null) {
          onQuickAction!();
        }
        return false; // Jangan hapus kartu dari list, hanya trigger action
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: issue.isOverdue
                ? AppColors.statusRejected.withValues(alpha: 0.4)
                : AppColors.cardBorder.withValues(alpha: 0.8),
            width: issue.isOverdue ? 1.5 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Strip Prioritas Vertikal 5px di tepi kiri
                Container(
                  width: 5,
                  color: priorityColor,
                ),
                Expanded(
                  child: InkWell(
                    onTap: onTap,
                    onLongPress: onQuickAction,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Bar: Kode Kendala & Status Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                issue.kodeKendala,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              StatusBadge(status: issue.status),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Judul Kendala
                          Text(
                            issue.judul,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMain,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          // Tag Kategori & Pesanan
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.fromHex(issue.categoryWarnaHex).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
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
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.fromHex(issue.categoryWarnaHex),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  issue.kodePesanan,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: AppColors.cardBorder),
                          const SizedBox(height: 10),

                          // Footer: Petugas, Tenggat, dan SLA Warning
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                                child: Text(
                                  issue.assignedNama.isNotEmpty ? issue.assignedNama[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  issue.assignedNama,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    issue.isOverdue
                                        ? Icons.error_outline_rounded
                                        : Icons.access_time_rounded,
                                    size: 13,
                                    color: issue.isOverdue
                                        ? AppColors.statusRejected
                                        : AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateUtil.formatRelativeSLA(issue.tenggatAt, isCompleted: isDone),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: issue.isOverdue ? FontWeight.w700 : FontWeight.w500,
                                      color: issue.isOverdue
                                          ? AppColors.statusRejected
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
}
