// lib/models/constellation_center.dart
class ConstellationCenter {
  final double rightAscension; // RA in hours (0-24)
  final double declination;    // Dec in degrees (-90 to +90)
  final double area;           // Area in square degrees
  final int rank;              // Rank by area
  final String abbreviation;   // Constellation abbreviation

  ConstellationCenter({
    required this.rightAscension,
    required this.declination,
    required this.area,
    required this.rank,
    required this.abbreviation,
  });

  // Convert RA from hours (0-24) to degrees (0-360)
  double get rightAscensionDegrees => rightAscension * 15.0;

  @override
  String toString() => 
    'Constellation $abbreviation: RA=${rightAscension.toStringAsFixed(2)}h, ' 
    'Dec=${declination.toStringAsFixed(2)}°, Area=${area.toStringAsFixed(2)}°²';
}