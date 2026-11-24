import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';

/// Login (Figma 3074:2136): phone OTP; any new number creates the account (C22: no email tab).
class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return OtpLoginScreen(
      onRequest: session.requestOtp,
      onVerify: (phone, code, challengeId) async {
        final flags = ref.read(appFlagsProvider);
        final data = await session.verifyOtp(phone: phone, code: code, challengeId: challengeId);
        // C1: the one-field «your name» step for a new customer (or one without a name yet).
        flags.needsName = data.flag('isNewCustomer') || data.obj('customer').strOrNull('displayName') == null;
        ref.invalidate(meProvider);
      },
    );
  }
}
