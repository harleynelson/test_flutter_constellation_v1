// lib/controllers/sky_view_controller.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/celestial_data.dart';

/// Controller for the sky view that handles camera position and user interaction
class SkyViewController extends ChangeNotifier {
  // Camera position (inside-out view)
  double _heading = 0.0;  // Horizontal angle (0=N, 90=E, 180=S, 270=W)
  double _pitch = 15.0;   // Vertical angle (-90=down, 0=horizon, 90=up)
  
  // Field of view
  double _fieldOfView = 90.0;
  double _zoomLevel = 1.0;
  
  // Auto-rotation
  bool _autoRotate = false;
  double _autoRotateSpeed = 0.2;
  late Ticker _ticker;
  final TickerProvider _tickerProvider;
  
  // Twinkle animation
  double _twinklePhase = 0.0;
  
  // Interaction variables
  Offset? _dragStart;
  double _dragSensitivity = 0.2;
  
  // Getters
  double get heading => _heading;
  double get pitch => _pitch;
  double get fieldOfView => _fieldOfView / _zoomLevel;
  double get twinklePhase => _twinklePhase;
  
  SkyViewController({required TickerProvider tickerProvider}) 
      : _tickerProvider = tickerProvider {
    _initTicker();
  }
  
  void _initTicker() {
    _ticker = _tickerProvider.createTicker((elapsed) {
      // Update twinkle phase
      _twinklePhase = elapsed.inMilliseconds / 5000.0 * pi;
      
      // Handle auto rotation if enabled
      if (_autoRotate) {
        _heading = (_heading + _autoRotateSpeed) % 360.0;
      }
      
      notifyListeners();
    });
    
    _ticker.start();
  }
  
  /// Sets the view direction
  void setViewDirection(double heading, double pitch) {
    _heading = heading % 360.0;
    // Clamp pitch to prevent flipping
    _pitch = pitch.clamp(-85.0, 85.0);
    notifyListeners();
  }
  
  /// Zooms in or out
  void zoom(double factor) {
    // Apply a damping factor to make zoom less sensitive
    final double dampened = 1.0 + (factor - 1.0) * 0.3;
    _zoomLevel = (_zoomLevel * dampened).clamp(0.5, 3.0);
    notifyListeners();
  }
  
  /// Enables or disables auto rotation
  void setAutoRotate(bool enabled) {
    _autoRotate = enabled;
    notifyListeners();
  }
  
  /// Set auto-rotation speed
  void setAutoRotateSpeed(double speed) {
    _autoRotateSpeed = speed;
    notifyListeners();
  }
  
  /// Set viewing position based on current date
  void setToCurrentDatePosition() {
    final now = DateTime.now();
    
    // Approximate sidereal time calculation
    // LST = 100.46 + 0.985647 * day + 15 * hour (simplified)
    final hour = now.hour + now.minute/60;
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    
    // Calculate approximate local sidereal time
    final lst = (100.46 + 0.985647 * dayOfYear + hour * 15.0) % 360.0;
    
    // Set heading: What's on the meridian is at RA = LST
    _heading = lst;
    
    // Set a default pitch looking slightly up
    _pitch = 15.0;
    
    notifyListeners();
  }
  
  /// Start a drag operation
  void handleScaleStart(ScaleStartDetails details) {
    _dragStart = details.focalPoint;
  }
  
  /// Handle updates during a scaling gesture
  void handleScaleUpdate(ScaleUpdateDetails details) {
    if (_dragStart == null) {
      _dragStart = details.focalPoint;
      return;
    }
    
    // Handle zoom with scale
    if (details.scale != 1.0) {
      zoom(details.scale);
    }
    
    // Calculate drag delta
    final dx = details.focalPoint.dx - _dragStart!.dx;
    final dy = details.focalPoint.dy - _dragStart!.dy;
    
    // Update drag start point for next frame
    _dragStart = details.focalPoint;
    
    // Update the view direction
    // Positive dx means dragging right, which should decrease heading (rotate left)
    // Positive dy means dragging down, which should decrease pitch (look down)
    _heading = (_heading - dx * _dragSensitivity) % 360.0;
    _pitch = (_pitch - dy * _dragSensitivity).clamp(-85.0, 85.0);
    
    notifyListeners();
  }
  
  /// End a drag operation
  void handleScaleEnd(ScaleEndDetails details) {
    _dragStart = null;
  }
  
  /// Start a drag operation
  void startDrag(Offset position) {
    _dragStart = position;
  }
  
  /// Update during drag
  void updateDrag(Offset currentPosition) {
    if (_dragStart == null) return;
    
    // Calculate the change in position
    final double dx = currentPosition.dx - _dragStart!.dx;
    final double dy = currentPosition.dy - _dragStart!.dy;
    
    // Update the view direction
    _heading = (_heading - dx * _dragSensitivity) % 360.0;
    if (_heading < 0) _heading += 360.0;
    
    // Update pitch with clamping to avoid flipping over
    _pitch = (_pitch - dy * _dragSensitivity).clamp(-85.0, 85.0);
    
    // Update drag start for next frame
    _dragStart = currentPosition;
    
    notifyListeners();
  }
  
  /// End the drag operation
  void endDrag() {
    _dragStart = null;
  }
  
  /// Handle manual drag updates (without scale)
  void handleDrag(Offset delta) {
    _heading = (_heading - delta.dx * _dragSensitivity) % 360.0;
    _pitch = (_pitch - delta.dy * _dragSensitivity).clamp(-85.0, 85.0);
    notifyListeners();
  }
  
  /// Reset view to default position
  void resetView() {
    _heading = 0.0;
    _pitch = 15.0;
    _zoomLevel = 1.0;
    notifyListeners();
  }
  
  /// Look at a specific constellation
  void lookAtConstellation(String abbreviation, CelestialData data) {
    final constellation = data.findConstellationByAbbr(abbreviation);
    if (constellation == null) return;
    
    // Calculate average position
    final centerPos = constellation.estimateCenterPosition(data.stars);
    
    // Convert RA/Dec to heading/pitch
    // For heading, RA corresponds directly (RA 0° = heading 0°)
    _heading = centerPos[0];
    // For pitch, Dec corresponds directly (Dec 0° = pitch 0°)
    _pitch = centerPos[1];
    
    notifyListeners();
  }
  
  /// Get the constellation at a screen position
  String? getConstellationAt(Offset position, CelestialData data) {
    // This would require raycast testing against constellation boundaries
    // For simplicity, this is a placeholder that doesn't do hit testing yet
    return null;
  }
  
  /// Convert azimuth to RA
  double get rightAscension => _heading;
  
  /// Convert altitude to Dec
  double get declination => _pitch;
  
  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}