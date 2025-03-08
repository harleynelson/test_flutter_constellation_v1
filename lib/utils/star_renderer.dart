// lib/utils/star_renderer.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/enhanced_constellation.dart';

/// Utility class for rendering stars with consistent appearance and behavior
class StarRenderer {
  /// Calculate star size based on magnitude and screen size
  static double calculateStarSize(double magnitude, Size screenSize) {
    // Base size calculation based on magnitude (brighter = larger)
    double baseSize = max(2.0, 8.0 - magnitude * 0.7);
    
    // Scale factor based on screen size
    // Use the smaller dimension to ensure stars don't get too large on any device
    double smallerDimension = min(screenSize.width, screenSize.height);
    double scaleFactor = smallerDimension / 1000.0; // Normalize to a reference size of 1000px
    
    // Apply scale factor with lower and upper bounds
    return max(1.5, min(baseSize * scaleFactor, 7.0));
  }
  
  /// Get star color based on spectral type
  static Color getStarColor(String? spectralType) {
    if (spectralType == null || spectralType.isEmpty) {
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
  
  /// Calculate twinkling factor for a star
  static double calculateTwinkleFactor(Object starIdentifier, double phase, {double intensity = 0.3}) {
    // Generate a consistent seed for this star
    final double starSeed = (starIdentifier.hashCode * 10) % 100;
    
    // Use a much slower twinkling by:
    // 1. Using a smaller multiplier for the twinkle phase
    // 2. Adding an offset based on star ID so they don't all twinkle in sync
    final double adjustedPhase = (phase * 0.2) + (starSeed / 100);
    
    // Very subtle twinkling - almost imperceptible
    return max(0, sin(adjustedPhase)) * intensity; // Controlled effect
  }
  
  /// Adjust color brightness for twinkling effect
  static Color adjustColorBrightness(Color color, double factor) {
    return Color.fromRGBO(
      min(255, color.red + ((255 - color.red) * factor).round()),
      min(255, color.green + ((255 - color.green) * factor).round()),
      min(255, color.blue + ((255 - color.blue) * factor).round()),
      color.opacity
    );
  }
  
  /// Draw a star with appropriate twinkling
  static void drawStar(
    Canvas canvas, 
    Object starIdentifier,
    Offset position, 
    double magnitude, 
    double phase, 
    Size screenSize, 
    {
      String? spectralType,
      double glowRatio = 1.5,
      double sizeMultiplier = 1.0,
      double twinkleIntensity = 0.3,
    }
  ) {
    // Calculate base star size
    final double size = calculateStarSize(magnitude, screenSize) * sizeMultiplier;
    
    // Calculate twinkling effect
    final double twinkleFactor = calculateTwinkleFactor(
      starIdentifier, phase, intensity: twinkleIntensity
    );
    
    // Adjust size and brightness with twinkling - minimal changes
    final double currentSize = size * (1.0 + twinkleFactor * 0.05);
    
    // Get star color based on spectral type
    final Color starColor = getStarColor(spectralType);
    
    // Make color slightly brighter during twinkle
    final Color twinkleColor = adjustColorBrightness(starColor, twinkleFactor * 0.08);
    
    // Draw star glow
    final Paint glowPaint = Paint()
      ..color = twinkleColor.withOpacity(0.3 + twinkleFactor * 0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    
    canvas.drawCircle(position, currentSize * glowRatio, glowPaint);
    
    // Draw star core
    final Paint starPaint = Paint()
      ..color = twinkleColor
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(position, currentSize, starPaint);
  }
  
  /// Draw a background star with simpler appearance
  static void drawBackgroundStar(
    Canvas canvas,
    int starIndex,
    Offset position,
    double radius,
    double baseOpacity,
    double phase,
    {
      double glowProbability = 0.2,
      double twinkleIntensity = 0.3,
    }
  ) {
    // Apply twinkling - but make sure opacity stays in valid range 0-1
    final double starSeed = starIndex * 17.0; // Use star index as seed
    
    // Use a fixed very slow phase with reduced effect
    final double twinkleFactor = max(0, sin(phase * 0.2 + (starSeed % pi))) * twinkleIntensity;
    
    // Adjust opacity with twinkling - ensure it's clamped to valid range
    final double opacity = min(1.0, max(0.0, baseOpacity * (1.0 + twinkleFactor * 0.2)));
    
    // Draw star
    final Paint starPaint = Paint()
      ..color = Colors.white.withOpacity(opacity);
    
    canvas.drawCircle(position, radius, starPaint);
    
    // Draw subtle glow for some stars based on probability
    final Random random = Random(starIndex);
    if (random.nextDouble() > (1.0 - glowProbability)) {
      final double glowOpacity = min(1.0, max(0.0, opacity * 0.3));
      final Paint glowPaint = Paint()
        ..color = Colors.white.withOpacity(glowOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      
      canvas.drawCircle(position, radius * 1.5, glowPaint);
    }
  }
  
  /// Draw constellation lines connecting stars
  static void drawConstellationLines(
    Canvas canvas, 
    List<List<String>> lines, 
    Map<String, Offset> starPositions, 
    {
      Color color = Colors.blue,
      double opacity = 0.4,
      double strokeWidth = 1.0
    }
  ) {
    final Paint linePaint = Paint()
      ..color = color.withOpacity(opacity)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    
    for (final line in lines) {
      if (line.length == 2) {
        final String star1Id = line[0];
        final String star2Id = line[1];
        
        if (starPositions.containsKey(star1Id) && starPositions.containsKey(star2Id)) {
          canvas.drawLine(
            starPositions[star1Id]!,
            starPositions[star2Id]!,
            linePaint
          );
        }
      }
    }
  }
}