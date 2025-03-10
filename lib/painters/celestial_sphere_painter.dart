import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../controllers/celestial_sphere_controller.dart';
import '../models/celestial_coordinate.dart';

/// Custom painter for rendering the celestial sphere
class CelestialSpherePainter extends CustomPainter {
  final CelestialSphereController controller;
  final Random _random = Random(42); // Fixed seed for consistent background
  
  CelestialSpherePainter({
    required this.controller,
  }) : super(repaint: controller);
  
  @override
  void paint(Canvas canvas, Size size) {
    // Draw background gradient
    _drawBackground(canvas, size);
    
    // Draw celestial grid if enabled
    if (controller.showGrid) {
      _drawCelestialGrid(canvas, size);
    }
    
    // Draw background stars
    if (controller.showBackgroundStars) {
      _drawBackgroundStars(canvas, size);
    }
    
    // Draw all constellations
    final processedConstellations = controller.processedConstellations;
    
    for (var constellationEntry in processedConstellations.entries) {
      final constellation = constellationEntry.value;
      
      // Draw constellation lines
      if (controller.showConstellationLines) {
        _drawConstellationLines(canvas, size, constellation);
      }
      
      // Draw constellation stars
      if (controller.showConstellationStars) {
        _drawConstellationStars(canvas, size, constellation);
      }
    }
  }
  
  void _drawBackground(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    
    // Space background gradient
    final Paint gradientPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 1.5,
        colors: [
          Color(0xFF101820), // Dark blue-black
          Color(0xFF000510), // Very dark blue
          Colors.black,
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect);
    
    canvas.drawRect(rect, gradientPaint);
  }
  
  void _drawCelestialGrid(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    final Paint equatorPaint = Paint()
      ..color = Colors.green.withOpacity(0.4)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
      
    final camera = controller.camera;
    
    // Draw declination circles (parallels)
    for (int dec = -80; dec <= 80; dec += 20) {
      List<Offset?> points = [];
      for (int ra = 0; ra < 360; ra += 5) {
        // Convert to celestial coordinates
        final coord = CelestialCoordinate(
          rightAscension: ra / 15, // Convert degrees to hours
          declination: dec.toDouble(),
        );
        
        // Convert to cartesian
        final vector = coord.toCartesian();
        
        // Project to screen
        final screenPoint = camera.projectToScreen(vector, size);
        points.add(screenPoint);
      }
      
      _drawPolyline(canvas, points, dec == 0 ? equatorPaint : gridPaint);
    }
    
    // Draw right ascension circles (meridians)
    for (int ra = 0; ra < 24; ra += 2) {
      List<Offset?> points = [];
      for (int dec = -90; dec <= 90; dec += 5) {
        // Convert to celestial coordinates
        final coord = CelestialCoordinate(
          rightAscension: ra.toDouble(),
          declination: dec.toDouble(),
        );
        
        // Convert to cartesian
        final vector = coord.toCartesian();
        
        // Project to screen
        final screenPoint = camera.projectToScreen(vector, size);
        points.add(screenPoint);
      }
      
      _drawPolyline(canvas, points, gridPaint);
    }
  }
  
  void _drawPolyline(Canvas canvas, List<Offset?> points, Paint paint) {
    if (points.isEmpty) return;
    
    Offset? lastPoint;
    
    for (var point in points) {
      if (point != null) {
        if (lastPoint != null) {
          // Only draw if both points are visible
          // Avoid connecting across the view when one point jumps sides
          if ((lastPoint - point).distance < 100) {
            canvas.drawLine(lastPoint, point, paint);
          }
        }
        lastPoint = point;
      } else {
        // When a point is null (not visible), break the line
        lastPoint = null;
      }
    }
  }
  
