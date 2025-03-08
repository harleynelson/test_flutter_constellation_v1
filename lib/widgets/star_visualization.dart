// lib/widgets/star_visualization.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/enhanced_constellation.dart';
import '../utils/star_renderer.dart';
import '../utils/twinkle_manager.dart';

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
  Offset? _tapPosition;
  double _twinklePhase = 0.0;
  
  // Stream subscription for twinkling
  late final StreamSubscription<double> _twinkleSub;
  
  @override
  void initState() {
    super.initState();
    
    // Use the shared TwinkleManager instead of creating a new controller
    final twinkleManager = TwinkleManager();
    // Ensure the manager is running
    twinkleManager.start(
      updateInterval: const Duration(milliseconds: 50),
      increment: 0.005, // Slower, more subtle twinkling
    );
    
    // Listen for phase updates
    _twinkleSub = twinkleManager.phaseStream.listen((phase) {
      setState(() {
        _twinklePhase = phase;
      });
    });
  }
  
  @override
  void dispose() {
    _twinkleSub.cancel();
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
      child: CustomPaint(
        painter: StarFieldPainter(
          stars: widget.stars,
          lines: widget.lines,
          twinklePhase: _twinklePhase,
          showStarNames: widget.showStarNames,
          showMagnitudes: widget.showMagnitudes,
          showSpectralTypes: widget.showSpectralTypes,
          tapPosition: _tapPosition,
          onStarTapped: widget.onStarTapped,
        ),
        size: Size.infinite,
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
    
    // Draw constellation lines if provided using the utility function
    if (lines != null) {
      StarRenderer.drawConstellationLines(
        canvas, 
        lines!, 
        starPositions,
        color: Colors.blue,
        opacity: 0.5,
        strokeWidth: 1.0
      );
    }
    
    // Draw stars using the utility functions
    for (var star in stars) {
      if (!starPositions.containsKey(star.id)) continue;
      
      final Offset position = starPositions[star.id]!;
      
      // Draw the star using the renderer
      StarRenderer.drawStar(
        canvas,
        star.id, // Use the star ID as identifier
        position,
        star.magnitude,
        twinklePhase,
        size,
        spectralType: star.spectralType,
        glowRatio: 1.8,
        sizeMultiplier: 1.2, // Slightly larger for better visibility
        twinkleIntensity: 0.15 // More subtle twinkling
      );
      
      // Draw star labels
      if (showStarNames) {
        _drawStarInfo(canvas, star, position);
      }
      
      // Check if this star was tapped
      if (tapPosition != null) {
        final double distance = (position - tapPosition!).distance;
        final double starSize = StarRenderer.calculateStarSize(star.magnitude, size);
        
        // If tapped within the star's radius, notify the callback
        if (distance <= starSize * 2 && onStarTapped != null) {
          // Use future to avoid calling during paint
          Future.microtask(() => onStarTapped!(star));
        }
      }
    }
  }
  
  /// Draw additional star information (name, magnitude, spectral type)
  void _drawStarInfo(Canvas canvas, CelestialStar star, Offset position) {
    // Calculate star size for positioning
    final double starRadius = StarRenderer.calculateStarSize(star.magnitude, Size(10, 10)) * 1.2;
    
    // Draw star name
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
      position.dx + starRadius + 4,
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
        position.dx + starRadius + 4,
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
        position.dx + starRadius + 4,
        position.dy + infoOffset - specPainter.height / 2,
      ));
    }
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