import 'package:flutter/material.dart';

/// Short, one-time entry motion. It never delays interaction or loops.
class EntryMotion extends StatefulWidget {
  const EntryMotion({
    super.key,
    required this.child,
    this.delayMilliseconds = 0,
  });
  final Widget child;
  final int delayMilliseconds;
  @override
  State<EntryMotion> createState() => _EntryMotionState();
}

class _EntryMotionState extends State<EntryMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Interval(
      widget.delayMilliseconds.clamp(0, 300) /
          (420 + widget.delayMilliseconds.clamp(0, 300)),
      1,
      curve: Curves.easeOutCubic,
    ),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    if (!_started) {
      _started = true;
      // A bounded delay is encoded in the animation, avoiding detached timers.
      _controller.duration = Duration(
        milliseconds: 420 + widget.delayMilliseconds.clamp(0, 300),
      );
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _curve,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: _curve.value,
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - _curve.value)),
        child: child,
      ),
    ),
  );
}
