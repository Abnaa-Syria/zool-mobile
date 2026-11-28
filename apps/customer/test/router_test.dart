import 'package:customer/app/providers.dart';
import 'package:customer/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_push/zool_push.dart';

void main() {
  testWidgets('onboarding → «ابدأ الآن» → login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final session = AuthSession(authPath: '/customer/auth', store: MemoryTokenStore());
    await session.restore();
    final flags = AppFlags(false);
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionProvider.overrideWithValue(session), appFlagsProvider.overrideWithValue(flags)],
      child: CustomerApp(session: session, flags: flags, push: ZoolPush(app: ZoolApp.customer, client: ApiClient(session), devicesPath: '/customer/devices')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('التالي'), findsOneWidget);
    await tester.tap(find.text('تخطي'));
    await tester.pumpAndSettle();
    expect(find.text('أدخل رقم هاتفك'), findsOneWidget);
    expect(flags.onboardingSeen, isTrue);
    expect(Directionality.of(tester.element(find.text('أدخل رقم هاتفك'))), TextDirection.rtl);
  });
}
