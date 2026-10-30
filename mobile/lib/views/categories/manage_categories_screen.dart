import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/error_mapper.dart';
import '../../core/utils/icon_util.dart';
import '../../data/models/models.dart';
import '../../providers/app_providers.dart';
import '../widgets/error_view.dart';

class ManageCategoriesScreen extends ConsumerStatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  ConsumerState<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends ConsumerState<ManageCategoriesScreen> {
  void _openCategoryDialog([ProblemCategory? category]) {
    final isEdit = category != null;
    final namaController = TextEditingController(text: category?.nama ?? '');
    final tenggatController = TextEditingController(text: category?.tenggatJam.toString() ?? '24');
    String selectedColor = category?.warnaHex ?? '#4F46E5';
    String selectedIcon = category?.ikon ?? 'warning_amber_rounded';
    bool aktif = category?.aktif ?? true;

    final formKey = GlobalKey<FormState>();

    final colorOptions = [
      '#4F46E5', '#EF4444', '#F59E0B', '#10B981', '#06B6D4',
      '#8B5CF6', '#EC4899', '#0284C7', '#64748B', '#0D9488',
    ];

    final iconOptions = [
      'warning_amber_rounded', 'broken_image', 'inventory_2_rounded',
      'local_shipping_rounded', 'alarm_rounded', 'assignment_late_rounded',
      'credit_card_off_rounded', 'help_outline_rounded',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                isEdit ? 'Ubah Kategori' : 'Tambah Kategori Baru',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nama Kategori
                      TextFormField(
                        controller: namaController,
                        decoration: const InputDecoration(labelText: 'Nama Kategori *'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),

                      // Tenggat Waktu SLA
                      TextFormField(
                        controller: tenggatController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Tenggat Waktu SLA (Jam) *',
                          suffixText: 'Jam',
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Tenggat wajib diisi';
                          final n = int.tryParse(v);
                          if (n == null || n <= 0) return 'Masukkan angka jam yang valid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Pilihan Warna Hex
                      const Text('Pilihan Warna Aksen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: colorOptions.map((hex) {
                          final isSel = selectedColor.toUpperCase() == hex.toUpperCase();
                          final color = AppColors.fromHex(hex);
                          return InkWell(
                            onTap: () => setDialogState(() => selectedColor = hex),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSel ? Border.all(color: Colors.black, width: 2.5) : null,
                              ),
                              child: isSel ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Pilihan Ikon Material
                      const Text('Pilihan Ikon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: iconOptions.map((iconName) {
                          final isSel = selectedIcon == iconName;
                          final iconData = IconUtil.getIcon(iconName);
                          return InkWell(
                            onTap: () => setDialogState(() => selectedIcon = iconName),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? AppColors.primaryContainer
                                    : (AppColors.isDark(context) ? const Color(0xFF131D31) : AppColors.backgroundLight),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSel ? AppColors.primary : AppColors.getCardBorder(context),
                                ),
                              ),
                              child: Icon(iconData, size: 20, color: isSel ? AppColors.primary : AppColors.getTextMain(context)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Switch Status Aktif
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Kategori Aktif', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.getTextMain(context))),
                          Switch(
                            value: aktif,
                            activeThumbColor: AppColors.statusResolved,
                            onChanged: (v) => setDialogState(() => aktif = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final repo = ref.read(repositoryProvider);
                      final nama = namaController.text.trim();
                      final jam = int.parse(tenggatController.text.trim());

                      try {
                        if (isEdit) {
                          await repo.updateCategory(
                            id: category.id,
                            nama: nama,
                            warnaHex: selectedColor,
                            ikon: selectedIcon,
                            tenggatJam: jam,
                            aktif: aktif,
                          );
                        } else {
                          await repo.createCategory(
                            nama: nama,
                            warnaHex: selectedColor,
                            ikon: selectedIcon,
                            tenggatJam: jam,
                            aktif: aktif,
                          );
                        }

                        ref.invalidate(categoriesProvider);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Kategori "$nama" berhasil ${isEdit ? 'diperbarui' : 'disimpan'}'),
                              backgroundColor: AppColors.statusResolved,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ErrorMapper.getMessage(e)),
                              backgroundColor: AppColors.statusRejected,
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmDelete(ProblemCategory category) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Hapus Kategori?'),
          content: Text(
            'Apakah Anda yakin ingin menghapus kategori "${category.nama}"?\n\nCatatan: Jika kategori ini sudah pernah digunakan dalam pelaporan kendala, sistem akan menolak penghapusan. Anda dapat menonaktifkannya sebagai alternatif.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusRejected),
              onPressed: () async {
                final repo = ref.read(repositoryProvider);
                try {
                  await repo.deleteCategory(category.id);
                  ref.invalidate(categoriesProvider);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Kategori "${category.nama}" berhasil dihapus'),
                        backgroundColor: AppColors.statusResolved,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(ErrorMapper.getMessage(e)),
                        backgroundColor: AppColors.statusRejected,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                }
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Kelola Kategori Kendala'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Tambah Kategori',
            onPressed: () => _openCategoryDialog(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: categoriesAsync.when(
        data: (cats) {
          if (cats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.category_outlined, size: 60, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  const Text('Belum ada kategori masalah'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _openCategoryDialog(),
                    child: const Text('Tambah Kategori Pertama'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cats.length,
            itemBuilder: (context, index) {
              final c = cats[index];
              final color = AppColors.fromHex(c.warnaHex);
              final icon = IconUtil.getIcon(c.ikon);

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.getCardColor(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.getCardBorder(context)),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  title: Row(
                    children: [
                      Text(
                        c.nama,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.getTextMain(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!c.aktif)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'NONAKTIF',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    'SLA: ${c.tenggatJam} Jam • Warna: ${c.warnaHex}',
                    style: TextStyle(color: AppColors.getTextMuted(context)),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
                        tooltip: 'Ubah',
                        onPressed: () => _openCategoryDialog(c),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.statusRejected),
                        tooltip: 'Hapus',
                        onPressed: () => _confirmDelete(c),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorView.fromException(
          error: err,
          onRetry: () => ref.invalidate(categoriesProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Kategori Baru', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _openCategoryDialog(),
      ),
    );
  }
}
