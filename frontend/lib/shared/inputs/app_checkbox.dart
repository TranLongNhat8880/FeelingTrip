import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// An animated checkbox inspired by Facebook / Twitter's like/heart pop reaction,
/// featuring a squash-and-pop bounce, shockwave ring, and micro-sparkle burst.
class AppCheckbox extends StatefulWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 20,
    this.borderRadius,
    this.activeColor = AppColors.primary,
    this.checkColor = Colors.white,
    this.borderColor = const Color(0xFFDEE4EF),
    this.hasError = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double size;
  final BorderRadius? borderRadius;
  final Color activeColor;
  final Color checkColor;
  final Color borderColor;
  final bool hasError;

  @override
  State<AppCheckbox> createState() => _AppCheckboxState();
}

class _AppCheckboxState extends State<AppCheckbox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burstController;

  @override
  void initState() {
    super.initState();
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
  }

  @override
  void didUpdateWidget(covariant AppCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.value && widget.value) {
      _triggerBurst();
    }
  }

  @override
  void dispose() {
    _burstController.dispose();
    super.dispose();
  }

  void _triggerBurst() {
    _burstController.forward(from: 0.0);
  }

  void _handleTap() {
    if (widget.onChanged == null) return;
    final newValue = !widget.value;
    widget.onChanged!(newValue);
    if (newValue) {
      _triggerBurst();
    }
  }

  double _calculateBoxScale(double t) {
    if (!_burstController.isAnimating) return 1.0;
    if (t < 0.18) {
      // 0.0 -> 0.18: squash down to 0.78
      return 1.0 - (0.22 * (t / 0.18));
    } else if (t < 0.58) {
      // 0.18 -> 0.58: pop up to 1.28 with bouncy curve
      final sub = (t - 0.18) / 0.40;
      final curved = Curves.easeOutBack.transform(sub.clamp(0.0, 1.0));
      return 0.78 + (0.50 * curved);
    } else {
      // 0.58 -> 1.0: settle back smoothly to 1.0
      final sub = (t - 0.58) / 0.42;
      final curved = Curves.easeInOutCubic.transform(sub.clamp(0.0, 1.0));
      return 1.28 - (0.28 * curved);
    }
  }

  double _calculateCheckmarkScale(double t) {
    if (!widget.value) return 0.0;
    if (!_burstController.isAnimating) return 1.0;
    if (t < 0.22) return 0.0;
    final sub = ((t - 0.22) / 0.50).clamp(0.0, 1.0);
    return Curves.easeOutBack.transform(sub);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius =
        widget.borderRadius ?? BorderRadius.circular(widget.size * 0.3);

    final effectiveBorderColor = widget.hasError
        ? AppColors.error
        : (widget.value ? widget.activeColor : widget.borderColor);

    return GestureDetector(
      onTap: widget.onChanged != null ? _handleTap : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _burstController,
        builder: (context, _) {
          final t = _burstController.value;
          final boxScale = _calculateBoxScale(t);
          final checkScale = _calculateCheckmarkScale(t);

          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // 1. Twitter-style Shockwave Ring & Sparkle burst (expands outside bounds)
                if (_burstController.isAnimating)
                  Positioned(
                    left: -widget.size * 0.8,
                    right: -widget.size * 0.8,
                    top: -widget.size * 0.8,
                    bottom: -widget.size * 0.8,
                    child: CustomPaint(
                      painter: _TwitterBurstPainter(
                        progress: t,
                        color: widget.activeColor,
                        accentColor: const Color(0xFF13B5FA),
                        sparkleColor: const Color(0xFFFFB300),
                      ),
                    ),
                  ),

                // 2. The Checkbox Box itself (Squash & Pop)
                Transform.scale(
                  scale: boxScale,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: widget.value ? widget.activeColor : Colors.white,
                      borderRadius: effectiveRadius,
                      border: Border.all(
                        color: effectiveBorderColor,
                        width: 1.5,
                      ),
                      boxShadow: widget.value
                          ? [
                              BoxShadow(
                                color: widget.activeColor.withValues(alpha: 0.32),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Transform.scale(
                      scale: checkScale,
                      child: Icon(
                        Icons.check_rounded,
                        size: widget.size * 0.75,
                        color: widget.checkColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TwitterBurstPainter extends CustomPainter {
  _TwitterBurstPainter({
    required this.progress,
    required this.color,
    required this.accentColor,
    required this.sparkleColor,
  });

  final double progress;
  final Color color;
  final Color accentColor;
  final Color sparkleColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = (size.width / 2) * 0.55;

    // 1. Expanding shockwave ring (progress: 0.05 -> 0.52)
    if (progress >= 0.05 && progress <= 0.55) {
      final ringProgress = (progress - 0.05) / 0.50;
      final ringRadius = baseRadius + (baseRadius * 1.1 * ringProgress);
      final ringOpacity = (1.0 - ringProgress).clamp(0.0, 1.0);
      final ringPaint = Paint()
        ..color = color.withValues(alpha: ringOpacity * 0.50)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (2.2 * (1.0 - ringProgress)).clamp(0.6, 2.2);

      canvas.drawCircle(center, ringRadius, ringPaint);
    }

    // 2. Bursting sparkle dots (progress: 0.18 -> 0.95)
    if (progress >= 0.18 && progress <= 0.95) {
      final particleProgress = (progress - 0.18) / 0.77;
      final particleOpacity = (1.0 - particleProgress).clamp(0.0, 1.0);
      final particleDistance =
          baseRadius + (baseRadius * 1.25 * particleProgress);
      final particleSize =
          (2.5 * (1.0 - particleProgress * 0.7)).clamp(0.5, 2.5);

      const particleCount = 7;
      final colors = [
        color,
        accentColor,
        sparkleColor,
        color,
        accentColor,
        sparkleColor,
        color,
      ];

      for (int i = 0; i < particleCount; i++) {
        final angle = (i * (2 * math.pi / particleCount)) - (math.pi / 2);
        final dx = center.dx + math.cos(angle) * particleDistance;
        final dy = center.dy + math.sin(angle) * particleDistance;

        final particlePaint = Paint()
          ..color = colors[i % colors.length].withValues(alpha: particleOpacity)
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset(dx, dy), particleSize, particlePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TwitterBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
