// lib/widgets/celestial_sky_view.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../models/enhanced_constellation.dart';
import '../controllers/celestial_projection_controller.dart';
import '../painters/enhanced_star_painter.dart';

/// A widget that renders the sky with proper celestial coordinates
class CelestialSkyView extends StatefulWidget {
  final List<EnhancedConstellation> constellations;
  final String? currentConstellation;
  final bool showConstellationLines;
  final bool showStarNames;
  final bool showMagnitudes;
  final bool enable3DMode;
  final Function(Map<String, dynamic>)? onStarTapped;

  const CelestialSkyView({
    Key? key,
    required this.constellations,
    this.currentConstellation,
    this.showConstellationLines = true,
    this.showStarNames = true,
    this.showMagnitudes = false,
    this.enable3DMode = false,
    this.onStarTapped,
  }) : super(key: key);

  @override
  State<CelestialSkyView> createState() => _CelestialSkyViewState();
}

class _CelestialSkyViewState extends State<CelestialSkyView> with SingleTickerProviderStateMixin {
  late CelestialProjectionController _projectionController;
  late Ticker _ticker;
  double _twinklePhase = 0.0;
  
  // Touch handling
  Offset? _lastDragPosition;
  
  // Selected star
  CelestialStar? _selectedStar;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize the projection controller
    _projectionController = CelestialProjectionController(
      is3DMode: widget.enable3DMode,
    );
    
    // Center the view on the selected constellation if provided
    _centerOnSelectedConstellation();
    
    // Initialize the animation ticker for twinkling
    _ticker = createTicker((elapsed) {
      setState(() {
        _twinklePhase = elapsed.inMilliseconds / 5000 * pi;
        
        // Update auto-rotation if enabled
        _projectionController.updateAutoRotation();
      });
    });
    
    _ticker.start();
  }
  
  @override
  void didUpdateWidget(CelestialSkyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update 3D mode if it changed
    if (oldWidget.enable3DMode != widget.enable3DMode) {
      _projectionController.setProjectionMode(widget.enable3DMode);
    }
    
    // Re-center if the constellation changed
    if (oldWidget.currentConstellation != widget.currentConstellation) {
      _centerOnSelectedConstellation();
    }
  }
  
  void _centerOnSelectedConstellation() {
    if (widget.currentConstellation != null && widget.constellations.isNotEmpty) {
      final constellation = widget.constellations.firstWhere(
        (c) => c.name == widget.currentConstellation,
        orElse: () => widget.constellations.first,
      );
      
      if (constellation.rightAscension != null && constellation.declination != null) {
        _projectionController.setViewCenter(
          constellation.rightAscension!,
          constellation.declination!
        );
      }
    }
  }
  
  @override
  void dispose() {
    _ticker.dispose();
    _projectionController.dispose();
    super.dispose();
  }
  
  // Find the constellation to be displayed
  EnhancedConstellation _getConstellationToShow() {
    if (widget.currentConstellation != null) {
      return widget.constellations.firstWhere(
        (c) => c.name == widget.currentConstellation,
        orElse: () => widget.constellations.first
      );
    }
    return widget.constellations.first;
  }
  
  // Handle star tap/selection
  void _handleStarTap(Offset position, Size size) {
    // Find which constellation we're currently showing
    final constellation = _getConstellationToShow();
    
    // Get the current projection
    final projection = _projectionController.projection;
    
    // Check each star to see if it was tapped
    CelestialStar? tappedStar;
    double closestDistance = 25.0; // Tap threshold in pixels
    
    for (var star in constellation.stars) {
      Offset starPosition;
      
      if (_projectionController.is3DMode) {
        final point3d = projection.celestialTo3D(
          star.rightAscension, 
          star.declination
        );
        
        // Skip stars behind the viewer
        if (point3d.z < 0) continue;
        
        starPosition = projection.project3DToScreen(point3d, size);
      } else {
        starPosition = projection.celestialToScreenStereographic(
          star.rightAscension, 
          star.declination, 
          size
        );
        
        // Skip stars outside view
        if (starPosition.dx < -100 || starPosition.dx > size.width + 100 ||
            starPosition.dy < -100 || starPosition.dy > size.height + 100) {
          continue;
        }
      }
      
      // Calculate distance to tap
      final distance = (starPosition - position).distance;
      
      // Check if this is the closest star tapped
      if (distance < closestDistance) {
        closestDistance = distance;
        tappedStar = star;
      }
    }
    
    // Update selection
    setState(() {
      _selectedStar = tappedStar;
    });
    
    // Notify parent if a star was tapped
    if (tappedStar != null && widget.onStarTapped != null) {
      HapticFeedback.lightImpact();
      widget.onStarTapped!(tappedStar.toMap());
    }
  }
  
  // Clear selection on tap outside stars
  void _handleTapOutside() {
    if (_selectedStar != null) {
      setState(() {
        _selectedStar = null;
      });
    }
  }
  
  
  @override
  Widget build(BuildContext context) {
    // Determine which constellation to show
    final constellation = _getConstellationToShow();
    
    return GestureDetector(
      onTapDown: (details) => _handleStarTap(details.localPosition, context.size ?? Size.zero),
      onTap: _handleTapOutside,
      onScaleStart: (details) {
        _lastDragPosition = details.focalPoint;
      },
      onScaleUpdate: (details) {
        // Handle combined drag and scale
        if (_lastDragPosition != null) {
          final Offset delta = details.focalPoint - _lastDragPosition!;
          
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
          final Size size = constraints.biggest;
          
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
              
              // Stars
              CustomPaint(
                painter: EnhancedStarPainter(
                  constellation: constellation,
                  projectionController: _projectionController,
                  showConstellationLines: widget.showConstellationLines,
                  showStarNames: widget.showStarNames,
                  showMagnitudes: widget.showMagnitudes,
                  twinklePhase: _twinklePhase,
                ),
                size: Size.infinite,
              ),
              
              // Mode indicator (3D/2D)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _projectionController.is3DMode ? "3D" : "2D",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              // Selected star information card
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
                          if (_selectedStar!.spectralType != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                'Spectral Type: ${_selectedStar!.spectralType}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          if (_selectedStar!.distance != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                'Distance: ${_selectedStar!.distance!.toStringAsFixed(1)} light years',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            'RA: ${_selectedStar!.rightAscension.toStringAsFixed(2)}°, Dec: ${_selectedStar!.declination.toStringAsFixed(2)}°',
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
          );
        },
      ),
    );
  }
}