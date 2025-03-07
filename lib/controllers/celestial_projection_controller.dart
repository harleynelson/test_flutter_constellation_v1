// lib/controllers/celestial_projection_controller.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/celestial_projections.dart';

/// Controller for managing celestial projections and view transformations
class CelestialProjectionController extends ChangeNotifier {
  // Projection parameters
  double _fieldOfView = 60.0;
  double _centerRightAscension = 0.0;
  double _centerDeclination = 45.0;
  double _rotationAngle = 0.0;
  double _perspectiveDepth = 0.3;
  
  // View mode
  bool _is3DMode = false;
  
  // 3D rotation angles (in radians)
  final Vector3D _rotationAngles = Vector3D(0.0, 0.0, 0.0);
  
  // User interaction
  double _dragX = 0.0;
  double _dragY = 0.0;
  double _zoomFactor = 1.0;
  
  // Auto rotation
  bool _autoRotate = false;
  double _autoRotateSpeed = 0.001; // radians per frame
  
  // Getters
  double get fieldOfView => _fieldOfView * (1.0 / _zoomFactor);
  double get centerRightAscension => _centerRightAscension;
  double get centerDeclination => _centerDeclination;
  double get rotationAngle => _rotationAngle;
  double get perspectiveDepth => _perspectiveDepth;
  bool get is3DMode => _is3DMode;
  bool get autoRotate => _autoRotate;
  
  // Create the projection instance
  CelestialProjection get projection => CelestialProjection(
    fieldOfView: fieldOfView,
    centerRightAscension: _centerRightAscension + _dragX,
    centerDeclination: _centerDeclination + _dragY,
    rotationAngle: _rotationAngle,
    rotationAngles: _is3DMode ? _rotationAngles : null,
    perspectiveDepth: _perspectiveDepth,
  );
  
  // Initialize with default or provided values
  CelestialProjectionController({
    double fieldOfView = 60.0,
    double centerRightAscension = 0.0,
    double centerDeclination = 45.0,
    double rotationAngle = 0.0,
    double perspectiveDepth = 0.3,
    bool is3DMode = false,
  }) : 
    _fieldOfView = fieldOfView,
    _centerRightAscension = centerRightAscension,
    _centerDeclination = centerDeclination,
    _rotationAngle = rotationAngle,
    _perspectiveDepth = perspectiveDepth,
    _is3DMode = is3DMode;
  
  // Set the center of the view (in degrees)
  void setViewCenter(double rightAscension, double declination) {
    // Normalize RA to 0-360
    rightAscension = rightAscension % 360.0;
    if (rightAscension < 0) rightAscension += 360.0;
    
    // Clamp declination to -90 to +90
    declination = declination.clamp(-90.0, 90.0);
    
    if (_centerRightAscension != rightAscension || _centerDeclination != declination) {
      _centerRightAscension = rightAscension;
      _centerDeclination = declination;
      _dragX = 0.0;
      _dragY = 0.0;
      notifyListeners();
    }
  }
  
  // Set the field of view (in degrees)
  void setFieldOfView(double fov) {
    final double newFov = fov.clamp(10.0, 180.0);
    if (_fieldOfView != newFov) {
      _fieldOfView = newFov;
      notifyListeners();
    }
  }
  
  // Zoom in/out
  void zoom(double factor) {
    final double newZoom = (_zoomFactor * factor).clamp(0.5, 5.0);
    if (_zoomFactor != newZoom) {
      _zoomFactor = newZoom;
      notifyListeners();
    }
  }
  
  // Handle rotation around viewing axis
  void rotate(double angle) {
    _rotationAngle = (_rotationAngle + angle) % (2 * pi);
    notifyListeners();
  }
  
  // Update for rotation (not panning) in 3D mode 
  void updateDragOffset(double deltaX, double deltaY) {
    if (_is3DMode) {
      // In 3D mode, we're rotating our view from the center of the celestial sphere
      // Convert drag to rotation angles (reversed for inside-out view)
      final double rotationFactorY = 5.0; 
      final double rotationFactorX = 5.0;
      
      // For inside looking out, we need to reverse the horizontal drag direction
      _rotationAngles.y -= deltaX * rotationFactorY * pi / 180.0;
      _rotationAngles.x += deltaY * rotationFactorX * pi / 180.0;
      
      // Normalize rotation angles for Y (allows continuous 360° rotation)
      _rotationAngles.y = _rotationAngles.y % (2 * pi);
      
      // Clamp X rotation to avoid flipping over the poles too far
      _rotationAngles.x = _rotationAngles.x.clamp(-pi/2 + 0.1, pi/2 - 0.1);
      
      // We don't need to update view center - the rotationAngles directly control the view
      notifyListeners();
    } else {
      // 2D mode - use traditional RA/Dec panning
      final double raFactor = 2.0;
      final double decFactor = 1.5;
      
      // Update drag offsets
      _dragX += deltaX * raFactor;
      _dragY -= deltaY * decFactor; // Inverted because screen Y is flipped
      
      // Normalize RA and clamp Dec
      _dragX = _dragX % 360.0;
      _dragY = _dragY.clamp(-90.0 - _centerDeclination, 90.0 - _centerDeclination);
      
      notifyListeners();
    }
  }
  
