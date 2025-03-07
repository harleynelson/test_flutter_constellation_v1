// lib/painters/enhanced_star_painter.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/enhanced_constellation.dart';
import '../controllers/celestial_projection_controller.dart';
import '../utils/celestial_projections.dart';

/// Painter for rendering stars with accurate celestial coordinates
class EnhancedStarPainter extends CustomPainter {
  final EnhancedConstellation constellation;
  final CelestialProjectionController projectionController;
  final bool showConstellationLines;
  final bool showStarNames;
  final bool showMagnitudes;
  final double starSizeScale;
  final double twinklePhase;
  
  EnhancedStarPainter({
    required this.constellation,
    required this.projectionController, 
    this.showConstellationLines = true,
    this.showStarNames = true,
    this.showMagnitudes = false,
    this.starSizeScale = 1.0,
    this.twinklePhase = 0.0,
  }) : super(repaint: projectionController);
  
  @override
  void paint(Canvas canvas, Size size) {
    // Get the current projection
    final projection = projectionController.projection;
    
    // Map stars to screen coordinates
    final Map<String, Offset> starPositions = {};
    final Map<String, double> starVisibility = {}; // For stars that may be behind view
    
    // Draw stars
    for (var star in constellation.stars) {
      Offset position;
      
      if (projectionController.is3DMode) {
        // Convert to 3D and project to screen with perspective
        final point3d = projection.celestialTo3D(
          star.rightAscension, 
          star.declination
        );
        position = projection.project3DToScreen(point3d, size);
        
        // Check if star is in front of the viewer (z < 0 means behind)
        starVisibility[star.id] = point3d.z < 0 ? 0.0 : 1.0;
      } else {
        // Use stereographic projection for 2D mode
        position = projection.celestialToScreenStereographic(
          star.rightAscension, 
          star.declination, 
          size
        );
        
        // Check if position is within screen bounds plus some margin
        final bool isVisible = position.dx > -200 && 
                               position.dx < size.width + 200 && 
                               position.dy > -200 && 
                               position.dy < size.height + 200;
        
        starVisibility[star.id] = isVisible ? 1.0 : 0.0;
      }
      
      starPositions[star.id] = position;
      
      // Only draw stars that are visible
      if (starVisibility[star.id]! > 0) {
        _drawStar(canvas, star, position);
      }
    }
    
    // Draw constellation lines
    if (showConstellationLines) {
      _drawConstellationLines(canvas, constellation.lines, starPositions, starVisibility);
    }
  }
  
