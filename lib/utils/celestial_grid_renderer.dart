// lib/utils/celestial_grid_renderer.dart
import 'package:flutter/material.dart';
import 'celestial_projections_inside.dart';

/// Utility class for rendering celestial grids
class CelestialGridRenderer {
  /// Draw a celestial grid on a canvas
  static void drawCelestialGrid(
    Canvas canvas, 
    Size size, 
    Vector3D viewDir, 
    Function(double, double) celestialToDirection,
    Function(Vector3D, Size, Vector3D) projectToScreen,
    Function(Vector3D, Vector3D) isPointVisible,
    {
      Color gridColor = Colors.lightBlue,
      double opacity = 0.2,
      double strokeWidth = 1.0,
      int meridianCount = 24,
      int parallelCount = 18,
    }
  ) {
    final Paint gridPaint = Paint()
      ..color = gridColor.withOpacity(opacity)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    
    // Draw meridians (longitude lines)
    for (int i = 0; i < meridianCount; i++) { // 24 meridians = 15° spacing
      final double ra = i * (360 / meridianCount); // RA in degrees
      final List<Offset> points = [];
      
      // Draw points along this meridian
      for (int j = 0; j <= 36; j++) { // Higher resolution for smoother curves
        final double dec = -90.0 + j * 5.0; // Dec in degrees
        
        // Convert to direction vector
        final direction = celestialToDirection(ra, dec);
        
        // Check if it's in our field of view
        if (!isPointVisible(direction, viewDir)) {
          // If we have points already, draw what we have so far
          if (points.isNotEmpty) {
            _drawLines(canvas, points, gridPaint);
            points.clear();
          }
          continue;
        }
        
        // Project to screen coordinates
        final screenPos = projectToScreen(
          direction, 
          size, 
          viewDir
        );
        
        points.add(screenPos);
      }
      
      _drawLines(canvas, points, gridPaint);
    }
    
    // Draw parallels (latitude lines)
    for (int i = 1; i < parallelCount; i++) { // Skip poles
      final double dec = -90.0 + i * (180 / parallelCount); // Dec in degrees
      final List<Offset> points = [];
      
      // Draw points along this parallel
      for (int j = 0; j <= 72; j++) { // Higher resolution for smoother curves
        final double ra = j * 5.0; // RA in degrees
        
        // Convert to direction vector
        final direction = celestialToDirection(ra, dec);
        
        // Check if it's in our field of view
        if (!isPointVisible(direction, viewDir)) {
          // If we have points already, draw what we have so far
          if (points.isNotEmpty) {
            _drawLines(canvas, points, gridPaint);
            points.clear();
          }
          continue;
        }
        
        // Project to screen coordinates
        final screenPos = projectToScreen(
          direction, 
          size, 
          viewDir
        );
        
        points.add(screenPos);
      }
      
      _drawLines(canvas, points, gridPaint);
    }
  }
  
  /// Draw a connected line through the given points
  static void _drawLines(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    
    canvas.drawPath(path, paint);
  }
}