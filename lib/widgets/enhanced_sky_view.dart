import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/star_display_controller.dart';
import '../widgets/background_stars_view.dart';
import '../widgets/constellation_view.dart';

/// A sky view that combines background stars and constellation rendering
/// with improved component separation and reusability
class EnhancedSkyView extends StatefulWidget {
  final List<Map<String, dynamic>> constellations;
  final String currentConstellation;
  final bool showConstellationLines;
  final bool showConstellationStars;
  final bool showBackgroundStars;
  final bool showStarNames;
  final Function(Map<String, dynamic>)? onStarTapped;

  const EnhancedSkyView({
    Key? key,
    required this.constellations,
    required this.currentConstellation,
    this.showConstellationLines = true,
    this.showConstellationStars = true,
    this.showBackgroundStars = true,
    this.showStarNames = true,
    this.onStarTapped,
  }) : super(key: key);

  @override
  State<EnhancedSkyView> createState() => _EnhancedSkyViewState();
}

class _EnhancedSkyViewState extends State<EnhancedSkyView> with SingleTickerProviderStateMixin {
  late StarDisplayController _controller;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize the controller
    _controller = StarDisplayController(
      tickerProvider: this,
      showConstellationLines: widget.showConstellationLines,
      showConstellationStars: widget.showConstellationStars,
      showBackgroundStars: widget.showBackgroundStars,
      showStarNames: widget.showStarNames,
    );
    
    // Add listener for star tap events once during initialization
    _controller.addListener(_onControllerUpdate);
  }
  
  void _onControllerUpdate() {
    // Handle star selection changes
    if (_controller.selectedStar != null) {
      _handleStarTapped(_controller.selectedStar!);
    }
  }
  
  @override
  void didUpdateWidget(EnhancedSkyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update controller settings if props changed
    if (oldWidget.showConstellationLines != widget.showConstellationLines ||
        oldWidget.showConstellationStars != widget.showConstellationStars ||
        oldWidget.showBackgroundStars != widget.showBackgroundStars ||
        oldWidget.showStarNames != widget.showStarNames) {
      _controller.updateSettings(
        showConstellationLines: widget.showConstellationLines,
        showConstellationStars: widget.showConstellationStars,
        showBackgroundStars: widget.showBackgroundStars,
        showStarNames: widget.showStarNames,
      );
    }
  }
  
  @override
  void dispose() {
    // Remove listener before disposing
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }
  
  // Find the current constellation data
  Map<String, dynamic> _getCurrentConstellation() {
    return widget.constellations.firstWhere(
      (c) => c['name'] == widget.currentConstellation,
      orElse: () => <String, dynamic>{},
    );
  }
  
  // Handle star tap events from the controller
  void _handleStarTapped(Map<String, dynamic> starData) {
    HapticFeedback.lightImpact();
    
    if (widget.onStarTapped != null) {
      widget.onStarTapped!(starData);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get current constellation
    final currentConstellation = _getCurrentConstellation();
    
    return Stack(
      children: [
        // Background stars layer
        BackgroundStarsView(controller: _controller),
        
        // Constellation layer
        if (currentConstellation.isNotEmpty)
          ConstellationView(
            controller: _controller,
            constellation: currentConstellation,
          ),
      ],
    );
  }
}