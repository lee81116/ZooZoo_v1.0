import 'dart:math';
import 'package:flutter/material.dart';

class RainEffect extends StatefulWidget {
  final bool isHeavy;

  const RainEffect({super.key, this.isHeavy = false});

  @override
  State<RainEffect> createState() => _RainEffectState();
}

class _RainEffectState extends State<RainEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_RainDrop> _drops = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _controller.addListener(_updateDrops);
  }

  void _updateDrops() {
    // Add new drops
    // Heavy rain = more drops per frame
    int spawnRate = widget.isHeavy ? 5 : 2;
    for (int i = 0; i < spawnRate; i++) {
      _drops.add(_RainDrop(
          x: _random.nextDouble(),
          y: -0.1,
          length: 0.05 + _random.nextDouble() * 0.05,
          speed: 0.02 + _random.nextDouble() * 0.02));
    }

    // Move drops
    for (var drop in _drops) {
      drop.y += drop.speed;
    }

    // Remove off-screen drops
    _drops.removeWhere((drop) => drop.y > 1.1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _RainPainter(_drops, widget.isHeavy),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _RainDrop {
  double x;
  double y;
  double length;
  double speed;

  _RainDrop(
      {required this.x,
      required this.y,
      required this.length,
      required this.speed});
}

class _RainPainter extends CustomPainter {
  final List<_RainDrop> drops;
  final bool isHeavy;

  _RainPainter(this.drops, this.isHeavy);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = isHeavy ? 2.0 : 1.0
      ..strokeCap = StrokeCap.round;

    for (var drop in drops) {
      final startX = drop.x * size.width;
      final startY = drop.y * size.height;
      final endX =
          startX - (drop.length * size.height * 0.2); // Slanted slightly
      final endY = startY + (drop.length * size.height);

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
