import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/icon_util.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool showIcon;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.status,
    this.showIcon = true,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final rawColor = AppColors.getStatusColor(status);
    final color = isDark ? (rawColor == AppColors.statusNew ? const Color(0xFF60A5FA) : (rawColor == AppColors.statusResolved ? const Color(0xFF4ADE80) : rawColor)) : rawColor;
    final bgColor = isDark ? color.withValues(alpha: 0.18) : AppColors.getStatusBgColor(status);
    final icon = IconUtil.getStatusIcon(status);
    final label = IconUtil.getStatusLabel(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.4 : 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(icon, size: fontSize + 3, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: fontSize,
            ),
          ),
        ],
      ),
    );
  }

}

class PriorityBadge extends StatelessWidget {
  final String prioritas;

  const PriorityBadge({super.key, required this.prioritas});

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final rawColor = AppColors.getPriorityColor(prioritas);
    final color = isDark ? (rawColor == AppColors.priorityLow ? const Color(0xFF94A3B8) : (rawColor == AppColors.priorityMedium ? const Color(0xFF38BDF8) : rawColor)) : rawColor;
    final label = IconUtil.getPriorityLabel(prioritas);
    final isCritical = prioritas.toLowerCase() == 'kritis';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: isCritical ? FontWeight.w800 : FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

}
