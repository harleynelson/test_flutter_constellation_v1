// lib/painters/wireframe_sphere_painter.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../controllers/celestial_projection_controller.dart';
import '../utils/celestial_projections.dart';

/// Painter for rendering a wireframe sphere to visualize the celestial sphere
class WireframeSphereCustomPainter extends CustomPainter {
  final CelestialProjectionController projectionController;
  final bool showMeridians;
  final bool showParallels;
  final int meridianCount;
  final int parallelCount;
  final Color color;
  
  WireframeSphereCustomPainter({
    required this.projectionController,
    this.showMeridians = true,
    this.showParallels = true,
    this.meridianCount = 24, // 24 meridians = 15° spacing
    this.parallelCount = 12, // 12 parallels = 15° spacing
    this.color = Colors.blue,
  }) : super(repaint: projectionController);
  
  @override
  void paint(Canvas canvas, Size size) {
    // Only draw in 3D mode
    if (!projectionController.is3DMode) return;
    
    final Paint linePaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    // Draw meridians (longitude lines, like segments of an orange)
    if (showMeridians) {
      for (int m = 0; m < meridianCount; m++) {
        final double longitude = m * (360 / meridianCount);
        final List<Offset> points = [];
        
        // Create points along this meridian
        for (int p = 0; p <= 36; p++) {  // Higher resolution for smoother curves
          final double latitude = -90 + p * (180 / 36);
          
          // Convert to 3D point
          final point3D = projectionController.projection.celestialTo3D(
            longitude,
            latitude
          );
          
          // Project to screen coordinates
          final screenPoint = projectionController.projection.project3DToScreen(
            point3D,
            size
          );
          
          // Skip invalid points (behind viewer)
          if (screenPoint.dx >= -5000 && screenPoint.dx <= size.width + 5000 &&
              screenPoint.dy >= -5000 && screenPoint.dy <= size.height + 5000) {
            points.add(screenPoint);
          } else if (points.isNotEmpty) {
            // Draw the segment collected so far
            _drawLines(canvas, points, linePaint);
            points.clear();
          }
        }
        
        _drawLines(canvas, points, linePaint);
      }
    }
    
    // Draw parallels (latitude lines, like horizontal slices)
    if (showParallels) {
      for (int p = 1; p < parallelCount; p++) {
        final double latitude = -90 + p * (180 / parallelCount);
        final List<Offset> points = [];
        
        // Create points along this parallel
        for (int m = 0; m <= 36; m++) {  // Higher resolution for smoother curves
          final double longitude = m * (360 / 36);
          
          // Convert to 3D point
          final point3D = projectionController.projection.celestialTo3D(
            longitude,
            latitude
          );
          
          // Project to screen coordinates
          final screenPoint = projectionController.projection.project3DToScreen(
            point3D,
            size
          );
          
          // Skip invalid points (behind viewer)
          if (screenPoint.dx >= -5000 && screenPoint.dx <= size.width + 5000 &&
              screenPoint.dy >= -5000 && screenPoint.dy <= size.height + 5000) {
            points.add(screenPoint);
          } else if (points.isNotEmpty) {
            // Draw the segment collected so far
            _drawLines(canvas, points, linePaint);
            points.clear();
          }
        }
        
        _drawLines(canvas, points, linePaint);
      }
    }
    
    // Draw compass directions for orientation
    _drawCompassLabels(canvas, size);
  }
  
  // Draw a connected line through the given points
  void _drawLines(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    
    canvas.drawPath(path, paint);
  }
  
  // Draw compass direction labels (N, E, S, W)
  void _drawCompassLabels(Canvas canvas, Size size) {
    final compassDirections = [
      {'label': 'N', 'ra': 0, 'dec': 90},     // North
      {'label': 'S', 'ra': 0, 'dec': -90},    // South
      {'label': 'E', 'ra': 90, 'dec': 0},     // East
      {'label': 'W', 'ra': 270, 'dec': 0},    // West
      {'label': 'NE', 'ra': 45, 'dec': 45},   // Northeast
      {'label': 'SE', 'ra': 135, 'dec': -45}, // Southeast
      {'label': 'SW', 'ra': 225, 'dec': -45}, // Southwest
      {'label': 'NW', 'ra': 315, 'dec': 45},  // Northwest
    ];
    
    for (final direction in compassDirections) {
      // Convert to 3D point
      final point3D = projectionController.projection.celestialTo3D(
        direction['ra'] as double,
        direction['dec'] as double
      );
      
      // Apply rotations to determine if the point is behind the viewer
      Vector3D rotated = point3D;
      final rotationAngles = projectionController.projection.rotationAngles;
      
      if (rotationAngles != null) {
        // Apply X rotation
        if (rotationAngles.x != 0) {
          final double cosX = cos(rotationAngles.x);
          final double sinX = sin(rotationAngles.x);
          rotated = Vector3D(
            rotated.x,
            rotated.y * cosX - rotated.z * sinX,
            rotated.y * sinX + rotated.z * cosX
          );
        }
        
        // Apply Y rotation
        if (rotationAngles.y != 0) {
          final double cosY = cos(rotationAngles.y);
          final double sinY = sin(rotationAngles.y);
          rotated = Vector3D(
            rotated.x * cosY + rotated.z * sinY,
            rotated.y,
            -rotated.x * sinY + rotated.z * cosY
          );
        }
      }
      
      // Skip if behind viewer
      if (rotated.z < -0.8) continue;
      
      // Project to screen coordinates
      final screenPoint = projectionController.projection.project3DToScreen(
        point3D,
        size
      );
      
      // Skip if offscreen
      if (screenPoint.dx < 0 || screenPoint.dx > size.width ||
          screenPoint.dy < 0 || screenPoint.dy > size.height) {
        continue;
      }
      
      // Draw the label
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: direction['label'] as String,
          style: TextStyle(
            color: color.withOpacity(0.7),
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black,
                offset: const Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas, 
        Offset(
          screenPoint.dx - textPainter.width / 2, 
          screenPoint.dy - textPainter.height / 2
        )
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant WireframeSphereCustomPainter oldDelegate) {
    return oldDelegate.projectionController != projectionController ||
           oldDelegate.meridianCount != meridianCount ||
           oldDelegate.parallelCount != parallelCount ||
           oldDelegate.color != color ||
           oldDelegate.showMeridians != showMeridians ||
           oldDelegate.showParallels != showParallels;
  }
}