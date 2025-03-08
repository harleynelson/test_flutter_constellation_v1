// lib/services/constellation_lines_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/constellation_line.dart';

/// Service for loading and managing constellation line data
class ConstellationLinesService {
  static const String _linesDataPath = 'assets/lines_in_20.txt';
  
  // In-memory cache
  static List<ConstellationLine>? _linesCache;
  
  // Group lines by segment key for faster lookup
  static Map<String, List<ConstellationLine>>? _linesBySegmentCache;
  
  /// Load constellation lines from data file
  static Future<List<ConstellationLine>> loadConstellationLines() async {
    // Return cache if available
    if (_linesCache != null) {
      return _linesCache!;
    }
    
    try {
      // Load text file
      final String fileContent = await rootBundle.loadString(_linesDataPath);
      final List<String> lines = LineSplitter.split(fileContent).toList();
      
      // Parse each line
      final List<ConstellationLine> constellationLines = [];
      
      // Skip header lines if present (lines that don't contain coordinates)
      final List<String> dataLines = lines.where((line) => 
        line.trim().isNotEmpty && 
        RegExp(r'^\s*[0-9]').hasMatch(line)
      ).toList();
      
      for (final line in dataLines) {
        try {
          // Split the line by whitespace and then process each part
          final parts = line.trim().split(RegExp(r'\s+'));
          
          if (parts.length >= 3) {
            final double ra = double.parse(parts[0]);
            
            // Handle declination with sign
            final String decPart = parts[1];
            double dec;
            if (decPart.startsWith('+') || decPart.startsWith('-')) {
              dec = double.parse(decPart);
            } else {
              // If the sign is a separate part (which is not the case in your sample data)
              final String decSign = parts[1].startsWith('-') ? '-' : '+';
              final double decValue = double.parse(parts[1].replaceFirst(RegExp(r'[+-]'), ''));
              dec = decSign == '-' ? -decValue : decValue;
            }
            
            // Get the segment key
            final String segmentKey = parts[2];
            
            constellationLines.add(ConstellationLine(
              rightAscension: ra,
              declination: dec,
              segmentKey: segmentKey,
            ));
          }
        } catch (e) {
          print('Error parsing constellation line: $line - $e');
          continue;
        }
      }
      
      _linesCache = constellationLines;
      
      // Create a map of lines grouped by segment key
      _buildLineSegmentMap(constellationLines);
      
      return constellationLines;
    } catch (e) {
      print('Error loading constellation lines: $e');
      return [];
    }
  }
  
  /// Build a map of lines grouped by segment key for faster lookup
  static void _buildLineSegmentMap(List<ConstellationLine> lines) {
    _linesBySegmentCache = {};
    
    for (final line in lines) {
      if (_linesBySegmentCache!.containsKey(line.segmentKey)) {
        _linesBySegmentCache![line.segmentKey]!.add(line);
      } else {
        _linesBySegmentCache![line.segmentKey] = [line];
      }
    }
  }
  
  /// Get all lines for a specific segment key
  static Future<List<ConstellationLine>> getLinesBySegmentKey(String segmentKey) async {
    if (_linesBySegmentCache == null) {
      await loadConstellationLines();
    }
    
    return _linesBySegmentCache![segmentKey] ?? [];
  }
  
  /// Get all unique segment keys
  static Future<List<String>> getAllSegmentKeys() async {
    if (_linesBySegmentCache == null) {
      await loadConstellationLines();
    }
    
    return _linesBySegmentCache!.keys.toList();
  }
  
  /// Group lines by segment and return them as polylines
  /// Each polyline is a list of points (RA, Dec) that form a connected line
  static Future<Map<String, List<List<double>>>> getPolylines() async {
    final lines = await loadConstellationLines();
    final Map<String, List<List<double>>> polylines = {};
    
    // Group lines by segment key
    final Map<String, List<ConstellationLine>> linesBySegment = {};
    
    for (final line in lines) {
      if (linesBySegment.containsKey(line.segmentKey)) {
        linesBySegment[line.segmentKey]!.add(line);
      } else {
        linesBySegment[line.segmentKey] = [line];
      }
    }
    
    // Convert each segment to a polyline
    for (final segmentKey in linesBySegment.keys) {
      final segmentLines = linesBySegment[segmentKey]!;
      
      // Sort lines by RA and Dec to ensure they connect properly
      // This might need adjustment depending on how the lines are ordered in the file
      segmentLines.sort((a, b) {
        if ((a.rightAscension - b.rightAscension).abs() < 0.01) {
          return a.declination.compareTo(b.declination);
        }
        return a.rightAscension.compareTo(b.rightAscension);
      });
      
      // Create polyline points
      final List<List<double>> points = segmentLines.map((line) => 
        [line.rightAscensionDegrees, line.declination]
      ).toList();
      
      polylines[segmentKey] = points;
    }
    
    return polylines;
  }
}