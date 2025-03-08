import 'dart:math';
import 'package:flutter/material.dart';
import '../controllers/star_display_controller.dart';

/// Custom painter that renders the background stars with twinkling effect
class BackgroundStarsPainter extends CustomPainter {
  final StarDisplayController controller;
  final Size size;
  
  BackgroundStarsPainter({
    required this.controller,
    required this.size,
  }) : super(repaint: controller);
  
  @override
  void paint(Canvas canvas, Size size) {
    if (!controller.showBackgroundStars) return;
    
    // Draw black background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );
    
    // Get cached background stars
    final stars = controller.getBackgroundStars(size);
    final twinklePhase = controller.twinklePhase;
    
    // Draw stars with twinkling effect
    for (var star in stars) {
      // Calculate twinkle effect based on phase
      final double twinkleFactor = max(0, sin((twinklePhase * star.twinkleSpeed) % (2 * pi)));
      
      // Increase radius by up to 10% during twinkle
      final double currentRadius = star.radius * (1.0 + twinkleFactor * 0.1);
      
      // Increase brightness by up to 10% during twinkle
      final double currentOpacity = min(1.0, star.baseOpacity * (1.0 + twinkleFactor * 0.1));
      
      // Draw star with current properties
      final Paint starPaint = Paint()
        ..color = Colors.white.withOpacity(currentOpacity);
      
      canvas.drawCircle(
        Offset(star.x, star.y),
        currentRadius,
        starPaint,
      );
      
      // Draw subtle glow (10% larger than the star)
      if (twinkleFactor > 0.3) {
        final Paint glowPaint = Paint()
          ..color = Colors.white.withOpacity(currentOpacity * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
        
        canvas.drawCircle(
          Offset(star.x, star.y),
          currentRadius * 1.1,
          glowPaint,
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(BackgroundStarsPainter oldDelegate) {
    return oldDelegate.controller.showBackgroundStars != controller.showBackgroundStars ||
           oldDelegate.size != size;
  }
}

/// Widget that renders the background stars with a night sky gradient
class BackgroundStarsView extends StatelessWidget {
  final StarDisplayController controller;
  
  const BackgroundStarsView({
    super.key,
    required this.controller,
  });
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return Stack(
              children: [
                // Gradient background
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.0,
                      colors: [
                        Color(0xFF111B2A), // Dark blue
                        Color(0xFF000510), // Very dark blue
                        Colors.black,
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                
                // Background stars
                CustomPaint(
                  painter: BackgroundStarsPainter(
                    controller: controller,
                    size: size,
                  ),
                  size: Size.infinite,
                ),
              ],
            );
          },
        );
      },
    );
  }
}