import 'dart:async';

import 'package:flutter/material.dart';

import 'zool_push.dart';

/// App-root glue: a tapped notification opens its screen, and a message that arrives while the
/// app is open shows as a snack bar (with «عرض») and refreshes whatever [onMessage] refreshes.
/// Give [pushMessenger] to `MaterialApp.scaffoldMessengerKey`.
mixin PushRouting<T extends StatefulWidget> on State<T> {
  final pushMessenger = GlobalKey<ScaffoldMessengerState>();
  final _subs = <StreamSubscription<PushNote>>[];

  void listenPush(ZoolPush push, {required void Function(PushNote note) open, VoidCallback? onMessage}) {
    _subs
      ..add(push.taps.listen(open))
      ..add(push.foreground.listen((note) {
        onMessage?.call();
        if (note.title.isEmpty && note.body.isEmpty) return;
        pushMessenger.currentState?.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (note.title.isNotEmpty) Text(note.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (note.body.isNotEmpty) Text(note.body),
            ]),
            action: SnackBarAction(label: 'عرض', onPressed: () => open(note)),
          ),
        );
      }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
