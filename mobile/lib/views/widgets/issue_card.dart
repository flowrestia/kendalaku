import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_util.dart';
import '../../core/utils/icon_util.dart';
import '../../data/models/models.dart';
import 'badges.dart';

class IssueCard extends StatefulWidget {
  final OrderIssue issue;
  final VoidCallback onTap;
  final VoidCallback? onQuickAction;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onToggleSelect;
  final bool canModify;
  final VoidCallback? onOpenTransitionModal;
  final VoidCallback? onViewOrder;
  final VoidCallback? onShareWhatsApp;

  const IssueCard({
    super.key,
    required this.issue,
    required this.onTap,
    this.onQuickAction,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onToggleSelect,
    this.canModify = true,
    this.onOpenTransitionModal,
    this.onViewOrder,
    this.onShareWhatsApp,
  });

  @override
  State<IssueCard> createState() => _IssueCardState();
}

class _IssueCardState extends State<IssueCard> {
  bool _isHovered = false;
  Offset? _lastTapPosition;

  bool get _isWebOrDesktop =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context) {
    return [
      if (widget.canModify)
        const PopupMenuItem<String>(
          value: 'ubah_status',
          child: Row(
            children: [
              Icon(Icons.swap_horiz_rounded, size: 18),
              SizedBox(width: 8),
              Text('Ubah status'),
            ],
          ),
        ),
      const PopupMenuItem<String>(
        value: 'pilih',
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 18),
            SizedBox(width: 8),
            Text('Pilih'),
          ],
        ),
      ),
      const PopupMenuItem<String>(
        value: 'lihat_pesanan',
        child: Row(
          children: [
            Icon(Icons.receipt_long_rounded, size: 18),
            SizedBox(width: 8),
            Text('Lihat pesanan'),
          ],
        ),
      ),
      const PopupMenuItem<String>(
        value: 'whatsapp',
        child: Row(
          children: [
            Icon(Icons.share_rounded, size: 18, color: Color(0xFF1EBE5D)),
            SizedBox(width: 8),
            Text('Bagikan ke WhatsApp'),
          ],
        ),
      ),
    ];
  }

  void _handleMenuAction(BuildContext context, String value) {
    switch (value) {
      case 'ubah_status':
        widget.onOpenTransitionModal?.call();
        break;
      case 'pilih':
        widget.onToggleSelect?.call(true);
        break;
      case 'lihat_pesanan':
        widget.onViewOrder?.call();
        break;
      case 'whatsapp':
        widget.onShareWhatsApp?.call();
        break;
    }
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final RenderBox? overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: _buildMenuItems(context),
    ).then((value) {
      if (value != null && context.mounted) {
        _handleMenuAction(context, value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = AppColors.getPriorityColor(widget.issue.prioritas);
    final isDone = widget.issue.status == 'selesai' || widget.issue.status == 'ditolak';
    final showCheckbox = widget.isSelectionMode || (_isWebOrDesktop && _isHovered);

    return Dismissible(
      key: Key('issue_${widget.issue.id}'),
      direction: (isDone || !widget.canModify) ? DismissDirection.none : DismissDirection.startToEnd,
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
        if (widget.onQuickAction != null) {
          widget.onQuickAction!();
        }
        return false; // Jangan hapus kartu dari list, hanya trigger action
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.getCardColor(context),
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
              color: widget.issue.isOverdue
                  ? AppColors.statusRejected.withValues(alpha: 0.5)
                  : AppColors.getCardBorder(context).withValues(alpha: 0.8),
              width: widget.issue.isOverdue ? 1.5 : 1,
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
                      onTap: widget.onTap,
                      onLongPress: widget.onQuickAction,
                      onSecondaryTapDown: (details) {
                        _lastTapPosition = details.globalPosition;
                      },
                      onSecondaryTap: () {
                        if (_lastTapPosition != null) {
                          _showContextMenu(context, _lastTapPosition!);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Bar: Kode Kendala, Status Badge, dan Menu Cepat
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    if (showCheckbox) ...[
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: Checkbox(
                                          value: widget.isSelectionMode ? widget.isSelected : false,
                                          activeColor: AppColors.primary,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          onChanged: (val) {
                                            widget.onToggleSelect?.call(val ?? false);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Text(
                                      widget.issue.kodeKendala,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: AppColors.isDark(context) ? AppColors.primaryLight : AppColors.primary,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    StatusBadge(status: widget.issue.status),
                                    const SizedBox(width: 2),
                                    PopupMenuButton<String>(
                                      icon: Icon(
                                        Icons.more_vert_rounded,
                                        size: 20,
                                        color: AppColors.getTextMuted(context),
                                      ),
                                      tooltip: 'Menu Cepat',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onSelected: (val) => _handleMenuAction(context, val),
                                      itemBuilder: (context) => _buildMenuItems(context),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Judul Kendala
                            Text(
                              widget.issue.judul,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.getTextMain(context),
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
                                    color: AppColors.fromHex(widget.issue.categoryWarnaHex).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        IconUtil.getIcon(widget.issue.categoryIkon),
                                        size: 13,
                                        color: AppColors.fromHex(widget.issue.categoryWarnaHex),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.issue.categoryNama,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.fromHex(widget.issue.categoryWarnaHex),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.isDark(context) ? AppColors.surfaceDark : Colors.grey.shade100,
                                    border: Border.all(color: AppColors.getCardBorder(context).withValues(alpha: 0.5)),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.issue.kodePesanan,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.getTextMuted(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Divider(height: 1, color: AppColors.getCardBorder(context)),
                            const SizedBox(height: 10),

                            // Footer: Petugas, Tenggat, dan SLA Warning
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 10,
                                  backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
                                  child: Text(
                                    widget.issue.assignedNama.isNotEmpty ? widget.issue.assignedNama[0].toUpperCase() : '?',
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
                                    widget.issue.assignedNama,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.getTextMuted(context),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                Row(
                                  children: [
                                    Icon(
                                      widget.issue.isOverdue
                                          ? Icons.error_outline_rounded
                                          : Icons.access_time_rounded,
                                      size: 13,
                                      color: widget.issue.isOverdue
                                          ? AppColors.statusRejected
                                          : AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateUtil.formatRelativeSLA(widget.issue.tenggatAt, isCompleted: isDone),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: widget.issue.isOverdue ? FontWeight.w700 : FontWeight.w500,
                                        color: widget.issue.isOverdue
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
      ),
    );
  }
}
