// lib/utils/star_renderer.dart
import 'dart:math';
import 'package:flutter/material.dart';

import 'celestial_projections.dart';

/// Utility class for rendering stars with consistent appearance and behavior
class StarRenderer {
  /// Calculate star size based on magnitude, screen size, and device pixel ratio
  static double calculateStarSize(double magnitude, Size screenSize) {
  // Base size calculation based on magnitude (brighter = larger)
  // Scaling down by reducing the base size and coefficient
  double baseSize = max(1.5, 6.0 - magnitude * 0.5); // Reduced from 8.0 to 6.0, coefficient from 0.7 to 0.5
  
  // Calculate diagonal size of screen for consistent scaling across devices
  double screenDiagonal = sqrt(screenSize.width * screenSize.width + 
                             screenSize.height * screenSize.height);
  
  // Scale factor based on screen diagonal (normalize to a reference size)
  // Reference: 1500px diagonal (typical tablet)
  double scaleFactor = screenDiagonal / 1500.0;
  
  // Apply logarithmic scaling to prevent stars from being too large on large screens
  // Reduce the scaling factor to make stars smaller
  double sizeScale = 0.5 + (log(scaleFactor + 0.5) / log(2)); // Reduced from 0.7 to 0.5
  
  // Apply scale with lower and upper bounds
  // Reduce both the minimum and maximum size
  return max(1.0, min(baseSize * sizeScale, 7.0)); // Reduced min from 1.5 to 1.0, max from 10.0 to 7.0
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
  
/// Calculate appropriate star sizes for background stars based on screen size
static double calculateBackgroundStarSize(int starIndex, Size screenSize) {
  // Use the star index to create different sized background stars
  final Random random = Random(starIndex);
   
  // Increase the base size
  double baseSize = random.nextDouble() * 0.5 + 1; // Increased from 0.2+0.01 to 0.5+0.8
   
  // Calculate diagonal size for consistent scaling
  double screenDiagonal = sqrt(screenSize.width * screenSize.width +
                             screenSize.height * screenSize.height);
   
  // Scale factor that grows more slowly for larger screens
  double scaleFactor = screenDiagonal / 1500.0;
  double sizeScale = 0.2 + (log(scaleFactor + 0.3) / log(3)); // Increased from 0.1 to 0.2
   
  // Apply scale with larger bounds
  return max(0.3, min(baseSize * sizeScale, 2.5)); // Increased min from 0.01 to 0.3, max from 1.5 to 2.5
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
    // Calculate base star size with screen-aware scaling
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
  
  /// Draw a background star with simpler appearance and size scaled by screen
  static void drawBackgroundStar(
    Canvas canvas,
    int starIndex,
    Offset position,
    double radius,
    double baseOpacity,
    double phase,
    Size screenSize,
    {
      double glowProbability = 0.2,
      double twinkleIntensity = 0.3,
    }
  ) {
    // Apply screen-aware scaling to background stars
    final double scaledRadius = calculateBackgroundStarSize(starIndex, screenSize);
    
    // Apply twinkling - but make sure opacity stays in valid range 0-1
    final double starSeed = starIndex * 17.0; // Use star index as seed
    
    // Use a fixed very slow phase with reduced effect
    final double twinkleFactor = max(0, sin(phase * 0.2 + (starSeed % pi))) * twinkleIntensity;
    
    // Adjust opacity with twinkling - ensure it's clamped to valid range
    final double opacity = min(1.0, max(0.0, baseOpacity * (1.0 + twinkleFactor * 0.2)));
    
    // Draw star
    final Paint starPaint = Paint()
      ..color = Colors.white.withOpacity(opacity);
    
    canvas.drawCircle(position, scaledRadius, starPaint);
    
    // Draw subtle glow for some stars based on probability
    final Random random = Random(starIndex);
    if (random.nextDouble() > (1.0 - glowProbability)) {
      final double glowOpacity = min(1.0, max(0.0, opacity * 0.3));
      final Paint glowPaint = Paint()
        ..color = Colors.white.withOpacity(glowOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      
      canvas.drawCircle(position, scaledRadius * 1.5, glowPaint);
    }
  }

  /// Draw a set of random background stars across the sky
static void drawRandomBackgroundStars(
  Canvas canvas,
  Size size,
  double twinklePhase,
  Function(Vector3D, Vector3D) isPointVisible,
  Function(Vector3D, Size, Vector3D) projectToScreen,
  Vector3D viewDirection,
  {
    int starDensity = 1, // Parameter to control star density
    int seed = 42, // Fixed seed for consistent pattern
    double glowProbability = 0.2,
    double twinkleIntensity = 0.3,
  }
) {
  final Random random = Random(seed);
  final int starCount = (size.width * size.height / 2000).round().clamp(500, 3000) * starDensity;
  
  for (int i = 0; i < starCount; i++) {
    // Create a random 3D direction
    final double theta = random.nextDouble() * 2 * pi;
    final double phi = acos(2 * random.nextDouble() - 1);
    
    final double x = sin(phi) * cos(theta);
    final double y = cos(phi);
    final double z = sin(phi) * sin(theta);
    
    final direction = Vector3D(x, y, z);
    
    // Check if it's in field of view
    if (!isPointVisible(direction, viewDirection)) {
      continue;
    }
    
    // Project to screen
    final screenPos = projectToScreen(direction, size, viewDirection);
    
    // Skip if off-screen
    if (screenPos.dx < 0 || screenPos.dx > size.width ||
        screenPos.dy < 0 || screenPos.dy > size.height) {
      continue;
    }
    
    // Generate random properties for this star
    double radius = random.nextDouble() * 1.0 + 0.3; // Random radius between 0.3-1.3 pixels
    double baseOpacity = random.nextDouble() * 0.5 + 0.2; // Random opacity between 0.2-0.7
    
    // Use the existing drawBackgroundStar method
    drawBackgroundStar(
      canvas,
      i,
      screenPos,
      radius,
      baseOpacity,
      twinklePhase,
      size,
      glowProbability: glowProbability,
      twinkleIntensity: twinkleIntensity
    );
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