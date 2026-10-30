import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../widgets/error_view.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('KendalaKu'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ErrorView.notFound(
          title: 'Halaman Tidak Ditemukan',
          message: 'Halaman yang kamu tuju tidak ditemukan atau alamat URL keliru.',
          onHome: () => context.go('/dashboard'),
        ),
      ),
    );
  }
}

class ForbiddenScreen extends StatelessWidget {
  const ForbiddenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('KendalaKu'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ErrorView.forbidden(
          title: 'Akses Ditolak',
          message: 'Kamu tidak memiliki izin untuk mengakses halaman atau fitur ini.',
          onHome: () => context.go('/dashboard'),
        ),
      ),
    );
  }
}

class ServerErrorScreen extends StatelessWidget {
  const ServerErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('KendalaKu'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ErrorView.serverError(
          title: 'Gangguan Server',
          message: 'Terjadi gangguan di server. Coba beberapa saat lagi.',
          onHome: () => context.go('/dashboard'),
        ),
      ),
    );
  }
}

