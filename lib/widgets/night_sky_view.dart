import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../painters/sky_painter.dart';
import 'animated_sky_view.dart';

class NightSkyView extends StatefulWidget {
  final List<Map<String, dynamic>> constellations;
  final Function(String) onConstellationSelected;
  
  const NightSkyView({
    Key? key,
    required this.constellations,
    required this.onConstellationSelected,
  }) : super(key: key);

  @override
  State<NightSkyView> createState() => _NightSkyViewState();
}

class _NightSkyViewState extends State<NightSkyView> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  String? _hoveredConstellation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            // Background with stars (drawn once)
            _buildStaticBackground(constraints.biggest),
            
            // Constellations layer that updates on hover
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: ConstellationsPainter(
                    constellations: widget.constellations,
                    animationValue: _animationController.value,
                    hoveredConstellation: _hoveredConstellation,
                    size: constraints.biggest,
                  ),
                  size: Size.infinite,
                );
              }
            ),
            
            // Interactive layer for constellation selection
            Stack(
              children: widget.constellations.map((constellation) {
                // Get constellation position consistently
                final String name = constellation['name'] as String;
                final Random random = Random(name.hashCode); // Deterministic positioning
                
                final double x = 0.2 + random.nextDouble() * 0.6;
                final double y = 0.2 + random.nextDouble() * 0.6;
                
                final double posX = constraints.maxWidth * x;
                final double posY = constraints.maxHeight * y;
                
                return Positioned(
                  left: posX - 40,
                  top: posY - 40,
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hoveredConstellation = name),
                    onExit: (_) => setState(() => _hoveredConstellation = null),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        widget.onConstellationSelected(name);
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Larger tap area
                          Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.transparent,
                            ),
                          ),
                          
                          // Subtle highlight indicator that appears on hover
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 200),
                            opacity: _hoveredConstellation == name ? 0.2 : 0.0,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue.withOpacity(0.3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.2),
                                    blurRadius: 10,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          // Constellation name
                          Positioned(
                            bottom: -5,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _hoveredConstellation == name ? 1.0 : 0.7,
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: _hoveredConstellation == name 
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.7),
                                  fontSize: _hoveredConstellation == name ? 14.0 : 12.0,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 5.0,
                                      color: Colors.blue.withOpacity(0.7),
                                      offset: const Offset(0, 0),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      }
    );
  }
  
  // Build static background that doesn't need to redraw on hover
  Widget _buildStaticBackground(Size size) {
    return CustomPaint(
      painter: StarBackgroundPainter(
        animationValue: _animationController.value,
        size: size,
      ),
      size: Size.infinite,
    );
  }
}

// Separate painter just for the background
class StarBackgroundPainter extends CustomPainter {
  final double animationValue;
  final Size size;
  final Random _random = Random(42);
  
