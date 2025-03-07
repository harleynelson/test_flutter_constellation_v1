import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vector_math/vector_math.dart' as vm;
import '../models/celestial_camera.dart';
import '../models/celestial_coordinate.dart';

/// Controller for managing the celestial sphere view
class CelestialSphereController extends ChangeNotifier {
  // Camera model
  final CelestialCamera camera = CelestialCamera();
  
  // Animation-related properties
  late Ticker _ticker;
  final TickerProvider _tickerProvider;
  bool _isDisposed = false;
  double _twinklePhase = 0.0;
  
  // Star selection properties
  Offset? _tapPosition;
  Map<String, dynamic>? _selectedStar;
  
  // Interaction properties
  Offset? _lastPanPosition;
  double _zoomLevel = 1.0; // Field of view adjustment
  
  // Configuration
  bool showConstellationLines;
  bool showConstellationStars;
  bool showBackgroundStars;
  bool showStarNames;
  bool showCelestialGrid;
  
  // Raw constellation data
  List<Map<String, dynamic>> constellationData = [];
  
  // Transformed constellation data with 3D coordinates
  Map<String, dynamic> _processedConstellations = {};
  
  // Getters
  double get twinklePhase => _twinklePhase;
  Offset? get tapPosition => _tapPosition;
  Map<String, dynamic>? get selectedStar => _selectedStar;
  double get zoomLevel => _zoomLevel;
  bool get showGrid => showCelestialGrid;
  Map<String, dynamic> get processedConstellations => _processedConstellations;
  
  CelestialSphereController({
    required TickerProvider tickerProvider,
    required List<Map<String, dynamic>> constellations,
    this.showConstellationLines = true,
    this.showConstellationStars = true,
    this.showBackgroundStars = true,
    this.showStarNames = true,
    this.showCelestialGrid = false,
  }) : _tickerProvider = tickerProvider {
    constellationData = constellations;
    _processConstellationData();
    _initTicker();
  }
  
  void _initTicker() {
    _ticker = _tickerProvider.createTicker((elapsed) {
      // Update the twinkle phase based on elapsed time
      // Complete cycle every 5 seconds for natural twinkling
      _twinklePhase = elapsed.inMilliseconds / 5000 * pi;
      notifyListeners();
    });
    
    // Start the animation
    _ticker.start();
  }
  
  /// Process the constellation data to add 3D coordinates
  void _processConstellationData() {
    _processedConstellations = {};
    
    for (var constellation in constellationData) {
      final String name = constellation['name'] as String;
      final String description = constellation['description'] as String;
      final List<dynamic> starsData = constellation['stars'] as List<dynamic>;
      final List<dynamic> linesData = constellation['lines'] as List<dynamic>;
      
      // Transform each star to include celestial coordinates
      final List<Map<String, dynamic>> transformedStars = [];
      
      for (var star in starsData) {
        final Map<String, dynamic> starData = {...star as Map<String, dynamic>};
        
        // Convert normalized x,y to celestial coordinates
        final double x = starData['x'] as double;
        final double y = starData['y'] as double;
        final celestialCoord = CelestialCoordinate.fromNormalizedXY(x, y);
        
        // Add celestial coordinates and 3D position
        starData['rightAscension'] = celestialCoord.rightAscension;
        starData['declination'] = celestialCoord.declination;
        final vector3 = celestialCoord.toCartesian();
        starData['vector3'] = {
          'x': vector3.x,
          'y': vector3.y,
          'z': vector3.z,
        };
        
        transformedStars.add(starData);
      }
      
      // Create processed constellation data
      _processedConstellations[name] = {
        'name': name,
        'description': description,
        'stars': transformedStars,
        'lines': linesData,
      };
    }
  }
  
  /// Handle tap down event
  void handleTapDown(TapDownDetails details) {
    _tapPosition = details.localPosition;
    notifyListeners();
  }
  
  /// Handle pan start event
  void handlePanStart(DragStartDetails details) {
    _lastPanPosition = details.localPosition;
  }
  
  /// Handle pan update event - rotate the view
  void handlePanUpdate(DragUpdateDetails details) {
    if (_lastPanPosition == null) return;
    
    // Calculate deltas
    final double dx = details.localPosition.dx - _lastPanPosition!.dx;
    final double dy = details.localPosition.dy - _lastPanPosition!.dy;
    
    // Scale the rotation based on screen size and zoom level
    final double rotationSensitivity = 0.005 * _zoomLevel;
    final double horizontalRotation = -dx * rotationSensitivity;
    final double verticalRotation = -dy * rotationSensitivity;
    
    // Apply rotation to camera
    camera.rotate(horizontalRotation, verticalRotation);
    
    // Update last position
    _lastPanPosition = details.localPosition;
    
    // Notify listeners of the change
    notifyListeners();
  }
  
  /// Handle zoom (scale) gestures
  void handleZoom(double scaleFactor) {
    // Apply zoom
    _zoomLevel *= scaleFactor;
    
    // Constrain zoom level
    _zoomLevel = _zoomLevel.clamp(0.5, 10.0);
    
    // Update field of view based on zoom level
    camera.fieldOfView = pi / 3 / _zoomLevel;
    
    notifyListeners();
  }
  
