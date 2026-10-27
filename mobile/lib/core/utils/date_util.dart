import 'package:intl/intl.dart';

class DateUtil {
  // Parsing string UTC (misal "2026-10-24T16:31:57Z" atau "2026-10-24 16:31:57") ke DateTime lokal perangkat
  static DateTime parseToLocal(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();
    if (dateValue is DateTime) return dateValue.toLocal();

    final str = dateValue.toString();
    try {
      DateTime dt;
      if (str.endsWith('Z')) {
        dt = DateTime.parse(str);
      } else {
        dt = DateTime.parse('${str.replaceAll(' ', 'T')}Z');
      }
      return dt.toLocal();
    } catch (_) {
      try {
        return DateTime.parse(str).toLocal();
      } catch (_) {
        return DateTime.now();
      }
    }
  }

  // Format standar Indonesia: "24 Okt 2026, 23:31 WIB"
  static String formatFull(dynamic dateValue) {
    if (dateValue == null) return '-';
    final dt = parseToLocal(dateValue);
    final formatted = DateFormat('dd MMM yyyy, HH:mm').format(dt);
    return '$formatted WIB';
  }

  // Format ringkas: "24 Okt, 23:31"
  static String formatShort(dynamic dateValue) {
    if (dateValue == null) return '-';
    final dt = parseToLocal(dateValue);
    return DateFormat('dd MMM, HH:mm').format(dt);
  }

  // Format tanggal saja: "24 Okt 2026"
  static String formatDateOnly(dynamic dateValue) {
    if (dateValue == null) return '-';
    final dt = parseToLocal(dateValue);
    return DateFormat('dd MMM yyyy').format(dt);
  }

  // Relatif SLA: "2 jam lagi" atau "Terlambat 4 jam"
  static String formatRelativeSLA(dynamic deadlineValue, {bool isCompleted = false}) {
    if (deadlineValue == null) return '-';
    final deadline = parseToLocal(deadlineValue);
    final now = DateTime.now();

    if (isCompleted) {
      return 'Tenggat: ${formatShort(deadline)}';
    }

    final diff = deadline.difference(now);
    if (diff.isNegative) {
      final hours = (-diff.inHours);
      if (hours < 1) {
        return 'Terlambat ${-diff.inMinutes} mnt';
      } else if (hours < 24) {
        return 'Terlambat $hours jam';
      } else {
        final days = (-diff.inDays);
        return 'Terlambat $days hari';
      }
    } else {
      if (diff.inHours < 1) {
        return '${diff.inMinutes} mnt lagi';
      } else if (diff.inHours < 24) {
        return '${diff.inHours} jam lagi';
      } else {
        return '${diff.inDays} hari lagi';
      }
    }
  }
}