  StarBackgroundPainter({
    required this.animationValue,
    required this.size,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Draw black background
    final Rect rect = Offset.zero & size;
    final Paint gradientPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          Color(0xFF111B2A), // Dark blue
          Color(0xFF000510), // Very dark blue
          Colors.black,
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect);
    
    canvas.drawRect(rect, gradientPaint);
    
    // Draw background stars
    final int starCount = (size.width * size.height / 3000).round().clamp(100, 500);
    
    for (int i = 0; i < starCount; i++) {
      final double x = _random.nextDouble() * size.width;
      final double y = _random.nextDouble() * size.height;
      final double radius = _random.nextDouble() * 1.0 + 0.3;
      final double opacity = _random.nextDouble() * 0.7 + 0.3;
      
      // Fade in stars with animation
      final double currentOpacity = opacity * min(1.0, animationValue * 2);
      
      final Paint starPaint = Paint()
        ..color = Colors.white.withOpacity(currentOpacity);
      
      canvas.drawCircle(Offset(x, y), radius, starPaint);
      
      // Add a subtle glow to some stars
      if (_random.nextDouble() > 0.7) {
        final Paint glowPaint = Paint()
          ..color = Colors.white.withOpacity(currentOpacity * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
        
        canvas.drawCircle(Offset(x, y), radius * 2, glowPaint);
      }
    }
  }
  
  @override
  bool shouldRepaint(StarBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

// Separate painter just for the constellations
class ConstellationsPainter extends CustomPainter {
  final List<Map<String, dynamic>> constellations;
  final double animationValue;
  final String? hoveredConstellation;
  final Size size;
  
  ConstellationsPainter({
    required this.constellations,
    required this.animationValue,
    required this.size,
    this.hoveredConstellation,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // For debugging - add border to see the painting area
    final Paint borderPaint = Paint()
      ..color = Colors.red.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
      
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);
    
    // Animate the constellations appearance
    final double constellationOpacity = min(1.0, animationValue * 1.5);
    _drawConstellations(canvas, size, constellationOpacity);
  }
  
  void _drawConstellations(Canvas canvas, Size size, double opacity) {
    // Build a map of constellation positions for consistency
    final Map<String, Offset> constellationPositions = {};
    
    for (var constellation in constellations) {
      final String name = constellation['name'] as String;
      final Random posRandom = Random(name.hashCode); // Deterministic positioning
      
      final double x = 0.15 + posRandom.nextDouble() * 0.7;
      final double y = 0.15 + posRandom.nextDouble() * 0.7;
      
      
      constellationPositions[name] = Offset(
        size.width * x,
        size.height * y
      );
    }
    
    for (var constellation in constellations) {
      final String name = constellation['name'] as String;
      final List<dynamic> stars = constellation['stars'] as List<dynamic>;
      final List<dynamic>? lines = constellation['lines'] as List<dynamic>?;
      
      // Get the pre-calculated position
      final Offset centerPosition = constellationPositions[name]!;
      final double centerX = centerPosition.dx;
      final double centerY = centerPosition.dy;
      
      // Scale factor to make constellations visible in the overview
      final double scale = 500; // Fixed scale instead of relative
      
      // Highlight the hovered constellation
      final bool isHighlighted = name == hoveredConstellation;
      
      // Draw constellation
      if (lines != null && stars.isNotEmpty) {
        // Calculate center of constellation from stars for correct positioning
        double minX = double.infinity, minY = double.infinity;
        double maxX = 0.0, maxY = 0.0;
        
        for (var star in stars) {
          final double x = (star['x'] as double);
          final double y = (star['y'] as double);
          minX = min(minX, x);
          minY = min(minY, y);
          maxX = max(maxX, x);
          maxY = max(maxY, y);
        }
        
        final double constellationWidth = maxX - minX;
        final double constellationHeight = maxY - minY;
        final double constellationCenterX = minX + constellationWidth / 2;
        final double constellationCenterY = minY + constellationHeight / 2;
        
        // Draw constellation lines
        final Paint linePaint = Paint()
          ..color = isHighlighted 
              ? Colors.blue.withOpacity(0.9 * opacity)
              : Colors.blue.withOpacity(0.5 * opacity)
          ..strokeWidth = isHighlighted ? 2.5 : 1.5
          ..style = PaintingStyle.stroke;
        
        // Draw lines between stars
        for (var line in lines) {
          final List<dynamic> connection = line as List<dynamic>;
          if (connection.length == 2) {
            final String star1Id = connection[0] as String;
            final String star2Id = connection[1] as String;
            
            Map<String, dynamic>? star1, star2;
            
            for (var star in stars) {
              final Map<String, dynamic> starData = star as Map<String, dynamic>;
              if (starData['id'] == star1Id) star1 = starData;
              if (starData['id'] == star2Id) star2 = starData;
            }
            
            if (star1 != null && star2 != null) {
              final double x1 = centerX + ((star1['x'] as double) - constellationCenterX) * scale;
              final double y1 = centerY + ((star1['y'] as double) - constellationCenterY) * scale;
              final double x2 = centerX + ((star2['x'] as double) - constellationCenterX) * scale;
              final double y2 = centerY + ((star2['y'] as double) - constellationCenterY) * scale;
              
              // Draw the connection line
              canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);
            }
          }
        }
        
        // Draw each star in the constellation
        for (var star in stars) {
          final Map<String, dynamic> starData = star as Map<String, dynamic>;
          final double magnitude = starData['magnitude'] as double;
          
          final double x = centerX + ((starData['x'] as double) - constellationCenterX) * scale;
          final double y = centerY + ((starData['y'] as double) - constellationCenterY) * scale;
          
          // Size based on magnitude but smaller for overview
          final double radius = isHighlighted
              ? (3.5 - min(3, magnitude)) * 1.2  // Larger when highlighted
              : (3.5 - min(3, magnitude)) * 0.8; // Make stars more visible
          
          // Draw the star
          final Paint starPaint = Paint()
            ..color = isHighlighted
                ? Colors.white.withOpacity(0.95 * opacity)
                : Colors.white.withOpacity(0.7 * opacity);
          
          canvas.drawCircle(Offset(x, y), radius, starPaint);
        }
      }
    }
  }
  
  @override
  bool shouldRepaint(ConstellationsPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.hoveredConstellation != hoveredConstellation;
  }
}