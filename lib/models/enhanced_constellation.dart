// lib/models/enhanced_constellation.dart

class EnhancedConstellation {
  final String name;
  final String description;
  final List<CelestialStar> stars;
  final List<List<String>> lines;
  final String? abbreviation; // IAU abbreviation
  final String? season; // Best viewing season
  final double? rightAscension; // Center RA in degrees (0-360)
  final double? declination; // Center Dec in degrees (-90 to +90)

  EnhancedConstellation({
    required this.name,
    required this.description,
    required this.stars,
    required this.lines,
    this.abbreviation,
    this.season,
    this.rightAscension,
    this.declination,
  });

  factory EnhancedConstellation.fromMap(Map<String, dynamic> map) {
    return EnhancedConstellation(
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      stars: (map['stars'] as List<dynamic>)
          .map((starMap) => CelestialStar.fromMap(starMap as Map<String, dynamic>))
          .toList(),
      lines: (map['lines'] as List<dynamic>)
          .map((line) => (line as List<dynamic>)
              .map((id) => id as String)
              .toList())
          .toList(),
      abbreviation: map['abbreviation'] as String?,
      season: map['season'] as String?,
      rightAscension: map['rightAscension'] as double?,
      declination: map['declination'] as double?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'stars': stars.map((star) => star.toMap()).toList(),
      'lines': lines,
      if (abbreviation != null) 'abbreviation': abbreviation,
      if (season != null) 'season': season,
      if (rightAscension != null) 'rightAscension': rightAscension,
      if (declination != null) 'declination': declination,
    };
  }
}

class CelestialStar {
  final String id;
  final String name;
  final double magnitude;
  
  // Celestial coordinates
  final double rightAscension; // In degrees (0-360)
  final double declination; // In degrees (-90 to +90)
  
  // Original app x/y coordinates for backward compatibility
  final double x;
  final double y;
  
  // Optional properties
  final String? spectralType;
  final double? distance; // In light years
  final String? constellation; // Constellation this star belongs to
  
  CelestialStar({
    required this.id,
    required this.name,
    required this.magnitude,
    required this.rightAscension,
    required this.declination,
    required this.x,
    required this.y,
    this.spectralType,
    this.distance,
    this.constellation,
  });

  factory CelestialStar.fromMap(Map<String, dynamic> map) {
    return CelestialStar(
      id: map['id'] as String,
      name: map['name'] as String,
      magnitude: map['magnitude'] as double,
      rightAscension: map['rightAscension'] as double? ?? 0.0,
      declination: map['declination'] as double? ?? 0.0,
      x: map['x'] as double,
      y: map['y'] as double,
      spectralType: map['spectralType'] as String?,
      distance: map['distance'] as double?,
      constellation: map['constellation'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'magnitude': magnitude,
      'rightAscension': rightAscension,
      'declination': declination,
      'x': x,
      'y': y,
      if (spectralType != null) 'spectralType': spectralType,
      if (distance != null) 'distance': distance,
      if (constellation != null) 'constellation': constellation,
    };
  }
}