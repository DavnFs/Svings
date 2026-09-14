import 'package:flutter/material.dart';

/// Pointer-down scale feedback (skill §1 Response): the press registers on
/// pointer-down and releases on pointer-up, so the UI answers in the same
/// frame as the touch instead of waiting for a tap commit.
///
/// Cancelling works like a native button — drag off the target and release,
/// and nothing fires. With `disableAnimations` (reduced motion, skill §14) the
/// scale is skipped entirely; the tap still works.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  const Pressable({super.key, required this.child, this.onTap, this.pressedScale = 0.97});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _handleUp(PointerUpEvent event) {
    if (!_down) return;
    setState(() => _down = false);
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(event.position);
    if (local.dx >= 0 && local.dy >= 0 && local.dx <= box.size.width && local.dy <= box.size.height) {
      widget.onTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: _handleUp,
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1.0,
        duration: reduce ? Duration.zero : const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
