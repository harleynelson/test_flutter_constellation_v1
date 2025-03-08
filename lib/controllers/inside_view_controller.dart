import 'package:flutter/material.dart';
import '../utils/celestial_projections_inside.dart';

/// Controller for managing the view from inside the celestial sphere
class InsideViewController extends ChangeNotifier {
  // View direction in degrees
  double _heading = 0.0;  // Horizontal angle (0=N, 90=E, 180=S, 270=W)
  double _pitch = 0.0;    // Vertical angle (-90=down, 0=horizon, 90=up)
  
  // Field of view in degrees
  double _fieldOfView = 110.0;
  
  // For smooth drag/rotation
  Offset? _dragStart;
  double _dragSensitivity = 0.2;
  
  // Auto-rotation
  bool _autoRotate = false;
  double _autoRotateSpeed = 0.01; // significantly reduced from default 0.5
  
  // Getters
  double get heading => _heading;
  double get pitch => _pitch;
  double get fieldOfView => _fieldOfView;
  bool get autoRotate => _autoRotate;
  double get autoRotateSpeed => _autoRotateSpeed;
  
  // Create the projection
  CelestialProjectionInside get projection => CelestialProjectionInside(
    heading: _heading,
    pitch: _pitch,
    fieldOfView: _fieldOfView,
  );
  
  // Get the view direction vector
  Vector3D getViewDirection() {
    return projection.viewToDirection();
  }
  
  // Start a drag operation
  void startDrag(Offset position) {
    _dragStart = position;
  }
  
  // Update during drag
  void updateDrag(Offset currentPosition) {
  if (_dragStart == null) return;
  
  // Calculate the change in position
  final double dx = currentPosition.dx - _dragStart!.dx;
  final double dy = currentPosition.dy - _dragStart!.dy;
  
  // Update the view direction
  // Positive dx means dragging right, so we should increase heading (rotate right)
  // Positive dy means dragging down, so we should decrease pitch (look down)
  _heading = (_heading + dx * _dragSensitivity) % 360.0;
  if (_heading < 0) _heading += 360.0;
  
  // Update pitch, with clamping to avoid flipping over
  _pitch = (_pitch + dy * _dragSensitivity).clamp(-80.0, 80.0);
  
  // Update drag start for next frame
  _dragStart = currentPosition;
  
  notifyListeners();
}
  
  // End the drag operation
  void endDrag() {
    _dragStart = null;
  }
  
  // Toggle auto-rotation
  void toggleAutoRotate() {
    _autoRotate = !_autoRotate;
    notifyListeners();
  }
  
  // Set auto-rotation speed
  void setAutoRotateSpeed(double speed) {
    if (_autoRotateSpeed != speed) {
      _autoRotateSpeed = speed;
      notifyListeners();
    }
  }
  
  // Update for auto-rotation
  void updateAutoRotation() {
    if (_autoRotate) {
      // Use the configured rotation speed
      _heading = (_heading + _autoRotateSpeed) % 360.0;
      notifyListeners();
    }
  }
  
  // Set the field of view
  void setFieldOfView(double fov) {
    _fieldOfView = fov.clamp(30.0, 150.0);
    notifyListeners();
  }
  
  // Zoom in or out
  void zoom(double factor) {
    _fieldOfView = (_fieldOfView / factor).clamp(30.0, 150.0);
    notifyListeners();
  }
  
  // Reset to the initial view
  void resetView() {
    _heading = 0.0;
    _pitch = 0.0;
    _fieldOfView = 100.0;
    notifyListeners();
  }
  
  // Set the view to look at a specific celestial coordinate
  void lookAt(double rightAscension, double declination) {
    // To look at RA/Dec coordinates:
    // - heading = RA (adjusted to our coordinate system)
    // - pitch = Dec
    
    // Convert RA to our heading system:
    // RA=0 corresponds to heading=180 (South)
    // RA=90 corresponds to heading=270 (West)
    // RA=180 corresponds to heading=0 (North)
    // RA=270 corresponds to heading=90 (East)
    _heading = (180.0 - rightAscension) % 360.0;
    if (_heading < 0) _heading += 360.0;
    
    // Dec directly maps to pitch
    _pitch = declination;
    
    notifyListeners();
  }
}