import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';

/// Login: phone OTP for drivers registered by their carrier (no self sign-up).
class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return OtpLoginScreen(
      badge: 'تطبيق السائق',
      subtitle: 'أدخل الرقم المسجّل لدى شركة النقل',
      onRequest: session.requestOtp,
      onVerify: (phone, code, challengeId) async {
        await session.verifyOtp(phone: phone, code: code, challengeId: challengeId);
        ref.invalidate(meProvider);
      },
    );
  }
}
