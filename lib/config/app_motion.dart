import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Motion tokens for page-level navigation: one documented rhythm for every
/// push and pop, instead of whatever the framework happens to fall back to.
///
/// [pageTransition] is [Transition.native], which hands the animation to
/// Flutter's `PageTransitionsTheme`. That resolves to Material 3's
/// "fade forwards" on Android (the incoming page travels in from a quarter of
/// the width out while it fades up, the outgoing page fades away) and to the
/// Cupertino slide on iOS. This is also what GetX already falls back to when
/// nothing is configured, so naming it here keeps the current motion while
/// making the choice explicit and immune to a stray per-call override.
///
/// Why not the alternatives:
/// - `Transition.cupertino` would play an iOS slide on Android too, and GetX's
///   cupertino branch is the only one that attaches its edge-swipe pop detector
///   unconditionally, so it would sit on top of the system back gesture.
/// - `Transition.rightToLeft` is a plain full-width slide, which is a step down
///   from the platform motion above on both platforms.
/// - `Transition.fadeIn` drops the spatial direction, so back and forward would
///   look identical.
///
/// If a single identical motion on every platform is ever wanted,
/// `Transition.rightToLeft` (or adding `animations`' shared-axis builder to
/// [pageTransition]) is the change, in one place.
class AppMotion {
  AppMotion._();

  static const pageTransition = Transition.native;

  /// GetX's own default, restated so the number is visible and pinned: 300ms is
  /// inside the 250-300ms band that still reads as immediate on a high
  /// refresh rate display.
  static const pageTransitionDuration = Duration(milliseconds: 300);

  /// Whether the platform asked for reduced motion ("Remove animations" on
  /// Android, Reduce Motion on iOS).
  ///
  /// Everything this app animates on its own goes through here. A custom
  /// animation that ignores it is a bug for the users who need it: the point of
  /// the setting is that content stops moving, not that it moves faster.
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// [duration], or zero when the user has asked for reduced motion — for
  /// implicit animations, where "off" means "already at the end state".
  static Duration maybe(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;

  /// Physics for the Home balance carousel.
  ///
  /// Normally the swipe settles with the platform's spring. With reduced motion
  /// the released card lands on the nearest page immediately, so the user still
  /// gets whole cards but never sees the strip travel.
  static ScrollPhysics carousel(BuildContext context) =>
      reduced(context) ? const _InstantPageSnapping() : const PageScrollPhysics();
}

/// Page paging that snaps without travelling: the ballistic simulation reports
/// the target offset as already reached, so the scroll position jumps on the
/// next frame instead of springing there.
class _InstantPageSnapping extends PageScrollPhysics {
  const _InstantPageSnapping();

  /// Sub-pixel: below this the card is already on its page.
  static const _epsilon = 0.5;

  @override
  _InstantPageSnapping applyTo(ScrollPhysics? ancestor) =>
      const _InstantPageSnapping();

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final viewport = position.viewportDimension;
    if (viewport <= 0) return null;
    final page = (position.pixels / viewport).roundToDouble();
    final target = (page * viewport)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < _epsilon) return null;
    return _SnapTo(target);
  }
}

class _SnapTo extends Simulation {
  _SnapTo(this.target);

  final double target;

  @override
  double x(double time) => target;

  @override
  double dx(double time) => 0;

  @override
  bool isDone(double time) => true;
}
