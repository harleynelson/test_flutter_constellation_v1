// lib/widgets/sky_view.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import '../models/enhanced_constellation.dart';
import '../models/constellation_center.dart';
import '../controllers/inside_view_controller.dart';
import '../utils/celestial_projections_inside.dart';
import '../services/constellation_centers_service.dart';
import '../services/constellation_lines_service.dart';
import '../utils/star_renderer.dart';
import '../utils/constellation_renderer.dart';
import '../utils/celestial_grid_renderer.dart';
import '../utils/constellation_centers_renderer.dart';
import '../utils/constellation_lines_renderer.dart';
import '../utils/twinkle_manager.dart';

/// A comprehensive night sky view with constellation visualization and user interaction
class SkyView extends StatefulWidget {
  final List<EnhancedConstellation> constellations;
  final Function(String)? onConstellationSelected;
  final Function(InsideViewController)? onControllerCreated;
  
  const SkyView({
    super.key,
    required this.constellations,
    this.onConstellationSelected,
    this.onControllerCreated,
  });
  
  @override
  State<SkyView> createState() => _SkyViewState();
}

class _SkyViewState extends State<SkyView> with SingleTickerProviderStateMixin {
  late InsideViewController _controller;
  late AnimationController _animationController;
  
  // Separate twinkling state from rotation
  double _twinklePhase = 0.0;
  
  String? _hoveredConstellation;
  String? _centerConstellation;
  
  // View settings
  bool _showStarNames = true;
  bool _showConstellationNames = true;
  bool _showConstellationLines = true;
  bool _showGrid = true;
  bool _showBackground = true;
  bool _showConstellationCenters = true;
  bool _showCustomLines = true;
  
  // To track visible constellations
  Map<String, ConstellationPositionInfo> _visibleConstellations = {};
  
  // Constellation centers data
  List<ConstellationCenter> _constellationCenters = [];
  bool _loadingCenters = true;
  
  // Constellation lines data
  Map<String, List<List<double>>> _constellationPolylines = {};
  bool _loadingLines = true;
  
  @override
  void initState() {
    super.initState();
    
    // Create the controller
    _controller = InsideViewController();
    
    // Slower auto-rotation
    _controller.setAutoRotateSpeed(0.01);
    
    // Notify parent
    if (widget.onControllerCreated != null) {
      widget.onControllerCreated!(_controller);
    }
    
    // Create animation controller for handling rotation updates
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    );
    
    _animationController.addListener(() {
      // Only handle rotation updates here
      _controller.updateAutoRotation();
      _updateCenterConstellation();
      
      // Force render refresh
      setState(() {});
    });
    
    _animationController.repeat();
    
    // Subscribe to the shared twinkle manager
    final twinkleManager = TwinkleManager();
    if (!twinkleManager.isRunning) {
      twinkleManager.start(
        updateInterval: const Duration(milliseconds: 100),
        increment: 0.003, // Subtle twinkling
      );
    }
    
    // Listen to phase updates
    twinkleManager.phaseStream.listen((phase) {
      setState(() {
        _twinklePhase = phase;
      });
    });
    
    // Load constellation centers and lines
    _loadConstellationData();
    
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
  
