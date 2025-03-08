// lib/widgets/improved_night_sky_view.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/enhanced_constellation.dart';
import '../controllers/inside_view_controller.dart';
import '../utils/celestial_projections_inside.dart';
import 'inside_sky_view.dart';

/// An improved night sky view with better view bounds, 
/// constellation highlighting, and display controls
class ImprovedNightSkyView extends StatefulWidget {
  final List<EnhancedConstellation> constellations;
  final Function(String)? onConstellationSelected;
  final Function(InsideViewController)? onControllerCreated;
  
  const ImprovedNightSkyView({
    Key? key,
    required this.constellations,
    this.onConstellationSelected,
    this.onControllerCreated,
  }) : super(key: key);
  
  @override
  State<ImprovedNightSkyView> createState() => _ImprovedNightSkyViewState();
}

class _ImprovedNightSkyViewState extends State<ImprovedNightSkyView> with SingleTickerProviderStateMixin {
  late InsideViewController _controller;
  late AnimationController _animationController;
  double _twinklePhase = 0.0;
  String? _hoveredConstellation;
  String? _centerConstellation;
  
  // View settings
  bool _showNames = true;
  bool _showLines = true;
  bool _showGrid = true;
  bool _showBackground = true;
  
  // To track visible constellations
  Map<String, ConstellationPositionInfo> _visibleConstellations = {};
  
  @override
  void initState() {
    super.initState();
    
    // Create the controller
    _controller = InsideViewController();
    
    // Significantly slow down the auto-rotation
    _updateRotationSpeed(0.01); // Reduced from default (usually 0.5)
    
    // Notify parent
    if (widget.onControllerCreated != null) {
      widget.onControllerCreated!(_controller);
    }
    
    // Create animation controller for effects
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    );
    
    _animationController.addListener(() {
      setState(() {
        _twinklePhase = _animationController.value * 2 * pi;
      });
      
      // Update auto-rotation
      _controller.updateAutoRotation();
      
      // Check which constellation is at the center
      _updateCenterConstellation();
    });
    
