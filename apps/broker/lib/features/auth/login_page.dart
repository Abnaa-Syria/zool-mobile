import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';

/// B1 — broker login (phone + OTP on `/broker/auth`).
class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return OtpLoginScreen(
      title: 'تسجيل دخول الوكيل',
      subtitle: 'أدخل رقم الجوال المسجّل لمكتبك لدى زول قو',
      onRequest: session.requestOtp,
      onVerify: (phone, code, challengeId) async {
        await session.verifyOtp(phone: phone, code: code, challengeId: challengeId);
        ref.invalidate(meProvider);
      },
    );
  }
}
