import 'package:flutter/material.dart';
import 'package:zool_ui/zool_ui.dart';

/// Splash (Figma 3074:2086): green gradient with the ZG mark while the session restores.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.centerEnd,
            end: AlignmentDirectional.centerStart,
            colors: [Color(0xFF146240), Color(0xFF1E7B55)],
          ),
        ),
        child: Center(child: ZoolLogo(size: 160)),
      ),
    );
  }
}
