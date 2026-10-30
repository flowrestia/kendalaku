import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/error_mapper.dart';
import '../../core/utils/whatsapp_util.dart';
import '../../data/models/models.dart';
import '../../providers/app_providers.dart';
import 'error_view.dart';

class WhatsAppPreviewSheet extends ConsumerStatefulWidget {
  final List<int>? selectedIds;
  final OrderIssue? singleIssue; // Untuk share dari detail kendala
  final IssueFilterState? activeFilter;

  const WhatsAppPreviewSheet({
    super.key,
    this.selectedIds,
    this.singleIssue,
    this.activeFilter,
  });

  static Future<void> show(
    BuildContext context, {
    List<int>? selectedIds,
    OrderIssue? singleIssue,
    IssueFilterState? activeFilter,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WhatsAppPreviewSheet(
        selectedIds: selectedIds,
        singleIssue: singleIssue,
        activeFilter: activeFilter,
      ),
    );
  }

  @override
  ConsumerState<WhatsAppPreviewSheet> createState() => _WhatsAppPreviewSheetState();
}

class _WhatsAppPreviewSheetState extends ConsumerState<WhatsAppPreviewSheet> {
  final _phoneController = TextEditingController();
  late TextEditingController _textController;
  bool _includeCustomer = true;
  bool _isLoading = true;
  String? _errorMessage;
  int _itemCount = 0;
  bool _isTruncated = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _loadShareText();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadShareText() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Jika share dari satu kendala
      if (widget.singleIssue != null) {
        final issue = widget.singleIssue!;
        final text = _formatSingleIssue(issue, _includeCustomer);
        setState(() {
          _textController.text = text;
          _itemCount = 1;
          _isTruncated = false;
          _isLoading = false;
        });
        return;
      }

      // Jika dari list
      final repo = ref.read(repositoryProvider);
      final filter = widget.activeFilter;

      final res = await repo.getShareText(
        search: filter?.search,
        status: filter?.status,
        prioritas: filter?.prioritas,
        categoryId: filter?.categoryId,
        assignedTo: filter?.assignedTo,
        isOverdue: filter?.isOverdue,
        ids: widget.selectedIds,
        includeCustomer: _includeCustomer,
      );

