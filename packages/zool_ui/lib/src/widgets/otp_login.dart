import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zool_core/zool_core.dart';

import '../theme.dart';
import 'basics.dart';

/// Phone + OTP login shared by the three apps (phone only, +249 by default).
///
/// [onRequest] calls `POST …/otp/request` and returns its data (`challengeId`, `cooldownSeconds`,
/// `devOtp` in development); [onVerify] signs in.
class OtpLoginScreen extends StatefulWidget {
  const OtpLoginScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onRequest,
    required this.onVerify,
    this.logo,
  });

  final String title;
  final String subtitle;
  final Future<Json> Function(String phone) onRequest;
  final Future<void> Function(String phone, String code, String? challengeId) onVerify;
  final Widget? logo;

  @override
  State<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends State<OtpLoginScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  String? _normalized;
  String? _challengeId;
  String? _devOtp;
  String? _error;
  bool _busy = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown = _cooldown > 0 ? _cooldown - 1 : 0);
      if (_cooldown == 0) t.cancel();
    });
  }

  Future<void> _request() async {
    final phone = normalizeSudanPhone(_phone.text);
    if (phone == null) {
      setState(() => _error = 'أدخل رقم جوال صحيحًا (مثال: 912345678)');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.onRequest(phone);
      if (!mounted) return;
      setState(() {
        _normalized = phone;
        _challengeId = data.strOrNull('challengeId');
        _devOtp = data.strOrNull('devOtp');
        _code.clear();
      });
      _startCooldown(data.integer('cooldownSeconds', 60));
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final code = latinDigits(_code.text.trim());
    if (code.length < 4) {
      setState(() => _error = 'أدخل رمز التحقق المرسل إلى جوالك');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onVerify(_normalized!, code, _challengeId);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final codeStep = _normalized != null;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Center(child: widget.logo ?? const ZoolLogo(size: 76)),
            const SizedBox(height: 28),
            Text(codeStep ? 'رمز التحقق' : widget.title, style: t.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              codeStep ? 'أدخل الرمز المرسل إلى ${formatPhone(_normalized)}' : widget.subtitle,
              style: t.bodyMedium?.copyWith(color: ZoolColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            if (!codeStep)
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩+ ]')), LengthLimitingTextInputFormatter(16)],
                  style: const TextStyle(fontSize: 18, letterSpacing: 1),
                  decoration: const InputDecoration(
                    prefixText: '+249  ',
                    hintText: '9XXXXXXXX',
                    labelText: 'رقم الجوال',
                  ),
                  onSubmitted: (_) => _request(),
                ),
              )
            else ...[
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  controller: _code,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]')), LengthLimitingTextInputFormatter(8)],
                  style: const TextStyle(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.w700),
                  decoration: const InputDecoration(hintText: '••••••'),
                  onSubmitted: (_) => _verify(),
                ),
              ),
              if (_devOtp != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _code.text = _devOtp!),
                  child: Text('بيئة التطوير: استخدم الرمز $_devOtp'),
                ),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: ZoolColors.error), textAlign: TextAlign.center),
            ],
            const SizedBox(height: 24),
            PrimaryButton(label: codeStep ? 'تأكيد' : 'إرسال رمز التحقق', busy: _busy, onPressed: codeStep ? _verify : _request),
            if (codeStep) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _busy || _cooldown > 0 ? null : _request,
                    child: Text(_cooldown > 0 ? 'إعادة الإرسال بعد $_cooldown ث' : 'إعادة إرسال الرمز'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _normalized = null;
                              _error = null;
                            }),
                    child: const Text('تغيير الرقم'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Brand mark: the ZoolGo bus in a green rounded square (no image asset needed).
class ZoolLogo extends StatelessWidget {
  const ZoolLogo({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: ZoolColors.secondary, borderRadius: BorderRadius.circular(size * 0.28)),
          child: Icon(Icons.directions_bus_filled_rounded, color: Colors.white, size: size * 0.56),
        ),
        const SizedBox(height: 8),
        Text('زول قو', style: TextStyle(fontSize: size * 0.3, fontWeight: FontWeight.w700, color: ZoolColors.secondary)),
      ],
    );
  }
}
