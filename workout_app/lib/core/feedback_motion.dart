import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Entry feedback gets its full duration after the page transition completes.
class _RouteEntryGate {
  Animation<double>? _route;
  VoidCallback? _start;
  bool _consumed = false;
  bool _scheduled = false;

  void start(BuildContext context, VoidCallback start) {
    if (_consumed || _scheduled) return;
    final page = ModalRoute.of(context);
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_consumed || !context.mounted) return;
      // Navigator can first measure a page offstage, where its animation
      // temporarily reports completed. Wait for the visible route instead.
      if (page?.offstage ?? false) {
        this.start(context, start);
        WidgetsBinding.instance.ensureVisualUpdate();
        return;
      }
      final route = page?.animation;
      if (route == null || route.status == AnimationStatus.completed) {
        cancel();
        start();
        return;
      }
      _start = start;
      if (_route == route) return;
      _route?.removeStatusListener(_onStatus);
      _route = route;
      route.addStatusListener(_onStatus);
    });
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    final start = _start;
    cancel();
    start?.call();
  }

  void cancel() {
    _consumed = true;
    _route?.removeStatusListener(_onStatus);
    _route = null;
    _start = null;
  }
}

/// A greeting fades once; the caller owns the app-session replay policy.
class WelcomeFade extends StatefulWidget {
  const WelcomeFade({super.key, required this.animate, required this.child});
  final bool animate;
  final Widget child;

  @override
  State<WelcomeFade> createState() => _WelcomeFadeState();
}

class _WelcomeFadeState extends State<WelcomeFade>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  final _entry = _RouteEntryGate();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _entry.cancel();
      _controller.value = 1;
    } else {
      _entry.start(context, () => _controller.forward());
    }
  }

  @override
  void dispose() {
    _entry.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => Opacity(
      opacity: Curves.easeOut.transform(_controller.value),
      child: child,
    ),
  );
}

/// Pops only on a persisted incomplete-to-complete transition, never on mount.
class SetCompletionFeedback extends StatefulWidget {
  const SetCompletionFeedback({
    super.key,
    required this.completed,
    required this.child,
  });
  final bool completed;
  final Widget child;

  @override
  State<SetCompletionFeedback> createState() => _SetCompletionFeedbackState();
}

class _SetCompletionFeedbackState extends State<SetCompletionFeedback>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 0;
  }

  @override
  void didUpdateWidget(covariant SetCompletionFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.completed || MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 0;
    } else if (!oldWidget.completed) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) => Transform.scale(
      scale: _controller.value == 1
          ? 1
          : 1 + .10 * math.sin(math.pi * _controller.value),
      child: child,
    ),
  );
}

class SetProgress extends StatelessWidget {
  const SetProgress({super.key, required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    // Replace an active tween immediately if reduced motion is enabled.
    if (MediaQuery.disableAnimationsOf(context)) return _indicator(value);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: value, end: value),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => _indicator(progress),
    );
  }

  Widget _indicator(double progress) => LinearProgressIndicator(
    value: progress,
    minHeight: 3,
    borderRadius: BorderRadius.circular(3),
    color: AppColors.lime,
    backgroundColor: AppColors.elevated,
    semanticsLabel: 'Completed sets',
    semanticsValue: '${(progress * 100).round()}%',
  );
}

/// A local, non-interactive sparkle around the saved-workout checkmark.
class CompletionSparkle extends StatefulWidget {
  const CompletionSparkle({
    super.key,
    required this.enabled,
    required this.child,
  });
  final bool enabled;
  final Widget child;

  @override
  State<CompletionSparkle> createState() => _CompletionSparkleState();
}

class _CompletionSparkleState extends State<CompletionSparkle>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );
  final _entry = _RouteEntryGate();

  // The summary header may scroll out of the lazy list. Retain its one-shot
  // state for this route so scrolling back does not celebrate again.
  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) {
      _entry.cancel();
      _controller.value = 1;
    } else {
      _entry.start(context, () => _controller.forward());
    }
  }

  @override
  void dispose() {
    _entry.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => Stack(
        clipBehavior: Clip.none,
        children: [
          child!,
          if (widget.enabled && _controller.isAnimating)
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: CustomPaint(
                    key: const ValueKey('completion-sparkles'),
                    painter: _SparklePainter(_controller.value),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final fadeIn = (progress / .15).clamp(0.0, 1.0);
    final fadeOut = ((1 - progress) / .55).clamp(0.0, 1.0);
    final opacity = fadeIn * fadeOut * .9;
    final paint = Paint()..color = AppColors.lime.withValues(alpha: opacity);
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 + 5 + progress * 9;
    for (var i = 0; i < 6; i++) {
      final angle = i * math.pi / 3 - math.pi / 2;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final extent = (i.isEven ? 4.5 : 3.0) * (1 - progress * .3);
      final star = Path()
        ..moveTo(point.dx, point.dy - extent)
        ..lineTo(point.dx + extent * .5, point.dy)
        ..lineTo(point.dx, point.dy + extent)
        ..lineTo(point.dx - extent * .5, point.dy)
        ..close();
      canvas.drawPath(star, paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
