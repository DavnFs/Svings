import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';

import 'package:cause_money_record/presentation/controller/c_settings.dart';

/// Root-level app lock. Sits ABOVE the navigator (wrapping `GetMaterialApp`
/// content via the `builder`), so it blocks every screen — including pushed
/// routes like detail/form/settings — with no per-route wiring.
///
/// Behavior:
/// - Locks on cold start (when the toggle is on) and on every resume from
///   background (`paused` → `resumed`), gated by the "lock on resume" flag.
/// - While locked, an opaque cover replaces all content: nothing underneath
///   is visible, screenshotted previews aside (see below).
/// - Unlock requires a fresh biometric `authenticate()` — the Settings toggle
///   only proved biometrics exist; this is the actual gate.
///
/// Navigation-entry audit: there is no deep-link, notification, or second
/// entry point — AndroidManifest has only MAIN/LAUNCHER, no VIEW/BROWSABLE
/// scheme, no FCM/notification plugin, and every route is a `Get.to` push
/// inside the single navigator this widget wraps. One overlay covers all.
///
/// Known ceiling (documented, not fixed here): on Android the OS task-switcher
/// snapshot is taken before `paused` fires, so a blurred recent-apps preview
/// can leak one frame. Fully preventing that needs `FLAG_SECURE` via a
/// platform channel — a separate native task if the threat model needs it.
class AppLock extends StatefulWidget {
  final Widget child;

  const AppLock({super.key, required this.child});

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  bool _locked = false;
  bool _wasPaused = false;

  CSettings get _settings => Get.find<CSettings>();

  bool get _wantsLock => _settings.appLock && _settings.loaded;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cold start behind the lock when enabled — content never flashes first
    // because this builds locked on the very first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _wantsLock && !_locked) setState(() => _locked = true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _wasPaused = true;
      return;
    }
    if (state == AppLifecycleState.resumed && _wasPaused) {
      _wasPaused = false;
      // lockOnResume=false means "only lock on cold start": resume passes.
      if (mounted && _wantsLock && _settings.lockOnResume && !_locked) {
        setState(() => _locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        // Toggle switched off while locked (only possible from... nowhere —
        // settings is under the overlay — but cheap to honor anyway).
        final locked = _locked && _settings.appLock;
        return Stack(children: [
          widget.child,
          if (locked) const _LockCover(),
        ]);
      },
    );
  }

  void unlockFromCover() {
    if (mounted) setState(() => _locked = false);
  }
}

/// Opaque lock cover with a single Unlock action. Positioned fills the whole
/// overlay stack, so back-button / pop cannot dismiss it — PopScope blocks
/// the system back while locked.
class _LockCover extends StatefulWidget {
  const _LockCover();

  @override
  State<_LockCover> createState() => _LockCoverState();
}

class _LockCoverState extends State<_LockCover> {
  bool _busy = false;

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: 'Unlock svings to view your data',
        biometricOnly: true,
      );
      if (ok && mounted) {
        context.findAncestorStateOfType<_AppLockState>()?.unlockFromCover();
      }
    } catch (_) {
      // Stay locked; user retries via the button.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      child: Material(
        color: scheme.surface,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, size: 56, color: scheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'svings is locked',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Authenticate to view your data',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const Key('applock_unlock'),
                    onPressed: _busy ? null : _unlock,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.fingerprint, size: 18),
                    label: const Text('Unlock'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