  /// Draw a single star with appropriate size based on magnitude
  void _drawStar(Canvas canvas, CelestialStar star, Offset position) {
    // Calculate star size based on magnitude (brighter stars are bigger)
    // Magnitude scale is inverted, with negative values being brightest
    double size = _magnitudeToSize(star.magnitude) * starSizeScale;
    
    // Apply small twinkle effect based on phase
    final double starSeed = position.dx * position.dy; // Unique per position
    final double twinkleSpeed = 0.5 + (sin(starSeed) + 1) * 0.5; // Range 0.5-1.5
    final double twinkleFactor = max(0, sin((twinklePhase * twinkleSpeed) % (2 * pi)));
    
    // Adjust size and brightness with twinkling
    size *= (1.0 + twinkleFactor * 0.1);
    
    // Calculate star color based on spectral type if available
    Color starColor = _getStarColor(star.spectralType ?? '');
    
    // Make color slightly brighter during twinkle
    starColor = _adjustColorBrightness(starColor, twinkleFactor * 0.15);
    
    // Draw star glow
    final Paint glowPaint = Paint()
      ..color = starColor.withOpacity(0.3 + twinkleFactor * 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    
    canvas.drawCircle(position, size * 1.5, glowPaint);
    
    // Draw star core
    final Paint starPaint = Paint()
      ..color = starColor
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(position, size, starPaint);
    
    // Draw star name if enabled
    if (showStarNames) {
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: star.name,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12.0,
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
      textPainter.paint(canvas, Offset(position.dx + size + 4, position.dy - textPainter.height / 2));
    }
    
    // Draw magnitude if enabled
    if (showMagnitudes) {
      final TextPainter magPainter = TextPainter(
        text: TextSpan(
          text: star.magnitude.toStringAsFixed(1),
          style: TextStyle(
            color: Colors.grey.withOpacity(0.7),
            fontSize: 10.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      magPainter.layout();
      if (showStarNames) {
        // Position below the name
        magPainter.paint(canvas, Offset(position.dx + size + 4, position.dy + 2));
      } else {
        // Position to the right of the star
        magPainter.paint(canvas, Offset(position.dx + size + 4, position.dy - magPainter.height / 2));
      }
    }
  }
  
  /// Draw the lines connecting stars in the constellation
  void _drawConstellationLines(
    Canvas canvas, 
    List<List<String>> lines, 
    Map<String, Offset> starPositions,
    Map<String, double> starVisibility
  ) {
    final Paint linePaint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    for (var line in lines) {
      if (line.length == 2) {
        final String star1Id = line[0];
        final String star2Id = line[1];
        
        // Skip if either star is not visible or position not calculated
        if (!starPositions.containsKey(star1Id) || 
            !starPositions.containsKey(star2Id) ||
            starVisibility[star1Id] == 0 ||
            starVisibility[star2Id] == 0) {
          continue;
        }
        
        final Offset p1 = starPositions[star1Id]!;
        final Offset p2 = starPositions[star2Id]!;
        
        // Draw constellation line
        canvas.drawLine(p1, p2, linePaint);
      }
    }
  }
  
  /// Convert stellar magnitude to display size
  double _magnitudeToSize(double magnitude) {
    // Magnitude scale: Lower is brighter
    // Typical visible magnitudes range from -1.5 (very bright) to 6 (barely visible)
    
    // Invert and scale to a reasonable pixel size range
    double size = 10.0 - magnitude;  // Now bigger value = bigger star
    
    // Clamp to reasonable range
    return size.clamp(2.0, 15.0);
  }
  
  /// Get star color based on spectral type
  Color _getStarColor(String spectralType) {
    // Default color (white) if spectral type is not available
    if (spectralType.isEmpty) {
      return Colors.white;
    }
    
    // Extract the main spectral class (first character)
    final String mainClass = spectralType[0].toUpperCase();
    
    // Colors based on stellar classification
    switch (mainClass) {
      case 'O': // Blue
        return const Color(0xFFCAE8FF);
      case 'B': // Blue-white
        return const Color(0xFFE6F0FF);
      case 'A': // White
        return Colors.white;
      case 'F': // Yellow-white
        return const Color(0xFFFFF8E8);
      case 'G': // Yellow (Sun-like)
        return const Color(0xFFFFEFB3);
      case 'K': // Orange
        return const Color(0xFFFFD2A1);
      case 'M': // Red
        return const Color(0xFFFFBDAD);
      default:
        return Colors.white;
    }
  }
  
  /// Adjust color brightness for twinkling effect
  Color _adjustColorBrightness(Color color, double factor) {
    return Color.fromRGBO(
      min(255, color.red + ((255 - color.red) * factor).round()),
      min(255, color.green + ((255 - color.green) * factor).round()),
      min(255, color.blue + ((255 - color.blue) * factor).round()),
      color.opacity
    );
  }
  
  @override
  bool shouldRepaint(covariant EnhancedStarPainter oldDelegate) {
    return oldDelegate.constellation != constellation ||
           oldDelegate.projectionController != projectionController ||
           oldDelegate.showConstellationLines != showConstellationLines ||
           oldDelegate.showStarNames != showStarNames ||
           oldDelegate.showMagnitudes != showMagnitudes ||
           oldDelegate.starSizeScale != starSizeScale ||
           oldDelegate.twinklePhase != twinklePhase;
  }
}