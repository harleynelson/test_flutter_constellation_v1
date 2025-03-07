import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart';
import 'celestial_coordinate.dart';

/// Camera model for the celestial sphere view
class CelestialCamera {
  /// Camera position (always at center for this implementation)
  final Vector3 position = Vector3(0, 0, 0);
  
  /// Camera orientation (where we're looking)
  Vector3 _lookDirection = Vector3(1, 0, 0); // Default: looking at RA=0, Dec=0
  
  /// Camera up direction
  Vector3 _upDirection = Vector3(0, 0, 1); // Default: celestial north pole is up
  
  /// Field of view in radians
  double fieldOfView = pi / 2; // 90 degrees
  
  /// Get the camera's look direction
  Vector3 get lookDirection => _lookDirection;
  
  /// Get the camera's up direction
  Vector3 get upDirection => _upDirection;
  
  /// Get right vector (calculated from look and up)
  Vector3 get rightDirection {
    final right = _lookDirection.cross(_upDirection);
    right.normalize();
    return right;
  }
  
  /// Look at a specific celestial coordinate
  void lookAt(CelestialCoordinate coordinate) {
    _lookDirection = coordinate.toCartesian();
    
    // Adjust up direction to keep celestial north pole up when possible
    final celestialNorth = Vector3(0, 0, 1);
    
    // If we're looking exactly at the pole, use a different up vector
    if ((_lookDirection - celestialNorth).length < 0.01 || 
        (_lookDirection + celestialNorth).length < 0.01) {
      _upDirection = Vector3(0, 1, 0);
    } else {
      // Calculate up direction perpendicular to look direction and in plane with north pole
      final right = _lookDirection.cross(celestialNorth);
      right.normalize();
      _upDirection = right.cross(_lookDirection);
      _upDirection.normalize();
    }
  }
  
  /// Rotate the camera with horizontal and vertical angle changes in radians
  void rotate(double horizontalRadians, double verticalRadians) {
    // Create rotation quaternions
    final horizontalRotation = Quaternion.axisAngle(upDirection, -horizontalRadians);
    
    // Apply horizontal rotation first
    _lookDirection = horizontalRotation.rotate(_lookDirection);
    
    // Calculate the axis for vertical rotation (perpendicular to look and up)
    final rightAxis = rightDirection;
    
    // Apply vertical rotation
    final verticalRotation = Quaternion.axisAngle(rightAxis, verticalRadians);
    _lookDirection = verticalRotation.rotate(_lookDirection);
    
    // Ensure look direction is normalized
    _lookDirection.normalize();
    
    // Recalculate up direction
    final celestialNorth = Vector3(0, 0, 1);
    final right = _lookDirection.cross(celestialNorth);
    if (right.length > 0.01) {
      right.normalize();
      _upDirection = right.cross(_lookDirection);
      _upDirection.normalize();
    }
  }
  
  /// Convert a point on the celestial sphere to screen coordinates
  /// Returns null if the point is not visible (behind the camera)
  Offset? projectToScreen(Vector3 point, Size screenSize) {
    // Calculate vector from camera to point
    final direction = point - position;
    direction.normalize();
    
    // Calculate dot product with view direction
    final dotProduct = direction.dot(_lookDirection);
    
    // If the point is behind the camera, return null
    if (dotProduct <= 0) return null;
    
    // Create view and projection matrices
    final viewMatrix = makeViewMatrix(position, position + _lookDirection, _upDirection);
    final projectionMatrix = makePerspectiveMatrix(
      fieldOfView, 
      screenSize.width / screenSize.height, 
      0.1, 
      100.0
    );
    
    // Combined matrix
    final viewProjectionMatrix = projectionMatrix * viewMatrix;
    
    // Convert to homogeneous coordinates
    final homogeneousCoords = Vector4(point.x, point.y, point.z, 1.0);
    
    // Apply transform
    final clipCoords = viewProjectionMatrix.transform(homogeneousCoords);
    
    // Perspective division
    final ndcX = clipCoords.x / clipCoords.w;
    final ndcY = clipCoords.y / clipCoords.w;
    
    // Convert to screen coordinates
    final screenX = (ndcX + 1.0) * screenSize.width / 2;
    final screenY = (1.0 - ndcY) * screenSize.height / 2;
    
    return Offset(screenX, screenY);
  }
  
  /// Get the current celestial coordinate the camera is looking at
  CelestialCoordinate getCurrentCoordinate() {
    // Convert cartesian to celestial coordinates
    final x = _lookDirection.x;
    final y = _lookDirection.y;
    final z = _lookDirection.z;
    
    // Calculate declination (from -90 to +90 degrees)
    final dec = asin(z) * 180 / pi;
    
    // Calculate right ascension (from 0 to 24 hours)
    var ra = atan2(y, x) * 12 / pi;
    
    // Make sure RA is in the range 0-24
    if (ra < 0) ra += 24;
    
    return CelestialCoordinate(rightAscension: ra, declination: dec);
  }
}