  // Convert rotation angles to new view center
  void _updateViewCenterFromRotation() {
    // Calculate the new center RA and Dec based on rotations around X, Y, Z axes
    // Start with a point at (0, 0, 1) - the center of view
    double x = 0.0;
    double y = 0.0;
    double z = 1.0;
    
    // Apply Y-axis rotation (horizontal movement)
    final double cosY = cos(_rotationAngles.y);
    final double sinY = sin(_rotationAngles.y);
    final double newX = x * cosY + z * sinY;
    final double newZ = -x * sinY + z * cosY;
    x = newX;
    z = newZ;
    
    // Apply X-axis rotation (vertical movement)
    final double cosX = cos(_rotationAngles.x);
    final double sinX = sin(_rotationAngles.x);
    final double newY = y * cosX - z * sinX;
    z = y * sinX + z * cosX;
    y = newY;
    
    // Convert back to spherical coordinates (RA, Dec)
    // Dec = asin(y)
    // RA = atan2(x, z)
    _centerDeclination = asin(y) * 180.0 / pi;
    _centerRightAscension = atan2(x, z) * 180.0 / pi;
    
    // Normalize RA to 0-360
    if (_centerRightAscension < 0) {
      _centerRightAscension += 360.0;
    }
  }
  
  // Reset 3D rotation angles
  void resetRotation() {
    _rotationAngles.x = 0.0;
    _rotationAngles.y = 0.0;
    _rotationAngles.z = 0.0;
    notifyListeners();
  }
  
  // End drag operations
  void endDrag() {
    if (_is3DMode) {
      // In 3D mode, rotation has already been applied directly
      // Nothing needs to be done here since we're using rotation angles directly
    } else {
      // In 2D mode, apply the drag to the center
      _centerRightAscension = (_centerRightAscension + _dragX) % 360.0;
      _centerDeclination = (_centerDeclination + _dragY).clamp(-90.0, 90.0);
      _dragX = 0.0;
      _dragY = 0.0;
    }
    notifyListeners();
  }
  
  // Toggle between 2D and 3D modes
  void toggleProjectionMode() {
    _is3DMode = !_is3DMode;
    if (_is3DMode) {
      // Reset rotations when switching to 3D mode
      resetRotation();
    } else {
      // Reset drag when switching to 2D mode
      _dragX = 0.0;
      _dragY = 0.0;
    }
    notifyListeners();
  }
  
  // Set specific projection mode
  void setProjectionMode(bool is3D) {
    if (_is3DMode != is3D) {
      _is3DMode = is3D;
      if (_is3DMode) {
        // Reset rotations when switching to 3D mode
        resetRotation();
      } else {
        // Reset drag when switching to 2D mode
        _dragX = 0.0;
        _dragY = 0.0;
      }
      notifyListeners();
    }
  }
  
  // Toggle auto-rotation
  void toggleAutoRotate() {
    _autoRotate = !_autoRotate;
    notifyListeners();
  }
  
  // Update for auto-rotation (call from animation)
  void updateAutoRotation() {
    if (_autoRotate) {
      if (_is3DMode) {
        // In 3D mode, for inside-out view we need to rotate in the opposite direction
        _rotationAngles.y -= _autoRotateSpeed;
        // Keep the angle in the range [0, 2π)
        _rotationAngles.y = _rotationAngles.y % (2 * pi);
        if (_rotationAngles.y < 0) _rotationAngles.y += 2 * pi;
      } else {
        // In 2D mode, rotate around the view center
        rotate(_autoRotateSpeed);
      }
    }
  }
  
  // Set the initial view based on current time
  void setViewToCurrentSky() {
    final DateTime now = DateTime.now().toUtc();
    final double ra = CelestialProjection.calculateViewingRA(now);
    setViewCenter(ra, 40.0); // Assuming mid-northern latitude
  }
  
  // Reset to default view
  void resetView() {
    _fieldOfView = 60.0;
    _rotationAngle = 0.0;
    _perspectiveDepth = 0.3;
    _zoomFactor = 1.0;
    _dragX = 0.0;
    _dragY = 0.0;
    resetRotation();
    notifyListeners();
  }}