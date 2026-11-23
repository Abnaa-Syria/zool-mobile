import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zool_core/zool_core.dart';
import 'package:zool_ui/zool_ui.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../data/models.dart';

/// Commission accruals by status, with the unsettled total.
class CommissionsPage extends ConsumerStatefulWidget {
  const CommissionsPage({super.key});

  @override
  ConsumerState<CommissionsPage> createState() => _CommissionsPageState();
}

class _CommissionsPageState extends ConsumerState<CommissionsPage> {
  static const _tabs = ['UNSETTLED', 'RESERVED', 'SETTLED', 'CLAWED_BACK'];
  Json? _summary;

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final t = Theme.of(context).textTheme;
    return DefaultTabController(
      length: _tabs.length,
      child: ZoolPage(
        title: 'العمولات',
        body: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(ZoolRadii.card)),
              child: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: [for (final s in _tabs) Tab(text: accrualStatus(s).$1)]),
            ),
            if (_summary != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: ZoolCard(
                  color: ZoolColors.secondarySoft,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('عمولات غير مُسوّاة (${_summary!.integer('unsettledCount')})', style: t.bodySmall),
                            Text(formatSdg(_summary!.integer('totalUnsettledMinor')), style: t.titleLarge?.copyWith(color: ZoolColors.secondary)),
                          ],
                        ),
                      ),
                      if (_summary!.date('lastSettledAt') != null)
                        Text('آخر تسوية\n${formatDayMonth(_summary!.date('lastSettledAt'))}', style: t.bodySmall, textAlign: TextAlign.end),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final status in _tabs)
                    PagedList<CommissionAccrual>(
                      reloadKey: status,
                      fetch: (page) async {
                        final res = await api.client.get('/broker/commissions', query: {'status': status, 'page': page, 'pageSize': 30});
                        final data = res.json;
                        if (mounted && (_summary == null || page == 1)) setState(() => _summary = data);
                        return (items: data.list('items').map(CommissionAccrual.new).toList(), totalPages: res.totalPages);
                      },
                      empty: const EmptyView(title: 'لا توجد عمولات هنا', icon: IconsaxPlusLinear.percentage_circle),
                      itemBuilder: (context, a) {
                        final (label, tone) = accrualStatus(a.status);
                        return ZoolCard(
                          onTap: () => context.push('/booking/${a.bookingId}'),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(formatSdg(a.amountMinor), style: t.titleSmall?.copyWith(color: ZoolColors.secondary)),
                                    Text('من حجز بقيمة ${formatSdg(a.bookingTotalMinor)} · ${formatDayMonth(a.createdAt)}', style: t.bodySmall),
                                  ],
                                ),
                              ),
                              StatusBadge(label, tone: tone),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
