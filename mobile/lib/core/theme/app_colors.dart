import 'package:flutter/material.dart';

class AppColors {
  // Brand Primary & Gradients
  static const Color primary = Color(0xFF4F46E5);      // Deep Indigo
  static const Color primaryLight = Color(0xFF6366F1); // Indigo Glow
  static const Color primaryDark = Color(0xFF3730A3);  // Midnight Indigo
  static const Color primaryContainer = Color(0xFFEEF2FF);

  // Accents
  static const Color accentTeal = Color(0xFF0D9488);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentCyan = Color(0xFF06B6D4);

  // Semantic Status Colors
  static const Color statusNew = Color(0xFF2563EB);        // Biru Elektrik (Baru)
  static const Color statusNewBg = Color(0xFFEFF6FF);
  
  static const Color statusProcessing = Color(0xFFEA580C); // Oranye (Sedang Diproses)
  static const Color statusProcessingBg = Color(0xFFFFF7ED);
  
  static const Color statusWaiting = Color(0xFFD97706);    // Amber (Menunggu Info)
  static const Color statusWaitingBg = Color(0xFFFFFBEB);
  
  static const Color statusResolved = Color(0xFF16A34A);   // Hijau (Selesai)
  static const Color statusResolvedBg = Color(0xFFF0FDF4);
  
  static const Color statusRejected = Color(0xFFDC2626);   // Merah (Ditolak)
  static const Color statusRejectedBg = Color(0xFFFEF2F2);

  // Priorities
  static const Color priorityLow = Color(0xFF64748B);      // Slate Grey
  static const Color priorityMedium = Color(0xFF0284C7);   // Sky Blue
  static const Color priorityHigh = Color(0xFFD97706);     // Oranye Amber
  static const Color priorityCritical = Color(0xFFE11D48); // Ruby Red

  // Surface & Neutrals
  static const Color backgroundLight = Color(0xFFF6F8FC); // Lembut sedikit sejuk
  static const Color backgroundGradientStart = Color(0xFFF8FAFF);
  static const Color backgroundGradientEnd = Color(0xFFEFF3FA);
  static const Color surfaceLight = Colors.white;
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color textMain = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);

  // Dark Theme Tokens
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardBorderDark = Color(0xFF334155);

  // Helper parser Hex string ke Color
  static Color fromHex(String hexString, {Color defaultColor = primary}) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return defaultColor;
    }
  }

  // Helper warna status
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'baru':
        return statusNew;
      case 'sedang_diproses':
        return statusProcessing;
      case 'menunggu_informasi':
        return statusWaiting;
      case 'selesai':
        return statusResolved;
      case 'ditolak':
        return statusRejected;
      default:
        return textMuted;
    }
  }

  static Color getStatusBgColor(String status) {
    switch (status.toLowerCase()) {
      case 'baru':
        return statusNewBg;
      case 'sedang_diproses':
        return statusProcessingBg;
      case 'menunggu_informasi':
        return statusWaitingBg;
      case 'selesai':
        return statusResolvedBg;
      case 'ditolak':
        return statusRejectedBg;
      default:
        return cardBorder;
    }
  }

  // Helper warna prioritas
  static Color getPriorityColor(String prioritas) {
    switch (prioritas.toLowerCase()) {
      case 'rendah':
        return priorityLow;
      case 'sedang':
        return priorityMedium;
      case 'tinggi':
        return priorityHigh;
      case 'kritis':
        return priorityCritical;
      default:
        return priorityMedium;
    }
  }
}
