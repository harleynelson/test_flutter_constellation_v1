// lib/models/constellation_line.dart
class ConstellationLine {
  final double rightAscension;  // RA in hours (0-24)
  final double declination;     // Dec in degrees (-90 to +90)
  final String segmentKey;      // Key identifying the line segment (e.g., "559:560")
  
  // Extracted star IDs from the segment key
  final String fromStarId;
  final String toStarId;

  ConstellationLine({
    required this.rightAscension,
    required this.declination,
    required this.segmentKey,
  }) : 
    fromStarId = segmentKey.split(':')[0],
    toStarId = segmentKey.split(':').length > 1 ? segmentKey.split(':')[1] : segmentKey.split(':')[0];

  // Convert RA from hours (0-24) to degrees (0-360)
  double get rightAscensionDegrees => rightAscension * 15.0;

  @override
  String toString() => 
    'Line $segmentKey: RA=${rightAscension.toStringAsFixed(2)}h, ' 
    'Dec=${declination.toStringAsFixed(2)}°, From=$fromStarId, To=$toStarId';
}