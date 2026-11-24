import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';

/// C1 — «اسمك» after the first login (`PATCH /customer/me { displayName }`).
class NamePage extends ConsumerStatefulWidget {
  const NamePage({super.key});

  @override
  ConsumerState<NamePage> createState() => _NamePageState();
}

class _NamePageState extends ConsumerState<NamePage> {
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) return setState(() => _error = 'اكتب اسمك (حرفان على الأقل).');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).updateMe(displayName: name);
      ref.invalidate(meProvider);
      ref.read(appFlagsProvider).needsName = false;
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ZoolPage(
      bottomBar: ZoolBottomBar(child: PrimaryButton(label: 'متابعة', busy: _busy, onPressed: _save)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
        children: [
          const Center(child: ZoolWordmark()),
          const SizedBox(height: 36),
          const Text('أهلًا بك في زول قو 👋', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: ZoolColors.textStrong)),
          const Text('ما اسمك؟ سنستخدمه في تذاكرك وحجوزاتك.', style: TextStyle(fontSize: 14, color: ZoolColors.textSecondary)),
          const SizedBox(height: 24),
          TextField(
            controller: _name,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(hintText: 'الاسم الكامل', errorText: _error, fillColor: Colors.white),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _busy ? null : () => ref.read(appFlagsProvider).needsName = false,
            child: const Text('لاحقًا'),
          ),
        ],
      ),
    );
  }
}
