// lib/widgets/sky_view_consolidated.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/celestial_data.dart';
import '../controllers/sky_view_controller.dart';
import '../painters/sky_painter.dart';
import '../utils/color_utils.dart';

/// A consolidated, streamlined view of the night sky showing constellations
/// A consolidated night sky viewer that displays stars and constellations
/// from the perspective of being inside the celestial sphere looking outward.
/// This simulates the natural view of the night sky as seen from Earth.
class SkyViewConsolidated extends StatefulWidget {
  final CelestialData data;
  final Function(String constellationName)? onConstellationSelected;
  
  const SkyViewConsolidated({
    super.key,
    required this.data,
    this.onConstellationSelected,
  });

  @override
  State<SkyViewConsolidated> createState() => _SkyViewConsolidatedState();
}

class _SkyViewConsolidatedState extends State<SkyViewConsolidated> with SingleTickerProviderStateMixin {
  late SkyViewController _controller;
  String? _hoveredConstellation;
  String? _selectedConstellation;
  
  // View settings
  bool _showStarNames = false;
  bool _showConstellationLines = true;
  bool _showConstellationBoundaries = false;
  bool _showGrid = false;
  bool _showAutoRotate = true;
  bool _showBrightStarsOnly = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize controller
    _controller = SkyViewController(tickerProvider: this);
    
    // Set default viewing position (can be based on current time/date)
    _controller.setToCurrentDatePosition();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
          onTapUp: _handleTap,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: SkyPainter(
                  data: widget.data,
                  controller: _controller,
                  showStarNames: _showStarNames,
                  showConstellationLines: _showConstellationLines,
                  showConstellationBoundaries: _showConstellationBoundaries,
                  showGrid: _showGrid,
                  brightStarsOnly: _showBrightStarsOnly,
                  hoveredConstellation: _hoveredConstellation,
                  selectedConstellation: _selectedConstellation,
                ),
                size: Size.infinite,
              );
            },
          ),
        ),
        
        // Direction indicator (North, South, etc.)
        Positioned(
          top: 16,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _getDirectionText(_controller.heading),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        
        // Controls panel
        Positioned(
          bottom: 20,
          left: 16,
          child: _buildControlPanel(),
        ),
        
        // Zoom indicator
        Positioned(
          bottom: 20,
          right: 16,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.zoom_in, color: Colors.white70, size: 16),
                    Slider(
                      value: _controller.fieldOfView,
                      min: 30.0,
                      max: 120.0,
                      divisions: 9,
                      onChanged: (value) {
                        setState(() {
                          _controller.zoom(90.0 / value);
                        });
                      },
                      activeColor: Colors.blue,
                      inactiveColor: Colors.blue.withOpacity(0.3),
                    ),
                    const Icon(Icons.zoom_out, color: Colors.white70, size: 16),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  void _handleTap(TapUpDetails details) {
    final constellation = _controller.getConstellationAt(details.localPosition, widget.data);
    if (constellation != null) {
      setState(() {
        _selectedConstellation = constellation;
      });
      
      if (widget.onConstellationSelected != null) {
        widget.onConstellationSelected!(constellation);
      }
    } else {
      setState(() {
        _selectedConstellation = null;
      });
    }
  }
  
  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Auto-rotate toggle
          _buildToggleButton("Auto-Rotate", _showAutoRotate, (value) {
            setState(() => _showAutoRotate = value);
            _controller.setAutoRotate(value);
          }),
          
          // Visualization controls
          const SizedBox(height: 8),
          const Text(
            "Display",
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIconToggle(
                Icons.star_border, 
                "Stars", 
                !_showBrightStarsOnly, 
                (value) => setState(() => _showBrightStarsOnly = !value)
              ),
              _buildIconToggle(
                Icons.polyline, 
                "Lines", 
                _showConstellationLines, 
                (value) => setState(() => _showConstellationLines = value)
              ),
              _buildIconToggle(
                Icons.grid_4x4, 
                "Grid", 
                _showGrid, 
                (value) => setState(() => _showGrid = value)
              ),
              _buildIconToggle(
                Icons.text_fields, 
                "Names", 
                _showStarNames, 
                (value) => setState(() => _showStarNames = value)
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          _buildResetButton(),
        ],
      ),
    );
  }
  
  // Convert heading to compass direction
  String _getDirectionText(double heading) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((heading + 22.5) % 360 / 45).floor();
    return "Looking ${directions[index]}";
  }
  
  // Build an icon toggle button
  Widget _buildIconToggle(IconData icon, String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: value ? Colors.blue.withOpacity(0.6) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: value ? Colors.blue : Colors.grey,
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: value ? Colors.white : Colors.grey,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: value ? Colors.white : Colors.grey,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildToggleButton(String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: value ? Colors.blue.withOpacity(0.6) : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: value ? Colors.blue : Colors.grey,
                  width: 1,
                ),
              ),
              child: value ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: value ? Colors.white : Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildResetButton() {
    return GestureDetector(
      onTap: () {
        _controller.resetView();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.withOpacity(0.6)),
        ),
        child: const Text(
          "Reset View",
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}