// lib/widgets/star_visualization.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/enhanced_constellation.dart';
import '../utils/celestial_projections.dart';

/// Widget that visualizes celestial stars with proper astronomical data
class StarVisualization extends StatefulWidget {
  final List<CelestialStar> stars;
  final List<List<String>>? lines;
  final bool showStarNames;
  final bool showMagnitudes;
  final bool showSpectralTypes;
  final Function(CelestialStar)? onStarTapped;
  
  const StarVisualization({
    Key? key,
    required this.stars,
    this.lines,
    this.showStarNames = true,
    this.showMagnitudes = false,
    this.showSpectralTypes = false,
    this.onStarTapped,
  }) : super(key: key);
  
  @override
  State<StarVisualization> createState() => _StarVisualizationState();
}

class _StarVisualizationState extends State<StarVisualization> with SingleTickerProviderStateMixin {
  late AnimationController _twinkleController;
  Offset? _tapPosition;
  
  @override
  void initState() {
    super.initState();
    
    // Create controller for twinkling effect
    _twinkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }
  
  @override
  void dispose() {
    _twinkleController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        setState(() {
          _tapPosition = details.localPosition;
        });
      },
      onTap: () {
        setState(() {
          _tapPosition = null;
        });
      },
      child: AnimatedBuilder(
        animation: _twinkleController,
        builder: (context, _) {
          return CustomPaint(
            painter: StarFieldPainter(
              stars: widget.stars,
              lines: widget.lines,
              twinklePhase: _twinkleController.value * 2 * pi,
              showStarNames: widget.showStarNames,
              showMagnitudes: widget.showMagnitudes,
              showSpectralTypes: widget.showSpectralTypes,
              tapPosition: _tapPosition,
              onStarTapped: widget.onStarTapped,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

/// Custom painter for rendering stars with proper astronomical properties
class StarFieldPainter extends CustomPainter {
  final List<CelestialStar> stars;
  final List<List<String>>? lines;
  final double twinklePhase;
  final bool showStarNames;
  final bool showMagnitudes;
  final bool showSpectralTypes;
  final Offset? tapPosition;
  final Function(CelestialStar)? onStarTapped;
  
  StarFieldPainter({
    required this.stars,
    this.lines,
    required this.twinklePhase,
    this.showStarNames = true,
    this.showMagnitudes = false,
    this.showSpectralTypes = false,
    this.tapPosition,
    this.onStarTapped,
  });
  
  @override
void paint(Canvas canvas, Size size) {
  // First fill background with black
  canvas.drawRect(
    Rect.fromLTWH(0, 0, size.width, size.height),
    Paint()..color = Colors.black,
  );
  
  // Map to store star positions for line drawing
  final Map<String, Offset> starPositions = {};
  
  // Calculate positions for all stars using proper celestial projection
  for (var star in stars) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    
    // Convert RA/Dec to radians
    final double raRadians = star.rightAscension * pi / 180.0;
    final double decRadians = star.declination * pi / 180.0;
    
    // Use stereographic projection for consistent appearance with 3D view
    // This maps celestial coordinates to a 2D plane
    double projX = cos(decRadians) * sin(raRadians);
    double projY = sin(decRadians);
    
    // Scale to fit screen with padding
    final double scale = min(size.width, size.height) * 0.4;
    final double x = centerX + projX * scale;
    final double y = centerY - projY * scale; // Negate Y for correct orientation
    
    starPositions[star.id] = Offset(x, y);
  }
  
  // Draw constellation lines if provided
  // if (lines != null && showLines) {
  //   _drawConstellationLines(canvas, starPositions);
  // }
  if (lines != null) {
    _drawConstellationLines(canvas, starPositions);
  }

  
  // Draw stars
  for (var star in stars) {
    if (!starPositions.containsKey(star.id)) continue;
    
    final Offset position = starPositions[star.id]!;
    _drawStar(canvas, star, position);
    
    // Check if this star was tapped
    if (tapPosition != null) {
      final double distance = (position - tapPosition!).distance;
      final double starRadius = _calculateStarRadius(star.magnitude);
      
      // If tapped within the star's radius, notify the callback
      if (distance <= starRadius * 2 && onStarTapped != null) {
        // Use future to avoid calling during paint
        Future.microtask(() => onStarTapped!(star));
      }
    }
  }
}
  
  /// Draw constellation lines connecting stars
  void _drawConstellationLines(Canvas canvas, Map<String, Offset> starPositions) {
    final Paint linePaint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    for (var line in lines!) {
      if (line.length == 2) {
        final String star1Id = line[0];
        final String star2Id = line[1];
        
        // Only draw line if both stars are in the map
        if (starPositions.containsKey(star1Id) && starPositions.containsKey(star2Id)) {
          canvas.drawLine(
            starPositions[star1Id]!,
            starPositions[star2Id]!,
            linePaint,
          );
        }
      }
    }
  }
  
  /// Draw a single star with appropriate visual properties
  void _drawStar(Canvas canvas, CelestialStar star, Offset position) {
    // Calculate star radius based on magnitude
    final double radius = _calculateStarRadius(star.magnitude);
    
    // Apply twinkling effect
    final double starSeed = position.dx * position.dy; // Use position as a seed
    final double twinkleSpeed = 0.5 + (sin(starSeed) + 1) * 0.5; // Range 0.5-1.5
    final double twinkleFactor = max(0, sin((twinklePhase * twinkleSpeed) % (2 * pi)));
    
    // Get star color based on spectral type
    final Color starColor = _getStarColor(star.spectralType);
    
    // Make color slightly brighter during twinkle
    final Color twinkleColor = _adjustColorBrightness(starColor, twinkleFactor * 0.15);
    
    // Draw star glow
    final Paint glowPaint = Paint()
      ..color = twinkleColor.withOpacity(0.3 + twinkleFactor * 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    
    canvas.drawCircle(position, radius * 1.8, glowPaint);
    
    // Draw star core
    final Paint starPaint = Paint()
      ..color = twinkleColor
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(position, radius, starPaint);
    
    // Draw star name if enabled
    if (showStarNames) {
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: star.name,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12.0,
            shadows: const [
              Shadow(
                blurRadius: 2.0,
                color: Colors.black,
                offset: Offset(1, 1),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(canvas, Offset(
        position.dx + radius + 4,
        position.dy - textPainter.height / 2,
      ));
      
      // Draw additional information if enabled
      double infoOffset = 0;
      
      if (showMagnitudes) {
        final TextPainter magPainter = TextPainter(
          text: TextSpan(
            text: 'Mag: ${star.magnitude.toStringAsFixed(1)}',
            style: TextStyle(
              color: Colors.grey.withOpacity(0.8),
              fontSize: 10.0,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        
        magPainter.layout();
        infoOffset += 12;
        magPainter.paint(canvas, Offset(
          position.dx + radius + 4,
          position.dy + infoOffset - magPainter.height / 2,
        ));
      }
      
      if (showSpectralTypes && star.spectralType != null) {
        final TextPainter specPainter = TextPainter(
          text: TextSpan(
            text: 'Type: ${star.spectralType}',
            style: TextStyle(
              color: Colors.grey.withOpacity(0.8),
              fontSize: 10.0,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        
        specPainter.layout();
        infoOffset += 12;
        specPainter.paint(canvas, Offset(
          position.dx + radius + 4,
          position.dy + infoOffset - specPainter.height / 2,
        ));
      }
    }
  }
  
  /// Calculate appropriate radius for a star based on its magnitude
  double _calculateStarRadius(double magnitude) {
    // Brighter stars (lower magnitude) are larger
    // Typical magnitude range: -1.5 (very bright) to 6 (barely visible)
    
    // Map magnitude to a reasonable pixel range (3-12)
    return max(3.0, 12.0 - magnitude * 1.5);
  }
  
  /// Get appropriate star color based on spectral type
  Color _getStarColor(String? spectralType) {
    if (spectralType == null || spectralType.isEmpty) {
      return Colors.white;
    }
    
    // Extract the main spectral class (first character)
    final String mainClass = spectralType[0].toUpperCase();
    
    // Colors based on spectral classification
    switch (mainClass) {
      case 'O': // Hot blue stars
        return const Color(0xFFCAE8FF);
      case 'B': // Blue-white stars
        return const Color(0xFFE6F0FF);
      case 'A': // White stars
        return Colors.white;
      case 'F': // Yellow-white stars
        return const Color(0xFFFFF8E8);
      case 'G': // Yellow stars (Sun-like)
        return const Color(0xFFFFEFB3);
      case 'K': // Orange stars
        return const Color(0xFFFFD2A1);
      case 'M': // Red stars
        return const Color(0xFFFFBDAD);
      default:
        return Colors.white;
    }
  }
  
  /// Adjust color brightness for twinkling effect
  Color _adjustColorBrightness(Color color, double factor) {
    return Color.fromRGBO(
      min(255, color.red + ((255 - color.red) * factor).round()),
      min(255, color.green + ((255 - color.green) * factor).round()),
      min(255, color.blue + ((255 - color.blue) * factor).round()),
      color.opacity
    );
  }
  
  @override
  bool shouldRepaint(covariant StarFieldPainter oldDelegate) {
    return oldDelegate.twinklePhase != twinklePhase ||
           oldDelegate.showStarNames != showStarNames ||
           oldDelegate.showMagnitudes != showMagnitudes ||
           oldDelegate.showSpectralTypes != showSpectralTypes ||
           oldDelegate.tapPosition != tapPosition ||
           oldDelegate.stars != stars;
  }
}