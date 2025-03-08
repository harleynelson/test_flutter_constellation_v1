import 'dart:math';
import 'package:flutter/material.dart';
import '../controllers/star_display_controller.dart';

/// Custom painter that renders a single constellation with stars and lines
class ConstellationPainter extends CustomPainter {
  final StarDisplayController controller;
  final Map<String, dynamic> constellation;
  final Size size;
  
  ConstellationPainter({
    required this.controller,
    required this.constellation,
    required this.size,
  }) : super(repaint: controller);
  
  @override
  void paint(Canvas canvas, Size size) {
    // Calculate constellation bounding box to determine scaling
    final List<dynamic> stars = constellation['stars'] as List<dynamic>;
    if (stars.isEmpty) return;
    
    // Find min/max coordinates to determine the constellation's natural bounds
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    
    for (var star in stars) {
      final Map<String, dynamic> starData = star as Map<String, dynamic>;
      final double x = starData['x'] as double;
      final double y = starData['y'] as double;
      
      minX = min(minX, x);
      minY = min(minY, y);
      maxX = max(maxX, x);
      maxY = max(maxY, y);
    }
    
    // Safety check - ensure we have valid bounds
    if (minX >= maxX || minY >= maxY) return;
    
    // Calculate constellation's natural width and height
    final double constellationWidth = maxX - minX;
    final double constellationHeight = maxY - minY;
    
    // Add padding to avoid stars being right at the edge
    final double padding = 0.1; // 10% padding
    final double targetWidth = size.width * (0.85 - padding * 2);
    final double targetHeight = size.height * (0.85 - padding * 2);
    
    // Calculate scale factors for width and height
    final double scaleX = targetWidth / constellationWidth;
    final double scaleY = targetHeight / constellationHeight;
    
    // Use the smaller scale to maintain aspect ratio
    final double scale = min(scaleX, scaleY);
    
    // Calculate centered position with padding
    final double scaledWidth = constellationWidth * scale;
    final double scaledHeight = constellationHeight * scale;
    final double left = (size.width - scaledWidth) / 2;
    final double top = (size.height - scaledHeight) / 2;
    
    // Adjusted offset to center the constellation properly
    final double offsetX = left - minX * scale;
    final double offsetY = top - minY * scale;
    
    // Draw constellation lines
    final List<dynamic>? lines = constellation['lines'] as List<dynamic>?;
    if (controller.showConstellationLines && lines != null) {
      _drawConstellationLines(canvas, scale, offsetX, offsetY, stars, lines);
    }

    // Draw constellation stars
    if (controller.showConstellationStars) {
      _drawConstellationStars(canvas, scale, offsetX, offsetY, stars);
    }
  }
  
  void _drawConstellationLines(Canvas canvas, double scale, double offsetX, double offsetY, 
      List<dynamic> stars, List<dynamic> lines) {
    final Paint linePaint = Paint()
      ..color = Colors.blue.withOpacity(0.6)
      ..strokeWidth = 3.0 // Thicker lines for better visibility
      ..style = PaintingStyle.stroke;

    for (var line in lines) {
      final List<dynamic> connection = line as List<dynamic>;
      if (connection.length == 2) {
        final String star1Id = connection[0] as String;
        final String star2Id = connection[1] as String;
        
        final Map<String, dynamic>? star1 = _findStarById(stars, star1Id);
        final Map<String, dynamic>? star2 = _findStarById(stars, star2Id);
        
        if (star1 != null && star2 != null) {
          final Offset p1 = Offset(
            offsetX + (star1['x'] as double) * scale,
            offsetY + (star1['y'] as double) * scale,
          );
          final Offset p2 = Offset(
            offsetX + (star2['x'] as double) * scale,
            offsetY + (star2['y'] as double) * scale,
          );
          
          canvas.drawLine(p1, p2, linePaint);
        }
      }
    }
  }

