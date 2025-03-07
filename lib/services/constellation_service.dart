// lib/services/constellation_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/enhanced_constellation.dart';

/// Service for loading and managing constellation data
class ConstellationService {
  static const String _enhancedDataPath = 'assets/enhanced_constellations.json';
  static const String _backupDataPath = 'assets/constellations.json';
  
  // In-memory cache
  static List<EnhancedConstellation>? _constellationsCache;
  
  /// Load constellations from the enhanced data file
  static Future<List<EnhancedConstellation>> loadConstellations() async {
    // Return cache if available
    if (_constellationsCache != null) {
      return _constellationsCache!;
    }
    
    try {
      // Try loading enhanced data first
      final String jsonString = await rootBundle.loadString(_enhancedDataPath);
      final List<dynamic> jsonData = json.decode(jsonString);
      
      _constellationsCache = jsonData
          .map((data) => EnhancedConstellation.fromMap(data))
          .toList();
          
      return _constellationsCache!;
    } catch (e) {
      // Fall back to original data if enhanced data cannot be loaded
      print('Error loading enhanced constellations: $e');
      print('Falling back to original constellation data');
      
      try {
        final String backupJsonString = await rootBundle.loadString(_backupDataPath);
        final List<dynamic> backupJsonData = json.decode(backupJsonString);
        
        // Convert old data to enhanced format
        final List<EnhancedConstellation> constellations = [];
        
        for (var data in backupJsonData) {
          // Extract stars with basic conversion of x/y to celestial coordinates
          final List<dynamic> originalStars = data['stars'] as List<dynamic>;
          final List<CelestialStar> enhancedStars = [];
          
          for (var star in originalStars) {
            // Generate approximate RA and Dec from x/y
            // This is just a crude approximation for backward compatibility
            final double x = star['x'] as double;
            final double y = star['y'] as double;
            
            // Map x (0-1) to RA (0-360)
            final double ra = x * 360.0;
            // Map y (0-1) to Dec (-90 to 90)
            final double dec = (y * 180.0) - 90.0;
            
            enhancedStars.add(CelestialStar(
              id: star['id'] as String,
              name: star['name'] as String,
              magnitude: star['magnitude'] as double,
              rightAscension: ra,
              declination: dec,
              x: x,
              y: y,
            ));
          }
          
          constellations.add(
            EnhancedConstellation(
              name: data['name'] as String,
              description: data['description'] as String? ?? '',
              stars: enhancedStars,
              lines: (data['lines'] as List<dynamic>)
                  .map((line) => (line as List<dynamic>)
                      .map((id) => id as String)
                      .toList())
                  .toList(),
            )
          );
        }
        
        _constellationsCache = constellations;
        return constellations;
      } catch (backupError) {
        print('Error loading backup constellation data: $backupError');
        // Return empty list if all loading attempts fail
        return [];
      }
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
  
  /// Converts RA in degrees to hours:minutes:seconds format
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
  
  /// Converts Declination in degrees to degrees:minutes:seconds format
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
}