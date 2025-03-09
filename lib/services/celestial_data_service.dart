// lib/services/celestial_data_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/celestial_data.dart';

/// Service for loading and managing celestial data
class CelestialDataService {
  // Singleton instance
  static final CelestialDataService _instance = CelestialDataService._internal();
  
  // Cached data
  CelestialData? _cachedData;
  
  // Factory constructor to return the singleton instance
  factory CelestialDataService() {
    return _instance;
  }
  
  // Private constructor
  CelestialDataService._internal();
  
  /// Load the celestial data from assets
  Future<CelestialData> loadData() async {
    if (_cachedData != null) {
      return _cachedData!;
    }
    
    try {
      _cachedData = await CelestialData.load();
      return _cachedData!;
    } catch (e) {
      print('Error loading celestial data: $e');
      // Return empty data on error
      return CelestialData(constellations: {}, stars: {});
    }
  }
  
  /// Format a right ascension value (in degrees) as a string
  static String formatRightAscension(double ra) {
    // Convert degrees to hours (0-24)
    final double raHours = ra / 15.0;
    
    final int hours = raHours.floor();
    final double minutesDouble = (raHours - hours) * 60;
    final int minutes = minutesDouble.floor();
    final double secondsDouble = (minutesDouble - minutes) * 60;
    final int seconds = secondsDouble.round();
    
    return '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
  }
  
  /// Format a declination value (in degrees) as a string
  static String formatDeclination(double dec) {
    final String sign = dec >= 0 ? '+' : '';
    
    final int degrees = dec.abs().floor();
    final double minutesDouble = (dec.abs() - degrees) * 60;
    final int minutes = minutesDouble.floor();
    final double secondsDouble = (minutesDouble - minutes) * 60;
    final int seconds = secondsDouble.round();
    
    return '$sign${degrees.toString().padLeft(2, '0')}° ${minutes.toString().padLeft(2, '0')}′ ${seconds.toString().padLeft(2, '0')}″';
  }
  
  /// Get a spectral type description
  static String getSpectralTypeDescription(String? spectralType) {
    if (spectralType == null || spectralType.isEmpty) {
      return 'Unknown';
    }
    
    // Extract just the main spectral class (first letter)
    final String mainClass = spectralType[0].toUpperCase();
    
    switch (mainClass) {
      case 'O':
        return 'Hot blue star (>30,000K)';
      case 'B':
        return 'Blue-white star (10,000-30,000K)';
      case 'A':
        return 'White star (7,500-10,000K)';
      case 'F':
        return 'Yellow-white star (6,000-7,500K)';
      case 'G':
        return 'Yellow star like our Sun (5,200-6,000K)';
      case 'K':
        return 'Orange star (3,700-5,200K)';
      case 'M':
        return 'Red star (<3,700K)';
      default:
        return 'Special type: $spectralType';
    }
  }
  
  /// Calculate the visible magnitude range of all stars
  static Map<String, double> calculateMagnitudeRange(CelestialData data) {
    double minMagnitude = double.infinity;
    double maxMagnitude = double.negativeInfinity;
    
    for (final star in data.stars.values) {
      if (star.magnitude < minMagnitude) {
        minMagnitude = star.magnitude;
      }
      if (star.magnitude > maxMagnitude) {
        maxMagnitude = star.magnitude;
      }
    }
    
    return {
      'min': minMagnitude,
      'max': maxMagnitude,
    };
  }
  
  /// Get stars organized by constellation
  static Map<String, List<Star>> getStarsByConstellation(CelestialData data) {
    final Map<String, List<Star>> result = {};
    
    for (final constellation in data.constellations.values) {
      result[constellation.abbreviation] = constellation.getStars(data.stars);
    }
    
    return result;
  }
  
  /// Find the nearest constellation to a given RA/Dec position
  static String? findNearestConstellation(CelestialData data, double ra, double dec) {
    String? nearestConstellation;
    double nearestDistance = double.infinity;
    
    for (final constellation in data.constellations.values) {
      final position = constellation.estimateCenterPosition(data.stars);
      
      // Simple Euclidean distance for now
      // In a real app, use proper angular distance on celestial sphere
      final double distance = _calculateDistance(ra, dec, position[0], position[1]);
      
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestConstellation = constellation.abbreviation;
      }
    }
    
    return nearestDistance < 30 ? nearestConstellation : null; // Threshold of 30 degrees
  }
  
  // Helper function to calculate approximate angular distance
  static double _calculateDistance(double ra1, double dec1, double ra2, double dec2) {
    // Simple Euclidean distance for demonstration
    // In a real app, use proper spherical trigonometry
    final double dRa = (ra1 - ra2) * cos((dec1 + dec2) * 0.5 * (3.14159265359 / 180.0));
    final double dDec = dec1 - dec2;
    return sqrt(dRa * dRa + dDec * dDec);
  }
}