  // Load constellation centers and lines data
  Future<void> _loadConstellationData() async {
    try {
      // Load centers
      final centers = await ConstellationCentersService.loadConstellationCenters();
      
      setState(() {
        _constellationCenters = centers;
        _loadingCenters = false;
      });
    } catch (e) {
      print('Error loading constellation centers: $e');
      setState(() {
        _loadingCenters = false;
      });
    }
    
    try {
      // Load lines
      final polylines = await ConstellationLinesService.getPolylines();
      
      setState(() {
        _constellationPolylines = polylines;
        _loadingLines = false;
      });
    } catch (e) {
      print('Error loading constellation lines: $e');
      setState(() {
        _loadingLines = false;
      });
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  // Find the constellation at the center of view
  void _updateCenterConstellation() {
    String? centerName;
    double closestDistance = double.infinity;
    
    final viewDir = _controller.getViewDirection();
    
    for (var constellation in widget.constellations) {
      if (constellation.rightAscension == null || constellation.declination == null) {
        continue;
      }
      
      // Get constellation direction vector
      final direction = _controller.projection.celestialToDirection(
        constellation.rightAscension!,
        constellation.declination!
      );
      
      // Calculate angular distance between view direction and constellation
      final dotProduct = viewDir.x * direction.x +
                         viewDir.y * direction.y +
                         viewDir.z * direction.z;
                         
      // When vectors are aligned, dot product approaches 1
      // Convert to an angular distance (0 means perfectly aligned)
      final distance = acos(dotProduct.clamp(-1.0, 1.0));
      
      if (distance < closestDistance) {
        closestDistance = distance;
        centerName = constellation.name;
      }
    }
    
    // Only update if the constellation changed and is within a reasonable field of view
    if (centerName != _centerConstellation && closestDistance < 0.3) { // ~15 degrees
      setState(() {
        _centerConstellation = centerName;
      });
    } else if (closestDistance >= 0.3 && _centerConstellation != null) {
      setState(() {
        _centerConstellation = null;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main sky view with Listener for mouse wheel
        Listener(
          onPointerSignal: (PointerSignalEvent event) {
            // Handle mouse wheel events
            if (event is PointerScrollEvent) {
              // Calculate zoom factor based on scroll direction
              final scrollUp = event.scrollDelta.dy < 0;
              final zoomFactor = scrollUp ? 1.1 : 0.9; // 10% zoom in/out
              
              // Apply zoom
              _controller.zoom(zoomFactor);
              
              // Optional: Add haptic feedback for zoom
              HapticFeedback.lightImpact();
            }
          },
          child: GestureDetector(
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
            onTapUp: (details) {
              _handleTap(details.localPosition);
            },
            child: MouseRegion(
              onHover: (event) {
                _handleHover(event.localPosition);
              },
              onExit: (_) {
                setState(() {
                  _hoveredConstellation = null;
                });
              },
              child: CustomPaint(
                painter: SkyPainter(
                  constellations: widget.constellations,
                  controller: _controller,
                  twinklePhase: _twinklePhase,
                  constellationCenters: _constellationCenters,
                  constellationPolylines: _constellationPolylines,
                  showGrid: _showGrid,
                  showBackground: _showBackground,
                  showStarNames: _showStarNames,
                  showConstellationNames: _showConstellationNames,
                  showConstellationCenters: _showConstellationCenters,
                  showConstellationLines: _showConstellationLines,
                  showCustomLines: _showCustomLines,
                  hoveredConstellation: _hoveredConstellation,
                  centerConstellation: _centerConstellation,
                  onPositionsCalculated: (constellations) {
                    _visibleConstellations = constellations;
                  },
                  viewBoundsPadding: 5000, // Large value to avoid clipping
                ),
                size: Size.infinite,
              ),
            ),
          ),
        ),
        
        // Controls in the bottom corner
        Positioned(
          bottom: 20,
          left: 20,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blueGrey.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSettingCheckbox('Star Names', _showStarNames, (value) {
                  setState(() => _showStarNames = value!);
                }),
                _buildSettingCheckbox('Constellation Names', _showConstellationNames, (value) {
                  setState(() => _showConstellationNames = value!);
                }),
                _buildSettingCheckbox('Constellation Centers', _showConstellationCenters, (value) {
                  setState(() => _showConstellationCenters = value!);
                }),
                _buildSettingCheckbox('Built-in Lines', _showConstellationLines, (value) {
                  setState(() => _showConstellationLines = value!);
                }),
                _buildSettingCheckbox('Custom Lines', _showCustomLines, (value) {
                  setState(() => _showCustomLines = value!);
                }),
                _buildSettingCheckbox('Grid', _showGrid, (value) {
                  setState(() => _showGrid = value!);
                }),
                _buildSettingCheckbox('Background', _showBackground, (value) {
                  setState(() => _showBackground = value!);
                }),
                const SizedBox(height: 8),
                _buildRotationToggle(),
              ],
            ),
          ),
        ),
        
        // Constellation information display
        if (_hoveredConstellation != null || _centerConstellation != null)
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _hoveredConstellation != null 
                        ? Colors.blue.withOpacity(0.6) 
                        : Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _hoveredConstellation ?? _centerConstellation!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_getConstellationBySeason(_hoveredConstellation ?? _centerConstellation!) != null)
                      Text(
                        'Best viewed in ${_getConstellationBySeason(_hoveredConstellation ?? _centerConstellation!)}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          
        // Zoom instructions tooltip
        Positioned(
          bottom: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.mouse, color: Colors.white70, size: 16),
                SizedBox(width: 8),
                Text(
                  "Scroll to zoom",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Loading indicator for data
        if (_loadingCenters || _loadingLines)
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(
                    width: 16, 
                    height: 16, 
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    )
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Loading data...",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
  
  // Get the season for a constellation
  String? _getConstellationBySeason(String name) {
    for (var constellation in widget.constellations) {
      if (constellation.name == name) {
        return constellation.season;
      }
    }
    return null;
  }
  
  // Handle tap events to select constellations
  void _handleTap(Offset position) {
    // Check if we tapped on a constellation
    for (final entry in _visibleConstellations.entries) {
      for (final star in entry.value.stars) {
        // Calculate distance to the star
        final distance = (star.screenPosition - position).distance;
        
        // Check if tap is within star's radius
        if (distance < 20) { // Larger hit area for easier tapping
          if (widget.onConstellationSelected != null) {
            HapticFeedback.mediumImpact();
            widget.onConstellationSelected!(entry.key);
          }
          return;
        }
      }
    }
  }
  
  // Handle hover events to highlight constellations
  void _handleHover(Offset position) {
    String? hoveredConstellation;
    
    // Check if we're hovering over a constellation
    for (final entry in _visibleConstellations.entries) {
      for (final star in entry.value.stars) {
        // Calculate distance to the star
        final distance = (star.screenPosition - position).distance;
        
        // Check if hover is within star's radius
        if (distance < 20) { // Larger hit area for better hover detection
          hoveredConstellation = entry.key;
          break;
        }
      }
      
      if (hoveredConstellation != null) {
        break;
      }
    }
    
    // Update state if the hovered constellation changed
    if (hoveredConstellation != _hoveredConstellation) {
      setState(() {
        _hoveredConstellation = hoveredConstellation;
      });
    }
  }
  
  // Build a custom checkbox with label
  Widget _buildSettingCheckbox(String label, bool value, Function(bool?) onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            checkColor: Colors.black,
            fillColor: MaterialStateProperty.resolveWith<Color>(
              (Set<MaterialState> states) {
                if (states.contains(MaterialState.selected)) {
                  return Colors.lightBlue;
                }
                return Colors.grey.withOpacity(0.5);
              },
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }
  
  // Build the auto-rotation toggle button
  Widget _buildRotationToggle() {
    return GestureDetector(
      onTap: () {
        _controller.toggleAutoRotate();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _controller.autoRotate ? Colors.blue.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _controller.autoRotate ? Colors.blue : Colors.grey,
            width: 1,
          ),
        ),
        child: Text(
          _controller.autoRotate ? 'Stop Rotation' : 'Auto Rotate',
          style: TextStyle(
            color: _controller.autoRotate ? Colors.white : Colors.grey,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the night sky with constellation centers and lines
class SkyPainter extends CustomPainter {
  final List<EnhancedConstellation> constellations;
  final List<ConstellationCenter> constellationCenters;
  final Map<String, List<List<double>>> constellationPolylines;
  final InsideViewController controller;
  final double twinklePhase;
  final bool showGrid;
  final bool showBackground;
  final bool showStarNames;
  final bool showConstellationNames;
  final bool showConstellationCenters;
  final bool showConstellationLines;
  final bool showCustomLines;  // Flag for the new line data
  final String? hoveredConstellation;
  final String? centerConstellation;
  final Function(Map<String, ConstellationPositionInfo>)? onPositionsCalculated;
  final double viewBoundsPadding;
  
  SkyPainter({
    required this.constellations,
    required this.controller,
    required this.twinklePhase,
    this.constellationCenters = const [],
    this.constellationPolylines = const {},
    this.showGrid = true,
    this.showBackground = true,
    this.showStarNames = true,
    this.showConstellationNames = true,
    this.showConstellationCenters = true,
    this.showConstellationLines = true,
    this.showCustomLines = true,
    this.hoveredConstellation,
    this.centerConstellation,
    this.onPositionsCalculated,
    this.viewBoundsPadding = 0,
  }) : super(repaint: controller);
  
  @override
  void paint(Canvas canvas, Size size) {
    // First draw the background stars if enabled
    if (showBackground) {
      _drawBackgroundStars(canvas, size);
    }
    
    // Get our current view direction
    final viewDir = controller.getViewDirection();
    
    // Map to track visible constellations
    final Map<String, ConstellationPositionInfo> visibleConstellations = {};
    
    // Draw the custom constellation lines if enabled
    if (showCustomLines && constellationPolylines.isNotEmpty) {
      ConstellationLinesRenderer.drawConstellationLines(
        canvas,
        constellationPolylines,
        size,
        viewDir,
        controller.projection.celestialToDirection,
        controller.projection.projectToScreen,
        controller.projection.isPointVisible,
        lineColor: Colors.cyan.shade400,
        opacity: 0.6,
        strokeWidth: 1.2,
      );
    }
    
    // Draw the constellations
    for (final constellation in constellations) {
      if (constellation.rightAscension == null || constellation.declination == null) {
        continue;
      }
      
      // Check if this constellation is highlighted
      final bool isHighlighted = constellation.name == hoveredConstellation || 
                               constellation.name == centerConstellation;
      
      // Collect stars and their screen positions
      final List<StarPositionInfo> constellationStars = [];
      final Map<String, Offset> starPositions = {};
      
      // Process stars
      for (final star in constellation.stars) {
        // Convert to 3D direction
        final direction = controller.projection.celestialToDirection(
          star.rightAscension, 
          star.declination
        );
        
        // Check if it's in our field of view (with extended bounds)
        if (!controller.projection.isPointVisible(direction, viewDir)) {
          continue;
        }
        
        // Project to screen coordinates
        final screenPos = controller.projection.projectToScreen(
          direction, 
          size, 
          viewDir
        );
        
        // Use extended bounds for visibility
        if (screenPos.dx < -viewBoundsPadding || screenPos.dx > size.width + viewBoundsPadding ||
            screenPos.dy < -viewBoundsPadding || screenPos.dy > size.height + viewBoundsPadding) {
          continue;
        }
        
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
      }
      
      // Only process constellation if it has visible stars
      if (constellationStars.isNotEmpty) {
        visibleConstellations[constellation.name] = ConstellationPositionInfo(
          name: constellation.name,
          stars: constellationStars,
        );
        
        // Use the ConstellationRenderer to draw the entire constellation
        ConstellationRenderer.drawConstellation(
          canvas,
          constellation,
          starPositions,
          twinklePhase,
          size,
          drawLines: showConstellationLines,
          drawStarNames: showStarNames,
          drawConstellationName: showConstellationNames && isHighlighted,
          isHighlighted: isHighlighted,
          lineColor: isHighlighted ? Colors.lightBlue : Colors.blue,
        );
      }
    }
    
    // Draw constellation centers if enabled
    if (showConstellationCenters && constellationCenters.isNotEmpty) {
      ConstellationCentersRenderer.drawConstellationCenters(
        canvas,
        constellationCenters,
        size,
        viewDir,
        controller.projection.celestialToDirection,
        controller.projection.projectToScreen,
        controller.projection.isPointVisible,
        textColor: Colors.yellow,
        opacity: 0.8,
        fontSize: 16.0,
      );
    }
    
    // Draw the celestial grid if enabled
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
  
  /// Draw background stars using the utility function
  void _drawBackgroundStars(Canvas canvas, Size size) {
    // Implementation for drawing background stars
    final Random random = Random(42);
    final int starCount = (size.width * size.height / 2000).round().clamp(500, 3000);
    
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
      
      // Use the utility function to draw background stars with size scaled to screen
      StarRenderer.drawBackgroundStar(
        canvas,
        i, // Use index as identifier
        screenPos,
        random.nextDouble() * 1.0 + 0.3, // Random radius between 0.3-1.3 pixels
        random.nextDouble() * 0.5 + 0.2, // Random opacity between 0.2-0.7
        twinklePhase,
        size, // Pass screen size for proper scaling
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant SkyPainter oldDelegate) {
    return oldDelegate.controller != controller ||
           oldDelegate.twinklePhase != twinklePhase ||
           oldDelegate.showGrid != showGrid ||
           oldDelegate.showBackground != showBackground ||
           oldDelegate.showStarNames != showStarNames ||
           oldDelegate.showConstellationNames != showConstellationNames ||
           oldDelegate.showConstellationLines != showConstellationLines ||
           oldDelegate.showConstellationCenters != showConstellationCenters ||
           oldDelegate.showCustomLines != showCustomLines ||
           oldDelegate.hoveredConstellation != hoveredConstellation ||
           oldDelegate.centerConstellation != centerConstellation;
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