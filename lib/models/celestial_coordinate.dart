import 'dart:math';
import 'package:vector_math/vector_math.dart';

/// Represents a point in celestial coordinates (RA and Dec)
class CelestialCoordinate {
  /// Right Ascension in hours (0-24)
  final double rightAscension;
  
  /// Declination in degrees (-90 to +90)
  final double declination;
  
  const CelestialCoordinate({
    required this.rightAscension,
    required this.declination,
  });
  
  /// Convert normalized x,y coordinates (0-1) to approximate celestial coordinates
  /// This is for converting the existing constellation data to the new format
  factory CelestialCoordinate.fromNormalizedXY(double x, double y) {
    // Map x (0-1) to RA (0-24 hours)
    final double ra = x * 24;
    
    // Map y (0-1) to Dec (-90 to +90 degrees)
    // Subtract from 0.5 so that higher y values are lower in declination
    final double dec = (0.5 - y) * 180;
    
    return CelestialCoordinate(rightAscension: ra, declination: dec);
  }
  
  /// Convert to cartesian coordinates on a unit sphere
  Vector3 toCartesian() {
    // Convert RA from hours (0-24) to radians (0-2π)
    final double raRadians = rightAscension * pi / 12;
    
    // Convert Dec from degrees to radians
    final double decRadians = declination * pi / 180;
    
    // Spherical to Cartesian conversion
    // In astronomical convention:
    // x = cos(dec) * cos(ra)
    // y = cos(dec) * sin(ra)
    // z = sin(dec)
    return Vector3(
      cos(decRadians) * cos(raRadians),
      cos(decRadians) * sin(raRadians),
      sin(decRadians),
    );
  }
  
  @override
  String toString() => 'RA: ${rightAscension.toStringAsFixed(2)}h, Dec: ${declination.toStringAsFixed(2)}°';
}