// lib/widgets/inside_sky_view.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../models/enhanced_constellation.dart';
import '../controllers/inside_view_controller.dart';
import '../utils/celestial_projections_inside.dart';

/// A widget that renders the view from inside the celestial sphere
class InsideSkyView extends StatefulWidget {
  final List<EnhancedConstellation> constellations;
  final Function(String)? onConstellationSelected;
  final Function(InsideViewController)? onControllerCreated;
  
  const InsideSkyView({
    Key? key,
    required this.constellations,
    this.onConstellationSelected,
    this.onControllerCreated,
  }) : super(key: key);
  
  @override
  State<InsideSkyView> createState() => _InsideSkyViewState();
}

class _InsideSkyViewState extends State<InsideSkyView> with SingleTickerProviderStateMixin {
  late InsideViewController _controller;
  late Ticker _ticker;
  double _twinklePhase = 0.0;
  String? _hoveredConstellation;
  bool _showGrid = true;
  
  // To track selected stars/constellations
  Map<String, ConstellationPositionInfo> _visibleConstellations = {};
  StarPositionInfo? _selectedStar;
  
  @override
  void initState() {
    super.initState();
    
    // Create the controller
    _controller = InsideViewController();
    
    // Notify parent
    if (widget.onControllerCreated != null) {
      widget.onControllerCreated!(_controller);
    }
    
    // Create ticker for animation
    _ticker = createTicker((elapsed) {
      setState(() {
        _twinklePhase = elapsed.inMilliseconds / 5000 * pi;
        
        // Update auto-rotation
        _controller.updateAutoRotation();
      });
    });
    
    _ticker.start();
    
    // Default to looking at the first constellation
    if (widget.constellations.isNotEmpty && 
        widget.constellations[0].rightAscension != null && 
        widget.constellations[0].declination != null) {
      _controller.lookAt(
        widget.constellations[0].rightAscension!,
        widget.constellations[0].declination!
      );
    }
    
    // Debug output
    print("DEBUG: Inside Sky View initialized with ${widget.constellations.length} constellations");
  }
  
  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (details) {
        _controller.startDrag(details.focalPoint);
      },
      onScaleUpdate: (details) {
        // Handle both drag and scale
        if (details.scale != 1.0) {
          _controller.zoom(details.scale);
        } else {
          _controller.updateDrag(details.focalPoint);
        }
      },
      onScaleEnd: (details) {
        _controller.endDrag();
      },
      onTapDown: (details) {
        _handleTap(details.localPosition);
      },
      child: Stack(
        children: [
          // Background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [
                  Color(0xFF111B2A), // Dark blue
                  Color(0xFF000510), // Very dark blue
                  Colors.black,
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          
          // Sky view
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: InsideSkyPainter(
                  constellations: widget.constellations,
                  controller: _controller,
                  twinklePhase: _twinklePhase,
                  showGrid: _showGrid,
                  onPositionsCalculated: (constellations) {
                    _visibleConstellations = constellations;
                  },
                ),
                size: Size.infinite,
              );
            },
          ),
          
          // UI Controls
          Positioned(
            top: 10,
            right: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Grid toggle button
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showGrid = !_showGrid;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _showGrid 
                              ? Colors.lightBlue.withOpacity(0.7) 
                              : Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _showGrid ? "Hide Grid" : "Show Grid",
                        style: TextStyle(
                          color: _showGrid ? Colors.lightBlue : Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Auto-rotation toggle
                GestureDetector(
                  onTap: () {
                    _controller.toggleAutoRotate();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _controller.autoRotate 
                            ? Colors.amber.withOpacity(0.7) 
                            : Colors.grey.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _controller.autoRotate ? "Stop Rotation" : "Auto Rotate",
                      style: TextStyle(
                        color: _controller.autoRotate ? Colors.amber : Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Direction indicator
          Positioned(
            bottom: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _getDirectionText(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Selected star/constellation info
          if (_selectedStar != null)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Card(
                color: Colors.black.withOpacity(0.7),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedStar!.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Magnitude: ${_selectedStar!.magnitude.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      if (_selectedStar!.constellation != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Constellation: ${_selectedStar!.constellation}',
                            style: const TextStyle(
                              fontSize: 16, 
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'RA: ${_selectedStar!.ra.toStringAsFixed(2)}°, Dec: ${_selectedStar!.dec.toStringAsFixed(2)}°',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Tap anywhere to close',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  /// Handle tap to select stars
  void _handleTap(Offset position) {
    // First check if we've tapped on a constellation
    StarPositionInfo? tappedStar;
    double closestDistance = 25.0; // Tap threshold in pixels
    
    // Check all visible constellations
    for (final entry in _visibleConstellations.entries) {
      for (final star in entry.value.stars) {
        final distance = (star.screenPosition - position).distance;
        if (distance < closestDistance) {
          closestDistance = distance;
          tappedStar = star;
        }
      }
    }
    
    setState(() {
      if (tappedStar != null) {
        _selectedStar = tappedStar;
      } else {
        // If we didn't tap a star, clear selection
        _selectedStar = null;
      }
    });
    
    // Notify if we selected a constellation
    if (tappedStar != null && tappedStar.constellation != null && widget.onConstellationSelected != null) {
      widget.onConstellationSelected!(tappedStar.constellation!);
    }
  }
  
  /// Get text description of current view direction
  String _getDirectionText() {
    final heading = _controller.heading;
    final pitch = _controller.pitch;
    
    String dirText = "";
    
    // Heading text
    if (heading >= 337.5 || heading < 22.5) {
      dirText = "N";
    } else if (heading >= 22.5 && heading < 67.5) {
      dirText = "NE";
    } else if (heading >= 67.5 && heading < 112.5) {
      dirText = "E";
    } else if (heading >= 112.5 && heading < 157.5) {
      dirText = "SE";
    } else if (heading >= 157.5 && heading < 202.5) {
      dirText = "S";
    } else if (heading >= 202.5 && heading < 247.5) {
      dirText = "SW";
    } else if (heading >= 247.5 && heading < 292.5) {
      dirText = "W";
    } else if (heading >= 292.5 && heading < 337.5) {
      dirText = "NW";
    }
    
    // Add pitch
    if (pitch >= 45) {
      dirText += " ↑";
    } else if (pitch <= -45) {
      dirText += " ↓";
    }
    
    return dirText;
  }
}

/// Painter for the inside sky view
class InsideSkyPainter extends CustomPainter {
  final List<EnhancedConstellation> constellations;
  final InsideViewController controller;
  final double twinklePhase;
  final bool showGrid;
  final Function(Map<String, ConstellationPositionInfo>)? onPositionsCalculated;
  
  InsideSkyPainter({
    required this.constellations,
    required this.controller,
    this.twinklePhase = 0.0,
    this.showGrid = true,
    this.onPositionsCalculated,
  }) : super(repaint: controller);
  
  @override
  void paint(Canvas canvas, Size size) {
    // First draw the background stars
    _drawBackgroundStars(canvas, size);
    
    // Get our current view direction
    final viewDir = controller.getViewDirection();
    
    // Map to track visible constellations
    final Map<String, ConstellationPositionInfo> visibleConstellations = {};
    
    // Draw the constellations
    for (final constellation in constellations) {
      if (constellation.rightAscension == null || constellation.declination == null) {
        continue;
      }
      
      // Collect stars and their screen positions
      final List<StarPositionInfo> constellationStars = [];
      final Map<String, Offset> starPositions = {};
      
      // Check if any stars are visible
      bool hasVisibleStars = false;
      
      // Process stars
      for (final star in constellation.stars) {
        // Convert to 3D direction
        final direction = controller.projection.celestialToDirection(
          star.rightAscension, 
          star.declination
        );
        
        // Check if it's in our field of view
        if (!controller.projection.isPointVisible(direction, viewDir)) {
          continue;
        }
        
        // Project to screen coordinates
        final screenPos = controller.projection.projectToScreen(
          direction, 
          size, 
          viewDir
        );
        
        // Skip if off-screen
        if (screenPos.dx < -1000 || screenPos.dx > size.width + 1000 ||
            screenPos.dy < -1000 || screenPos.dy > size.height + 1000) {
          continue;
        }
        
        hasVisibleStars = true;
        
        // Store position
        starPositions[star.id] = screenPos;
        
        // Add to visible stars list
        constellationStars.add(StarPositionInfo(
          id: star.id,
          name: star.name,
          magnitude: star.magnitude,
          ra: star.rightAscension,
          dec: star.declination,
          direction: direction,
          screenPosition: screenPos,
          constellation: constellation.name,
          spectralType: star.spectralType,
        ));
        
        // Draw the star
        _drawStar(canvas, star, screenPos);
      }
      
      // Draw constellation lines if we have at least 2 visible stars
      if (hasVisibleStars) {
        visibleConstellations[constellation.name] = ConstellationPositionInfo(
          name: constellation.name,
          stars: constellationStars,
        );
        
        // Draw the lines
        _drawConstellationLines(canvas, constellation.lines, starPositions);
      }
    }
    
    // Draw the celestial grid
    if (showGrid) {
      _drawCelestialGrid(canvas, size, viewDir);
    }
    
    // Notify about calculated positions
    if (onPositionsCalculated != null) {
      onPositionsCalculated!(visibleConstellations);
    }
  }
  
  /// Draw background stars
  void _drawBackgroundStars(Canvas canvas, Size size) {
  final Random random = Random(42);
  final int starCount = (size.width * size.height / 2000).round().clamp(500, 3000);
  
  // For consistent but realistic-looking random stars, we'll create them in 3D space
  // and then project them to the screen
  for (int i = 0; i < starCount; i++) {
    // Create a random 3D direction
    final double theta = random.nextDouble() * 2 * pi; // Azimuth
    final double phi = acos(2 * random.nextDouble() - 1); // Inclination
    
    final double x = sin(phi) * cos(theta);
    final double y = cos(phi);
    final double z = sin(phi) * sin(theta);
    
    final direction = Vector3D(x, y, z);
    
    // Check if it's in our field of view
    if (!controller.projection.isPointVisible(direction, controller.getViewDirection())) {
      continue;
    }
    
    // Project to screen coordinates
    final screenPos = controller.projection.projectToScreen(
      direction, 
      size, 
      controller.getViewDirection()
    );
    
    // Skip if off-screen
    if (screenPos.dx < 0 || screenPos.dx > size.width ||
        screenPos.dy < 0 || screenPos.dy > size.height) {
      continue;
    }
    
    // Randomize size and brightness
    final double radius = random.nextDouble() * 1.0 + 0.3; // 0.3-1.3 pixels
    final double baseOpacity = random.nextDouble() * 0.5 + 0.2; // 0.2-0.7
    
    // Apply twinkling - but make sure opacity stays in valid range 0-1
    final double starSeed = screenPos.dx * screenPos.dy;
    final double twinkleSpeed = 0.5 + (sin(starSeed) + 1) * 0.5; // Range 0.5-1.5
    final double twinkleFactor = max(0, sin((twinklePhase * twinkleSpeed) % (2 * pi)));
    
    // Adjust opacity with twinkling - ensure it's clamped to valid range
    final double opacity = min(1.0, max(0.0, baseOpacity * (1.0 + twinkleFactor * 0.3)));
    
    // Draw star
    final Paint starPaint = Paint()
      ..color = Colors.white.withOpacity(opacity);
    
    canvas.drawCircle(screenPos, radius, starPaint);
    
    // Draw subtle glow for some stars
    if (random.nextDouble() > 0.8) {
      final double glowOpacity = min(1.0, max(0.0, opacity * 0.3));
      final Paint glowPaint = Paint()
        ..color = Colors.white.withOpacity(glowOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
      
      canvas.drawCircle(screenPos, radius * 1.5, glowPaint);
    }
  }
}
  
  /// Draw a single star
  void _drawStar(Canvas canvas, CelestialStar star, Offset position) {
    // Calculate star size based on magnitude (brighter = larger)
    final double size = _calculateStarSize(star.magnitude);
    
    // Apply small twinkle effect
    final double starSeed = position.dx * position.dy;
    final double twinkleSpeed = 0.5 + (sin(starSeed) + 1) * 0.5;
    final double twinkleFactor = max(0, sin((twinklePhase * twinkleSpeed) % (2 * pi)));
    
    // Adjust size and brightness with twinkling
    final double currentSize = size * (1.0 + twinkleFactor * 0.1);
    
    // Get star color based on spectral type
    final Color starColor = _getStarColor(star.spectralType);
    
    // Make color slightly brighter during twinkle
    final Color twinkleColor = _adjustColorBrightness(starColor, twinkleFactor * 0.15);
    
    // Draw star glow
    final Paint glowPaint = Paint()
      ..color = twinkleColor.withOpacity(0.3 + twinkleFactor * 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    
    canvas.drawCircle(position, currentSize * 1.5, glowPaint);
    
    // Draw star core
    final Paint starPaint = Paint()
      ..color = twinkleColor
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(position, currentSize, starPaint);
  }
  
  /// Draw constellation lines
  void _drawConstellationLines(Canvas canvas, List<List<String>> lines, Map<String, Offset> starPositions) {
    final Paint linePaint = Paint()
      ..color = Colors.blue.withOpacity(0.4)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    for (final line in lines) {
      if (line.length == 2) {
        final String star1Id = line[0];
        final String star2Id = line[1];
        
        if (starPositions.containsKey(star1Id) && starPositions.containsKey(star2Id)) {
          canvas.drawLine(
            starPositions[star1Id]!,
            starPositions[star2Id]!,
            linePaint
          );
        }
      }
    }
  }
  
  /// Draw the celestial grid
  void _drawCelestialGrid(Canvas canvas, Size size, Vector3D viewDir) {
    final Paint gridPaint = Paint()
      ..color = Colors.lightBlue.withOpacity(0.2)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    // Draw meridians (longitude lines)
    for (int i = 0; i < 24; i++) { // 24 meridians = 15° spacing
      final double ra = i * 15.0; // RA in degrees
      final List<Offset> points = [];
      
      // Draw points along this meridian
      for (int j = 0; j <= 36; j++) { // Higher resolution for smoother curves
        final double dec = -90.0 + j * 5.0; // Dec in degrees
        
        // Convert to direction vector
        final direction = controller.projection.celestialToDirection(ra, dec);
        
        // Check if it's in our field of view
        if (!controller.projection.isPointVisible(direction, viewDir)) {
          // If we have points already, draw what we have so far
          if (points.isNotEmpty) {
            _drawLines(canvas, points, gridPaint);
            points.clear();
          }
          continue;
        }
        
        // Project to screen coordinates
        final screenPos = controller.projection.projectToScreen(
          direction, 
          size, 
          viewDir
        );
        
        points.add(screenPos);
      }
      
      _drawLines(canvas, points, gridPaint);
    }
    
    // Draw parallels (latitude lines)
    for (int i = 1; i < 18; i++) { // 18 parallels = 10° spacing, skip poles
      final double dec = -90.0 + i * 10.0; // Dec in degrees
      final List<Offset> points = [];
      
      // Draw points along this parallel
      for (int j = 0; j <= 72; j++) { // Higher resolution for smoother curves
        final double ra = j * 5.0; // RA in degrees
        
        // Convert to direction vector
        final direction = controller.projection.celestialToDirection(ra, dec);
        
        // Check if it's in our field of view
        if (!controller.projection.isPointVisible(direction, viewDir)) {
          // If we have points already, draw what we have so far
          if (points.isNotEmpty) {
            _drawLines(canvas, points, gridPaint);
            points.clear();
          }
          continue;
        }
        
        // Project to screen coordinates
        final screenPos = controller.projection.projectToScreen(
          direction, 
          size, 
          viewDir
        );
        
        points.add(screenPos);
      }
      
      _drawLines(canvas, points, gridPaint);
    }
    
    // Draw cardinal direction labels
    _drawCardinalLabels(canvas, size, viewDir);
  }
  
  /// Draw cardinal direction labels
  void _drawCardinalLabels(Canvas canvas, Size size, Vector3D viewDir) {
    final directions = [
      {'label': 'N', 'ra': 0.0, 'dec': 0.0},    // North
      {'label': 'S', 'ra': 180.0, 'dec': 0.0},  // South
      {'label': 'E', 'ra': 90.0, 'dec': 0.0},   // East
      {'label': 'W', 'ra': 270.0, 'dec': 0.0},  // West
    ];
    
    for (final direction in directions) {
      // Convert to direction vector
      final dir = controller.projection.celestialToDirection(
        direction['ra'] as double, 
        direction['dec'] as double
      );
      
      // Check if it's in our field of view
      if (!controller.projection.isPointVisible(dir, viewDir)) {
        continue;
      }
      
      // Project to screen coordinates
      final screenPos = controller.projection.projectToScreen(
        dir, 
        size, 
        viewDir
      );
      
      // Draw the label
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: direction['label'] as String,
          style: TextStyle(
            color: Colors.lightBlue.withOpacity(0.7),
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(
                color: Colors.black,
                offset: Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas, 
        Offset(
          screenPos.dx - textPainter.width / 2, 
          screenPos.dy - textPainter.height / 2
        )
      );
    }
  }
  
  /// Draw a connected line through the given points
  void _drawLines(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    
    canvas.drawPath(path, paint);
  }
  
  /// Calculate star size based on magnitude
  double _calculateStarSize(double magnitude) {
    // Brighter stars (lower magnitude) are larger
    return max(2.0, 8.0 - magnitude * 0.7);
  }
  
  /// Get star color based on spectral type
  Color _getStarColor(String? spectralType) {
    if (spectralType == null || spectralType.isEmpty) {
      return Colors.white;
    }
    
    // Extract the main spectral class (first character)
    final String mainClass = spectralType[0].toUpperCase();
    
    // Colors based on stellar classification
    switch (mainClass) {
      case 'O': // Blue
        return const Color(0xFFCAE8FF);
      case 'B': // Blue-white
        return const Color(0xFFE6F0FF);
      case 'A': // White
        return Colors.white;
      case 'F': // Yellow-white
        return const Color(0xFFFFF8E8);
      case 'G': // Yellow (Sun-like)
        return const Color(0xFFFFEFB3);
      case 'K': // Orange
        return const Color(0xFFFFD2A1);
      case 'M': // Red
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
  bool shouldRepaint(covariant InsideSkyPainter oldDelegate) {
    return oldDelegate.controller != controller ||
           oldDelegate.twinklePhase != twinklePhase ||
           oldDelegate.showGrid != showGrid;
  }
}

/// Information about a constellation's position on screen
class ConstellationPositionInfo {
  final String name;
  final List<StarPositionInfo> stars;
  
  ConstellationPositionInfo({
    required this.name,
    required this.stars,
  });
}

/// Information about a star's position and properties
class StarPositionInfo {
  final String id;
  final String name;
  final double magnitude;
  final double ra;
  final double dec;
  final Vector3D direction;
  final Offset screenPosition;
  final String? constellation;
  final String? spectralType;
  
  StarPositionInfo({
    required this.id,
    required this.name,
    required this.magnitude,
    required this.ra,
    required this.dec,
    required this.direction,
    required this.screenPosition,
    this.constellation,
    this.spectralType,
  });
}