    _animationController.repeat();
    
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
    _animationController.dispose();
    super.dispose();
  }
  
  // Update the rotation speed
  void _updateRotationSpeed(double speed) {
    // Use the public setter method
    _controller.setAutoRotateSpeed(speed);
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
        // Main sky view
        GestureDetector(
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
              painter: ImprovedSkyPainter(
                constellations: widget.constellations,
                controller: _controller,
                twinklePhase: _twinklePhase,
                showGrid: _showGrid,
                showBackground: _showBackground,
                showNames: _showNames,
                showLines: _showLines,
                hoveredConstellation: _hoveredConstellation,
                centerConstellation: _centerConstellation,
                onPositionsCalculated: (constellations) {
                  _visibleConstellations = constellations;
                },
                // Extend the view bounds significantly 
                viewBoundsPadding: 5000, // Large value to avoid clipping
              ),
              size: Size.infinite,
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
                _buildSettingCheckbox('Names', _showNames, (value) {
                  setState(() => _showNames = value!);
                }),
                _buildSettingCheckbox('Lines', _showLines, (value) {
                  setState(() => _showLines = value!);
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

/// Custom painter for the night sky with improved view bounds
class ImprovedSkyPainter extends CustomPainter {
  final List<EnhancedConstellation> constellations;
  final InsideViewController controller;
  final double twinklePhase;
  final bool showGrid;
  final bool showBackground;
  final bool showNames;
  final bool showLines;
  final String? hoveredConstellation;
  final String? centerConstellation;
  final Function(Map<String, ConstellationPositionInfo>)? onPositionsCalculated;
  final double viewBoundsPadding;
  
  ImprovedSkyPainter({
    required this.constellations,
    required this.controller,
    this.twinklePhase = 0.0,
    this.showGrid = true,
    this.showBackground = true,
    this.showNames = true,
    this.showLines = true,
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
        
        // Use extended bounds for visibility - allows stars to be visible even if they're off-screen
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
        
        // Draw constellation lines if enabled
        if (showLines) {
          _drawConstellationLines(canvas, constellation.lines, starPositions, isHighlighted);
        }
        
        // Draw stars
        for (final star in constellation.stars) {
          if (starPositions.containsKey(star.id)) {
            _drawStar(canvas, star, starPositions[star.id]!, isHighlighted);
          }
        }
        
        // Draw constellation name if this is the highlighted constellation
        if (isHighlighted && showNames) {
          _drawConstellationName(canvas, constellation, constellationStars);
        }
      }
    }
    
    // Draw the celestial grid if enabled
    if (showGrid) {
      _drawCelestialGrid(canvas, size, viewDir);
    }
    
    // Notify about calculated positions
    if (onPositionsCalculated != null) {
      onPositionsCalculated!(visibleConstellations);
    }
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
  bool shouldRepaint(covariant ImprovedSkyPainter oldDelegate) {
    return oldDelegate.controller != controller ||
           oldDelegate.twinklePhase != twinklePhase ||
           oldDelegate.showGrid != showGrid ||
           oldDelegate.showBackground != showBackground ||
           oldDelegate.showNames != showNames ||
           oldDelegate.showLines != showLines ||
           oldDelegate.hoveredConstellation != hoveredConstellation ||
           oldDelegate.centerConstellation != centerConstellation;
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
  
  /// Draw constellation lines
  void _drawConstellationLines(
    Canvas canvas, 
    List<List<String>> lines, 
    Map<String, Offset> starPositions,
    bool isHighlighted
  ) {
    final Paint linePaint = Paint()
      ..color = isHighlighted 
          ? Colors.lightBlue.withOpacity(0.8) 
          : Colors.blue.withOpacity(0.4)
      ..strokeWidth = isHighlighted ? 2.0 : 1.0
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
  
  /// Draw a single star
  void _drawStar(Canvas canvas, CelestialStar star, Offset position, bool isHighlighted) {
    // Calculate star size based on magnitude
    final double sizeMultiplier = isHighlighted ? 1.5 : 1.0;
    final double baseSize = max(2.5, 8.0 - star.magnitude * 0.8);
    final double size = baseSize * sizeMultiplier;
    
    // Apply twinkling effect
    final double starSeed = position.dx * position.dy;
    final double twinkleSpeed = 0.5 + (sin(starSeed) + 1) * 0.5;
    final double twinkleFactor = max(0, sin((twinklePhase * twinkleSpeed) % (2 * pi)));
    
    // Get star color based on spectral type
    final Color starColor = _getStarColor(star.spectralType);
    final Color highlightedColor = isHighlighted 
        ? _adjustColorBrightness(starColor, 0.3) 
        : starColor;
    
    // Make color slightly brighter during twinkle
    final Color twinkleColor = _adjustColorBrightness(highlightedColor, twinkleFactor * 0.15);
    
    // Draw star glow
    final Paint glowPaint = Paint()
      ..color = twinkleColor.withOpacity(0.3 + twinkleFactor * 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    
    canvas.drawCircle(position, size * 1.8, glowPaint);
    
    // Draw star core
    final Paint starPaint = Paint()
      ..color = twinkleColor
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(position, size, starPaint);
    
    // Draw star name if enabled and this is a bright star
    if (showNames && star.magnitude < 2.5) {
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: star.name,
          style: TextStyle(
            color: Colors.white.withOpacity(isHighlighted ? 0.9 : 0.7),
            fontSize: isHighlighted ? 14.0 : 12.0,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
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
        position.dx + size + 4,
        position.dy - textPainter.height / 2,
      ));
    }
  }
  
  /// Draw the constellation name at a good position
  void _drawConstellationName(
    Canvas canvas, 
    EnhancedConstellation constellation,
    List<StarPositionInfo> stars
  ) {
    if (stars.isEmpty) return;
    
    // Find the center position of the visible stars
    double sumX = 0, sumY = 0;
    for (final star in stars) {
      sumX += star.screenPosition.dx;
      sumY += star.screenPosition.dy;
    }
    
    final Offset center = Offset(sumX / stars.length, sumY / stars.length);
    
    // Draw constellation name
    final TextPainter nameTextPainter = TextPainter(
      text: TextSpan(
        text: constellation.name,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18.0,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              blurRadius: 3.0,
              color: Colors.black,
              offset: Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    nameTextPainter.layout();
    nameTextPainter.paint(canvas, Offset(
      center.dx - nameTextPainter.width / 2,
      center.dy - nameTextPainter.height / 2 - 30,
    ));
    
    // Draw constellation abbreviation if available
    if (constellation.abbreviation != null) {
      final TextPainter abbrTextPainter = TextPainter(
        text: TextSpan(
          text: '(${constellation.abbreviation})',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14.0,
            shadows: [
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
      
      abbrTextPainter.layout();
      abbrTextPainter.paint(canvas, Offset(
        center.dx - abbrTextPainter.width / 2,
        center.dy - abbrTextPainter.height / 2 + 3,
      ));
    }
  }
  
  /// Draw the celestial grid
  void _drawCelestialGrid(Canvas canvas, Size size, Vector3D viewDir) {
    final Paint gridPaint = Paint()
      ..color = Colors.lightBlue.withOpacity(0.15)
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
        
        // Check if it's in our field of view with extended bounds
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
        
        // Use extended bounds for grid lines too
        if (screenPos.dx < -viewBoundsPadding || screenPos.dx > size.width + viewBoundsPadding ||
            screenPos.dy < -viewBoundsPadding || screenPos.dy > size.height + viewBoundsPadding) {
          if (points.isNotEmpty) {
            _drawLines(canvas, points, gridPaint);
            points.clear();
          }
          continue;
        }
        
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
        
        // Check if it's in our field of view with extended bounds
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
        
        // Use extended bounds for grid lines
        if (screenPos.dx < -viewBoundsPadding || screenPos.dx > size.width + viewBoundsPadding ||
            screenPos.dy < -viewBoundsPadding || screenPos.dy > size.height + viewBoundsPadding) {
          if (points.isNotEmpty) {
            _drawLines(canvas, points, gridPaint);
            points.clear();
          }
          continue;
        }
        
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
  }}