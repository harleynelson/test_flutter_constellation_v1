import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class SkyPainter extends CustomPainter {
  final List<Map<String, dynamic>> constellations;
  final String currentConstellation;
  final bool showConstellationLines;
  final bool showConstellationStars;
  final bool showBackgroundStars;
  final bool showStarNames;
  final Function(Map<String, dynamic>)? onStarTapped;
  final Offset? tapPosition;
  final Random _random = Random(42); // Fixed seed for consistent background stars
  final Ticker? _ticker;
  final double _twinklePhase;
  
  // Cache for background stars
  static List<Map<String, dynamic>>? _backgroundStarsCache;
  static Size? _lastSize;

  SkyPainter({
    required this.constellations,
    required this.currentConstellation,
    required this.showConstellationLines,
    required this.showConstellationStars,
    required this.showBackgroundStars,
    this.showStarNames = true,
    this.onStarTapped,
    this.tapPosition,
    Ticker? ticker,
    double twinklePhase = 0.0,
  }) : _ticker = ticker, 
       _twinklePhase = twinklePhase;

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
        final double baseOpacity = _random.nextDouble() * 0.5 + 0.2; // Random opacity (0.2-0.7)
        final double twinkleSpeed = _random.nextDouble() * 3.0 + 1.0; // Random twinkle speed (1.0-4.0)
        
        _backgroundStarsCache!.add({
          'x': x,
          'y': y,
          'radius': radius,
          'baseOpacity': baseOpacity,
          'twinkleSpeed': twinkleSpeed,
        });
      }
    }
    
    // Draw stars from cache with twinkling effect
    for (var star in _backgroundStarsCache!) {
      // Calculate twinkle effect based on phase
      final double baseRadius = star['radius'] as double;
      final double baseOpacity = star['baseOpacity'] as double;
      final double twinkleSpeed = star['twinkleSpeed'] as double;
      
      // Calculate twinkling using sine wave (only use positive values)
      final double twinkleFactor = max(0, sin((_twinklePhase * twinkleSpeed) % (2 * pi)));
      
      // Increase radius by up to 10% during twinkle
      final double currentRadius = baseRadius * (1.0 + twinkleFactor * 0.1);
      
      // Increase brightness by up to 10% during twinkle
      final double currentOpacity = min(1.0, baseOpacity * (1.0 + twinkleFactor * 0.1));
      
      // Draw star with current properties
      final Paint starPaint = Paint()
        ..color = Colors.white.withOpacity(currentOpacity);
      
      canvas.drawCircle(
        Offset(star['x'] as double, star['y'] as double),
        currentRadius,
        starPaint,
      );
      
      // Draw subtle glow (10% larger than the star)
      if (twinkleFactor > 0.3) {
        final Paint glowPaint = Paint()
          ..color = Colors.white.withOpacity(currentOpacity * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
        
        canvas.drawCircle(
          Offset(star['x'] as double, star['y'] as double),
          currentRadius * 1.1,
          glowPaint,
        );
      }
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
      
      // Apply twinkling effect to main stars too, but more subtly
      final double starSeed = x * y; // Use position as a seed for random variation
      final double twinkleSpeed = 0.5 + (sin(starSeed) + 1) * 0.5; // Range 0.5-1.5
      final double twinkleFactor = sin((_twinklePhase * twinkleSpeed) % (2 * pi));
      
      // Calculate twinkling effect - positive values = brighter/larger
      final double twinkleEffect = max(0, twinkleFactor); // Only use positive part of sine wave
      
      // Increase star radius by 10% during twinkle
      final double currentRadius = radius * (1.0 + twinkleEffect * 0.1);
      
      // Create a twinkling glow effect (10% larger than the star)
      final double glowRadius = currentRadius * 1.1;
      
      // Draw glow
      final Paint glowPaint = Paint()
        ..color = _calculateStarColor(magnitude).withOpacity(0.3 + twinkleEffect * 0.1)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      
      canvas.drawCircle(Offset(x, y), glowRadius, glowPaint);
      
      // Draw star core with 10% brightness increase during twinkle
      final Color baseColor = _calculateStarColor(magnitude);
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
      if (tapPosition != null && onStarTapped != null) {
        final double tapDistance = (Offset(x, y) - tapPosition!).distance;
        if (tapDistance < currentRadius * 2) { // Larger tap target for better UX
          // Call the callback with star data (will be handled outside)
          Future.microtask(() => onStarTapped!(starData));
        }
      }
      
      // Draw star name if enabled
      if (showStarNames) {
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

  double _calculateStarRadius(double magnitude) {
    // Magnitude scale is reversed: lower numbers are brighter
    // Return a base radius between 3-8 pixels
    return 8 - min(5, max(0, magnitude - 1));
  }

  Color _calculateStarColor(double magnitude) {
    // Brighter stars tend to be slightly blue-white
    // Dimmer stars tend to be slightly yellow-red
    if (magnitude < 1.0) {
      return Colors.white;
    } else if (magnitude < 2.0) {
      return const Color(0xFFF0F8FF); // Slightly blue-white (AliceBlue)
    } else if (magnitude < 3.0) {
      return const Color(0xFFF5F5DC); // Slightly yellow (Beige)
    } else {
      return const Color(0xFFFFE4B5); // Slightly orange (Moccasin)
    }
  }

  @override
  bool shouldRepaint(SkyPainter oldDelegate) {
    return oldDelegate.currentConstellation != currentConstellation ||
        oldDelegate.showConstellationLines != showConstellationLines ||
        oldDelegate.showConstellationStars != showConstellationStars ||
        oldDelegate.showStarNames != showStarNames ||
        oldDelegate._twinklePhase != _twinklePhase ||
        oldDelegate.tapPosition != tapPosition ||
        (oldDelegate.showBackgroundStars != showBackgroundStars && showBackgroundStars);
  }
}