import 'package:firebase_core/firebase_core.dart';

/// Firebase project of the ZoolGo apps (`zoolgo-568d8`), from `google-services.json`.
/// These are public client identifiers (shipped in every APK), not secrets.
enum ZoolApp {
  customer('1:181838035019:android:4d241b0e8969aa65e235ce'),
  broker('1:181838035019:android:927afb9159082cbfe235ce'),
  driver('1:181838035019:android:41ea8b0af5d8771ce235ce');

  const ZoolApp(this.androidAppId);

  final String androidAppId;

  FirebaseOptions get androidOptions => FirebaseOptions(
        apiKey: 'AIzaSyDWJGSXb53tQ0f2VlhJ07k2UQi-pn9A064',
        appId: androidAppId,
        messagingSenderId: '181838035019',
        projectId: 'zoolgo-568d8',
        storageBucket: 'zoolgo-568d8.firebasestorage.app',
      );
}