  /// Reset the view to default position
  void resetView() {
    // Look at RA=0, Dec=0 (celestial origin)
    camera.lookAt(const CelestialCoordinate(rightAscension: 6, declination: 20));
    _zoomLevel = 1.0;
    camera.fieldOfView = pi / 3;
    notifyListeners();
  }
  
  /// Handle star selection
  void handleStarTapped(Map<String, dynamic> starData) {
    _tapPosition = null;
    _selectedStar = starData;
    notifyListeners();
  }
  
  /// Clear the current selection
  void clearSelection() {
    if (_selectedStar != null) {
      _selectedStar = null;
      notifyListeners();
    }
  }
  
  /// Look at a specific constellation
  void lookAtConstellation(String constellationName) {
    final constellation = _processedConstellations[constellationName];
    if (constellation == null) return;
    
    // Calculate the center position of the constellation
    final List<Map<String, dynamic>> stars = 
        (constellation['stars'] as List<dynamic>).cast<Map<String, dynamic>>();
    
    if (stars.isEmpty) return;
    
    // Average RA and Dec
    double totalRA = 0;
    double totalDec = 0;
    
    for (var star in stars) {
      totalRA += star['rightAscension'] as double;
      totalDec += star['declination'] as double;
    }
    
    final avgRA = totalRA / stars.length;
    final avgDec = totalDec / stars.length;
    
    // Look at the constellation's center
    camera.lookAt(CelestialCoordinate(rightAscension: avgRA, declination: avgDec));
    
    // Set an appropriate zoom level based on constellation size
    _calculateOptimalZoom(stars);
    
    notifyListeners();
  }
  
  /// Calculate optimal zoom level for the constellation
  void _calculateOptimalZoom(List<Map<String, dynamic>> stars) {
    if (stars.length < 2) {
      _zoomLevel = 1.0;
      camera.fieldOfView = pi / 3;
      return;
    }
    
    // Find the angular size of the constellation
    double maxAngularDistance = 0;
    
    // Get the center point
    final center = camera.lookDirection;
    
    // Check angular distance from center to each star
    for (var star in stars) {
      final Map<String, dynamic> vector = star['vector3'] as Map<String, dynamic>;
      final vm.Vector3 starVector = vm.Vector3(
        vector['x'] as double,
        vector['y'] as double,
        vector['z'] as double,
      );
      
      final double angularDistance = acos(center.dot(starVector).clamp(-1.0, 1.0));
      maxAngularDistance = max(maxAngularDistance, angularDistance);
    }
    
    // Add margin
    maxAngularDistance *= 1.5;
    
    // Ensure it's not too small
    maxAngularDistance = max(maxAngularDistance, pi / 12);
    
    // Set field of view to encompass the constellation
    camera.fieldOfView = min(pi / 2, maxAngularDistance * 2);
    
    // Update zoom level based on field of view
    _zoomLevel = (pi / 3) / camera.fieldOfView;
  }
  
  /// Convert a star's 3D position to screen coordinates
  Offset? starToScreenCoordinates(Map<String, dynamic> star, Size screenSize) {
    final Map<String, dynamic> vector = star['vector3'] as Map<String, dynamic>;
    final vm.Vector3 position = vm.Vector3(
      vector['x'] as double,
      vector['y'] as double,
      vector['z'] as double,
    );
    
    return camera.projectToScreen(position, screenSize);
  }
  
  /// Update controller settings
  void updateSettings({
    bool? showConstellationLines,
    bool? showConstellationStars,
    bool? showBackgroundStars,
    bool? showStarNames,
    bool? showCelestialGrid,
  }) {
    bool changed = false;
    
    if (showConstellationLines != null && this.showConstellationLines != showConstellationLines) {
      this.showConstellationLines = showConstellationLines;
      changed = true;
    }
    
    if (showConstellationStars != null && this.showConstellationStars != showConstellationStars) {
      this.showConstellationStars = showConstellationStars;
      changed = true;
    }
    
    if (showBackgroundStars != null && this.showBackgroundStars != showBackgroundStars) {
      this.showBackgroundStars = showBackgroundStars;
      changed = true;
    }
    
    if (showStarNames != null && this.showStarNames != showStarNames) {
      this.showStarNames = showStarNames;
      changed = true;
    }
    
    if (showCelestialGrid != null && this.showCelestialGrid != showCelestialGrid) {
      this.showCelestialGrid = showCelestialGrid;
      changed = true;
    }
    
    if (changed) {
      notifyListeners();
    }
  }
  
  @override
  void dispose() {
    if (!_isDisposed) {
      _ticker.dispose();
      _isDisposed = true;
      super.dispose();
    }
  }
  
  /// Calculate star color based on magnitude
  Color calculateStarColor(double magnitude) {
    // Brighter stars tend to be slightly blue-white
    // Dimmer stars tend to be slightly yellow-red
    if (magnitude < 1.0) {
      return Colors.white;
    } else if (magnitude < 2.0) {
      return const Color(0xFFF0F8FF); // Slightly blue-white (AliceBlue)
    } else if (magnitude < 3.0) {
      return const Color(0xFFF5F5DC); // Slightly yellow (Beige)
    } else {
      return const Color(0xFFFFE4B5); // Slightly orange (Moccasin)
    }
  }
  
  /// Calculate star radius based on magnitude
  double calculateStarRadius(double magnitude) {
    // Magnitude scale is reversed: lower numbers are brighter
    return 8 - min(5, max(0, magnitude - 1));
  }
}