import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/error_mapper.dart';

class ErrorView extends StatelessWidget {
  final ErrorType variant;
  final String? title;
  final String? message;
  final VoidCallback? onRetry;
  final VoidCallback? onHome;
  final bool isCompact;
  final bool useOutlinedRetry;

  const ErrorView({
    super.key,
    this.variant = ErrorType.unexpected,
    this.title,
    this.message,
    this.onRetry,
    this.onHome,
    this.isCompact = false,
    this.useOutlinedRetry = false,
  });

  factory ErrorView.fromException({
    Key? key,
    required dynamic error,
    VoidCallback? onRetry,
    VoidCallback? onHome,
    String? title,
    bool isCompact = false,
    bool useOutlinedRetry = false,
  }) {
    final appError = ErrorMapper.map(error);
    return ErrorView(
      key: key,
      variant: appError.type,
      title: title,
      message: appError.message,
      onRetry: onRetry,
      onHome: onHome,
      isCompact: isCompact,
      useOutlinedRetry: useOutlinedRetry,
    );
  }

  const ErrorView.noConnection({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.onHome,
    this.isCompact = false,
    this.useOutlinedRetry = false,
  }) : variant = ErrorType.noConnection;

  const ErrorView.notFound({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.onHome,
    this.isCompact = false,
    this.useOutlinedRetry = false,
  }) : variant = ErrorType.notFound;

  const ErrorView.forbidden({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.onHome,
    this.isCompact = false,
    this.useOutlinedRetry = false,
  }) : variant = ErrorType.forbidden;

  const ErrorView.serverError({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.onHome,
    this.isCompact = false,
    this.useOutlinedRetry = false,
  }) : variant = ErrorType.serverError;

  const ErrorView.unexpected({
    super.key,
    this.title,
    this.message,
    this.onRetry,
    this.onHome,
    this.isCompact = false,
    this.useOutlinedRetry = false,
  }) : variant = ErrorType.unexpected;

  IconData _getIcon() {
    switch (variant) {
      case ErrorType.noConnection:
        return Icons.wifi_off_rounded;
      case ErrorType.notFound:
        return Icons.search_off_rounded;
      case ErrorType.forbidden:
        return Icons.lock_outline_rounded;
      case ErrorType.serverError:
        return Icons.dns_rounded;
      case ErrorType.validation:
        return Icons.warning_amber_rounded;
      case ErrorType.unexpected:
      case ErrorType.unauthorized:
        return Icons.error_outline_rounded;
    }
  }

  Color _getColor() {
    switch (variant) {
      case ErrorType.noConnection:
        return AppColors.priorityMedium;
      case ErrorType.notFound:
        return AppColors.primary;
      case ErrorType.forbidden:
        return AppColors.priorityCritical;
      case ErrorType.serverError:
      case ErrorType.unexpected:
      case ErrorType.unauthorized:
        return AppColors.statusRejected;
      case ErrorType.validation:
        return AppColors.priorityHigh;
    }
  }

  String _getDefaultTitle() {
    switch (variant) {
      case ErrorType.noConnection:
        return 'Koneksi Terputus';
      case ErrorType.notFound:
        return 'Data Tidak Ditemukan';
      case ErrorType.forbidden:
        return 'Akses Ditolak';
      case ErrorType.serverError:
        return 'Gangguan Server';
      case ErrorType.validation:
        return 'Data Tidak Valid';
      case ErrorType.unauthorized:
        return 'Sesi Berakhir';
      case ErrorType.unexpected:
        return 'Terjadi Kesalahan';
    }
  }

  String _getDefaultMessage() {
    switch (variant) {
      case ErrorType.noConnection:
        return ErrorMapper.noConnectionMessage;
      case ErrorType.notFound:
        return ErrorMapper.notFoundMessage;
      case ErrorType.forbidden:
        return ErrorMapper.forbiddenMessage;
      case ErrorType.serverError:
        return ErrorMapper.serverErrorMessage;
      case ErrorType.unauthorized:
        return ErrorMapper.unauthorizedMessage;
      case ErrorType.validation:
        return 'Periksa kembali data yang dimasukkan.';
      case ErrorType.unexpected:
        return ErrorMapper.unexpectedMessage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayTitle = title ?? _getDefaultTitle();
    final displayMessage = message ?? _getDefaultMessage();
    final accentColor = _getColor();
    final iconData = _getIcon();
    // Meningkatkan kontras teks penjelasan di mode gelap & terang (WCAG AA)
    final messageColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155);

    if (isCompact) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData, size: 36, color: accentColor),
              const SizedBox(height: 8),
              if (displayTitle.isNotEmpty)
                Text(
                  displayTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.getTextMain(context),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                displayMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: messageColor,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                if (useOutlinedRetry)
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Coba Lagi'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(120, 48),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Coba Lagi'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(120, 48),
                    ),
                  ),
              ],
            ],
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: accentColor.withValues(alpha: 0.2), width: 2),
              ),
              child: Icon(iconData, size: 40, color: accentColor),
            ),
            const SizedBox(height: 18),
            Text(
              displayTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: AppColors.getTextMain(context),
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                displayMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: messageColor,
                  height: 1.4,
                ),
              ),
            ),
            if (onRetry != null || onHome != null) const SizedBox(height: 20),
            if (onRetry != null) ...[
              if (useOutlinedRetry)
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Coba Lagi'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    minimumSize: const Size(160, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Coba Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(160, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
            ],
            if (onHome != null) ...[
              if (onRetry != null) const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: onHome,
                icon: const Icon(Icons.home_rounded, size: 20),
                label: const Text('Kembali ke Beranda'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(200, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

