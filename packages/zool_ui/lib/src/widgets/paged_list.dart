import 'package:flutter/material.dart';

import '../theme.dart';
import 'states.dart';

/// One page from a list endpoint: items + `meta.totalPages`.
typedef PageResult<T> = ({List<T> items, int totalPages});

/// Infinite list over `page` / `pageSize` endpoints with pull-to-refresh, empty and error states.
/// Change [reloadKey] to reload from page 1 (e.g. a new tab, search text or data version).
class PagedList<T> extends StatefulWidget {
  const PagedList({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    required this.empty,
    this.reloadKey,
    this.padding = const EdgeInsets.all(16),
    this.separator = 10,
    this.header,
  });

  final Future<PageResult<T>> Function(int page) fetch;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget empty;
  final Object? reloadKey;
  final EdgeInsetsGeometry padding;
  final double separator;
  final Widget? header;

  @override
  State<PagedList<T>> createState() => _PagedListState<T>();
}

class _PagedListState<T> extends State<PagedList<T>> {
  final List<T> _items = [];
  int _page = 0;
  int _totalPages = 1;
  bool _loading = false;
  Object? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(PagedList<T> old) {
    super.didUpdateWidget(old);
    if (old.reloadKey != widget.reloadKey) _reload();
  }

  Future<void> _reload() async {
    _generation++;
    setState(() {
      _items.clear();
      _page = 0;
      _totalPages = 1;
      _error = null;
      _loading = false;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || _page >= _totalPages) return;
    final gen = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.fetch(_page + 1);
      if (!mounted || gen != _generation) return;
      setState(() {
        _items.addAll(res.items);
        _page++;
        _totalPages = res.totalPages < 1 ? 1 : res.totalPages;
      });
    } catch (e) {
      if (mounted && gen == _generation) setState(() => _error = e);
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = widget.header;
    Widget body;
    if (_items.isEmpty && _loading) {
      body = ListView(children: [?header, const LoadingView()]);
    } else if (_items.isEmpty && _error != null) {
      body = ListView(children: [?header, ErrorView(error: _error!, onRetry: _reload)]);
    } else if (_items.isEmpty) {
      body = ListView(padding: widget.padding, children: [?header, widget.empty]);
    } else {
      final extra = header == null ? 0 : 1;
      body = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) _loadMore();
          return false;
        },
        child: ListView.separated(
          padding: widget.padding,
          itemCount: _items.length + extra + 1,
          separatorBuilder: (_, i) => SizedBox(height: i < extra ? 0 : widget.separator),
          itemBuilder: (context, i) {
            if (i < extra) return header!;
            final idx = i - extra;
            if (idx < _items.length) return widget.itemBuilder(context, _items[idx]);
            if (_error != null) {
              return TextButton(onPressed: _loadMore, child: const Text('تعذّر تحميل المزيد — إعادة المحاولة'));
            }
            if (_page < _totalPages) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator(color: ZoolColors.secondary, strokeWidth: 2.5)),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      );
    }
    return RefreshIndicator(color: ZoolColors.secondary, onRefresh: _reload, child: body);
  }
}
