import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

abstract final class AppMotion {
  static bool reduced = false;
  static bool haptics = true;
  static const press = Duration(milliseconds: 100);
  static const quick = Duration(milliseconds: 180);
  static const move = Duration(milliseconds: 260);
  static const reveal = Duration(milliseconds: 320);
  static Duration resolve(BuildContext context, Duration role) =>
      reduced || MediaQuery.disableAnimationsOf(context) ? Duration.zero : role;
  static Future<void> selection() async {
    if (haptics) {
      try {
        await HapticFeedback.selectionClick();
      } catch (_) {
        /* Optional device feedback. */
      }
    }
  }

  static Future<void> commit() async {
    if (haptics) {
      try {
        await HapticFeedback.lightImpact();
      } catch (_) {
        /* Saving never depends on device feedback. */
      }
    }
  }
}

class AppRouteTransition extends CustomTransition {
  @override
  Widget buildTransition(
    BuildContext context,
    Curve? curve,
    Alignment? alignment,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.resolve(context, AppMotion.move) == Duration.zero) {
      return child;
    }
    return FadeTransition(
      opacity: animation.drive(CurveTween(curve: Curves.easeOutCubic)),
      child: child,
    );
  }
}

/// One-shot, interruptible reveal. Content is immediately interactive.
class Reveal extends StatefulWidget {
  const Reveal({super.key, required this.child});
  final Widget child;
  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: AppMotion.reveal,
  );
  late final animation = CurvedAnimation(
    parent: controller,
    curve: Curves.easeOutCubic,
  );
  late final slideAnimation = Tween<Offset>(
    begin: const Offset(0, .025),
    end: Offset.zero,
  ).animate(animation);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.resolve(context, AppMotion.reveal) == Duration.zero) {
      controller.value = 1;
    } else if (!controller.isAnimating && controller.value == 0) {
      controller.forward();
    }
  }

  @override
  void dispose() {
    animation.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => controller.value = 1,
    child: FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: slideAnimation,
        child: widget.child,
      ),
    ),
  );
}

class BusyLabel extends StatelessWidget {
  const BusyLabel(this.label, {super.key, required this.busy});
  final String label;
  final bool busy;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppMotion.resolve(context, AppMotion.quick),
    child: Text(busy ? 'Please wait…' : label, key: ValueKey(busy)),
  );
}

/// Smooth scroll and entrance reveal animation with customizable stagger.
class ScrollReveal extends StatefulWidget {
  const ScrollReveal({
    super.key,
    required this.child,
    this.index = 0,
    this.delay,
    this.offset = const Offset(0, 0.08),
    this.duration = const Duration(milliseconds: 380),
  });

  final Widget child;
  final int index;
  final Duration? delay;
  final Offset offset;
  final Duration duration;

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _fadeAnimation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _slideAnimation = Tween<Offset>(
    begin: widget.offset,
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  ));
  late final Animation<double> _scaleAnimation = Tween<double>(
    begin: 0.95,
    end: 1.0,
  ).animate(CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  ));

  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    final delayMs = widget.delay?.inMilliseconds ??
        (widget.index * 40).clamp(0, 300);
    if (AppMotion.reduced) {
      _controller.value = 1.0;
    } else if (delayMs > 0) {
      _delayTimer = Timer(Duration(milliseconds: delayMs), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.resolve(context, widget.duration) == Duration.zero) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AppMotion.resolve(context, widget.duration) == Duration.zero) {
      return widget.child;
    }
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}
