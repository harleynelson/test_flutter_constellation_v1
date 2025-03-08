// lib/widgets/inside_sky_view.dart
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../models/enhanced_constellation.dart';
import '../controllers/inside_view_controller.dart';
import '../utils/celestial_projections_inside.dart';
import '../utils/star_renderer.dart';
import '../utils/celestial_grid_renderer.dart';
import '../utils/twinkle_manager.dart';

/// A widget that renders the view from inside the celestial sphere
class InsideSkyView extends StatefulWidget {
  final List<EnhancedConstellation> constellations;
  final Function(String)? onConstellationSelected;
  final Function(InsideViewController)? onControllerCreated;
  
  const InsideSkyView({
    super.key,
    required this.constellations,
    this.onConstellationSelected,
    this.onControllerCreated,
  });
  
  @override
  State<InsideSkyView> createState() => _InsideSkyViewState();
}

class _InsideSkyViewState extends State<InsideSkyView> with SingleTickerProviderStateMixin {
  late InsideViewController _controller;
  late Ticker _ticker;
  double _twinklePhase = 0.0;
  bool _showGrid = true;
  
  // To track selected stars/constellations
  Map<String, ConstellationPositionInfo> _visibleConstellations = {};
  StarPositionInfo? _selectedStar;
  
  // Stream subscription for twinkling
  StreamSubscription<double>? _twinkleSub;

  @override
  void initState() {
    super.initState();
    
    // Create the controller
    _controller = InsideViewController();
    
    // Notify parent
    if (widget.onControllerCreated != null) {
      widget.onControllerCreated!(_controller);
    }
    
    // Create ticker for rotation animation only
    _ticker = createTicker((elapsed) {
      if (_controller.autoRotate) {
        _controller.updateAutoRotation();
        setState(() {}); // Trigger redraw
      }
    });
    
    _ticker.start();
    
    // Setup twinkling with the shared manager
    final twinkleManager = TwinkleManager();
    twinkleManager.start(); // Use default settings
    
    // Listen for phase updates
    _twinkleSub = twinkleManager.phaseStream.listen((phase) {
      setState(() {
        _twinklePhase = phase;
      });
    });
    
    // Default to looking at the first constellation
    if (widget.constellations.isNotEmpty && 
        widget.constellations[0].rightAscension != null && 
        widget.constellations[0].declination != null) {
      _controller.lookAt(
        widget.constellations[0].rightAscension!,
        widget.constellations[0].declination!
      );
    }
  }
  
  @override
  void dispose() {
    _twinkleSub?.cancel();
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
        
        // Draw the star using our shared renderer
        StarRenderer.drawStar(
          canvas,
          star.id,
          screenPos,
          star.magnitude,
          twinklePhase,
          size,
          spectralType: star.spectralType,
          twinkleIntensity: 0.3
        );
      }
      
      // Draw constellation lines if we have at least 2 visible stars
      if (hasVisibleStars) {
        visibleConstellations[constellation.name] = ConstellationPositionInfo(
          name: constellation.name,
          stars: constellationStars,
        );
        
        // Draw the lines using shared renderer
        StarRenderer.drawConstellationLines(canvas, constellation.lines, starPositions);
      }
    }
    
    // Draw the celestial grid
    if (showGrid) {
      CelestialGridRenderer.drawCelestialGrid(
        canvas, 
        size, 
        viewDir,
        controller.projection.celestialToDirection,
        controller.projection.projectToScreen,
        controller.projection.isPointVisible
      );
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
      
      // Draw background star using shared renderer
      StarRenderer.drawBackgroundStar(
        canvas,
        i,
        screenPos,
        radius,
        baseOpacity,
        twinklePhase,
        size,
        glowProbability: 0.2,
        twinkleIntensity: 0.3
      );
    }
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