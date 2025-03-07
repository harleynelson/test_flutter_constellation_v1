// lib/widgets/celestial_night_sky_view.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../models/enhanced_constellation.dart';
import '../controllers/celestial_projection_controller.dart';
import '../utils/celestial_projections.dart';
import '../painters/wireframe_sphere_painter.dart';

/// A widget that renders multiple constellations in a full sky view with 3D support
class CelestialNightSkyView extends StatefulWidget {
  final List<EnhancedConstellation> constellations;
  final Function(String) onConstellationSelected;
  final Function(CelestialProjectionController)? onControllerCreated;
  final bool enable3DMode;

  const CelestialNightSkyView({
    Key? key,
    required this.constellations,
    required this.onConstellationSelected,
    this.onControllerCreated,
    this.enable3DMode = false,
  }) : super(key: key);

  @override
  State<CelestialNightSkyView> createState() => _CelestialNightSkyViewState();
}

class _CelestialNightSkyViewState extends State<CelestialNightSkyView> with SingleTickerProviderStateMixin {
  late CelestialProjectionController _projectionController;
  late Ticker _ticker;
  double _twinklePhase = 0.0;
  String? _hoveredConstellation;
  Offset? _lastDragPosition;
  bool _showWireframe = true; // Default to showing wireframe
  
  // Store calculated positions of constellations for hit testing
  final Map<String, _ConstellationAreaInfo> _constellationPositions = {};
  
