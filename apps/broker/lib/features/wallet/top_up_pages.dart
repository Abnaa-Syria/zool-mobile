import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../data/models.dart';

/// B2 — new top-up request (amount), then the request page.
class NewTopUpPage extends ConsumerStatefulWidget {
  const NewTopUpPage({super.key});

  @override
  ConsumerState<NewTopUpPage> createState() => _NewTopUpPageState();
}

class _NewTopUpPageState extends ConsumerState<NewTopUpPage> {
  final _amount = TextEditingController();
  final _key = const Uuid().v4();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final minor = parseSdgToMinor(_amount.text);
    if (minor == null) return setState(() => _error = 'أدخل مبلغًا صحيحًا.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final topUp = await ref.read(apiProvider).createTopUp(amountMinor: minor, idempotencyKey: _key);
      ref.read(bookingsVersionProvider.notifier).state++;
      if (mounted) context.pushReplacement('/top-up/${topUp.id}');
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('شحن المحفظة')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('المبلغ المراد شحنه', style: t.titleSmall),
          const SizedBox(height: 8),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩.,]'))],
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            decoration: InputDecoration(suffixText: 'ج.س', errorText: _error, hintText: '0'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final v in const [100000, 250000, 500000, 1000000])
                ActionChip(label: Text(formatSdg(v * 100)), onPressed: () => setState(() => _amount.text = '$v')),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'بعد إنشاء الطلب ادفع المبلغ بالطريقة المعتادة ثم ارفع صورة الإيصال ورقم العملية؛ تُضاف القيمة للمحفظة بعد تأكيد المنصة.',
            style: t.bodySmall,
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(child: PrimaryButton(label: 'إنشاء طلب الشحن', busy: _busy, onPressed: _submit)),
    );
  }
}

/// A top-up request: status (polled while open), receipt upload (manual fallback), mock confirm in dev.
class TopUpDetailPage extends ConsumerStatefulWidget {
  const TopUpDetailPage({super.key, required this.topUpId});

  final String topUpId;

  @override
  ConsumerState<TopUpDetailPage> createState() => _TopUpDetailPageState();
}

