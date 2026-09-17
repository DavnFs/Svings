import 'package:flutter/material.dart';

/// Reusable state widget: handles loading, error, empty, and content
/// in one place. Pure MD3 — scheme colors, tonal icon tiles, FilledButton.
class StateView extends StatelessWidget {
  final bool loading;
  final String? error;
  final bool empty;
  final Widget child;
  final VoidCallback? onRetry;
  final String emptyMessage;
  final String emptyTitle;
  final IconData emptyIcon;

  const StateView({
    super.key,
    required this.loading,
    required this.error,
    required this.empty,
    required this.child,
    this.onRetry,
    this.emptyMessage = 'No transactions recorded yet',
    this.emptyTitle = 'No Data',
    this.emptyIcon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return _loadingView(context);
    if (error != null) return _errorView(context);
    if (empty) return _emptyView(context);
    return child;
  }

  Widget _loadingView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 14),
            Text(
              'Loading...',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.cloud_off_outlined,
                size: 30,
                color: scheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                height: 40,
                child: FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Try Again', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                emptyIcon,
                size: 30,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              emptyTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
