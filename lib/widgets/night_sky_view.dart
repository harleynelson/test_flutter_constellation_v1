import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  
  // Store the size for background consistency
  Size? _currentSize;
  // Store the background widget to prevent redrawing
  Widget? _backgroundWidget;
  // Store constellation positions
  Map<String, ConstellationInfo> _constellationInfoMap = {};
  
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
        final Size size = constraints.biggest;
        
        // Only calculate positions and create background when size changes
        if (_currentSize != size || _backgroundWidget == null) {
          _currentSize = size;
          _calculateConstellationInfos(size);
          _createBackgroundWidget(size);
        }
        
        return Stack(
          children: [
            // Static background - never redraws on hover
            _backgroundWidget!,
            
            // Transparent overlay for hover effects only
            Stack(
              children: widget.constellations.map((constellation) {
                final String name = constellation['name'] as String;
                final ConstellationInfo info = _constellationInfoMap[name]!;
                
                return Positioned(
                  left: info.centerX - info.radius,
                  top: info.centerY - info.radius,
                  width: info.radius * 2,
                  height: info.radius * 2,
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _hoveredConstellation = name),
                    onExit: (_) => setState(() => _hoveredConstellation = null),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        widget.onConstellationSelected(name);
                      },
                      child: _hoveredConstellation == name 
                          ? _buildHoverEffect(name, info.radius * 2) 
                          : Container(color: Colors.transparent),
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
  
  // Calculate all constellation positions and sizes once
  void _calculateConstellationInfos(Size size) {
    _constellationInfoMap = {};
    
    for (var constellation in widget.constellations) {
      final String name = constellation['name'] as String;
      final List<dynamic> stars = constellation['stars'] as List<dynamic>;
      
      if (stars.isEmpty) continue;
      
      // Random position based on constellation name
      final Random posRandom = Random(name.hashCode);
      final double centerX = size.width * (0.2 + posRandom.nextDouble() * 0.6);
      final double centerY = size.height * (0.2 + posRandom.nextDouble() * 0.6);
      
      // Calculate constellation bounds
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
      
      // Scale for display
      final double scale = 500;
      
      // Find the maximum distance from center to any star
      double maxDistance = 0;
      final List<ConstellationStar> scaledStars = [];
      
      for (var star in stars) {
        final double starX = centerX + ((star['x'] as double) - constellationCenterX) * scale;
        final double starY = centerY + ((star['y'] as double) - constellationCenterY) * scale;
        
        scaledStars.add(ConstellationStar(
          id: star['id'] as String,
          x: starX,
          y: starY,
          magnitude: star['magnitude'] as double
        ));
        
        final double distance = sqrt(pow(starX - centerX, 2) + pow(starY - centerY, 2));
        maxDistance = max(maxDistance, distance);
      }
      
      // Create line connections
      final List<dynamic>? linesData = constellation['lines'] as List<dynamic>?;
      final List<ConstellationLine> lines = [];
      
      if (linesData != null) {
        for (var line in linesData) {
          final List<dynamic> connection = line as List<dynamic>;
          if (connection.length == 2) {
            final String star1Id = connection[0] as String;
            final String star2Id = connection[1] as String;
            
            // Find the stars by ID
            ConstellationStar? star1, star2;
            for (var star in scaledStars) {
              if (star.id == star1Id) star1 = star;
              if (star.id == star2Id) star2 = star;
            }
            
            if (star1 != null && star2 != null) {
              lines.add(ConstellationLine(star1: star1, star2: star2));
            }
          }
        }
      }
      
      // Add some padding to radius
      final double radius = maxDistance + 30.0;
      
      _constellationInfoMap[name] = ConstellationInfo(
        centerX: centerX,
        centerY: centerY,
        radius: radius,
        stars: scaledStars,
        lines: lines
      );
    }
  }
  
  // Create the background widget once
  void _createBackgroundWidget(Size size) {
    _backgroundWidget = AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return RepaintBoundary(
          child: CustomPaint(
            painter: StaticNightSkyPainter(
              constellations: _constellationInfoMap,
              animationValue: _animationController.value,
              size: size,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }
  
  // Build hover effect widget
  Widget _buildHoverEffect(String name, double size) {
    return Stack(
      children: [
        // Subtle highlight glow
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue.withOpacity(0.1),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 5,
              ),
            ],
          ),
        ),
        
        // Constellation name
        Positioned(
          bottom: size * 0.4,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    blurRadius: 8.0,
                    color: Colors.black,
                    offset: Offset(0, 0),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

// Custom class to hold scaled star information
class ConstellationStar {
  final String id;
  final double x;
  final double y;
  final double magnitude;
  
  ConstellationStar({
    required this.id,
    required this.x,
    required this.y,
    required this.magnitude,
  });
}

// Custom class to hold line connection information
class ConstellationLine {
  final ConstellationStar star1;
  final ConstellationStar star2;
  
  ConstellationLine({
    required this.star1,
    required this.star2,
  });
}

// Custom class to hold constellation information
class ConstellationInfo {
  final double centerX;
  final double centerY;
  final double radius;
  final List<ConstellationStar> stars;
  final List<ConstellationLine> lines;
  
  ConstellationInfo({
    required this.centerX,
    required this.centerY,
    required this.radius,
    required this.stars,
    required this.lines,
  });
}

// Completely static painter that draws everything just once
class StaticNightSkyPainter extends CustomPainter {
  final Map<String, ConstellationInfo> constellations;
  final double animationValue;
  final Size size;
  final Random _random = Random(42);
  
  StaticNightSkyPainter({
    required this.constellations,
    required this.animationValue,
    required this.size,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Draw background gradient
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
    
    // Draw all constellations
    for (var entry in constellations.entries) {
      final ConstellationInfo info = entry.value;
      
      // Draw constellation lines
      final Paint linePaint = Paint()
        ..color = Colors.blue.withOpacity(0.5 * animationValue)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      
      for (var line in info.lines) {
        canvas.drawLine(
          Offset(line.star1.x, line.star1.y),
          Offset(line.star2.x, line.star2.y),
          linePaint
        );
      }
      
      // Draw stars
      for (var star in info.stars) {
        final double radius = (3.5 - min(3, star.magnitude)) * 0.8;
        
        final Paint starPaint = Paint()
          ..color = Colors.white.withOpacity(0.8 * animationValue);
        
        canvas.drawCircle(Offset(star.x, star.y), radius, starPaint);
      }
    }
  }
  
  @override
  bool shouldRepaint(StaticNightSkyPainter oldDelegate) {
    // Only repaint during the initial animation
    return oldDelegate.animationValue != animationValue;
  }
}