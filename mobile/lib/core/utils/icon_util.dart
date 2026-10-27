import 'package:flutter/material.dart';

class IconUtil {
  // Mapping nama ikon string dari backend ke IconData Material
  static IconData getIcon(String? iconName) {
    if (iconName == null || iconName.isEmpty) {
      return Icons.warning_amber_rounded;
    }

    switch (iconName) {
      case 'alarm_rounded':
      case 'clock':
        return Icons.alarm_rounded;
      case 'inventory_2_rounded':
      case 'package':
        return Icons.inventory_2_rounded;
      case 'receipt_long_rounded':
        return Icons.receipt_long_rounded;
      case 'cancel_presentation_rounded':
        return Icons.cancel_presentation_rounded;
      case 'rule_rounded':
        return Icons.rule_rounded;
      case 'broken_image_rounded':
        return Icons.broken_image_rounded;
      case 'fiber_new_rounded':
        return Icons.fiber_new_rounded;
      case 'autorenew_rounded':
        return Icons.autorenew_rounded;
      case 'hourglass_top_rounded':
        return Icons.hourglass_top_rounded;
      case 'check_circle_rounded':
        return Icons.check_circle_rounded;
      case 'cancel_rounded':
        return Icons.cancel_rounded;
      default:
        return Icons.report_problem_rounded;
    }
  }

  // Icon spesifik untuk status kendala
  static IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'baru':
        return Icons.fiber_new_rounded;
      case 'sedang_diproses':
        return Icons.autorenew_rounded;
      case 'menunggu_informasi':
        return Icons.hourglass_top_rounded;
      case 'selesai':
        return Icons.check_circle_rounded;
      case 'ditolak':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  // Label rapi bahasa Indonesia untuk status
  static String getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'baru':
        return 'Baru';
      case 'sedang_diproses':
        return 'Sedang Diproses';
      case 'menunggu_informasi':
        return 'Menunggu Info';
      case 'selesai':
        return 'Selesai';
      case 'ditolak':
        return 'Ditolak';
      default:
        return status;
    }
  }

  // Label rapi prioritas
  static String getPriorityLabel(String prioritas) {
    switch (prioritas.toLowerCase()) {
      case 'rendah':
        return 'Rendah';
      case 'sedang':
        return 'Sedang';
      case 'tinggi':
        return 'Tinggi';
      case 'kritis':
        return 'Kritis';
      default:
        return prioritas;
    }
  }
}
