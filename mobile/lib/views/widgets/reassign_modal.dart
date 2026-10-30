import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/error_mapper.dart';
import '../../data/models/models.dart';
import '../../providers/app_providers.dart';

class ReassignModal extends ConsumerStatefulWidget {
  final OrderIssue issue;
  final VoidCallback onSuccess;

  const ReassignModal({
    super.key,
    required this.issue,
    required this.onSuccess,
  });

  static Future<void> show(BuildContext context, {required OrderIssue issue, required VoidCallback onSuccess}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReassignModal(issue: issue, onSuccess: onSuccess),
    );
  }

  @override
  ConsumerState<ReassignModal> createState() => _ReassignModalState();
}

class _ReassignModalState extends ConsumerState<ReassignModal> {
  final _catatanController = TextEditingController();
  int? _selectedUserId;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _catatanController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedUserId == null) {
      setState(() => _errorMessage = 'Pilih petugas tujuan');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(repositoryProvider);
      await repo.reassignIssue(
        widget.issue.id,
        _selectedUserId!,
        catatan: _catatanController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = ErrorMapper.getMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersListProvider);
    final isDark = AppColors.isDark(context);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
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
                color: isDark ? const Color(0xFF475569) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pindahkan ke Petugas Lain',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.getTextMain(context)),
                    ),
                    Text(
                      'Kendala ${widget.issue.kodeKendala}',
                      style: TextStyle(fontSize: 12, color: AppColors.getTextMuted(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF450A0A) : AppColors.statusRejectedBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.statusRejected.withValues(alpha: 0.3)),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 12, color: AppColors.statusRejected, fontWeight: FontWeight.w600),
              ),
            ),
          Text('Petugas Tujuan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.getTextMain(context))),
          const SizedBox(height: 8),
          usersAsync.when(
            data: (users) {
              final petugasList = users.where((u) => u.role == 'petugas').toList();
              if (petugasList.isEmpty) {
                return Text('Tidak ada petugas terdaftar', style: TextStyle(color: AppColors.getTextMuted(context)));
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131D31) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.getCardBorder(context)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _selectedUserId,
                    dropdownColor: AppColors.getCardColor(context),
                    hint: Text('Pilih petugas...', style: TextStyle(fontSize: 13, color: AppColors.getTextMuted(context))),
                    items: petugasList.map((u) {
                      final isCurrent = widget.issue.assignedTo == u.id;
                      return DropdownMenuItem<int>(
                        value: u.id,
                        child: Text(
                          '${u.nama}${isCurrent ? ' (Saat ini)' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isCurrent ? AppColors.getTextMuted(context) : AppColors.getTextMain(context),
                            fontWeight: isCurrent ? FontWeight.normal : FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedUserId = val;
                        _errorMessage = null;
                      });
                    },
                  ),
                ),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (err, _) => Text(ErrorMapper.getMessage(err), style: const TextStyle(color: AppColors.statusRejected)),
          ),
          const SizedBox(height: 16),
          Text('Catatan Pengalihan (Opsional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.getTextMain(context))),
          const SizedBox(height: 8),
          TextField(
            controller: _catatanController,
            maxLines: 2,
            maxLength: 300,
            style: TextStyle(color: AppColors.getTextMain(context)),
            decoration: InputDecoration(
              hintText: 'Contoh: Dialihkan karena beban kerja atau izin sakit...',
              hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : AppColors.textMuted),
              fillColor: isDark ? const Color(0xFF131D31) : Colors.white,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.getCardBorder(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.getCardBorder(context)),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_isSubmitting ? 'Memproses...' : 'Simpan & Alihkan'),
            ),
          ),
        ],
      ),
    );
  }
}