class _TopUpDetailPageState extends ConsumerState<TopUpDetailPage> {
  Timer? _poll;
  String? _lastStatus;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  /// Provider confirmation every 5 s; platform review every 30 s.
  void _schedule(TopUp x) {
    if (_lastStatus != null && _lastStatus != x.status && x.status == 'CONFIRMED') refreshMoney(ref);
    _lastStatus = x.status;
    _poll?.cancel();
    if (!x.open) return;
    _poll = Timer(Duration(seconds: x.status == 'PENDING' ? 5 : 30), () {
      if (mounted) ref.invalidate(topUpProvider(widget.topUpId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final topUp = ref.watch(topUpProvider(widget.topUpId));
    ref.listen(topUpProvider(widget.topUpId), (_, next) {
      if (next.value != null) _schedule(next.value!);
    });
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('طلب شحن')),
      body: AsyncBody(
        value: topUp,
        onRetry: () => ref.invalidate(topUpProvider(widget.topUpId)),
        data: (x) {
          if (_lastStatus == null) WidgetsBinding.instance.addPostFrameCallback((_) => _schedule(x));
          final (label, tone) = topUpStatus(x.status);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ZoolCard(
                child: Column(
                  children: [
                    Text(formatSdg(x.amountMinor), style: t.titleLarge?.copyWith(color: ZoolColors.secondary, fontSize: 26)),
                    const SizedBox(height: 8),
                    StatusBadge(label, tone: tone),
                    const SizedBox(height: 12),
                    InfoRow('تاريخ الطلب', formatDateTime(x.createdAt)),
                    if (x.paymentReference != null) InfoRow('رقم العملية', x.paymentReference!),
                    InfoRow('الإيصال', x.hasEvidence ? 'مرفوع' : 'لم يُرفع'),
                    if (x.confirmedAt != null) InfoRow('تاريخ التأكيد', formatDateTime(x.confirmedAt)),
                    if (x.failedAt != null) InfoRow('تاريخ الرفض', formatDateTime(x.failedAt)),
                    if (x.note != null && x.note!.isNotEmpty) InfoRow(x.status == 'FAILED' ? 'سبب الرفض' : 'ملاحظة', x.note!),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (x.status == 'PENDING') ...[
                Text('أكمل الطلب', style: t.titleSmall),
                const SizedBox(height: 8),
                Text('ادفع المبلغ ثم ارفع صورة الإيصال مع رقم العملية لتراجعه المنصة.', style: t.bodySmall),
                const SizedBox(height: 12),
                PrimaryButton(label: 'رفع الإيصال', icon: Icons.upload_file_rounded, onPressed: () => _showEvidenceSheet(context, x)),
                if (x.mockConfirmAvailable) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () async {
                      try {
                        await ref.read(apiProvider).mockConfirmTopUp(x.id);
                        refreshMoney(ref);
                        ref.invalidate(topUpProvider(x.id));
                      } catch (e) {
                        if (context.mounted) showErrorSnack(context, e);
                      }
                    },
                    child: const Text('تأكيد الدفع التجريبي (بيئة التطوير)'),
                  ),
                ],
              ] else if (x.status == 'PENDING_REVIEW')
                const _Hint(icon: Icons.hourglass_top_rounded, text: 'الإيصال قيد مراجعة المنصة. ستتحدث الحالة تلقائيًا وتصلك رسالة عند التأكيد.')
              else if (x.status == 'CONFIRMED')
                const _Hint(icon: Icons.check_circle_rounded, text: 'تمت إضافة المبلغ إلى محفظة المكتب.'),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEvidenceSheet(BuildContext context, TopUp x) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EvidenceSheet(topUpId: x.id),
    );
    if (done == true) ref.invalidate(topUpProvider(x.id));
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => ZoolCard(
        color: ZoolColors.secondarySoft,
        child: Row(children: [
          Icon(icon, color: ZoolColors.secondary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: ZoolColors.secondary))),
        ]),
      );
}

class _EvidenceSheet extends ConsumerStatefulWidget {
  const _EvidenceSheet({required this.topUpId});

  final String topUpId;

  @override
  ConsumerState<_EvidenceSheet> createState() => _EvidenceSheetState();
}

class _EvidenceSheetState extends ConsumerState<_EvidenceSheet> {
  final _ref = TextEditingController();
  final _note = TextEditingController();
  XFile? _file;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ref.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final f = await ImagePicker().pickImage(source: source, imageQuality: 80, maxWidth: 2000);
      if (f != null) setState(() => _file = f);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر فتح الكاميرا أو المعرض. تحقّق من الأذونات.');
    }
  }

  Future<void> _submit() async {
    if (_ref.text.trim().length < 3) return setState(() => _error = 'أدخل رقم العملية كما في الإيصال.');
    if (_file == null) return setState(() => _error = 'أرفق صورة الإيصال.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).submitEvidence(widget.topUpId, receiptPath: _file!.path, paymentReference: latinDigits(_ref.text.trim()), note: _note.text.trim());
      ref.read(bookingsVersionProvider.notifier).state++;
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('رفع إيصال الدفع', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextField(controller: _ref, decoration: const InputDecoration(labelText: 'رقم العملية / المرجع البنكي')),
            const SizedBox(height: 12),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: () => _pick(ImageSource.camera), icon: const Icon(Icons.photo_camera_rounded), label: const Text('كاميرا'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(onPressed: () => _pick(ImageSource.gallery), icon: const Icon(Icons.photo_library_rounded), label: const Text('المعرض'))),
              ],
            ),
            if (_file != null) ...[
              const SizedBox(height: 8),
              Text('مرفق: ${_file!.name}', style: Theme.of(context).textTheme.bodySmall),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: ZoolColors.error)),
            ],
            const SizedBox(height: 16),
            PrimaryButton(label: 'إرسال للمراجعة', busy: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