  void _drawConstellationStars(Canvas canvas, double scale, double offsetX, double offsetY, 
      List<dynamic> stars) {
    final tapPosition = controller.tapPosition;
    final twinklePhase = controller.twinklePhase;
    
    for (var star in stars) {
      final Map<String, dynamic> starData = star as Map<String, dynamic>;
      final double x = offsetX + (starData['x'] as double) * scale;
      final double y = offsetY + (starData['y'] as double) * scale;
      final double magnitude = starData['magnitude'] as double;
      
      // Scale star radius appropriately
      final double baseRadius = controller.calculateStarRadius(magnitude);
      // Ensure reasonable star size that scales with the constellation but not too large
      final double radius = max(baseRadius, 2.0) * min(scale * 0.05, 3.0);
      
      // Apply twinkling effect to main stars too, but more subtly
      final double starSeed = x * y; // Use position as a seed for random variation
      final double twinkleSpeed = 0.5 + (sin(starSeed) + 1) * 0.5; // Range 0.5-1.5
      final double twinkleFactor = sin((twinklePhase * twinkleSpeed) % (2 * pi));
      
      // Calculate twinkling effect - positive values = brighter/larger
      final double twinkleEffect = max(0, twinkleFactor); // Only use positive part of sine wave
      
      // Increase star radius by 10% during twinkle
      final double currentRadius = radius * (1.0 + twinkleEffect * 0.1);
      
      // Create a twinkling glow effect (10% larger than the star)
      final double glowRadius = currentRadius * 1.1;
      
      // Draw glow
      final Paint glowPaint = Paint()
        ..color = controller.calculateStarColor(magnitude).withOpacity(0.3 + twinkleEffect * 0.1)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      
      canvas.drawCircle(Offset(x, y), glowRadius, glowPaint);
      
      // Draw star core with 10% brightness increase during twinkle
      final Color baseColor = controller.calculateStarColor(magnitude);
      final Color brighterColor = Color.fromRGBO(
        min(255, baseColor.red + (255 - baseColor.red) * twinkleEffect * 0.1).round(),
        min(255, baseColor.green + (255 - baseColor.green) * twinkleEffect * 0.1).round(),
        min(255, baseColor.blue + (255 - baseColor.blue) * twinkleEffect * 0.1).round(),
        1.0
      );
      
      final Paint starPaint = Paint()
        ..color = brighterColor
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(x, y), currentRadius, starPaint);
      
      // Check if tap is within this star
      if (tapPosition != null) {
        final double tapDistance = (Offset(x, y) - tapPosition).distance;
        if (tapDistance < currentRadius * 2) { // Larger tap target for better UX
          // Call the callback with star data (will be handled outside)
          Future.microtask(() => controller.handleStarTapped(starData));
        }
      }
      
      // Draw star name if enabled
      if (controller.showStarNames) {
        final double fontSize = max(12.0, min(14.0, scale * 0.02));
        
        final TextPainter textPainter = TextPainter(
          text: TextSpan(
            text: starData['name'] as String,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: fontSize,
              fontWeight: FontWeight.w500, // Semi-bold for better readability
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.7),
                  offset: const Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        
        textPainter.layout();
        textPainter.paint(canvas, Offset(x + radius + 4, y - textPainter.height / 2));
      }
    }
  }

  Map<String, dynamic>? _findStarById(List<dynamic> stars, String id) {
    for (var star in stars) {
      final Map<String, dynamic> starData = star as Map<String, dynamic>;
      if (starData['id'] == id) {
        return starData;
      }
    }
    return null;
  }
  
  @override
  bool shouldRepaint(ConstellationPainter oldDelegate) {
    return oldDelegate.controller != controller ||
           oldDelegate.constellation != constellation ||
           oldDelegate.size != size;
  }
}

/// Widget that renders a single constellation with interactive features
class ConstellationView extends StatelessWidget {
  final StarDisplayController controller;
  final Map<String, dynamic> constellation;
  
  const ConstellationView({
    super.key,
    required this.controller,
    required this.constellation,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: controller.handleTap,
      onTap: controller.clearSelection,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return Stack(
            children: [
              // Constellation stars and lines
              CustomPaint(
                painter: ConstellationPainter(
                  controller: controller,
                  constellation: constellation,
                  size: size,
                ),
                size: Size.infinite,
              ),
              
              // Star info card when selected
              if (controller.selectedStar != null)
                _buildStarInfoCard(controller.selectedStar!),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildStarInfoCard(Map<String, dynamic> star) {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Card(
        color: Colors.black.withOpacity(0.7),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                star['name'] as String,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Magnitude: ${(star['magnitude'] as double).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ID: ${star['id'] as String}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tap anywhere to close',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}