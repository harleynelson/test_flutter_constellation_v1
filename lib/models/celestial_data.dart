// lib/models/celestial_data.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';

/// Represents a comprehensive model of celestial objects
class CelestialData {
  final Map<String, Constellation> constellations;
  final Map<int, Star> stars;
  
  CelestialData({
    required this.constellations,
    required this.stars,
  });
  
  /// Load data from the consolidated JSON file
  static Future<CelestialData> load() async {
    try {
      final String jsonData = await rootBundle.loadString('assets/combined_constellation_data.json');
      final Map<String, dynamic> data = json.decode(jsonData);
      
      // Parse stars first
      final Map<String, dynamic> starsData = data['stars'] as Map<String, dynamic>;
      final Map<int, Star> stars = {};
      
      starsData.forEach((key, value) {
        final int id = int.parse(key);
        stars[id] = Star.fromJson(id, value as Map<String, dynamic>);
      });
      
      // Parse constellations
      final Map<String, dynamic> constellationsData = data['constellations'] as Map<String, dynamic>;
      final Map<String, Constellation> constellations = {};
      
      constellationsData.forEach((key, value) {
        constellations[key] = Constellation.fromJson(
          key, 
          value as Map<String, dynamic>,
          stars,
        );
      });
      
      return CelestialData(
        constellations: constellations,
        stars: stars,
      );
    } catch (e) {
      print('Error loading celestial data: $e');
      return CelestialData(constellations: {}, stars: {});
    }
  }
  
  /// Get a list of all constellation names
  List<String> get constellationNames => constellations.keys.toList();
  
  /// Get a list of all bright stars (magnitude < 3)
  List<Star> get brightStars => 
      stars.values.where((star) => star.magnitude < 3.0).toList();
  
  /// Find a star by its HIP number
  Star? findStarById(int id) => stars[id];
  
  /// Find a constellation by its abbreviation
  Constellation? findConstellationByAbbr(String abbr) => 
      constellations[abbr];
}

/// Represents a single star
class Star {
  final int id; // HIP number
  final double ra; // Right ascension in degrees
  final double dec; // Declination in degrees
  final double magnitude; // Apparent magnitude
  final String? spectralType; // Spectral classification
  final double bv; // B-V color index
  final String? name; // Common name if any
  
  Star({
    required this.id,
    required this.ra,
    required this.dec,
    required this.magnitude,
    this.spectralType,
    required this.bv,
    this.name,
  });
  
  /// Create a star from JSON data
  factory Star.fromJson(int id, Map<String, dynamic> json) {
    return Star(
      id: id,
      ra: json['ra'] as double,
      dec: json['dec'] as double,
      magnitude: json['magnitude'] as double,
      spectralType: json['spectral_type'] as String?,
      bv: json['b_v'] as double,
      name: json['name'] as String?,
    );
  }
  
  /// Convert to a 3D cartesian unit vector (pointing outward from center)
  List<double> toVector3D() {
    final double raRad = ra * (3.14159265359 / 180.0);
    final double decRad = dec * (3.14159265359 / 180.0);
    
    // For inside-out view, positive x-axis points to RA=0,
    // positive y-axis points to RA=90, positive z-axis points to Dec=90
    final double x = cos(decRad) * cos(raRad);
    final double y = cos(decRad) * sin(raRad);
    final double z = sin(decRad);
    
    return [x, y, z];
  }
  
  @override
  String toString() => name ?? 'HIP $id';
}

/// Represents a constellation
class Constellation {
  final String abbreviation;
  final String name;
  final String description;
  final List<List<int>> lines; // Star connections using HIP IDs
  final List<int> starIds; // All stars in constellation by HIP IDs
  final int brightestStarId; // HIP ID of brightest star
  
  Constellation({
    required this.abbreviation,
    required this.name,
    required this.description,
    required this.lines,
    required this.starIds,
    required this.brightestStarId,
  });
  
  /// Create a constellation from JSON data
  factory Constellation.fromJson(
    String abbr, 
    Map<String, dynamic> json,
    Map<int, Star> allStars,
  ) {
    // Convert line connections where each line is a list of star HIP IDs
    final List<List<int>> parsedLines = [];
    for (final line in json['lines'] as List<dynamic>) {
      parsedLines.add((line as List<dynamic>).cast<int>());
    }
    
    return Constellation(
      abbreviation: abbr,
      name: json['name'] as String,
      description: json['description'] as String,
      lines: parsedLines,
      starIds: (json['star_count'] as int > 0) 
          ? List<int>.from(parsedLines.expand((line) => line).toSet())
          : [],
      brightestStarId: json['brightest_star'] as int,
    );
  }
  
  /// Get the stars that make up this constellation
  List<Star> getStars(Map<int, Star> allStars) {
    return starIds
        .map((id) => allStars[id])
        .whereType<Star>()
        .toList();
  }
  
  /// Get the brightest star in this constellation
  Star? getBrightestStar(Map<int, Star> allStars) {
    return allStars[brightestStarId];
  }
  
  /// Estimate the center position of this constellation (average of all stars)
  List<double> estimateCenterPosition(Map<int, Star> allStars) {
    if (starIds.isEmpty) {
      return [0, 0, 0];
    }
    
    final List<Star> stars = getStars(allStars);
    if (stars.isEmpty) {
      return [0, 0, 0];
    }
    
    double totalRa = 0;
    double totalDec = 0;
    
    for (final star in stars) {
      totalRa += star.ra;
      totalDec += star.dec;
    }
    
    return [totalRa / stars.length, totalDec / stars.length];
  }
}