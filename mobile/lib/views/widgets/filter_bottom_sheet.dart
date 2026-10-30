import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/icon_util.dart';
import '../../providers/app_providers.dart';

class FilterBottomSheet extends ConsumerStatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  ConsumerState<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends ConsumerState<FilterBottomSheet> {
  String? _selectedStatus;
  String? _selectedPrioritas;
  int? _selectedCategory;
  bool? _isOverdue;

  final List<String> _statuses = ['baru', 'sedang_diproses', 'menunggu_informasi', 'selesai', 'ditolak'];
  final List<String> _prioritasList = ['rendah', 'sedang', 'tinggi', 'kritis'];

  @override
  void initState() {
    super.initState();
    final filter = ref.read(issueFilterProvider);
    _selectedStatus = filter.status;
    _selectedPrioritas = filter.prioritas;
    _selectedCategory = filter.categoryId;
    _isOverdue = filter.isOverdue;
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final isDark = AppColors.isDark(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF475569) : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filter Kendala Pesanan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextMain(context)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedStatus = null;
                      _selectedPrioritas = null;
                      _selectedCategory = null;
                      _isOverdue = null;
                    });
                  },
                  child: const Text('Reset', style: TextStyle(color: AppColors.statusRejected)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Status Filter Chips
            Text('Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.getTextMuted(context))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _statuses.map((st) {
                final isSelected = _selectedStatus == st;
                final color = AppColors.getStatusColor(st);
                return ChoiceChip(
                  label: Text(IconUtil.getStatusLabel(st)),
                  selected: isSelected,
                  selectedColor: color.withValues(alpha: isDark ? 0.35 : 0.2),
                  backgroundColor: AppColors.getCardColor(context),
                  labelStyle: TextStyle(
                    color: isSelected ? (isDark ? Colors.white : color) : AppColors.getTextMain(context),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    setState(() => _selectedStatus = val ? st : null);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Prioritas Filter Chips
            Text('Prioritas', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.getTextMuted(context))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _prioritasList.map((pr) {
                final isSelected = _selectedPrioritas == pr;
                final color = AppColors.getPriorityColor(pr);
                return ChoiceChip(
                  label: Text(IconUtil.getPriorityLabel(pr)),
                  selected: isSelected,
                  selectedColor: color.withValues(alpha: isDark ? 0.35 : 0.2),
                  backgroundColor: AppColors.getCardColor(context),
                  labelStyle: TextStyle(
                    color: isSelected ? (isDark ? Colors.white : color) : AppColors.getTextMain(context),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                  onSelected: (val) {
                    setState(() => _selectedPrioritas = val ? pr : null);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Overdue Toggle Switch
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.alarm_on_rounded, size: 18, color: AppColors.statusRejected),
                    const SizedBox(width: 8),
                    Text(
                      'Hanya yang Melewati Tenggat (Overdue)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.getTextMain(context)),
                    ),
                  ],
                ),
                Switch(
                  value: _isOverdue ?? false,
                  activeThumbColor: AppColors.statusRejected,
                  onChanged: (val) {
                    setState(() => _isOverdue = val ? true : null);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Kategori Dropdown
            Text('Kategori Masalah', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.getTextMuted(context))),
            const SizedBox(height: 8),
            categoriesAsync.when(
              data: (cats) => DropdownButtonFormField<int>(
                initialValue: _selectedCategory,
                dropdownColor: AppColors.getCardColor(context),
                decoration: InputDecoration(
                  hintText: 'Semua Kategori',
                  hintStyle: TextStyle(color: isDark ? Colors.white54 : AppColors.textMuted),
                ),
                items: [
                  DropdownMenuItem<int>(
                    value: null,
                    child: Text('Semua Kategori', style: TextStyle(color: AppColors.getTextMain(context))),
                  ),
                  ...cats.map((c) => DropdownMenuItem<int>(
                    value: c.id,
                    child: Text(c.nama, style: TextStyle(color: AppColors.getTextMain(context))),
                  )),
                ],
                onChanged: (val) => setState(() => _selectedCategory = val),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => const SizedBox(),
            ),
            const SizedBox(height: 24),

            // Terapkan Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  ref.read(issueFilterProvider.notifier).updateFilter((state) => state.copyWith(
                    status: _selectedStatus,
                    prioritas: _selectedPrioritas,
                    categoryId: _selectedCategory,
                    isOverdue: _isOverdue,
                    clearStatus: _selectedStatus == null,
                    clearPrioritas: _selectedPrioritas == null,
                    clearCategory: _selectedCategory == null,
                    clearOverdue: _isOverdue == null,
                  ));
                  Navigator.pop(context);
                },
                child: const Text('Terapkan Filter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