  @override
  void initState() {
    super.initState();
    
    // Initialize projection controller with more sensible defaults for 3D viewing
    _projectionController = CelestialProjectionController(
      fieldOfView: 100.0, // Wider field of view to see more stars at once
      centerRightAscension: 0.0,
      centerDeclination: 0.0, // Look straight ahead initially
      is3DMode: widget.enable3DMode,
      perspectiveDepth: widget.enable3DMode ? 0.8 : 0.0, // Increased perspective effect
    );
    
    // Create a ticker for animation
    _ticker = createTicker((elapsed) {
      setState(() {
        _twinklePhase = elapsed.inMilliseconds / 5000 * pi;
        
        // Update auto-rotation if enabled
        if (widget.enable3DMode) {
          _projectionController.updateAutoRotation();
        }
      });
    });
    
    _ticker.start();
    
    // Notify parent about the controller
    if (widget.onControllerCreated != null) {
      widget.onControllerCreated!(_projectionController);
    }
    
    // Debug - print constellation info
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _debugPrintConstellationInfo();
    });
  }
  
  // Debug function to print constellation information
  void _debugPrintConstellationInfo() {
    print('DEBUG: Number of constellations: ${widget.constellations.length}');
    
    // Sample some constellations to check their coordinates
    for (var constellation in widget.constellations.take(5)) {
      print('DEBUG: Constellation ${constellation.name}: '
          'RA=${constellation.rightAscension}, '
          'Dec=${constellation.declination}, '
          'Stars=${constellation.stars.length}');
      
      if (constellation.stars.isNotEmpty) {
        final star = constellation.stars.first;
        print('DEBUG: First star: ${star.name}, '
            'RA=${star.rightAscension}, '
            'Dec=${star.declination}');
      }
    }
  }
  
  @override
  void didUpdateWidget(CelestialNightSkyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update 3D mode if changed
    if (oldWidget.enable3DMode != widget.enable3DMode) {
      _projectionController.setProjectionMode(widget.enable3DMode);
    }
  }
  
  @override
  void dispose() {
    _ticker.dispose();
    _projectionController.dispose();
    super.dispose();
  }
  
  // Calculate the positions of constellations on screen
  void _calculateConstellationPositions(Size screenSize) {
    _constellationPositions.clear();
    final projection = _projectionController.projection;
    
    print("DEBUG: Calculating positions for ${widget.constellations.length} constellations");
    int visible = 0;
    
    for (var constellation in widget.constellations) {
      if (constellation.rightAscension == null || constellation.declination == null) {
        print("DEBUG: Constellation ${constellation.name} missing RA/Dec coordinates");
        continue; // Skip constellations without proper coordinates
      }
      
      // Get center position in screen coordinates
      Offset position;
      bool isVisible = true;
      
      // Draw ALL constellations for debugging
      isVisible = true;
      
      // Convert the celestial coordinates to 3D point
      final centerPoint = projection.celestialTo3D(
        constellation.rightAscension!, 
        constellation.declination!
      );
      
      // Project to screen coordinates
      position = projection.project3DToScreen(centerPoint, screenSize);
      
      // In 3D mode, determine if the constellation is in front or behind us
      if (_projectionController.is3DMode) {
        // Apply the rotations to check if it's behind us
        Vector3D rotated = centerPoint;
        final rotationAngles = _projectionController.projection.rotationAngles;
        
        if (rotationAngles != null) {
          // Apply X rotation (around X axis)
          if (rotationAngles.x != 0) {
            final double cosX = cos(rotationAngles.x);
            final double sinX = sin(rotationAngles.x);
            rotated = Vector3D(
              rotated.x,
              rotated.y * cosX - rotated.z * sinX,
              rotated.y * sinX + rotated.z * cosX
            );
          }
          
          // Apply Y rotation (around Y axis)
          if (rotationAngles.y != 0) {
            final double cosY = cos(rotationAngles.y);
            final double sinY = sin(rotationAngles.y);
            rotated = Vector3D(
              rotated.x * cosY + rotated.z * sinY,
              rotated.y,
              -rotated.x * sinY + rotated.z * cosY
            );
          }
          
          // Inside-looking-out: Objects with z < -0.8 are almost directly behind us
          if (rotated.z < -0.8) {
            print("DEBUG: Constellation ${constellation.name} is behind viewer (z=${rotated.z.toStringAsFixed(2)})");
            isVisible = false;
          }
        }
      }
      
      // Skip positions that are way off screen (more than 2000 pixels away)
      if (position.dx < -2000 || position.dx > screenSize.width + 2000 ||
          position.dy < -2000 || position.dy > screenSize.height + 2000) {
        isVisible = false;
      }
      
      // For visible constellations, add them to the map
      if (isVisible) {
        visible++;
        // Calculate a larger radius for better visibility
        final radius = 80.0 + min(constellation.stars.length * 8.0, 60.0);
        
        _constellationPositions[constellation.name] = _ConstellationAreaInfo(
          center: position,
          radius: radius,
        );
      }
    }
    
    print("DEBUG: Total visible constellations: $visible");
  }
  
  // Check if a point is within a constellation's hit area
  String? _getConstellationAtPosition(Offset position) {
    for (var entry in _constellationPositions.entries) {
      final info = entry.value;
      if ((position - info.center).distance <= info.radius) {
        return entry.key;
      }
    }
    return null;
  }
  
  @override
  Widget build(BuildContext context) {
    // Print debug info about constellation positions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_constellationPositions.isNotEmpty) {
        print("DEBUG: Visible constellations in current view: ${_constellationPositions.length}");
        _constellationPositions.entries.take(3).forEach((entry) {
          print("DEBUG: ${entry.key} at position (${entry.value.center.dx.toStringAsFixed(1)}, ${entry.value.center.dy.toStringAsFixed(1)})");
        });
      } else {
        print("DEBUG: No visible constellations in current view");
      }
    });
    
    return MouseRegion(
      onHover: (details) {
        final constellation = _getConstellationAtPosition(details.localPosition);
        if (_hoveredConstellation != constellation) {
          setState(() {
            _hoveredConstellation = constellation;
          });
        }
      },
      onExit: (_) {
        setState(() {
          _hoveredConstellation = null;
        });
      },
      child: GestureDetector(
        onTapDown: (details) {
          final constellation = _getConstellationAtPosition(details.localPosition);
          if (constellation != null) {
            setState(() {
              _hoveredConstellation = constellation;
            });
          }
        },
        onTap: () {
          if (_hoveredConstellation != null) {
            HapticFeedback.mediumImpact();
            widget.onConstellationSelected(_hoveredConstellation!);
            setState(() {
              _hoveredConstellation = null;
            });
          }
        },
        onScaleStart: (details) {
          _lastDragPosition = details.focalPoint;
        },
        onScaleUpdate: (details) {
          if (_lastDragPosition != null) {
            final delta = details.focalPoint - _lastDragPosition!;
            
            // Apply pan if no scaling or rotation is happening
            if (details.scale == 1.0 && details.rotation == 0.0) {
              _projectionController.updateDragOffset(
                delta.dx / 100.0,
                delta.dy / 100.0
              );
            }
            
            // Apply scale if scaling is happening
            if (details.scale != 1.0) {
              _projectionController.zoom(details.scale);
            }
            
            // Apply rotation if rotation is happening
            if (details.rotation != 0.0) {
              _projectionController.rotate(details.rotation);
            }
            
            _lastDragPosition = details.focalPoint;
          }
        },
        onScaleEnd: (details) {
          _lastDragPosition = null;
          _projectionController.endDrag();
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            
            // Calculate constellation positions for hit testing
            _calculateConstellationPositions(size);
            
            return Stack(
              children: [
                // Background gradient
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
                
                // Draw random background stars
                CustomPaint(
                  painter: _BackgroundStarsPainter(
                    twinklePhase: _twinklePhase,
                  ),
                  size: Size.infinite,
                ),
                
                // Draw wireframe sphere
                if (_projectionController.is3DMode && _showWireframe)
                  CustomPaint(
                    painter: WireframeSphereCustomPainter(
                      projectionController: _projectionController,
                      meridianCount: 12, // 12 longitude lines (30° spacing)
                      parallelCount: 7,  // 7 latitude lines (30° spacing)
                      color: Colors.lightBlue,
                    ),
                    size: Size.infinite,
                  ),
                
                // Draw constellation markers
                ..._constellationPositions.entries.map((entry) {
                  final name = entry.key;
                  final info = entry.value;
                  final isHovered = name == _hoveredConstellation;
                  
                  // Try to find the constellation to get more data
                  final constellation = widget.constellations.firstWhere(
                    (c) => c.name == name,
                    orElse: () => widget.constellations.first,
                  );
                  
                  return Positioned(
                    left: info.center.dx - info.radius,
                    top: info.center.dy - info.radius,
                    width: info.radius * 2,
                    height: info.radius * 2,
                    child: _buildConstellationMarker(
                      name,
                      isHovered,
                      info.radius * 2,
                      constellation,
                    ),
                  );
                }).toList(),
                
                // Mode indicator (3D/2D)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _projectionController.is3DMode ? "3D Overview" : "2D Overview",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      
                      // Wireframe toggle button
                      if (_projectionController.is3DMode)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showWireframe = !_showWireframe;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _showWireframe 
                                      ? Colors.lightBlue.withOpacity(0.7) 
                                      : Colors.grey.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _showWireframe ? "Hide Grid" : "Show Grid",
                                style: TextStyle(
                                  color: _showWireframe ? Colors.lightBlue : Colors.white70,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Help text
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Text(
                    'Tap on a constellation to view details',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildConstellationMarker(
    String name, 
    bool isHovered, 
    double size,
    EnhancedConstellation constellation,
  ) {
    return AnimatedOpacity(
      opacity: isHovered ? 1.0 : 0.7,
      duration: const Duration(milliseconds: 200),
      child: Stack(
        children: [
          // Highlight circle
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withOpacity(isHovered ? 0.2 : 0.05),
              border: Border.all(
                color: Colors.blue.withOpacity(isHovered ? 0.5 : 0.2),
                width: isHovered ? 2.0 : 1.0,
              ),
            ),
          ),
          
          // Draw the constellation pattern
          CustomPaint(
            size: Size(size, size),
            painter: _ConstellationPatternPainter(
              constellation: constellation,
              isHovered: isHovered,
            ),
          ),
          
          // Constellation name
          Positioned(
            bottom: size * 0.2, // Moved lower to avoid overlapping with pattern
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isHovered ? 18.0 : 14.0,
                      fontWeight: FontWeight.bold,
                      shadows: const [
                        Shadow(
                          blurRadius: 8.0,
                          color: Colors.black,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isHovered && constellation.abbreviation != null)
                    Text(
                      '(${constellation.abbreviation})',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12.0,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Painter for rendering a miniature constellation pattern
class _ConstellationPatternPainter extends CustomPainter {
  final EnhancedConstellation constellation;
  final bool isHovered;
  
  _ConstellationPatternPainter({
    required this.constellation,
    this.isHovered = false,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (constellation.stars.isEmpty) return;
    
    // Find min/max coordinates of the stars for scaling
    double minX = double.infinity, minY = double.infinity;
    double maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    
    // Use RA/Dec coordinates first (they should be more reliable)
    bool useRaDec = constellation.stars.every(
      (star) => star.rightAscension != 0 && star.declination != 0
    );
    
    for (var star in constellation.stars) {
      if (useRaDec) {
        minX = min(minX, star.rightAscension);
        minY = min(minY, star.declination);
        maxX = max(maxX, star.rightAscension);
        maxY = max(maxY, star.declination);
      } else {
        // Fall back to original x/y coordinates if RA/Dec not reliable
        minX = min(minX, star.x);
        minY = min(minY, star.y);
        maxX = max(maxX, star.x);
        maxY = max(maxY, star.y);
      }
    }
    
    // Safety check
    if (minX >= maxX || minY >= maxY) return;
    
    // Calculate scale and offset
    final double width = maxX - minX;
    final double height = maxY - minY;
    final double scale = min(
      (size.width * 0.7) / width,
      (size.height * 0.7) / height
    );
    
    // Center the constellation
    final double offsetX = (size.width - (width * scale)) / 2;
    final double offsetY = (size.height - (height * scale)) / 2;
    
    // Create map of star positions
    final Map<String, Offset> starPositions = {};
    
    // Draw the stars
    for (var star in constellation.stars) {
      // Calculate position
      double starX, starY;
      if (useRaDec) {
        starX = offsetX + (star.rightAscension - minX) * scale;
        starY = offsetY + (star.declination - minY) * scale;
      } else {
        starX = offsetX + (star.x - minX) * scale;
        starY = offsetY + (star.y - minY) * scale;
      }
      
      // Store position for line drawing
      starPositions[star.id] = Offset(starX, starY);
      
      // Draw star
      final double starSize = _calculateStarSize(star.magnitude);
      final Paint starPaint = Paint()
        ..color = _getStarColor(star.magnitude)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(starX, starY), starSize, starPaint);
    }
    
    // Draw constellation lines
    final Paint linePaint = Paint()
      ..color = Colors.blue.withOpacity(isHovered ? 0.7 : 0.4)
      ..strokeWidth = isHovered ? 2.0 : 1.0
      ..style = PaintingStyle.stroke;
    
    for (var line in constellation.lines) {
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
  
  double _calculateStarSize(double magnitude) {
    // Brighter stars (lower magnitude) are larger
    return max(2.0, 5.0 - magnitude * 0.5);
  }
  
  Color _getStarColor(double magnitude) {
    // Brightest stars are white to blue-white
    if (magnitude < 1.0) {
      return Colors.white;
    } else if (magnitude < 2.0) {
      return const Color(0xFFF8F9FF); // Very light blue
    } else if (magnitude < 3.0) {
      return const Color(0xFFFFFAF0); // Light yellow
    } else {
      return const Color(0xFFFFE4C4); // Light orange
    }
  }
  
  @override
  bool shouldRepaint(_ConstellationPatternPainter oldDelegate) {
    return oldDelegate.constellation != constellation || 
           oldDelegate.isHovered != isHovered;
  }
}

/// Stores information about a constellation's position on screen
class _ConstellationAreaInfo {
  final Offset center;
  final double radius;
  
  _ConstellationAreaInfo({
    required this.center,
    required this.radius,
  });
}

/// Painter for the random background stars
class _BackgroundStarsPainter extends CustomPainter {
  final double twinklePhase;
  final Random _random = Random(42); // Fixed seed for consistent background
  
  _BackgroundStarsPainter({
    required this.twinklePhase,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the number of stars based on screen size
    final int starCount = (size.width * size.height / 2000).round().clamp(200, 1000);
    
    for (int i = 0; i < starCount; i++) {
      // Use fixed seed for consistent positions but varied properties
      final double x = _random.nextDouble() * size.width;
      final double y = _random.nextDouble() * size.height;
      final double radius = _random.nextDouble() * 1.2 + 0.3; // 0.3-1.5
      final double baseOpacity = _random.nextDouble() * 0.5 + 0.2; // 0.2-0.7
      
      // Unique twinkle effect per star
      final double starSeed = x * y; // Unique per position
      final double twinkleSpeed = 0.5 + (sin(starSeed) + 1) * 0.5; // Range 0.5-1.5
      final double twinkleFactor = max(0, sin((twinklePhase * twinkleSpeed) % (2 * pi)));
      
      // Adjust opacity with twinkling
      final double opacity = baseOpacity * (1.0 + twinkleFactor * 0.3);
      
      // Draw star
      final Paint starPaint = Paint()
        ..color = Colors.white.withOpacity(opacity);
      
      canvas.drawCircle(Offset(x, y), radius, starPaint);
      
      // Draw subtle glow for some stars
      if (_random.nextDouble() > 0.7) {
        final Paint glowPaint = Paint()
          ..color = Colors.white.withOpacity(opacity * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
        
        canvas.drawCircle(Offset(x, y), radius * 1.5, glowPaint);
      }
    }
  }
  
  @override
  bool shouldRepaint(_BackgroundStarsPainter oldDelegate) {
    return oldDelegate.twinklePhase != twinklePhase;
  }
}