import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/icon_util.dart';
import 'badges.dart';

class StatusTransitionModal extends StatefulWidget {
  final String currentStatus;
  final Function(String nextStatus, String catatanTindakan, String? catatanPenyelesaian) onSubmit;

  const StatusTransitionModal({
    super.key,
    required this.currentStatus,
    required this.onSubmit,
  });

  // State Machine: Menghitung status tujuan yang VALID sesuai aturan bisnis
  static List<String> getValidNextStatuses(String currentStatus) {
    switch (currentStatus.toLowerCase()) {
      case 'baru':
        return ['sedang_diproses', 'ditolak'];
      case 'sedang_diproses':
        return ['menunggu_informasi', 'selesai', 'ditolak'];
      case 'menunggu_informasi':
        return ['sedang_diproses'];
      case 'selesai':
      case 'ditolak':
      default:
        return []; // Status akhir tidak dapat ditransisikan lagi
    }
  }

  @override
  State<StatusTransitionModal> createState() => _StatusTransitionModalState();
}

class _StatusTransitionModalState extends State<StatusTransitionModal> {
  String? _selectedStatus;
  final _catatanTindakanController = TextEditingController();
  final _catatanPenyelesaianController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final validStatuses = StatusTransitionModal.getValidNextStatuses(widget.currentStatus);
    if (validStatuses.isNotEmpty) {
      _selectedStatus = validStatuses.first;
    }
  }

  @override
  void dispose() {
    _catatanTindakanController.dispose();
    _catatanPenyelesaianController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final validStatuses = StatusTransitionModal.getValidNextStatuses(widget.currentStatus);

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title & Status Saat Ini
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Transisi Status Penanganan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain,
                    ),
                  ),
                  StatusBadge(status: widget.currentStatus),
                ],
              ),
              const SizedBox(height: 16),

              if (validStatuses.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.textMuted),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Kendala telah berada pada status akhir (selesai / ditolak) dan tidak dapat ditransisikan lagi.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ] else ...[
                const Text(
                  'Pilih Status Baru (Hanya Status Valid):',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),

                // Pilihan Tombol Status Valid
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: validStatuses.map((st) {
                    final isSelected = _selectedStatus == st;
                    final color = AppColors.getStatusColor(st);
                    final icon = IconUtil.getStatusIcon(st);
                    final label = IconUtil.getStatusLabel(st);

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedStatus = st;
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? color : color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? color : color.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 16, color: isSelected ? Colors.white : color),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Input Catatan Tindakan
                TextFormField(
                  controller: _catatanTindakanController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Tindakan Petugas *',
                    hintText: 'Contoh: Memeriksa kondisi fisik produk di rak gudang...',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Catatan tindakan wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Catatan Penyelesaian (HANYA MUNCUL & WAJIB JIKA STATUS SELESAI)
                if (_selectedStatus == 'selesai') ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.statusResolvedBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.statusResolved.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 16, color: AppColors.statusResolved),
                            SizedBox(width: 6),
                            Text(
                              'Aturan Wajib: Catatan Penyelesaian',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppColors.statusResolved,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Pilihan Cepat:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            'Barang diganti',
                            'Alamat dikoreksi',
                            'Pelanggan dihubungi',
                            'Data pesanan diperbaiki',
                            'Pengiriman dijadwalkan ulang',
                          ].map((template) {
                            return ActionChip(
                              label: Text(
                                template,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              backgroundColor: Colors.white,
                              side: BorderSide(
                                color: AppColors.statusResolved.withValues(alpha: 0.4),
                              ),
                              onPressed: () {
                                setState(() {
                                  _catatanPenyelesaianController.text = template;
                                  _catatanPenyelesaianController.selection = TextSelection.fromPosition(
                                    TextPosition(offset: template.length),
                                  );
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _catatanPenyelesaianController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            fillColor: Colors.white,
                            labelText: 'Catatan Penyelesaian *',
                            hintText: 'Jelaskan solusi akhir, tindakan penggantian/perbaikan barang...',
                          ),
                          validator: (val) {
                            if (_selectedStatus == 'selesai' && (val == null || val.trim().isEmpty)) {
                              return 'Catatan penyelesaian wajib diisi jika status selesai';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],


                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate() && _selectedStatus != null) {
                              setState(() => _isSubmitting = true);
                              try {
                                await widget.onSubmit(
                                  _selectedStatus!,
                                  _catatanTindakanController.text.trim(),
                                  _selectedStatus == 'selesai' ? _catatanPenyelesaianController.text.trim() : null,
                                );
                                if (context.mounted) Navigator.pop(context);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(e.toString().replaceAll('Exception: ', '')),
                                      backgroundColor: AppColors.statusRejected,
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _isSubmitting = false);
                              }
                            }
                          },
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Simpan Perubahan Status'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
