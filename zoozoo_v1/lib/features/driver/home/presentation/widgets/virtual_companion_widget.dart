
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../services/companion_service.dart';

class VirtualCompanionWidget extends StatefulWidget {
  final String imagePath;
  const VirtualCompanionWidget({super.key, required this.imagePath});

  @override
  State<VirtualCompanionWidget> createState() => _VirtualCompanionWidgetState();
}

class _VirtualCompanionWidgetState extends State<VirtualCompanionWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  final CompanionService _service = CompanionService();
  String? _currentMessage;
  bool _showBubble = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    setState(() {
      _currentMessage = _service.getRandomMessage();
      _showBubble = true;
    });

    // Auto hide bubble after 3 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _showBubble = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _animation.value),
            child: child,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showBubble && _currentMessage != null)
              _buildSpeechBubble(_currentMessage!),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Image.asset(
                widget.imagePath,
                width: 100, // Reasonable size
                height: 100,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeechBubble(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          // Triangle part could be added here with CustomPaint or a rotated container,
          // but simple is fine for now.
        ],
      ),
    );
  }
}
