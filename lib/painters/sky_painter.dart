import 'dart:math';
import 'package:flutter/material.dart';

class SkyPainter extends CustomPainter {
  final List<Map<String, dynamic>> constellations;
  final String currentConstellation;
  final bool showConstellationLines;
  final bool showConstellationStars;
  final bool showBackgroundStars;
  final Random _random = Random(42); // Fixed seed for consistent background stars
  
  // Cache for background stars
  static List<Map<String, dynamic>>? _backgroundStarsCache;
  static Size? _lastSize;

  SkyPainter({
    required this.constellations,
    required this.currentConstellation,
    required this.showConstellationLines,
    required this.showConstellationStars,
    required this.showBackgroundStars,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw black background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );

    // Draw background stars
    if (showBackgroundStars) {
      _drawBackgroundStars(canvas, size);
    }

    // Find current constellation
    final currentConstellationData = constellations.firstWhere(
      (c) => c['name'] == currentConstellation,
      orElse: () => <String, dynamic>{},
    );

    if (currentConstellationData.isEmpty) return;
    
    // Calculate constellation bounding box to determine scaling
    final List<dynamic> stars = currentConstellationData['stars'] as List<dynamic>;
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
    final List<dynamic>? lines = currentConstellationData['lines'] as List<dynamic>?;
    if (showConstellationLines && lines != null) {
      _drawConstellationLines(canvas, scale, offsetX, offsetY, stars, lines);
    }

    // Draw constellation stars
    if (showConstellationStars) {
      _drawConstellationStars(canvas, scale, offsetX, offsetY, stars);
    }
  }
  
  void _drawBackgroundStars(Canvas canvas, Size size) {
    // Generate background stars only if they haven't been generated yet or if the size changed
    if (_backgroundStarsCache == null || _lastSize != size) {
      _lastSize = size;
      _backgroundStarsCache = [];
      
      // Create more stars for larger screens
      final int starCount = (size.width * size.height / 2000).round().clamp(200, 1000);
      
      for (int i = 0; i < starCount; i++) {
        final double x = _random.nextDouble() * size.width;
        final double y = _random.nextDouble() * size.height;
        final double radius = _random.nextDouble() * 1.0 + 0.5; // Random star size (0.5-1.5)
        final double opacity = _random.nextDouble() * 0.5 + 0.2; // Random opacity (0.2-0.7)
        
        _backgroundStarsCache!.add({
          'x': x,
          'y': y,
          'radius': radius,
          'opacity': opacity,
        });
      }
    }
    
    // Draw stars from cache
    for (var star in _backgroundStarsCache!) {
      final Paint starPaint = Paint()
        ..color = Colors.white.withOpacity(star['opacity'] as double);
      
      canvas.drawCircle(
        Offset(star['x'] as double, star['y'] as double),
        star['radius'] as double,
        starPaint,
      );
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

  void _drawConstellationStars(Canvas canvas, double scale, double offsetX, double offsetY, List<dynamic> stars) {
    for (var star in stars) {
      final Map<String, dynamic> starData = star as Map<String, dynamic>;
      final double x = offsetX + (starData['x'] as double) * scale;
      final double y = offsetY + (starData['y'] as double) * scale;
      final double magnitude = starData['magnitude'] as double;
      
      // Scale star radius appropriately
      final double baseRadius = _calculateStarRadius(magnitude);
      // Ensure reasonable star size that scales with the constellation but not too large
      final double radius = max(baseRadius, 2.0) * min(scale * 0.05, 3.0);
      
      final Paint starPaint = Paint()
        ..color = _calculateStarColor(magnitude)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(x, y), radius, starPaint);
      
      // Draw star name with appropriate font size
      final double fontSize = max(12.0, min(14.0, scale * 0.02));
      
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: starData['name'] as String,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: fontSize,
            fontWeight: FontWeight.w500, // Semi-bold for better readability
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + radius + 4, y - textPainter.height / 2));
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

  double _calculateStarRadius(double magnitude) {
    // Magnitude scale is reversed: lower numbers are brighter
    // Return a base radius between 3-8 pixels
    return 8 - min(5, max(0, magnitude - 1));
  }

  Color _calculateStarColor(double magnitude) {
    // Brighter stars tend to be slightly blue-white
    // Dimmer stars tend to be slightly yellow-red
    if (magnitude < 2.0) {
      return Colors.white;
    } else if (magnitude < 3.0) {
      return Colors.blue[100] ?? Colors.white;
    } else {
      return Colors.yellow[100] ?? Colors.white;
    }
  }

  @override
  bool shouldRepaint(SkyPainter oldDelegate) {
    return oldDelegate.currentConstellation != currentConstellation ||
        oldDelegate.showConstellationLines != showConstellationLines ||
        oldDelegate.showConstellationStars != showConstellationStars ||
        (oldDelegate.showBackgroundStars != showBackgroundStars && showBackgroundStars);
  }
}