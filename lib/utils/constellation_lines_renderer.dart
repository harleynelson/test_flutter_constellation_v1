// lib/utils/constellation_lines_renderer.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/constellation_line.dart';
import '../utils/celestial_projections_inside.dart';

/// Utility class for rendering constellation lines
class ConstellationLinesRenderer {
  // Make this a utility class with only static methods
  ConstellationLinesRenderer._();
  
  /// Draw all constellation lines using inside-out projection
  static void drawConstellationLines(
    Canvas canvas, 
    Map<String, List<List<double>>> polylines,
    Size size,
    Vector3D viewDirection,
    Function(double, double) celestialToDirection,
    Function(Vector3D, Size, Vector3D) projectToScreen,
    Function(Vector3D, Vector3D) isPointVisible,
    {
      Color lineColor = Colors.blue,
      double opacity = 0.5,
      double strokeWidth = 1.0,
    }
  ) {
    final Paint linePaint = Paint()
      ..color = lineColor.withOpacity(opacity)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    
    for (final segmentKey in polylines.keys) {
      final points = polylines[segmentKey]!;
      
      if (points.length <= 1) continue;  // Skip segments with less than 2 points
      
      // Draw the polyline
      _drawPolyline(
        canvas, 
        points, 
        viewDirection, 
        celestialToDirection, 
        projectToScreen, 
        isPointVisible, 
        size,
        linePaint,
      );
    }
  }
  
  /// Draw a single polyline
  static void _drawPolyline(
    Canvas canvas,
    List<List<double>> points,
    Vector3D viewDirection,
    Function(double, double) celestialToDirection,
    Function(Vector3D, Size, Vector3D) projectToScreen,
    Function(Vector3D, Vector3D) isPointVisible,
    Size size,
    Paint paint,
  ) {
    final List<Offset> screenPoints = [];
    
    for (final point in points) {
      final rightAscension = point[0]; // RA in degrees
      final declination = point[1];    // Dec in degrees
      
      // Convert to 3D direction vector
      final direction = celestialToDirection(rightAscension, declination);
      
      // Check if it's in our field of view
      if (!isPointVisible(direction, viewDirection)) {
        // If we have accumulated points, draw them and start a new path
        if (screenPoints.isNotEmpty) {
          _drawPath(canvas, screenPoints, paint);
          screenPoints.clear();
        }
        continue;
      }
      
      // Project to screen coordinates
      final screenPos = projectToScreen(direction, size, viewDirection);
      
      // Skip if off-screen
      if (screenPos.dx < -1000 || screenPos.dx > size.width + 1000 ||
          screenPos.dy < -1000 || screenPos.dy > size.height + 1000) {
        if (screenPoints.isNotEmpty) {
          _drawPath(canvas, screenPoints, paint);
          screenPoints.clear();
        }
        continue;
      }
      
      // Add to current path
      screenPoints.add(screenPos);
    }
    
    // Draw any remaining points
    if (screenPoints.length > 1) {
      _drawPath(canvas, screenPoints, paint);
    }
  }
  
  /// Draw a path through the given points
  static void _drawPath(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    
    final Path path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    
    for (int i = 1; i < points.length; i++) {
      // Only connect if the distance between points is reasonable
      // This prevents lines from stretching across the whole screen
      if ((points[i] - points[i-1]).distance < 300) {
        path.lineTo(points[i].dx, points[i].dy);
      } else {
        // Start a new sub-path
        path.moveTo(points[i].dx, points[i].dy);
      }
    }
    
    canvas.drawPath(path, paint);
  }
}