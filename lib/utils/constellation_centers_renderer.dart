// lib/utils/constellation_centers_renderer.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/constellation_center.dart';
import '../utils/celestial_projections_inside.dart';

/// Utility class for rendering constellation center labels
class ConstellationCentersRenderer {
  // Make this a utility class with only static methods
  ConstellationCentersRenderer._();
  
  /// Draw constellation center labels using inside-out projection
  static void drawConstellationCenters(
    Canvas canvas, 
    List<ConstellationCenter> centers,
    Size size,
    Vector3D viewDirection,
    Function(double, double) celestialToDirection,
    Function(Vector3D, Size, Vector3D) projectToScreen,
    Function(Vector3D, Vector3D) isPointVisible,
    {
      Color textColor = Colors.yellow,
      double opacity = 0.7,
      double fontSize = 14.0,
      bool drawBackground = true,
      bool scaleByRank = true,
    }
  ) {
    for (var center in centers) {
      // Convert to 3D direction vector
      final direction = celestialToDirection(
        center.rightAscensionDegrees, 
        center.declination
      );
      
      // Check if it's in our field of view
      if (!isPointVisible(direction, viewDirection)) {
        continue;
      }
      
      // Project to screen coordinates
      final screenPos = projectToScreen(
        direction, 
        size, 
        viewDirection
      );
      
      // Skip if off-screen
      if (screenPos.dx < 0 || screenPos.dx > size.width ||
          screenPos.dy < 0 || screenPos.dy > size.height) {
        continue;
      }
      
      // Calculate size based on rank if enabled (higher rank = smaller size)
      final double adjustedFontSize = scaleByRank
          ? fontSize * (1.0 - (center.rank / 100.0)) // Subtle scaling based on rank
          : fontSize;
      
      // Draw text with background
      _drawConstellationLabel(
        canvas,
        center.abbreviation,
        screenPos,
        textColor: textColor,
        opacity: opacity,
        fontSize: adjustedFontSize,
        drawBackground: drawBackground,
      );
    }
  }
  
  /// Draw a constellation label at the specified position
  static void _drawConstellationLabel(
    Canvas canvas,
    String text,
    Offset position,
    {
      Color textColor = Colors.yellow,
      double opacity = 0.7,
      double fontSize = 14.0,
      bool drawBackground = true,
    }
  ) {
    // Create text painter
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor.withOpacity(opacity),
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.7),
              offset: const Offset(1.0, 1.0),
              blurRadius: 2.0,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    // Layout text
    textPainter.layout();
    
    // Draw background if enabled
    if (drawBackground) {
      final Rect textRect = Rect.fromCenter(
        center: position,
        width: textPainter.width + 8,
        height: textPainter.height + 4,
      );
      
      final Paint bgPaint = Paint()
        ..color = Colors.black.withOpacity(0.5)
        ..style = PaintingStyle.fill;
      
      final Paint borderPaint = Paint()
        ..color = textColor.withOpacity(opacity * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      
      // Draw rounded rectangle with border
      final RRect rRect = RRect.fromRectAndRadius(
        textRect, 
        const Radius.circular(4.0)
      );
      
      canvas.drawRRect(rRect, bgPaint);
      canvas.drawRRect(rRect, borderPaint);
    }
    
    // Draw text centered at the position
    textPainter.paint(
      canvas, 
      Offset(
        position.dx - textPainter.width / 2, 
        position.dy - textPainter.height / 2
      )
    );
  }
}