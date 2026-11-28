import 'package:broker/app/providers.dart';
import 'package:broker/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_push/zool_push.dart';

void main() {
  testWidgets('signed out → the login screen (phone step, RTL)', (tester) async {
    final session = AuthSession(authPath: '/broker/auth', store: MemoryTokenStore());
    await session.restore(); // no stored token → signed out, no network
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionProvider.overrideWithValue(session)],
      child: BrokerApp(session: session, push: ZoolPush(app: ZoolApp.broker, client: ApiClient(session), devicesPath: '/broker/devices')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('أدخل رقم هاتفك'), findsOneWidget);
    expect(find.text('تطبيق مكاتب الوكلاء'), findsOneWidget);
    expect(Directionality.of(tester.element(find.text('أدخل رقم هاتفك'))), TextDirection.rtl);

    // Invalid phone shows the Arabic validation message without calling the API.
    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.text('التالي'));
    await tester.pump();
    expect(find.textContaining('أدخل رقم جوال صحيحًا'), findsOneWidget);
  });
}
