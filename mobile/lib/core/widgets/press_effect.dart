/// A press that you can see on things that are not buttons.
///
/// Material gives a ripple to `InkWell`, `ListTile` and every button, and the
/// theme darkens that ripple so it reads in daylight. What it does not give is
/// any feedback on a *card-shaped* target — a quick action, a medicine card, a
/// report row — where the ripple is a faint wash across a large pale rectangle
/// and easy to miss on a cheap screen outdoors.
///
/// This adds the missing half: the card dips to 97% while held. It is layered
/// on a [Listener] rather than a [GestureDetector] on purpose. A Listener reads
/// raw pointer events and never enters the gesture arena, so the child's own
/// `InkWell`/`ListTile` still wins the tap, still ripples, and still carries
/// the semantics. Wrapping in a second `GestureDetector` would put two tap
/// recognisers in the arena for one finger.
///
/// Reduced motion collapses the animation to zero through [AppMotion.of], so a
/// user who has asked the OS to stop things moving gets the ripple alone.
library;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class PressEffect extends StatefulWidget {
  const PressEffect({
    super.key,
    required this.child,
    this.scale = 0.97,
    this.enabled = true,
  });

  final Widget child;

  /// How far it dips. 0.97 is the whole budget — DESIGN.md's motion dial is
  /// 3/10 and a card that visibly shrinks is a toy, not a health record.
  final double scale;

  /// Off for a disabled target, so nothing that cannot be tapped appears to
  /// respond to being tapped.
  final bool enabled;

  @override
  State<PressEffect> createState() => _PressEffectState();
}

class _PressEffectState extends State<PressEffect> {
  bool _held = false;

  /// Past this, the finger is scrolling the list rather than pressing the card,
  /// so the dip is released. Matches [kTouchSlop].
  static const _slop = kTouchSlop;

  Offset? _origin;

  void _press(Offset at) {
    if (!widget.enabled) return;
    _origin = at;
    if (!_held) setState(() => _held = true);
  }

  void _release() {
    _origin = null;
    if (_held) setState(() => _held = false);
  }

  void _maybeRelease(Offset at) {
    final origin = _origin;
    if (origin == null) return;
    if ((at - origin).distance > _slop) _release();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) => _press(event.position),
      onPointerMove: (event) => _maybeRelease(event.position),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: AnimatedScale(
        scale: _held ? widget.scale : 1.0,
        // `fast` is the token DESIGN.md §5 assigns to "press, ripple, chip
        // toggle", and 120ms sits inside the 100-150ms band a press wants. The
        // asymmetry is carried by the curve rather than by a second duration:
        // easing out on the way down, in on the way back.
        duration: AppMotion.of(context, AppMotion.fast),
        curve: _held ? AppMotion.enter : AppMotion.leave,
        child: widget.child,
      ),
    );
  }
}
