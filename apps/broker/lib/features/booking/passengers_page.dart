import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_ui/zool_ui.dart';

import 'flow.dart';
import 'hold_expired.dart';

/// Passenger data (3083:2634): one form per seat — name, phone, gender (FEMALE required on a
/// women-only seat), optional ID number.
class PassengersPage extends ConsumerStatefulWidget {
  const PassengersPage({super.key});

  @override
  ConsumerState<PassengersPage> createState() => _PassengersPageState();
}

class _PassengersPageState extends ConsumerState<PassengersPage> {
  bool _showErrors = false;

  void _continue() {
    final flow = ref.read(bookingFlowProvider);
    final invalid = [
      for (var i = 0; i < flow.passengers.length; i++) validatePassenger(flow.passengers[i], womenOnly: flow.womenOnlyAt(i)),
    ].any((e) => e.name != null || e.phone != null || e.gender != null);
    if (invalid) {
      setState(() => _showErrors = true);
      showMessageSnack(context, 'أكمل بيانات الركاب المطلوبة.', success: false);
      return;
    }
    context.push('/book/review');
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(bookingFlowProvider);
    final out = flow.outbound;
    if (out == null) {
      return const ZoolPage(title: 'بيانات المسافرين', body: EmptyView(title: 'ابدأ الحجز من جديد', icon: IconsaxPlusLinear.ticket));
    }
    return ZoolPage(
      title: 'بيانات المسافرين',
      bottomBar: ZoolBottomBar(child: PrimaryButton(label: 'مراجعة الحجز والأسعار', onPressed: _continue)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const Text('أدخل تفاصيل الركاب بدقة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ZoolColors.textStrong)),
          Text('مطلوب لإصدار تذكرة ${out.trip.companyName} الرسمية', style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
          const SizedBox(height: 12),
          if (flow.expiresAt != null) ...[
            HoldCountdown(expiresAt: flow.expiresAt!, onExpired: () => onHoldExpired(context, ref)),
            const SizedBox(height: 12),
          ],
          for (var i = 0; i < flow.passengers.length; i++) ...[
            _PassengerForm(
              key: ValueKey('p$i'),
              index: i,
              seatLabel: [out.seats[i].label, if (flow.inbound != null) flow.inbound!.seats[i].label].join(' / '),
              womenOnly: flow.womenOnlyAt(i),
              draft: flow.passengers[i],
              showErrors: _showErrors,
              onChanged: (p) => ref.read(bookingFlowProvider.notifier).setPassenger(i, p),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

const _ordinals = ['الأول', 'الثاني', 'الثالث', 'الرابع', 'الخامس', 'السادس', 'السابع', 'الثامن', 'التاسع'];

class _PassengerForm extends StatefulWidget {
  const _PassengerForm({
    super.key,
    required this.index,
    required this.seatLabel,
    required this.womenOnly,
    required this.draft,
    required this.showErrors,
    required this.onChanged,
  });

  final int index;
  final String seatLabel;
  final bool womenOnly;
  final PassengerDraft draft;
  final bool showErrors;
  final ValueChanged<PassengerDraft> onChanged;

  @override
  State<_PassengerForm> createState() => _PassengerFormState();
}

class _PassengerFormState extends State<_PassengerForm> {
  late final _name = TextEditingController(text: widget.draft.fullName);
  late final _phone = TextEditingController(text: widget.draft.phone);
  late final _id = TextEditingController(text: widget.draft.idNumber);

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _id.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final err = widget.showErrors ? validatePassenger(d, womenOnly: widget.womenOnly) : (name: null, phone: null, gender: null);
    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6, top: 12),
          child: Text(text, style: const TextStyle(fontSize: 13, color: ZoolColors.textSecondary)),
        );
    return ZoolCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'المسافر ${widget.index < _ordinals.length ? _ordinals[widget.index] : widget.index + 1} (مقعد ${widget.seatLabel})',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ZoolColors.textStrong),
                ),
              ),
              if (widget.womenOnly) const StatusBadge('مقعد سيدات', tone: BadgeTone.brand),
            ],
          ),
          label('الاسم الكامل (مطابق للهوية)'),
          TextField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(hintText: 'مثال: أحمد محمد علي', errorText: err.name),
            onChanged: (v) => widget.onChanged(d.copyWith(fullName: v)),
          ),
          label('رقم الجوال'),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            textDirection: TextDirection.ltr,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩+ ]')), LengthLimitingTextInputFormatter(16)],
            decoration: InputDecoration(hintText: '09XXXXXXXX', errorText: err.phone),
            onChanged: (v) => widget.onChanged(d.copyWith(phone: v)),
          ),
          label('الجنس${widget.womenOnly ? ' (مطلوب: مقعد سيدات)' : ''}'),
          Row(
            children: [
              for (final (value, text) in const [('MALE', 'ذكر'), ('FEMALE', 'أنثى')]) ...[
                Expanded(
                  child: ChoiceChip(
                    label: SizedBox(width: double.infinity, child: Text(text, textAlign: TextAlign.center)),
                    selected: d.gender == value,
                    showCheckmark: false,
                    onSelected: (on) => widget.onChanged(d.copyWith(gender: () => on ? value : null)),
                  ),
                ),
                if (value == 'MALE') const SizedBox(width: 10),
              ],
            ],
          ),
          if (err.gender != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(err.gender!, style: const TextStyle(color: ZoolColors.error, fontSize: 12))),
          label('رقم الهوية الوطنية / الجواز (اختياري)'),
          TextField(
            controller: _id,
            decoration: const InputDecoration(hintText: 'رقم الهوية'),
            onChanged: (v) => widget.onChanged(d.copyWith(idNumber: v)),
          ),
        ],
      ),
    );
  }
}