  void _drawBackgroundStars(Canvas canvas, Size size) {
    // Create more stars for larger screens
    final int starCount = (size.width * size.height / 2000).round().clamp(200, 1000);
    final twinklePhase = controller.twinklePhase;
    
    for (int i = 0; i < starCount; i++) {
      // Generate random position on unit sphere
      final phi = _random.nextDouble() * 2 * pi; // Azimuthal angle
      final theta = acos(2 * _random.nextDouble() - 1); // Polar angle
      
      // Convert to cartesian coordinates
      final x = sin(theta) * cos(phi);
      final y = sin(theta) * sin(phi);
      final z = cos(theta);
      
      // Create position vector
      final vm.Vector3 position = vm.Vector3(x, y, z);
      
      // Project to screen
      final screenPoint = controller.camera.projectToScreen(position, size);
      
      // Skip if not visible
      if (screenPoint == null) continue;
      
      // Random properties for this star
      final double radius = _random.nextDouble() * 1.0 + 0.5;
      final double baseOpacity = _random.nextDouble() * 0.5 + 0.2;
      final double twinkleSpeed = _random.nextDouble() * 3.0 + 1.0;
      
      // Calculate twinkle effect
      final double twinkleFactor = max(0, sin((twinklePhase * twinkleSpeed) % (2 * pi)));
      
      // Increase radius by up to 10% during twinkle
      final double currentRadius = radius * (1.0 + twinkleFactor * 0.1);
      
      // Increase brightness by up to 10% during twinkle
      final double currentOpacity = min(1.0, baseOpacity * (1.0 + twinkleFactor * 0.1));
      
      // Draw star with current properties
      final Paint starPaint = Paint()
        ..color = Colors.white.withOpacity(currentOpacity);
      
      canvas.drawCircle(
        screenPoint,
        currentRadius,
        starPaint,
      );
      
      // Draw subtle glow (10% larger than the star)
      if (twinkleFactor > 0.3) {
        final Paint glowPaint = Paint()
          ..color = Colors.white.withOpacity(currentOpacity * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
        
        canvas.drawCircle(
          screenPoint,
          currentRadius * 1.1,
          glowPaint,
        );
      }
    }
  }
  
  void _drawConstellationLines(Canvas canvas, Size size, Map<String, dynamic> constellation) {
    final List<dynamic> stars = constellation['stars'] as List<dynamic>;
    final List<dynamic> lines = constellation['lines'] as List<dynamic>;
    
    final Paint linePaint = Paint()
      ..color = Colors.blue.withOpacity(0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    for (var line in lines) {
      final List<dynamic> connection = line as List<dynamic>;
      if (connection.length == 2) {
        final String star1Id = connection[0] as String;
        final String star2Id = connection[1] as String;
        
        // Find the stars by ID
        Map<String, dynamic>? star1, star2;
        for (var star in stars) {
          final Map<String, dynamic> starData = star as Map<String, dynamic>;
          final String id = starData['id'] as String;
          if (id == star1Id) star1 = starData;
          if (id == star2Id) star2 = starData;
        }
        
        if (star1 != null && star2 != null) {
          // Project both stars to screen coordinates
          final screenPos1 = controller.starToScreenCoordinates(star1, size);
          final screenPos2 = controller.starToScreenCoordinates(star2, size);
          
          // Only draw line if both stars are visible
          if (screenPos1 != null && screenPos2 != null) {
            // Only connect if the distance isn't too great
            // (prevents lines spanning across the view when one star jumps sides)
            if ((screenPos1 - screenPos2).distance < 300) {
              canvas.drawLine(screenPos1, screenPos2, linePaint);
            }
          }
        }
      }
    }
  }
  
  void _drawConstellationStars(Canvas canvas, Size size, Map<String, dynamic> constellation) {
    final List<dynamic> stars = constellation['stars'] as List<dynamic>;
    final tapPosition = controller.tapPosition;
    final twinklePhase = controller.twinklePhase;
    
    for (var star in stars) {
      final Map<String, dynamic> starData = star as Map<String, dynamic>;
      
      // Project star to screen coordinates
      final screenPos = controller.starToScreenCoordinates(starData, size);
      
      // Skip if not visible
      if (screenPos == null) continue;
      
      final double magnitude = starData['magnitude'] as double;
      
      // Star properties based on magnitude
      final double baseRadius = controller.calculateStarRadius(magnitude);
      final Color baseColor = controller.calculateStarColor(magnitude);
      
      // Apply twinkling effect
      final double starSeed = screenPos.dx * screenPos.dy;
      final double twinkleSpeed = 0.5 + (sin(starSeed) + 1) * 0.5; // Range 0.5-1.5
      final double twinkleFactor = sin((twinklePhase * twinkleSpeed) % (2 * pi));
      
      // Calculate twinkling effect - positive values = brighter/larger
      final double twinkleEffect = max(0, twinkleFactor);
      
      // Increase star radius by 10% during twinkle
      final double currentRadius = baseRadius * (1.0 + twinkleEffect * 0.1);
      
      // Create a twinkling glow effect
      final double glowRadius = currentRadius * 1.3;
      
      // Draw glow
      final Paint glowPaint = Paint()
        ..color = baseColor.withOpacity(0.3 + twinkleEffect * 0.1)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      
      canvas.drawCircle(screenPos, glowRadius, glowPaint);
      
      // Draw star core with 10% brightness increase during twinkle
      final Color brighterColor = Color.fromRGBO(
        min(255, baseColor.red + (255 - baseColor.red) * twinkleEffect * 0.1).round(),
        min(255, baseColor.green + (255 - baseColor.green) * twinkleEffect * 0.1).round(),
        min(255, baseColor.blue + (255 - baseColor.blue) * twinkleEffect * 0.1).round(),
        1.0
      );
      
      final Paint starPaint = Paint()
        ..color = brighterColor
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(screenPos, currentRadius, starPaint);
      
      // Check if tap is within this star
      if (tapPosition != null) {
        final double tapDistance = (screenPos - tapPosition).distance;
        if (tapDistance < currentRadius * 2) { // Larger tap target for better UX
          // Call the callback with star data (will be handled outside)
          Future.microtask(() => controller.handleStarTapped(starData));
        }
      }
      
      // Draw star name if enabled
      if (controller.showStarNames) {
        final TextPainter textPainter = TextPainter(
          text: TextSpan(
            text: starData['name'] as String,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
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
        textPainter.paint(canvas, Offset(
          screenPos.dx + currentRadius + 4,
          screenPos.dy - textPainter.height / 2,
        ));
      }
    }
  }
  
  @override
  bool shouldRepaint(CelestialSpherePainter oldDelegate) {
    return oldDelegate.controller != controller;
  }
}