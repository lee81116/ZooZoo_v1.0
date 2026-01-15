import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Parallax background that responds to device tilt
class ParallaxBackground extends StatefulWidget {
  final String imagePath;
  final double maxOffset;

  const ParallaxBackground({
    super.key,
    required this.imagePath,
    this.maxOffset = 20.0,
  });

  @override
  State<ParallaxBackground> createState() => _ParallaxBackgroundState();
}

class _ParallaxBackgroundState extends State<ParallaxBackground> {
  double _offsetX = 0;
  double _offsetY = 0;
  StreamSubscription? _accelerometerSubscription;

  @override
  void initState() {
    super.initState();
    _initAccelerometer();
  }

  void _initAccelerometer() {
    _accelerometerSubscription = accelerometerEventStream().listen(
      (event) {
        if (mounted) {
          setState(() {
            // Normalize accelerometer values to offset
            _offsetX = (event.x / 10) * widget.maxOffset;
            _offsetY = (event.y / 10) * widget.maxOffset;
          });
        }
      },
      onError: (error) {
        // Accelerometer not available (e.g., on web/desktop)
        debugPrint('Accelerometer not available: $error');
      },
    );
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: OverflowBox(
            maxWidth: constraints.maxWidth + widget.maxOffset * 2,
            maxHeight: constraints.maxHeight + widget.maxOffset * 2,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(_offsetX, _offsetY, 0),
              child: Image.asset(
                widget.imagePath,
                fit: BoxFit.cover,
                width: constraints.maxWidth + widget.maxOffset * 2,
                height: constraints.maxHeight + widget.maxOffset * 2,
                errorBuilder: (context, error, stackTrace) {
                  return _buildFallbackBackground(constraints);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallbackBackground(BoxConstraints constraints) {
    return Container(
      width: constraints.maxWidth + widget.maxOffset * 2,
      height: constraints.maxHeight + widget.maxOffset * 2,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFD4A574), // Primary - 焦糖奶茶
            Color(0xFF4A3728), // Accent - 濃縮咖啡
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 64,
          color: Colors.white54,
        ),
      ),
    );
  }
}
