import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../data/models.dart';
import '../boarding/board_action.dart';
import '../boarding/boarding_page.dart';
import '../trips/trip_detail_page.dart';

/// «المسح» tab: the trip being boarded and a button to open the camera (the camera itself runs
/// full screen so it is off whenever the scanner is not on screen).
class ScanTab extends ConsumerWidget {
  const ScanTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    return ZoolPage(
      header: const Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          'مسح التذاكر',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ZoolColors.textStrong),
        ),
      ),
      body: AsyncBody<DriverDashboard>(
        value: dash,
        onRetry: () => ref.invalidate(dashboardProvider),
        data: (d) {
          final trip = d.currentTrip;
          if (trip == null || trip.status != 'BOARDING') {
            final next = trip ?? d.nextTrip;
            return EmptyView(
              title: trip?.status == 'IN_PROGRESS' ? 'انطلقت الرحلة' : 'لا توجد رحلة في مرحلة الصعود',
              message: trip?.status == 'IN_PROGRESS'
                  ? 'يتوقف المسح بعد الانطلاق. يمكنك مراجعة قائمة الركاب من تفاصيل الرحلة.'
                  : 'ابدأ الصعود من تفاصيل رحلتك ثم امسح تذاكر الركاب من هنا.',
              icon: IconsaxPlusLinear.scan_barcode,
              action: next == null
                  ? null
                  : OutlinedButton(
                      onPressed: () => context.push('/trip/${next.id}'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(200, 44)),
                      child: const Text('تفاصيل الرحلة'),
                    ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              ZoolCard(
                radius: ZoolRadii.bigCard,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(color: ZoolColors.secondarySoft, borderRadius: BorderRadius.circular(24)),
                      child: const Icon(IconsaxPlusLinear.scan_barcode, size: 52, color: ZoolColors.brand),
                    ),
                    const SizedBox(height: 14),
                    Text(trip.routeLabel, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      'صعد ${trip.boarded} من ${trip.booked} · ${relativeDeparture(trip.departureAt)}',
                      style: const TextStyle(fontSize: 12, color: ZoolColors.textSecondary),
                    ),
                    const SizedBox(height: 18),
                    PrimaryButton(label: 'فتح الكاميرا', icon: IconsaxPlusLinear.camera, onPressed: () => context.push('/trip/${trip.id}/scan')),
                    const SizedBox(height: 8),
                    TextButton(onPressed: () => context.push('/trip/${trip.id}/passengers'), child: const Text('قائمة الركاب')),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// QR scanner (Figma 3043:3291) → result card (3043:3312). Every result has its own state:
/// valid (board, with cash when due), already boarded, another trip, cancelled, unknown code.
class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key, required this.tripId});

  final String tripId;

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.normal, formats: const [BarcodeFormat.qrCode, BarcodeFormat.code128]);
  bool _handling = false;
  String? _lastCode;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final code = capture.barcodes.map((b) => b.rawValue).whereType<String>().where((s) => s.trim().length >= 4).firstOrNull;
    if (code == null || _handling) return;
    // Ignore the same code for a moment after its sheet closes.
    if (code == _lastCode && DateTime.now().difference(_lastAt) < const Duration(seconds: 3)) return;
    await _check(code.trim());
  }

  Future<void> _check(String code) async {
    setState(() => _handling = true);
    try {
      final result = await ref.read(apiProvider).scan(widget.tripId, code);
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        isScrollControlled: true,
        builder: (_) => ScanResultSheet(tripId: widget.tripId, result: result),
      );
    } catch (e) {
      if (mounted) showMessageSnack(context, driverErrorText(e), success: false);
    } finally {
      _lastCode = code;
      _lastAt = DateTime.now();
      if (mounted) setState(() => _handling = false);
    }
  }

  Future<void> _manual() async {
    final ctl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إدخال رقم التذكرة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctl,
          autofocus: true,
          textDirection: TextDirection.ltr,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'ZG-20261124-…'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(ctl.text), child: const Text('تحقق')),
        ],
      ),
    );
    final typed = code?.trim().toUpperCase() ?? '';
    if (typed.length < 4 || !mounted) return;
    // The scan endpoint only trusts the signed QR; a typed number is looked up in this trip's
    // manifest and boarded manually from the passenger sheet (full number or its last digits).
    setState(() => _handling = true);
    try {
      final manifest = await ref.read(apiProvider).manifest(widget.tripId);
      final match = manifest.passengers.where((p) => p.ticketNumber == typed || p.ticketNumber.endsWith(typed)).toList();
      if (!mounted) return;
      if (match.length == 1) {
        await showPassengerSheet(context, widget.tripId, match.single, tripStatus: manifest.status);
      } else {
        showMessageSnack(context, match.isEmpty ? 'لا توجد تذكرة بهذا الرقم في هذه الرحلة.' : 'أدخل رقم التذكرة كاملًا.', success: false);
      }
    } catch (e) {
      if (mounted) showMessageSnack(context, driverErrorText(e), success: false);
    } finally {
      if (mounted) setState(() => _handling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(tripProvider(widget.tripId)).value;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => _CameraError(error: error, onManual: _manual),
            ),
          ),
          const Positioned.fill(child: _Viewfinder()),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    RoundIconButton(icon: IconsaxPlusLinear.arrow_right, tooltip: 'رجوع', onTap: () => Navigator.of(context).maybePop()),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'مسح التذكرة',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          if (trip != null) Text('صعد ${trip.boarded} من ${trip.booked}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                    ValueListenableBuilder(
                      valueListenable: _controller,
                      builder: (context, state, _) => RoundIconButton(
                        icon: state.torchState == TorchState.on ? IconsaxPlusBold.flash_1 : IconsaxPlusLinear.flash_1,
                        tooltip: 'الإضاءة',
                        onTap: _controller.toggleTorch,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(14)),
                    child: _handling
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                              SizedBox(width: 10),
                              Text('جارٍ التحقق من التذكرة…', style: TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          )
                        : const Text(
                            'وجّه الكاميرا نحو رمز QR على تذكرة الراكب',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _handling ? null : _manual,
                    icon: const Icon(IconsaxPlusLinear.keyboard, size: 18),
                    label: const Text('إدخال رقم التذكرة يدويًا'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black45,
                      side: const BorderSide(color: Colors.white54),
                      minimumSize: const Size(0, 46),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final side = (c.maxWidth * 0.68).clamp(200.0, 320.0);
        return Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _MaskPainter(side))),
            Center(
              child: Container(
                width: side,
                height: side,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF82F2A8), width: 3),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Dims the camera outside the centred square window.
class _MaskPainter extends CustomPainter {
  _MaskPainter(this.side);

  final double side;

  @override
  void paint(Canvas canvas, Size size) {
    final window = RRect.fromRectAndRadius(Rect.fromCenter(center: size.center(Offset.zero), width: side, height: side), const Radius.circular(24));
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(window);
    canvas.drawPath(path, Paint()..color = Colors.black54);
  }

  @override
  bool shouldRepaint(_MaskPainter old) => old.side != side;
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error, required this.onManual});

  final MobileScannerException error;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: const Color(0xFF1C2A22),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(IconsaxPlusLinear.camera_slash, color: Colors.white70, size: 48),
              const SizedBox(height: 12),
              Text(
                denied ? 'اسمح للتطبيق باستخدام الكاميرا من إعدادات الهاتف لمسح التذاكر.' : 'تعذّر تشغيل الكاميرا.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Result card (Figma 3043:3312): headline + chip, passenger, seat, trip line, action.
class ScanResultSheet extends ConsumerStatefulWidget {
  const ScanResultSheet({super.key, required this.tripId, required this.result});

  final String tripId;
  final ScanResult result;

  @override
  ConsumerState<ScanResultSheet> createState() => _ScanResultSheetState();
}

class _ScanResultSheetState extends ConsumerState<ScanResultSheet> {
  bool _busy = false;

  Future<void> _board(ManifestEntry p) async {
    setState(() => _busy = true);
    final ok = await boardPassenger(context, ref, widget.tripId, p, method: 'QR');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final p = r.ticket;
    final (title, chip, color) = scanResultText(r);
    final explain = switch (r.result) {
      'ALREADY_BOARDED' => p?.boardedAt != null ? 'سُجّل صعود هذا الراكب الساعة ${formatTime(p!.boardedAt)}.' : 'سُجّل صعود هذا الراكب من قبل.',
      'WRONG_TRIP' => 'هذه التذكرة لرحلة أخرى. وجّه الراكب إلى الباص الصحيح.',
      'CANCELLED' => 'هذه التذكرة ملغاة ولا يُسمح بالصعود بها.',
      'INVALID' => 'لم يتم التعرف على الرمز. اطلب من الراكب فتح التذكرة من التطبيق أو أدخل رقمها يدويًا.',
      _ => null,
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(r.isValid ? IconsaxPlusBold.tick_circle : IconsaxPlusBold.info_circle, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: ZoolColors.textStrong),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    chip,
                    style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (explain != null) ...[const SizedBox(height: 10), Text(explain, style: const TextStyle(fontSize: 13, color: ZoolColors.textSecondary))],
            if (p != null) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: ZoolColors.divider),
              ),
              InfoRow('الراكب', p.fullName, bold: true),
              InfoRow('المقعد المخصص', 'مقعد ${p.seatLabel}', bold: true, valueColor: ZoolColors.brand),
              InfoRow('خط الرحلة', r.tripLabel, bold: true),
              InfoRow('المغادرة', formatDateTime(r.departureAt)),
              if (p.cashToCollectMinor > 0) InfoRow('يدفع نقدًا', formatSdg(p.cashToCollectMinor), bold: true, valueColor: ZoolColors.warning),
            ],
            const SizedBox(height: 16),
            if (r.isValid && p != null)
              PrimaryButton(
                label: p.cashToCollectMinor > 0 ? 'استلام المبلغ وتسجيل الصعود' : 'تسجيل ومتابعة المسح',
                color: ZoolColors.brand,
                busy: _busy,
                onPressed: _busy ? null : () => _board(p),
              )
            else
              PrimaryButton(label: 'متابعة المسح', color: ZoolColors.brand, onPressed: () => Navigator.of(context).pop()),
            if (r.isValid) TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('إلغاء')),
          ],
        ),
      ),
    );
  }
}
