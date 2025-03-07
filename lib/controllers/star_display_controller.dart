import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Controls the display and animation of stars in the night sky
class StarDisplayController extends ChangeNotifier {
  // Animation-related properties
  late Ticker _ticker;
  double _twinklePhase = 0.0;
  final TickerProvider _tickerProvider;
  bool _isDisposed = false;
  
  // Background stars cache
  static List<BackgroundStar>? _backgroundStarsCache;
  static Size? _lastSize;
  
  // Star selection properties
  Offset? _tapPosition;
  Map<String, dynamic>? _selectedStar;
  
  // Configuration
  bool showConstellationLines;
  bool showConstellationStars;
  bool showBackgroundStars;
  bool showStarNames;
  
  double get twinklePhase => _twinklePhase;
  Offset? get tapPosition => _tapPosition;
  Map<String, dynamic>? get selectedStar => _selectedStar;
  
  StarDisplayController({
    required TickerProvider tickerProvider,
    this.showConstellationLines = true,
    this.showConstellationStars = true,
    this.showBackgroundStars = true,
    this.showStarNames = true,
  }) : _tickerProvider = tickerProvider {
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
  
  void handleTap(TapDownDetails details) {
    _tapPosition = details.localPosition;
    notifyListeners();
  }
  
  void handleStarTapped(Map<String, dynamic> starData) {
    _tapPosition = null;
    _selectedStar = starData;
    notifyListeners();
  }
  
  void clearSelection() {
    if (_selectedStar != null) {
      _selectedStar = null;
      notifyListeners();
    }
  }
  
  List<BackgroundStar> getBackgroundStars(Size size) {
    // Generate background stars only if they haven't been generated yet or if size changed
    if (_backgroundStarsCache == null || _lastSize != size) {
      _lastSize = size;
      _backgroundStarsCache = [];
      
      // Create more stars for larger screens
      final int starCount = (size.width * size.height / 2000).round().clamp(200, 1000);
      final Random random = Random(42); // Fixed seed for consistent background
      
      for (int i = 0; i < starCount; i++) {
        _backgroundStarsCache!.add(BackgroundStar(
          x: random.nextDouble() * size.width,
          y: random.nextDouble() * size.height,
          radius: random.nextDouble() * 1.0 + 0.5, // Random size (0.5-1.5)
          baseOpacity: random.nextDouble() * 0.5 + 0.2, // Random opacity (0.2-0.7)
          twinkleSpeed: random.nextDouble() * 3.0 + 1.0, // Random speed (1.0-4.0)
        ));
      }
    }
    
    return _backgroundStarsCache!;
  }
  
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
  
  double calculateStarRadius(double magnitude) {
    // Magnitude scale is reversed: lower numbers are brighter
    return 8 - min(5, max(0, magnitude - 1));
  }
  
  void updateSettings({
    bool? showConstellationLines,
    bool? showConstellationStars,
    bool? showBackgroundStars,
    bool? showStarNames,
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
}

/// Represents a background star with twinkling properties
class BackgroundStar {
  final double x;
  final double y;
  final double radius;
  final double baseOpacity;
  final double twinkleSpeed;
  
  BackgroundStar({
    required this.x,
    required this.y,
    required this.radius,
    required this.baseOpacity,
    required this.twinkleSpeed,
  });
}