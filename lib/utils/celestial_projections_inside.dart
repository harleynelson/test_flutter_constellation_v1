// lib/utils/celestial_projections_inside.dart
import 'dart:math';
import 'package:flutter/material.dart';

/// Simple 3D vector class with mutable properties
class Vector3D {
  double x;
  double y;
  double z;
  
  Vector3D(this.x, this.y, this.z);
  
  @override
  String toString() => 'Vector3D($x, $y, $z)';
}

/// Utility class for celestial projection with true inside-out perspective
class CelestialProjectionInside {
  // The field of view in degrees - how much of the sky we can see at once
  final double fieldOfView;
  
  // The direction we're looking, in spherical coordinates
  // heading: angle around the horizon (0=North, 90=East, 180=South, 270=West)
  final double heading;
  
  // pitch: angle up/down from horizon (-90=straight down, 0=horizon, 90=straight up)
  final double pitch;
  
  // Create a new projection with the given parameters
  CelestialProjectionInside({
    this.fieldOfView = 90.0,
    this.heading = 0.0,
    this.pitch = 0.0,
  });
  
  /// Convert celestial (RA/Dec) coordinates to 3D direction vector
  /// This places the viewer at the center (0,0,0) looking out
  Vector3D celestialToDirection(double rightAscension, double declination) {
    // Convert to radians
    final raRad = rightAscension * pi / 180.0;
    final decRad = declination * pi / 180.0;
    
    // Convert to unit vector pointing from center (0,0,0) outward
    // x = toward ra=0, y = toward north pole, z = toward ra=90
    final x = cos(decRad) * cos(raRad);
    final y = sin(decRad);
    final z = cos(decRad) * sin(raRad);
    
    return Vector3D(x, y, z);
  }
  
  /// Convert our heading and pitch to a view direction vector
  Vector3D viewToDirection() {
    // Convert to radians
    final headingRad = heading * pi / 180.0;
    final pitchRad = pitch * pi / 180.0;
    
    // Calculate the direction we're looking
    // For heading: 0=North(+z), 90=East(+x), 180=South(-z), 270=West(-x)
    // For pitch: -90=down(-y), 0=horizon, 90=up(+y)
    final x = cos(pitchRad) * sin(headingRad);
    final y = sin(pitchRad);
    final z = cos(pitchRad) * cos(headingRad);
    
    return Vector3D(x, y, z);
  }
  
  /// Calculate if a point is visible in our current view
  bool isPointVisible(Vector3D point, Vector3D viewDir) {
    // Normalize the point direction (ensure it's a unit vector)
    final length = sqrt(point.x * point.x + point.y * point.y + point.z * point.z);
    final normalizedPoint = Vector3D(
      point.x / length,
      point.y / length,
      point.z / length
    );
    
    // Calculate the dot product between our view direction and the point direction
    // dot = cos(angle between vectors)
    final dot = viewDir.x * normalizedPoint.x + 
                viewDir.y * normalizedPoint.y + 
                viewDir.z * normalizedPoint.z;
    
    // If dot > 0, the point is in front of us (angle < 90 degrees)
    // We add a buffer based on field of view
    final viewCos = cos(fieldOfView * pi / 360.0); // Half FOV in radians
    
    return dot > viewCos;
  }
  
  /// Project a 3D direction onto the 2D view plane
  Offset projectToScreen(Vector3D point, Size screenSize, Vector3D viewDir) {
    // First check if the point is behind us
    if (!isPointVisible(point, viewDir)) {
      return Offset(-10000, -10000); // Off-screen
    }
    
    // We need to find the up and right vectors for our view
    // Up is perpendicular to view direction and world up (0,1,0) unless we're looking straight up/down
    Vector3D up;
    if (viewDir.y > 0.99 || viewDir.y < -0.99) {
      // Looking straight up/down, use world-z as tempUp
      up = Vector3D(0, 0, viewDir.y > 0 ? -1 : 1);
    } else {
      // Normal case
      //const worldUp = Vector3D(0, 1, 0);
      // Cross product viewDir × worldUp gives right vector
      final rightX = viewDir.z;
      final rightY = 0;
      final rightZ = -viewDir.x;
      
      // Normalize right vector
      final rightLength = sqrt(rightX * rightX + rightZ * rightZ);
      final normalizedRightX = rightX / rightLength;
      final normalizedRightZ = rightZ / rightLength;
      
      // Cross product right × viewDir gives up vector
      up = Vector3D(
        normalizedRightZ * viewDir.y,
        normalizedRightX * viewDir.z - normalizedRightZ * viewDir.x,
        -normalizedRightX * viewDir.y
      );
    }
    
    // Now we have viewDir, up, and we can compute right = viewDir × up
    final right = Vector3D(
      viewDir.y * up.z - viewDir.z * up.y,
      viewDir.z * up.x - viewDir.x * up.z,
      viewDir.x * up.y - viewDir.y * up.x
    );
    
    // Project the point onto our view plane
    // First, calculate vector from viewpoint to the point
    final toPoint = Vector3D(point.x, point.y, point.z);
    
    // Calculate the dot products to get 2D coordinates in our view space
    final dot = toPoint.x * viewDir.x + toPoint.y * viewDir.y + toPoint.z * viewDir.z;
    final rightDot = toPoint.x * right.x + toPoint.y * right.y + toPoint.z * right.z;
    final upDot = toPoint.x * up.x + toPoint.y * up.y + toPoint.z * up.z;
    
    // Calculate the angle from view center
    final angleFromCenter = acos(dot);
    
    // Calculate the x,y position on a unit circle
    final scale = tan(angleFromCenter) / angleFromCenter;
    final x = rightDot * scale;
    final y = upDot * scale;
    
    // Scale to screen size with a factor based on FOV
    final scaleFactor = (screenSize.width / 1) / tan(fieldOfView * pi / 360); // Increase scaling
    
    return Offset(
      screenSize.width / 2 + x * scaleFactor,
      screenSize.height / 2 - y * scaleFactor  // Flip y because screen coords go down
    );
  }
}