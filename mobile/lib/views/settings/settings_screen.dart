import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_util.dart';
import '../../core/utils/error_mapper.dart';
import '../../core/utils/icon_util.dart';
import '../../providers/app_providers.dart';
import '../widgets/error_view.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final formKey = GlobalKey<FormState>();
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isSubmitting = false;
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color ?? Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Ubah Kata Sandi Akun',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pastikan kata sandi baru minimal 8 karakter dan berbeda dari kata sandi lama.',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 16),

                      // Password Lama
                      TextFormField(
                        controller: oldPasswordController,
                        obscureText: obscureOld,
                        decoration: InputDecoration(
                          labelText: 'Kata Sandi Lama *',
                          hintText: 'Masukkan kata sandi saat ini',
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureOld ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              size: 20,
                            ),
                            onPressed: () => setState(() => obscureOld = !obscureOld),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Kata sandi lama wajib diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Password Baru
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          labelText: 'Kata Sandi Baru *',
                          hintText: 'Minimal 8 karakter',
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              size: 20,
                            ),
                            onPressed: () => setState(() => obscureNew = !obscureNew),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Kata sandi baru wajib diisi';
                          }
                          if (val.length < 8) {
                            return 'Kata sandi baru minimal 8 karakter';
                          }
                          if (val == oldPasswordController.text) {
                            return 'Kata sandi baru tidak boleh sama dengan kata sandi lama';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Konfirmasi Password Baru
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Konfirmasi Kata Sandi Baru *',
                          hintText: 'Ulangi kata sandi baru',
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              size: 20,
                            ),
                            onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Konfirmasi kata sandi wajib diisi';
                          }
                          if (val != newPasswordController.text) {
                            return 'Konfirmasi kata sandi tidak cocok';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Tombol Submit
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;

                                  setState(() => isSubmitting = true);
                                  try {
                                    final repo = ref.read(repositoryProvider);
                                    await repo.changePassword(
                                      oldPasswordController.text,
                                      newPasswordController.text,
                                    );

                                    if (sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop();
                                    }

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Kata sandi berhasil diperbarui'),
                                          backgroundColor: AppColors.statusResolved,
                                        ),
                                      );
                                    }
                                  } catch (err) {
                                    setState(() => isSubmitting = false);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(ErrorMapper.getMessage(err)),
                                          backgroundColor: AppColors.statusRejected,
                                        ),
                                      );
                                    }
                                  }
                                },
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Simpan Kata Sandi'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }


  void _showUsersDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final usersAsync = ref.watch(usersListProvider);
            return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.getCardColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Daftar Petugas Lapangan & Admin',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextMain(context)),
              ),
              const SizedBox(height: 12),
              usersAsync.when(
                data: (users) {
                  if (users.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Belum ada data petugas'),
                      ),
                    );
                  }
                  return SizedBox(
                    height: 320,
                    child: ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final u = users[index];
                        final emailDisplay = (u.email != null && u.email!.isNotEmpty) ? u.email! : 'Tidak ada email';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppColors.getBackgroundColor(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.getCardBorder(context)),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: u.isAdmin ? AppColors.primary : AppColors.accentTeal,
                                child: Text(
                                  u.nama.isNotEmpty ? u.nama[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(u.nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              subtitle: Text('$emailDisplay • Role: ${u.role.toUpperCase()}'),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (u.isAdmin ? AppColors.primary : AppColors.accentTeal).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  u.role.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: u.isAdmin ? AppColors.primary : AppColors.accentTeal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },

                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => ErrorView.fromException(
                  error: err,
                  title: 'Gagal memuat petugas',
                  useOutlinedRetry: true,
                  onRetry: () => ref.invalidate(usersListProvider),
                ),
              ),
            ],
          ),
        );
          },
        );
      },
    );
  }

  void _showActivitiesDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final activitiesAsync = ref.watch(activitiesListProvider);
            return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.getCardColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Riwayat Aktivitas & Audit Trail Tim',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextMain(context)),
              ),
              const SizedBox(height: 12),
              activitiesAsync.when(
                data: (activities) {
                  if (activities.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Belum ada riwayat aktivitas tindakan'),
                      ),
                    );
                  }

                  return SizedBox(
                    height: 380,
                    child: ListView.builder(
                      itemCount: activities.length,
                      itemBuilder: (context, index) {
                        final act = activities[index];
                        final statusSebelumnyaDisplay = act.statusSebelumnya.trim().isEmpty
                            ? 'Laporan Dibuat'
                            : IconUtil.getStatusLabel(act.statusSebelumnya);
                        final statusBaruDisplay = IconUtil.getStatusLabel(act.statusBaru);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.getBackgroundColor(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.getCardBorder(context)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    act.kodeKendala,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12),
                                  ),
                                  Text(
                                    DateUtil.formatFull(act.createdAt),
                                    style: TextStyle(fontSize: 10, color: AppColors.getTextMuted(context)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                act.judulKendala,
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.getTextMain(context)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.getStatusBgColor(act.statusSebelumnya),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          statusSebelumnyaDisplay,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.getStatusColor(act.statusSebelumnya),
                                          ),
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4),
                                        child: Icon(Icons.arrow_forward_rounded, size: 12, color: AppColors.textMuted),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.getStatusBgColor(act.statusBaru),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          statusBaruDisplay,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.getStatusColor(act.statusBaru),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '• Oleh: ${act.olehUserNama}',
                                    style: TextStyle(fontSize: 10, color: AppColors.getTextMuted(context)),
                                  ),
                                ],
                              ),
                              if (act.catatanTindakan.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '"${act.catatanTindakan}"',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.isDark(context) ? Colors.white70 : Colors.grey.shade700,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },

                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => ErrorView.fromException(
                  error: err,
                  title: 'Gagal memuat riwayat aktivitas',
                  useOutlinedRetry: true,
                  onRetry: () => ref.invalidate(activitiesListProvider),
                ),
              ),
            ],
          ),
        );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        title: Text(
          'Pengaturan & Profil',
          style: TextStyle(
            color: AppColors.getTextMain(context),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.getCardColor(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.getCardBorder(context)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      user != null && user.nama.isNotEmpty ? user.nama[0].toUpperCase() : 'U',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.nama ?? 'Pengguna',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getTextMain(context)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? '-',
                          style: TextStyle(fontSize: 13, color: AppColors.getTextMuted(context)),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.isDark(context) ? AppColors.primary.withValues(alpha: 0.25) : AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            user?.role.toUpperCase() ?? 'PETUGAS',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),


            const SizedBox(height: 20),

            // Kelola Menu
            Material(
              color: Theme.of(context).cardTheme.color ?? Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    // Ubah Kata Sandi Akun
                    ListTile(
                      key: const Key('settings_change_password_tile'),
                      leading: const Icon(Icons.lock_reset_rounded, color: AppColors.primary),
                      title: const Text('Ubah Kata Sandi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Perbarui kata sandi akun untuk keamanan'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showChangePasswordDialog(context, ref),
                    ),
                    const Divider(height: 1, indent: 56),

                    if (user?.isAdmin ?? false) ...[
                      ListTile(
                        leading: const Icon(Icons.category_rounded, color: AppColors.primary),
                        title: const Text('Kelola Kategori Kendala', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('Atur SLA, warna, ikon, dan status aktif kategori'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/categories'),
                      ),
                      const Divider(height: 1, indent: 56),
                    ],
                    ListTile(
                      leading: const Icon(Icons.people_outline_rounded, color: AppColors.accentTeal),
                      title: const Text('Daftar Petugas Lapangan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Lihat seluruh staf dan admin aktif'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showUsersDialog(context, ref),
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const Icon(Icons.history_rounded, color: AppColors.accentAmber),
                      title: const Text('Riwayat Aktivitas Tim', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('Audit trail transisi dan tindakan operasional'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showActivitiesDialog(context, ref),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Mode Tema (Fase 7)
            Material(
              color: Theme.of(context).cardTheme.color ?? Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.palette_outlined, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Mode Tampilan Tema',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pilih tema terang, gelap, atau mengikuti setelan sistem perangkat',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    Consumer(
                      builder: (context, ref, child) {
                        final currentTheme = ref.watch(themeModeProvider);
                        return SegmentedButton<ThemeMode>(
                          key: const Key('theme_mode_segmented_button'),
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode_outlined, size: 16),
                              label: Text('Terang'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_outlined, size: 16),
                              label: Text('Gelap'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.brightness_auto_outlined, size: 16),
                              label: Text('Sistem'),
                            ),
                          ],
                          selected: {currentTheme},
                          onSelectionChanged: (newSelection) {
                            ref.read(themeModeProvider.notifier).setThemeMode(newSelection.first);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),


            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.statusRejected,
                  side: const BorderSide(color: AppColors.statusRejected),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Keluar dari Akun', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
