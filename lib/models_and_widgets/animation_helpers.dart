import 'package:flutter/material.dart';

/// Widget für elegante Entrance-Animationen von Cards/Items
class EntranceAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final int delayMs; // Staggered animation delay in ms
  final double beginScale;

  const EntranceAnimation({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 350),
    this.curve = Curves.easeOutCubic,
    this.delayMs = 0,
    this.beginScale = 0.85,
  }) : super(key: key);

  @override
  State<EntranceAnimation> createState() => _EntranceAnimationState();
}

class _EntranceAnimationState extends State<EntranceAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final value = _animation.value;
        return Transform.scale(
          scale: widget.beginScale + (value * (1.0 - widget.beginScale)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Widget für Slide-In Animationen (von links, rechts, oben, unten)
class SlideInAnimation extends StatefulWidget {
  final Widget child;
  final SlideDirection direction;
  final Duration duration;
  final Curve curve;
  final int delayMs;

  const SlideInAnimation({
    Key? key,
    required this.child,
    this.direction = SlideDirection.fromLeft,
    this.duration = const Duration(milliseconds: 400),
    this.curve = Curves.easeOutCubic,
    this.delayMs = 0,
  }) : super(key: key);

  @override
  State<SlideInAnimation> createState() => _SlideInAnimationState();
}

class _SlideInAnimationState extends State<SlideInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    
    final offset = _getBeginOffset();
    _animation = Tween<Offset>(begin: offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _getBeginOffset() {
    return switch (widget.direction) {
      SlideDirection.fromLeft => const Offset(-1.0, 0),
      SlideDirection.fromRight => const Offset(1.0, 0),
      SlideDirection.fromTop => const Offset(0, -1.0),
      SlideDirection.fromBottom => const Offset(0, 1.0),
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: _animation.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

enum SlideDirection { fromLeft, fromRight, fromTop, fromBottom }

/// Widget für Fade-In Animationen
class FadeInAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final int delayMs;

  const FadeInAnimation({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOut,
    this.delayMs = 0,
  }) : super(key: key);

  @override
  State<FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<FadeInAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Staggered animation controller für Listen mit mehreren Items
class StaggeredAnimationController {
  final int itemCount;
  final int delayBetweenItemsMs;
  final int initialDelayMs;

  StaggeredAnimationController({
    required this.itemCount,
    this.delayBetweenItemsMs = 50,
    this.initialDelayMs = 0,
  });

  int getDelayForIndex(int index) {
    return initialDelayMs + (index * delayBetweenItemsMs);
  }
}
