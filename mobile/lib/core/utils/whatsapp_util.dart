class WhatsAppUtil {
  /// Normalisasi nomor telepon ke format internasional standar WhatsApp
  /// Contoh: '0812-3456-7890' -> '6281234567890'
  /// '0812 3456 789' -> '628123456789'
  /// '+62 812 3456' -> '628123456'
  /// '628123456' -> '628123456'
  static String normalizePhoneNumber(String raw) {
    if (raw.trim().isEmpty) return '';

    // Hapus semua karakter non-digit kecuali jika ada
    String cleaned = raw.replaceAll(RegExp(r'[^\d]'), '');

    // Jika berawalan '08', ganti '0' dengan '62' -> '628...'
    if (cleaned.startsWith('0')) {
      cleaned = '62${cleaned.substring(1)}';
    }

    return cleaned;
  }

  /// Membuat link URL WhatsApp resmi
  /// Jika [phone] kosong: `https://wa.me/?text={encoded}`
  /// Jika [phone] ada: `https://wa.me/{normalized_phone}?text={encoded}`
  static String buildWhatsAppUrl({String? phone, required String text}) {
    final encodedText = Uri.encodeComponent(text);
    final normalizedPhone = phone != null ? normalizePhoneNumber(phone) : '';

    if (normalizedPhone.isNotEmpty) {
      return 'https://wa.me/$normalizedPhone?text=$encodedText';
    }
    return 'https://wa.me/?text=$encodedText';
  }

  /// Ambang batas karakter aman untuk query string URL WhatsApp web & mobile
  static const int maxSafeUrlLength = 1800;

  /// Memeriksa apakah teks terlalu panjang untuk ditautkan via URL browser
  static bool isTextTooLongForUrl(String text) {
    final encoded = Uri.encodeComponent(text);
    return encoded.length > maxSafeUrlLength;
  }
}
