import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/providers.dart';

final _contentProvider = FutureProvider.autoDispose.family<Json, String>((ref, slug) => ref.watch(apiProvider).content(slug));

/// Legal pages (privacy 3074:3059, terms) from `GET /public/content/:slug`.
class ContentPage extends ConsumerWidget {
  const ContentPage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(_contentProvider(slug));
    return ZoolPage(
      title: page.value?.str('titleAr') ?? (slug == 'privacy' ? 'سياسة الأمان والخصوصية' : 'الشروط والأحكام'),
      body: AsyncBody(
        value: page,
        onRetry: () => ref.invalidate(_contentProvider(slug)),
        data: (p) => ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
          for (final s in p.list('sections')) ...[
            ZoolCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.str('titleAr'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(s.str('bodyAr'), style: const TextStyle(fontSize: 14, height: 1.7, color: ZoolColors.textSecondary)),
              ]),
            ),
            const SizedBox(height: 10),
          ],
          if (p.date('updatedAt') != null) Text('آخر تحديث: ${formatLongDate(p.date('updatedAt'))}', style: const TextStyle(fontSize: 12, color: ZoolColors.textMuted)),
        ]),
      ),
    );
  }
}
