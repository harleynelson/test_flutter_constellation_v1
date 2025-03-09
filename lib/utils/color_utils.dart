// lib/utils/color_utils.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Utility class for star colors and visual effects
class ColorUtils {
  /// Get color based on B-V color index
  static Color getStarColorFromBV(double bv) {
    // B-V approximation to RGB colors
    if (bv < -0.3) return const Color(0xFFCAE8FF);      // Very blue (hot)
    if (bv < 0.0) return const Color(0xFFE6F0FF);       // Blue-white
    if (bv < 0.3) return Colors.white;                  // White
    if (bv < 0.6) return const Color(0xFFFFF8E8);       // Yellow-white
    if (bv < 1.0) return const Color(0xFFFFEFB3);       // Yellow
    if (bv < 1.5) return const Color(0xFFFFD2A1);       // Orange
    return const Color(0xFFFFBDAD);                     // Red
  }
  
  /// Get color based on spectral type
  static Color getStarColorFromSpectralType(String? spectralType) {
    if (spectralType == null || spectralType.isEmpty) {
      return Colors.white;
    }
    
    final String mainClass = spectralType[0].toUpperCase();
    
    switch (mainClass) {
      case 'O': return const Color(0xFFCAE8FF);    // Blue
      case 'B': return const Color(0xFFE6F0FF);    // Blue-white
      case 'A': return Colors.white;               // White
      case 'F': return const Color(0xFFFFF8E8);    // Yellow-white
      case 'G': return const Color(0xFFFFEFB3);    // Yellow
      case 'K': return const Color(0xFFFFD2A1);    // Orange
      case 'M': return const Color(0xFFFFBDAD);    // Red
      default:  return Colors.white;
    }
  }
  
  /// Calculate star size based on magnitude and zoom
  static double calculateStarSize(double magnitude, double baseSize, double zoom) {
    // Brighter stars (lower magnitude) appear larger
    double size = (6.0 - magnitude.clamp(-1.5, 6.0)) * baseSize;
    // Apply zoom factor
    size *= zoom * 0.5;
    // Ensure a minimum visible size
    return math.max(1.5, size);
  }
  
  /// Create a twinkling effect (returns an opacity factor)
  static double calculateTwinkle(int starId, double phase, double intensity) {
    // Use star ID as seed for varied twinkling
    final double offset = ((starId * 81) % 100) / 100.0;
    final double adjustedPhase = phase + offset * 2 * math.pi;
    
    // Subtle sine wave oscillation
    return 1.0 + math.sin(adjustedPhase) * intensity;
  }
  
  /// Adjust color brightness for twinkling
  static Color adjustBrightness(Color color, double factor) {
    final int r = math.min(255, (color.red + (255 - color.red) * factor).round());
    final int g = math.min(255, (color.green + (255 - color.green) * factor).round());
    final int b = math.min(255, (color.blue + (255 - color.blue) * factor).round());
    
    return Color.fromRGBO(r, g, b, color.opacity);
  }
  
  /// Draw a star with glow effect
  static void drawStar(
    Canvas canvas, 
    Offset position, 
    double radius, 
    Color color, 
    double twinkleFactor
  ) {
    // Adjust color based on twinkle
    final Color adjustedColor = adjustBrightness(color, twinkleFactor * 0.2);
    
    // Draw glow
    final Paint glowPaint = Paint()
      ..color = adjustedColor.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    
    canvas.drawCircle(position, radius * 1.5, glowPaint);
    
    // Draw star core
    final Paint corePaint = Paint()..color = adjustedColor;
    canvas.drawCircle(position, radius, corePaint);
  }
}