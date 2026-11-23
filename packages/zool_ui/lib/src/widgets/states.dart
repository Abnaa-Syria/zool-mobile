import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zool_core/zool_core.dart';

import '../theme.dart';

/// Centered spinner.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: ZoolColors.secondary)));
}

/// Empty state: icon, title, optional hint and action.
class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.title, this.message, this.icon = Icons.inbox_outlined, this.action});

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: ZoolColors.secondarySoft, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: ZoolColors.secondary),
            ),
            const SizedBox(height: 16),
            Text(title, style: t.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(message!, style: t.bodySmall, textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Error state with the Arabic message for the error code and a retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final offline = error is ApiException && (error as ApiException).isNetwork;
    return EmptyView(
      icon: offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      title: offline ? 'لا يوجد اتصال' : 'حدث خطأ',
      message: errorMessage(error),
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(minimumSize: const Size(160, 44)),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
    );
  }
}

/// Renders an [AsyncValue]: spinner on first load, error with retry, then [data]. While
/// refreshing it keeps the previous data on screen.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.data, this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) return data(value.requireValue);
    if (value.hasError) return ErrorView(error: value.error!, onRetry: onRetry);
    return const LoadingView();
  }
}

/// Snack bars.
void showErrorSnack(BuildContext context, Object error) => _snack(context, errorMessage(error), ZoolColors.error);

void showMessageSnack(BuildContext context, String message, {bool success = true}) =>
    _snack(context, message, success ? ZoolColors.secondary : ZoolColors.text);

void _snack(BuildContext context, String message, Color color) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
}

/// Yes/no confirmation; returns true when confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  String confirmLabel = 'تأكيد',
  String cancelLabel = 'تراجع',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
      content: content ?? (message == null ? null : Text(message)),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                child: Text(cancelLabel),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  backgroundColor: destructive ? ZoolColors.error : ZoolColors.primary,
                ),
                child: Text(confirmLabel),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Informational dialog with one button.
Future<void> showInfoDialog(BuildContext context, {required String title, required String message, String button = 'حسنًا'}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
      content: Text(message),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
          child: Text(button),
        ),
      ],
    ),
  );
}
