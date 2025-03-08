// lib/utils/twinkle_manager.dart
import 'dart:async';
import 'dart:math';

/// Manager for consistent star twinkling across the application
class TwinkleManager {
  /// Singleton instance
  static final TwinkleManager _instance = TwinkleManager._internal();
  
  /// Current twinkle phase value (0 to 2π)
  double _twinklePhase = 0.0;
  
  /// Timer for updating the twinkle phase
  Timer? _timer;
  
  /// Stream controller for broadcasting updates
  final StreamController<double> _phaseController = StreamController<double>.broadcast();
  
  /// Get the stream of phase updates
  Stream<double> get phaseStream => _phaseController.stream;
  
  /// Get the current phase value
  double get currentPhase => _twinklePhase;
  
  /// Whether the manager is currently running
  bool get isRunning => _timer != null && _timer!.isActive;
  
  /// Factory constructor to return the singleton instance
  factory TwinkleManager() {
    return _instance;
  }
  
  /// Private constructor for singleton
  TwinkleManager._internal();
  
  /// Start the twinkling animation
  void start({
    Duration updateInterval = const Duration(milliseconds: 500),
    double increment = 0.003,
  }) {
    // Cancel any existing timer
    _timer?.cancel();
    
    // Start a new timer
    _timer = Timer.periodic(updateInterval, (timer) {
      // Update the phase
      _twinklePhase += increment;
      if (_twinklePhase > 2 * pi) {
        _twinklePhase -= 2 * pi;
      }
      
      // Broadcast the update
      _phaseController.add(_twinklePhase);
    });
  }
  
  /// Stop the twinkling animation
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
  
  /// Change the update speed
  void setSpeed({
    Duration? updateInterval,
    double? increment,
  }) {
    if (_timer == null) return;
    
    // Only restart if we're changing the interval
    if (updateInterval != null) {
      stop();
      start(
        updateInterval: updateInterval,
        increment: increment ?? 0.003,
      );
    } else if (increment != null) {
      // Just update the increment value if only that changed
      stop();
      start(increment: increment);
    }
  }
  
  /// Clean up resources
  void dispose() {
    stop();
    _phaseController.close();
  }
}