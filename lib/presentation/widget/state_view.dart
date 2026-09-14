import 'package:flutter/material.dart';
import 'package:cause_money_record/config/app_color.dart';

/// Reusable state widget: handles loading, error, empty, and content
/// in one place with BitChord-inspired clean aesthetics.
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
    if (loading) return _loadingView();
    if (error != null) return _errorView(context);
    if (empty) return _emptyView(context);
    return child;
  }

  Widget _loadingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColor.accent,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Loading...',
              style: TextStyle(
                color: AppColor.textSecondary,
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
                color: AppColor.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.cloud_off_outlined,
                size: 30,
                color: AppColor.danger,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load data',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColor.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColor.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColor.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
                color: AppColor.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                emptyIcon,
                size: 30,
                color: AppColor.accent,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              emptyTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColor.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
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