      if (mounted) {
        setState(() {
          _textController.text = res.text;
          _itemCount = res.count;
          _isTruncated = res.truncated;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ErrorMapper.getMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  String _formatSingleIssue(OrderIssue it, bool includeCust) {
    final now = DateTime.now().toUtc();
    final parsedTenggat = DateTime.tryParse(it.tenggatAt)?.toUtc() ?? now;
    final diff = parsedTenggat.difference(now);
    final diffHours = (diff.inMinutes.abs() / 60.0).round().clamp(1, 9999);

    String slaText;
    if (it.status == 'selesai') {
      slaText = 'Tuntas';
    } else if (it.status == 'ditolak') {
      slaText = 'Ditolak';
    } else if (it.isOverdue || now.isAfter(parsedTenggat)) {
      slaText = 'Terlambat $diffHours jam';
    } else {
      slaText = 'Sisa $diffHours jam';
    }

    final tenggatWIB = parsedTenggat.add(const Duration(hours: 7));
    final tenggatStr = '${tenggatWIB.day.toString().padLeft(2, '0')}/${tenggatWIB.month.toString().padLeft(2, '0')} ${tenggatWIB.hour.toString().padLeft(2, '0')}:${tenggatWIB.minute.toString().padLeft(2, '0')}';

    final orderLine = includeCust && it.namaPelanggan.isNotEmpty
        ? '${it.kodePesanan} (${it.namaPelanggan})'
        : it.kodePesanan;

    final sb = StringBuffer();
    sb.writeln('*KENDALA LAYANAN - KENDALAKU*');
    sb.writeln('*[${it.kodeKendala}]* *[${it.prioritas.toUpperCase()}]* ${it.judul}');
    sb.writeln('Pesanan: $orderLine');
    sb.writeln('Kategori: ${it.categoryNama}');
    sb.writeln('Status: ${it.status} | Petugas: ${it.assignedNama}');
    sb.writeln('Tenggat: $tenggatStr WIB ($slaText)');
    if (it.deskripsi.isNotEmpty) {
      sb.writeln('Deskripsi: ${it.deskripsi}');
    }
    return sb.toString();
  }

  Future<void> _openWhatsApp() async {
    final text = _textController.text;
    final phone = _phoneController.text.trim();

    if (WhatsAppUtil.isTextTooLongForUrl(text)) {
      _showTextTooLongDialog();
      return;
    }

    final urlString = WhatsAppUtil.buildWhatsAppUrl(phone: phone, text: text);
    final uri = Uri.parse(urlString);

    try {
      final launched = await launchUrl(
        uri,
        mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka WhatsApp. Silakan gunakan tombol "Salin Teks".'),
            backgroundColor: AppColors.statusRejected,
          ),
        );
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
    }
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: _textController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Teks daftar kendala berhasil disalin ke clipboard'),
        backgroundColor: AppColors.statusResolved,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showTextTooLongDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.accentAmber, size: 28),
            SizedBox(width: 10),
            Text('Teks Terlalu Panjang', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Teks kendala melebihi batas panjang URL WhatsApp browser (sekitar 1.800 karakter). Tautan langsung dapat terpotong oleh browser.\n\nDisarankan menyalin teks secara langsung dengan tombol "Salin Teks" atau kurangi jumlah kendala yang dipilih.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(ctx);
              _copyText();
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Salin Teks Saja'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isTextTooLong = WhatsAppUtil.isTextTooLongForUrl(_textController.text);
    final isDark = AppColors.isDark(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: AppColors.getCardColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF475569) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.share_rounded, color: Color(0xFF25D366), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kirim ke WhatsApp',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.getTextMain(context)),
                        ),
                        Text(
                          widget.singleIssue != null
                              ? 'Ringkasan 1 Kendala'
                              : '$_itemCount kendala${_isTruncated ? ' (dibatasi 20 item)' : ''}',
                          style: TextStyle(fontSize: 12, color: AppColors.getTextMuted(context)),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.getTextMuted(context)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Divider(height: 20, color: AppColors.getCardBorder(context)),

          // Body
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Menyiapkan format pesan...', style: TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? ErrorView.unexpected(
                        message: _errorMessage,
                        isCompact: true,
                        onRetry: _loadShareText,
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Switch Sertakan Nama Pelanggan
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF131D31) : AppColors.backgroundLight,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.getCardBorder(context)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Sertakan Nama Pelanggan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.getTextMain(context))),
                                        Text('Sembunyikan untuk menjaga privasi pelanggan jika diperlukan', style: TextStyle(fontSize: 11, color: AppColors.getTextMuted(context))),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _includeCustomer,
                                    activeThumbColor: AppColors.primary,
                                    onChanged: (val) {
                                      setState(() => _includeCustomer = val);
                                      _loadShareText();
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Input Nomor WhatsApp Tujuan
                            TextField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: TextStyle(color: AppColors.getTextMain(context)),
                              decoration: InputDecoration(
                                labelText: 'Nomor WhatsApp Tujuan (Opsional)',
                                hintText: 'Contoh: 08123456789 atau 628123456789',
                                hintStyle: TextStyle(color: isDark ? Colors.white54 : AppColors.textMuted),
                                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                                helperText: 'Jika kosong, WhatsApp akan membuka dialog pilih kontak',
                                helperStyle: TextStyle(fontSize: 11, color: AppColors.getTextMuted(context)),
                                suffixIcon: _phoneController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _phoneController.clear();
                                          setState(() {});
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 14),

                            // Peringatan jika teks terlalu panjang untuk URL
                            if (isTextTooLong)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.accentAmber.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, color: AppColors.accentAmber, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Teks melebihi 1.800 karakter. Tombol Buka WhatsApp mungkin dibatasi browser. Disarankan gunakan tombol "Salin Teks".',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Pratinjau Teks (Bisa diedit)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Pratinjau Pesan (Dapat Diedit)',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.getTextMain(context)),
                                ),
                                Text(
                                  '${_textController.text.length} karakter',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isTextTooLong ? AppColors.statusRejected : AppColors.getTextMuted(context),
                                    fontWeight: isTextTooLong ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            TextField(
                              controller: _textController,
                              maxLines: 10,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                                height: 1.4,
                                color: AppColors.getTextMain(context),
                              ),
                              decoration: InputDecoration(
                                fillColor: isDark ? const Color(0xFF131D31) : AppColors.backgroundLight,
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: AppColors.getCardBorder(context)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: AppColors.getCardBorder(context)),
                                ),
                                contentPadding: const EdgeInsets.all(14),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
          ),

          // Action Buttons Footer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: AppColors.getCardColor(context),
              border: Border(top: BorderSide(color: AppColors.getCardBorder(context))),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _copyText,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('Salin Teks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _openWhatsApp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: const Text(
                      'Buka WhatsApp',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
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
