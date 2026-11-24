import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zool_core/zool_core.dart';

import '../theme.dart';
import 'basics.dart';

/// Phone + OTP login from the design (Figma 3074:2136): ZOOL GO wordmark, «أدخل رقم هاتفك»,
/// +249 chip and phone field, «التالي». Phone only (no email tab in v1). Shared by the three apps.
///
/// [onRequest] calls `POST …/otp/request` and returns its data (`challengeId`, `cooldownSeconds`,
/// `devOtp` in development); [onVerify] signs in.
class OtpLoginScreen extends StatefulWidget {
  const OtpLoginScreen({
    super.key,
    required this.onRequest,
    required this.onVerify,
    this.title = 'أدخل رقم هاتفك',
    this.subtitle = 'سنرسل لك رمز التحقق للتأكيد',
    this.badge,
  });

  final String title;
  final String subtitle;

  /// Small label under the logo (e.g. «تطبيق الوكلاء»).
  final String? badge;
  final Future<Json> Function(String phone) onRequest;
  final Future<void> Function(String phone, String code, String? challengeId) onVerify;

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

  static final _glass = BoxDecoration(
    color: Colors.white.withValues(alpha: 0.6),
    border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
    borderRadius: BorderRadius.circular(ZoolRadii.button),
  );

  @override
  Widget build(BuildContext context) {
    final codeStep = _normalized != null;
    return Scaffold(
      backgroundColor: ZoolColors.background,
      body: Stack(
        children: [
          Positioned(
            top: MediaQuery.sizeOf(context).height * 0.057,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: SvgPicture.asset('assets/icons/login_decor.svg', package: 'zool_ui', width: MediaQuery.sizeOf(context).width, fit: BoxFit.fitWidth),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
              children: [
                const Center(child: ZoolWordmark()),
                if (widget.badge != null) ...[
                  const SizedBox(height: 10),
                  Center(child: StatusBadge(widget.badge!, tone: BadgeTone.brand)),
                ],
                const SizedBox(height: 32),
                Text(
                  codeStep ? 'رمز التحقق' : widget.title,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ZoolColors.textStrong, height: 1.5),
                ),
                Text(
                  codeStep ? 'أدخل الرمز المرسل إلى ${formatPhone(_normalized)}' : widget.subtitle,
                  style: const TextStyle(fontSize: 14, color: ZoolColors.textStrong),
                ),
                const SizedBox(height: 24),
                if (!codeStep)
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      children: [
                        Container(
                          width: 96,
                          height: 48,
                          decoration: _glass,
                          alignment: Alignment.center,
                          child: const Text('🇸🇩  +249', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ZoolColors.textStrong)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: _glass,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.center,
                            child: TextField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              autofillHints: const [AutofillHints.telephoneNumberNational],
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩+ ]')), LengthLimitingTextInputFormatter(16)],
                              style: const TextStyle(fontSize: 16, letterSpacing: 0.5),
                              decoration: const InputDecoration(
                                hintText: '9XX XXX XXX',
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onSubmitted: (_) => _request(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Container(
                      height: 56,
                      decoration: _glass,
                      alignment: Alignment.center,
                      child: TextField(
                        controller: _code,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        textAlign: TextAlign.center,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩]')), LengthLimitingTextInputFormatter(8)],
                        style: const TextStyle(fontSize: 24, letterSpacing: 10, fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(
                          hintText: '••••••',
                          filled: false,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        onSubmitted: (_) => _verify(),
                      ),
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
                  Text(_error!, style: const TextStyle(color: ZoolColors.error, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                PrimaryButton(label: codeStep ? 'تأكيد' : 'التالي', busy: _busy, onPressed: codeStep ? _verify : _request),
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
        ],
      ),
    );
  }
}

/// The ZOOL GO wordmark from the design (two SVG parts, LTR).
class ZoolWordmark extends StatelessWidget {
  const ZoolWordmark({super.key, this.height = 39});

  final double height;

  @override
  Widget build(BuildContext context) {
    final scale = height / 39.117;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/icons/logo_zool.svg', package: 'zool_ui', width: 152.054 * scale, height: 39.117 * scale),
          SizedBox(width: 12.75 * scale),
          SvgPicture.asset('assets/icons/logo_go.svg', package: 'zool_ui', width: 77.198 * scale, height: 38.53 * scale),
        ],
      ),
    );
  }
}

/// The ZG brand mark (onboarding / splash).
class ZoolLogo extends StatelessWidget {
  const ZoolLogo({super.key, this.size = 64});

  /// Width of the mark (its height is 65 %).
  final double size;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/icons/logo_mark.svg', package: 'zool_ui', width: size, height: size * 0.65);
}
