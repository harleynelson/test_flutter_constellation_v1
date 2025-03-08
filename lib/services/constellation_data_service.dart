// lib/services/constellation_data_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/enhanced_constellation.dart';

/// Service class for loading and managing constellation data
class ConstellationDataService {
  static const String _dataPath = 'assets/enhanced_constellations.json';
  
  // In-memory cache
  static List<EnhancedConstellation>? _constellationsCache;
  
  /// Load constellations from the enhanced data file
  static Future<List<EnhancedConstellation>> loadConstellations() async {
    // Return cache if available
    if (_constellationsCache != null) {
      return _constellationsCache!;
    }
    
    try {
      // Load enhanced data
      final String jsonString = await rootBundle.loadString(_dataPath);
      final List<dynamic> jsonData = json.decode(jsonString);
      
      _constellationsCache = jsonData
          .map((data) => EnhancedConstellation.fromMap(data))
          .toList();
          
      return _constellationsCache!;
    } catch (e) {
      print('Error loading constellations: $e');
      return [];
    }
  }
  
  /// Get a specific constellation by name
  static Future<EnhancedConstellation?> getConstellationByName(String name) async {
    final constellations = await loadConstellations();
    
    try {
      return constellations.firstWhere((c) => c.name == name);
    } catch (e) {
      return null;
    }
  }
  
  /// Get constellations by season
  static Future<List<EnhancedConstellation>> getConstellationsBySeason(String season) async {
    final constellations = await loadConstellations();
    return constellations.where((c) => c.season == season).toList();
  }
  
  /// Find stars by magnitude range
  static Future<List<CelestialStar>> findStarsByMagnitudeRange(double minMag, double maxMag) async {
    final constellations = await loadConstellations();
    final List<CelestialStar> matchingStars = [];
    
    for (var constellation in constellations) {
      for (var star in constellation.stars) {
        if (star.magnitude >= minMag && star.magnitude <= maxMag) {
          // Create a copy of the star with constellation name
          final starWithConstellation = CelestialStar(
            id: star.id,
            name: star.name,
            magnitude: star.magnitude,
            rightAscension: star.rightAscension,
            declination: star.declination,
            x: star.x,
            y: star.y,
            spectralType: star.spectralType,
            distance: star.distance,
            constellation: constellation.name,
          );
          
          matchingStars.add(starWithConstellation);
        }
      }
    }
    
    return matchingStars;
  }
  
  /// Format Right Ascension (in degrees) to hours:minutes:seconds
  static String formatRA(double ra) {
    // Convert to hours (RA is in 24-hour format, so divide by 15)
    final double hours = ra / 15.0;
    
    final int hourInt = hours.floor();
    final double minutesDouble = (hours - hourInt) * 60;
    final int minutesInt = minutesDouble.floor();
    final double secondsDouble = (minutesDouble - minutesInt) * 60;
    final int secondsInt = secondsDouble.round();
    
    return '${hourInt.toString().padLeft(2, '0')}h ${minutesInt.toString().padLeft(2, '0')}m ${secondsInt.toString().padLeft(2, '0')}s';
  }
  
  /// Format Declination (in degrees) to degrees:minutes:seconds
  static String formatDec(double dec) {
    final String sign = dec >= 0 ? '+' : '-';
    final double absDec = dec.abs();
    
    final int degInt = absDec.floor();
    final double minutesDouble = (absDec - degInt) * 60;
    final int minutesInt = minutesDouble.floor();
    final double secondsDouble = (minutesDouble - minutesInt) * 60;
    final int secondsInt = secondsDouble.round();
    
    return '$sign${degInt.toString().padLeft(2, '0')}° ${minutesInt.toString().padLeft(2, '0')}′ ${secondsInt.toString().padLeft(2, '0')}″';
  }
  
  /// Calculate angular distance between two celestial points
  static double calculateAngularDistance(
    double ra1, double dec1,
    double ra2, double dec2
  ) {
    // Convert to radians
    final double ra1Rad = ra1 * (pi / 180.0);
    final double dec1Rad = dec1 * (pi / 180.0);
    final double ra2Rad = ra2 * (pi / 180.0);
    final double dec2Rad = dec2 * (pi / 180.0);
    
    // Haversine formula
    final double dlon = ra2Rad - ra1Rad;
    final double dlat = dec2Rad - dec1Rad;
    final double a = pow(sin(dlat / 2), 2) + 
                   cos(dec1Rad) * cos(dec2Rad) * pow(sin(dlon / 2), 2);
    final double c = 2 * asin(sqrt(a));
    
    // Convert to degrees
    return c * (180.0 / pi);
  }
}