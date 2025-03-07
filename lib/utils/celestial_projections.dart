// lib/utils/celestial_projections.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/enhanced_constellation.dart';

/// Utility class for celestial coordinate calculations and projections
class CelestialProjection {
  /// Field of view in degrees
  final double fieldOfView;
  
  /// Center right ascension in degrees
  final double centerRightAscension;
  
  /// Center declination in degrees 
  final double centerDeclination;
  
  /// 3D rotation angles (in radians)
  final Vector3D? rotationAngles;
  
  /// Rotation angle for orientation (in radians)
  final double rotationAngle;
  
  /// Perspective depth for 3D effect (0.0 = flat, 1.0 = full perspective)
  final double perspectiveDepth;
  
  CelestialProjection({
    this.fieldOfView = 60.0,
    this.centerRightAscension = 0.0,
    this.centerDeclination = 0.0,
    this.rotationAngles,
    this.rotationAngle = 0.0,
    this.perspectiveDepth = 0.0,
  });
  
  /// Converts celestial coordinates (RA, Dec) to 2D screen coordinates
  /// using stereographic projection
  Offset celestialToScreenStereographic(
    double rightAscension, 
    double declination, 
    Size screenSize,
  ) {
    // Convert degrees to radians
    final double raRad = rightAscension * pi / 180.0;
    final double decRad = declination * pi / 180.0;
    final double centerRaRad = centerRightAscension * pi / 180.0;
    final double centerDecRad = centerDeclination * pi / 180.0;
    
    // Calculate direction cosines for inside-looking-out perspective
    final double x = -cos(decRad) * sin(raRad - centerRaRad);
    final double y = sin(decRad) * cos(centerDecRad) - cos(decRad) * sin(centerDecRad) * cos(raRad - centerRaRad);
    final double z = -sin(decRad) * sin(centerDecRad) - cos(decRad) * cos(centerDecRad) * cos(raRad - centerRaRad);
    
    // Check if the star is behind the viewer
    if (z < 0) {
      return Offset(-1000, -1000); // Behind the viewer, not visible
    }
    
    // Apply stereographic projection
    final double scale = screenSize.width / (fieldOfView * pi / 180.0);
    
    // Calculate 2D coordinates
    double projX = x / (1.0 + z);
    double projY = y / (1.0 + z);
    
    // Apply rotation if needed
    if (rotationAngle != 0) {
      final double cosAngle = cos(rotationAngle);
      final double sinAngle = sin(rotationAngle);
      final double rotX = projX * cosAngle - projY * sinAngle;
      final double rotY = projX * sinAngle + projY * cosAngle;
      projX = rotX;
      projY = rotY;
    }
    
    // Scale and center on screen
    final double screenX = screenSize.width / 2 + projX * scale;
    final double screenY = screenSize.height / 2 - projY * scale; // Y is flipped in screen coordinates
    
    return Offset(screenX, screenY);
  }
  
  /// Converts celestial coordinates to 3D coordinates for perspective rendering
  Vector3D celestialTo3D(double rightAscension, double declination) {
    // Convert degrees to radians
    final double raRad = rightAscension * pi / 180.0;
    final double decRad = declination * pi / 180.0;
    
    // Convert spherical to Cartesian coordinates (unit sphere)
    // X, Y, Z calculate positions on a unit celestial sphere
    final double x = cos(decRad) * cos(raRad);
    final double y = cos(decRad) * sin(raRad);
    final double z = sin(decRad);
    
    return Vector3D(x, y, z);
  }
  
  /// Project 3D coordinates onto 2D screen with perspective
  Offset project3DToScreen(Vector3D point, Size screenSize) {
    // Apply all 3D rotations if provided
    Vector3D rotated = point;
    
    if (rotationAngles != null) {
      // Apply X rotation (around X axis)
      if (rotationAngles!.x != 0) {
        final double cosX = cos(rotationAngles!.x);
        final double sinX = sin(rotationAngles!.x);
        rotated = Vector3D(
          rotated.x,
          rotated.y * cosX - rotated.z * sinX,
          rotated.y * sinX + rotated.z * cosX
        );
      }
      
      // Apply Y rotation (around Y axis)
      if (rotationAngles!.y != 0) {
        final double cosY = cos(rotationAngles!.y);
        final double sinY = sin(rotationAngles!.y);
        rotated = Vector3D(
          rotated.x * cosY + rotated.z * sinY,
          rotated.y,
          -rotated.x * sinY + rotated.z * cosY
        );
      }
      
      // Apply Z rotation (around Z axis)
      if (rotationAngles!.z != 0) {
        final double cosZ = cos(rotationAngles!.z);
        final double sinZ = sin(rotationAngles!.z);
        rotated = Vector3D(
          rotated.x * cosZ - rotated.y * sinZ,
          rotated.x * sinZ + rotated.y * cosZ,
          rotated.z
        );
      }
    }
    
    // Then rotate to match viewing angle (traditional 2D rotation)
    rotated = _rotatePoint(rotated, rotationAngle);
    
    // For inside-looking-out, we need to check if the point is in front of us
    // Points with z < 0 are behind the viewer, so don't draw them
    if (rotated.z > 0) {
      return Offset(-10000, -10000); // Off-screen
    }
    
    // Apply perspective projection
    final double distanceFromViewer = 2.0; // Arbitrary distance from camera
    double perspective = distanceFromViewer / (distanceFromViewer + rotated.z * perspectiveDepth);
    
    // Calculate screen coordinates
    final double screenX = screenSize.width / 2 + rotated.x * perspective * (screenSize.width / 3);
    final double screenY = screenSize.height / 2 - rotated.y * perspective * (screenSize.height / 3);
    
    return Offset(screenX, screenY);
  }
  
  /// Find apparent distance between two stars in 3D space
  double calculateApparentDistance(
    double ra1, double dec1,
    double ra2, double dec2,
  ) {
    final Vector3D point1 = celestialTo3D(ra1, dec1);
    final Vector3D point2 = celestialTo3D(ra2, dec2);
    
    // Calculate Euclidean distance between points on unit sphere
    final double dx = point2.x - point1.x;
    final double dy = point2.y - point1.y;
    final double dz = point2.z - point1.z;
    
    return sqrt(dx * dx + dy * dy + dz * dz);
  }
  
  /// Rotate a point around the Y axis
  Vector3D _rotatePoint(Vector3D point, double angle) {
    final double cosA = cos(angle);
    final double sinA = sin(angle);
    
    return Vector3D(
      point.x * cosA + point.z * sinA,
      point.y,
      -point.x * sinA + point.z * cosA,
    );
  }
  
  /// Calculate current viewing position based on date and time
  /// This can be used to set the centerRightAscension based on current time
  static double calculateViewingRA(DateTime time) {
    // Get fractional hour of the day in UTC
    final double utcHour = time.hour + time.minute / 60.0;
    
    // Calculate Local Sidereal Time (approximate)
    // 1 sidereal day is approximately 23h 56m 4s
    final int dayOfYear = time.difference(DateTime(time.year, 1, 1)).inDays;
    final double lst = (100.46 + 0.985647 * dayOfYear + utcHour * 15.0) % 360.0;
    
    return lst;
  }
}

/// Simple 3D vector class
class Vector3D {
  double x;
  double y;
  double z;
  
  Vector3D(this.x, this.y, this.z);
  
  @override
  String toString() => 'Vector3D($x, $y, $z)';
}