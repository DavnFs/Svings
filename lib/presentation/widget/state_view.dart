import 'package:flutter/material.dart';
import 'package:cause_money_record/config/app_color.dart';

/// Reusable state widget — handles loading / error / empty / content
/// in one place. Use with [StateView.snapshot] for AsyncSnapshot-style
/// or [StateView.flags] for explicit boolean state.
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
    this.emptyMessage = 'Belum ada data',
    this.emptyTitle = 'Kosong',
    this.emptyIcon = Icons.inbox_outlined,
  });

  /// Convenience constructor for AsyncSnapshot-style usage.
  factory StateView.snapshot({
    Key? key,
    required AsyncSnapshot snapshot,
    required Widget child,
    VoidCallback? onRetry,
    String emptyMessage = 'Belum ada data',
    String emptyTitle = 'Kosong',
    IconData emptyIcon = Icons.inbox_outlined,
  }) {
    if (snapshot.hasError) {
      return StateView(
        key: key,
        loading: false,
        error: snapshot.error.toString(),
        empty: false,
        child: child,
        onRetry: onRetry,
      );
    }
    if (!snapshot.hasData) {
      return StateView(
        key: key,
        loading: true,
        error: null,
        empty: false,
        child: child,
        onRetry: onRetry,
      );
    }
    final data = snapshot.data;
    if (data == null || (data is Iterable && data.isEmpty)) {
      return StateView(
        key: key,
        loading: false,
        error: null,
        empty: true,
        child: child,
        onRetry: onRetry,
        emptyMessage: emptyMessage,
        emptyTitle: emptyTitle,
        emptyIcon: emptyIcon,
      );
    }
    return StateView(
      key: key,
      loading: false,
      error: null,
      empty: false,
      child: child,
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return _loadingView();
    if (error != null) return _errorView(context);
    if (empty) return _emptyView(context);
    return child;
  }

  Widget _loadingView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColor.accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Memuat...',
            style: TextStyle(
              color: AppColor.textSecondary.withOpacity(0.8),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColor.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.cloud_off_outlined,
                size: 36,
                color: AppColor.danger,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Gagal memuat data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColor.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColor.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColor.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Coba lagi'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColor.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                emptyIcon,
                size: 36,
                color: AppColor.accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColor.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColor.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
