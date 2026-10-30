import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/error_mapper.dart';
import '../../core/utils/icon_util.dart';
import '../../data/models/models.dart';
import '../../providers/app_providers.dart';

class IssueWizardScreen extends ConsumerStatefulWidget {
  const IssueWizardScreen({super.key});

  @override
  ConsumerState<IssueWizardScreen> createState() => _IssueWizardScreenState();
}

class _IssueWizardScreenState extends ConsumerState<IssueWizardScreen> {
  int _currentStep = 0;

  // Form State Step 1: Pesanan
  Order? _selectedOrder;
  String _orderSearchQuery = '';

  // Form State Step 2: Kategori & Deskripsi
  ProblemCategory? _selectedCategory;
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();

  // Form State Step 3: Prioritas & Petugas
  String _selectedPrioritas = 'sedang';
  User? _selectedPetugas;
  bool _isSaving = false;

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  void _submitIssue() async {
    if (_selectedOrder == null || _selectedCategory == null) return;
    if (_judulController.text.trim().isEmpty || _deskripsiController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(repositoryProvider);
      final newIssue = await repo.createIssue(
        orderId: _selectedOrder!.id,
        categoryId: _selectedCategory!.id,
        judul: _judulController.text.trim(),
        deskripsi: _deskripsiController.text.trim(),
        prioritas: _selectedPrioritas,
        assignedTo: _selectedPetugas?.id,
      );

      ref.invalidate(issuesListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kendala ${newIssue.kodeKendala} berhasil dilaporkan!'),
            backgroundColor: AppColors.statusResolved,
          ),
        );
        context.go('/issues');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMapper.getMessage(e)),
            backgroundColor: AppColors.statusRejected,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final usersAsync = ref.watch(usersListProvider);

    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text('Lapor Kendala Baru'),
      ),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        elevation: 0,
        onStepContinue: () {
          if (_currentStep == 0) {
            if (_selectedOrder == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pilih salah satu pesanan terlebih dahulu')),
              );
              return;
            }
            setState(() => _currentStep = 1);
          } else if (_currentStep == 1) {
            if (_selectedCategory == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pilih salah satu kategori masalah')),
              );
              return;
            }
            if (_judulController.text.trim().isEmpty || _deskripsiController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Judul dan deskripsi kendala wajib diisi')),
              );
              return;
            }
            setState(() => _currentStep = 2);
          } else if (_currentStep == 2) {
            _submitIssue();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          } else {
            Navigator.pop(context);
          }
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : details.onStepContinue,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(_currentStep == 2 ? 'Kirim Laporan Kendala' : 'Lanjutkan'),
                  ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _isSaving ? null : details.onStepCancel,
                    child: const Text('Kembali'),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          // Step 1: Pilih Pesanan
          Step(
            title: const Text('Pesanan'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Langkah 1: Pilih Pesanan Terkait',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextMain(context)),
                ),
                const SizedBox(height: 6),
                Text(
                  'Cari invoice pesanan simulasi pelanggan yang mengalami kendala operasional.',
                  style: TextStyle(color: AppColors.getTextMuted(context), fontSize: 13),
                ),
                const SizedBox(height: 16),

                // Search Box
                TextField(
                  style: TextStyle(color: AppColors.getTextMain(context)),
                  decoration: InputDecoration(
                    hintText: 'Cari invoice atau nama pelanggan...',
                    hintStyle: TextStyle(color: isDark ? Colors.white54 : AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF131D31) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.getCardBorder(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.getCardBorder(context)),
                    ),
                  ),
                  onChanged: (val) => setState(() => _orderSearchQuery = val.toLowerCase()),
                ),
                const SizedBox(height: 12),

                ordersAsync.when(
                  data: (orders) {
                    final filtered = orders.where((o) {
                      return o.kodePesanan.toLowerCase().contains(_orderSearchQuery) ||
                          o.namaPelanggan.toLowerCase().contains(_orderSearchQuery) ||
                          o.produk.toLowerCase().contains(_orderSearchQuery);
                    }).toList();

                    if (filtered.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Text('Tidak ada pesanan yang sesuai', style: TextStyle(color: AppColors.getTextMuted(context)))),
                      );
                    }

                    return SizedBox(
                      height: 280,
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final o = filtered[index];
                          final isSelected = _selectedOrder?.id == o.id;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : AppColors.primaryContainer)
                                  : AppColors.getCardColor(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.getCardBorder(context),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: ListTile(
                                title: Text(
                                  o.kodePesanan,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? AppColors.primary : AppColors.getTextMain(context),
                                  ),
                                ),
                                subtitle: Text(
                                  '${o.namaPelanggan} • ${o.produk} (${o.jumlah} item)',
                                  style: TextStyle(color: AppColors.getTextMuted(context)),
                                ),
                                trailing: isSelected
                                    ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                                    : null,
                                onTap: () => setState(() => _selectedOrder = o),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Text(ErrorMapper.getMessage(err), style: const TextStyle(color: AppColors.statusRejected)),
                ),
              ],
            ),
          ),

          // Step 2: Kategori & Deskripsi
          Step(
            title: const Text('Kendala'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Langkah 2: Pilih Kategori Masalah & Deskripsi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextMain(context)),
                ),
                const SizedBox(height: 12),

                // Category Chips Selection
                Text('Kategori Masalah *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.getTextMain(context))),
                const SizedBox(height: 8),
                categoriesAsync.when(
                  data: (cats) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: cats.map((cat) {
                      final isSelected = _selectedCategory?.id == cat.id;
                      final catColor = AppColors.fromHex(cat.warnaHex);

                      return InkWell(
                        onTap: () => setState(() => _selectedCategory = cat),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? catColor : catColor.withValues(alpha: isDark ? 0.2 : 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? catColor : catColor.withValues(alpha: isDark ? 0.4 : 0.25),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                IconUtil.getIcon(cat.ikon),
                                size: 14,
                                color: isSelected ? Colors.white : (isDark ? catColor : catColor),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cat.nama,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : (isDark ? Colors.white : catColor),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const SizedBox(),
                ),
                const SizedBox(height: 16),

                // SLA Preview Box
                if (_selectedCategory != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_outlined, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'SLA Standar Kategori: ${_selectedCategory!.tenggatJam} jam penyelesaian',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF93C5FD) : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Judul
                TextFormField(
                  controller: _judulController,
                  style: TextStyle(color: AppColors.getTextMain(context)),
                  decoration: const InputDecoration(
                    labelText: 'Judul Ringkas Kendala *',
                    hintText: 'Misal: Barang pecah saat packing gudang',
                  ),
                ),
                const SizedBox(height: 12),

                // Deskripsi
                TextFormField(
                  controller: _deskripsiController,
                  maxLines: 3,
                  style: TextStyle(color: AppColors.getTextMain(context)),
                  decoration: const InputDecoration(
                    labelText: 'Rincian & Deskripsi Lengkap *',
                    hintText: 'Jelaskan kondisi fisik barang, lokasi gudang, atau kronologi kendala...',
                  ),
                ),
              ],
            ),
          ),

          // Step 3: Prioritas & Delegasi Petugas
          Step(
            title: const Text('Penugasan'),
            isActive: _currentStep >= 2,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Langkah 3: Atur Prioritas & Penugasan Petugas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.getTextMain(context)),
                ),
                const SizedBox(height: 16),

                // Prioritas
                Text('Tingkat Prioritas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.getTextMain(context))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['rendah', 'sedang', 'tinggi', 'kritis'].map((pr) {
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
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedPrioritas = pr);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Petugas Penanggung Jawab
                Text('Tugaskan ke Petugas (Opsional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.getTextMain(context))),
                const SizedBox(height: 8),
                usersAsync.when(
                  data: (users) => DropdownButtonFormField<User>(
                    initialValue: _selectedPetugas,
                    dropdownColor: AppColors.getCardColor(context),
                    decoration: InputDecoration(
                      hintText: 'Pilih Petugas Lapangan',
                      hintStyle: TextStyle(color: isDark ? Colors.white54 : AppColors.textMuted),
                    ),
                    items: [
                      DropdownMenuItem<User>(
                        value: null,
                        child: Text('Belum Ditugaskan (-)', style: TextStyle(color: AppColors.getTextMain(context))),
                      ),
                      ...users.map((u) => DropdownMenuItem<User>(
                        value: u,
                        child: Text('${u.nama} (${u.role})', style: TextStyle(color: AppColors.getTextMain(context))),
                      )),
                    ],
                    onChanged: (val) => setState(() => _selectedPetugas = val),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const SizedBox(),
                ),
                const SizedBox(height: 20),

                // Ringkasan Konfirmasi
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131D31) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.getCardBorder(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ringkasan Laporan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.getTextMain(context))),
                      const SizedBox(height: 6),
                      Text(
                        '• Pesanan: ${_selectedOrder?.kodePesanan ?? '-'} (${_selectedOrder?.namaPelanggan ?? '-'})',
                        style: TextStyle(color: AppColors.getTextMuted(context), fontSize: 13),
                      ),
                      Text(
                        '• Kategori: ${_selectedCategory?.nama ?? '-'}',
                        style: TextStyle(color: AppColors.getTextMuted(context), fontSize: 13),
                      ),
                      Text(
                        '• Judul: ${_judulController.text.isNotEmpty ? _judulController.text : '-'}',
                        style: TextStyle(color: AppColors.getTextMuted(context), fontSize: 13),
                      ),
                      Text(
                        '• Prioritas: ${IconUtil.getPriorityLabel(_selectedPrioritas)}',
                        style: TextStyle(color: AppColors.getTextMuted(context), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
