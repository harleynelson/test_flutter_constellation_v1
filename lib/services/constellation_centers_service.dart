// lib/services/constellation_centers_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/constellation_center.dart';

/// Service for loading and managing constellation center data
class ConstellationCentersService {
  static const String _centersDataPath = 'assets/centers_20.txt';
  
  // In-memory cache
  static List<ConstellationCenter>? _centersCache;
  
  /// Load constellation centers from data file
  static Future<List<ConstellationCenter>> loadConstellationCenters() async {
    // Return cache if available
    if (_centersCache != null) {
      return _centersCache!;
    }
    
    try {
      // Load text file
      final String fileContent = await rootBundle.loadString(_centersDataPath);
      final List<String> lines = LineSplitter.split(fileContent).toList();
      
      // Parse each line
      final List<ConstellationCenter> centers = [];
      
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        
        try {
          // The format is fixed-width but we need to be careful with spaces
          // Split the line by whitespace and then process each part
          final parts = line.trim().split(RegExp(r'\s+'));
          
          if (parts.length >= 5) {
            final double ra = double.parse(parts[0]);
            final String decSign = parts[1].startsWith('-') ? '-' : '+';
            final double decValue = double.parse(parts[1].replaceFirst(RegExp(r'[+-]'), ''));
            final double dec = decSign == '-' ? -decValue : decValue;
            final double area = double.parse(parts[2]);
            final int rank = int.parse(parts[3]);
            final String abbr = parts[4];
            
            centers.add(ConstellationCenter(
              rightAscension: ra,
              declination: dec,
              area: area,
              rank: rank,
              abbreviation: abbr,
            ));
          }
        } catch (e) {
          print('Error parsing line: $line - $e');
          continue;
        }
      }
      
      _centersCache = centers;
      return centers;
    } catch (e) {
      print('Error loading constellation centers: $e');
      return [];
    }
  }
  
  /// Get a specific constellation center by abbreviation
  static Future<ConstellationCenter?> getByAbbreviation(String abbreviation) async {
    final centers = await loadConstellationCenters();
    
    try {
      return centers.firstWhere(
        (center) => center.abbreviation.toLowerCase() == abbreviation.toLowerCase()
      );
    } catch (e) {
      return null;
    }
  }
  
  /// Get all constellation centers within a specific declination range
  static Future<List<ConstellationCenter>> getByDeclinationRange(
    double minDec, 
    double maxDec
  ) async {
    final centers = await loadConstellationCenters();
    
    return centers.where(
      (center) => center.declination >= minDec && center.declination <= maxDec
    ).toList();
  }
}