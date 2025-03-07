// lib/screens/enhanced_constellation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/enhanced_constellation.dart';
import '../services/constellation_service.dart';
import '../widgets/celestial_sky_view.dart';
import '../widgets/inside_sky_view.dart';
import '../controllers/inside_view_controller.dart';

class EnhancedConstellationScreen extends StatefulWidget {
  const EnhancedConstellationScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedConstellationScreen> createState() => _EnhancedConstellationScreenState();
}

class _EnhancedConstellationScreenState extends State<EnhancedConstellationScreen> 
    with WidgetsBindingObserver {
  String _currentConstellation = "Ursa Major";
  bool _showConstellationLines = true;
  bool _showStarNames = true;
  bool _showMagnitudes = false;
  bool _enable3DMode = true;  // Default to 3D mode
  bool _isOverviewMode = true;
  bool _isLoading = true;
  List<EnhancedConstellation> _constellations = [];
  
  // Reference to the inside view controller
  InsideViewController? _insideViewController;
  // We no longer need the legacy format since our new overview uses the enhanced model
  
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Enable auto-rotation for better visibility
      if (_isOverviewMode && _insideViewController != null) {
        // This will be called after the view is visible
        WidgetsBinding.instance.addPostFrameCallback((_) {
          print("DEBUG: Enabling auto-rotation for inside view");
          _insideViewController!.toggleAutoRotate();
        });
      }
    }
  }
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadConstellations();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadConstellations() async {
    try {
      // Load enhanced constellations
      final constellations = await ConstellationService.loadConstellations();
      
      setState(() {
        _constellations = constellations;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading constellations: $e');
      // Show error state
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _showStarDetails(Map<String, dynamic> starData) {
    // Provide haptic feedback when a star is selected
    HapticFeedback.lightImpact();
    
    // For logging example:
    print('Star selected: ${starData['name']} (${starData['id']})');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isOverviewMode 
            ? _enable3DMode ? '3D Night Sky Overview' : 'Night Sky Overview'
            : 'Constellation: $_currentConstellation'),
        actions: [
          if (!_isOverviewMode)
            IconButton(
              icon: const Icon(Icons.zoom_out),
              tooltip: 'Zoom out to full sky view',
              onPressed: () {
                setState(() {
                  _isOverviewMode = true;
                });
              },
            ),
          // Toggle 3D mode
          IconButton(
            icon: Icon(_enable3DMode ? Icons.view_in_ar : Icons.view_in_ar_outlined),
            tooltip: _enable3DMode ? 'Switch to 2D mode' : 'Switch to 3D mode',
            onPressed: () {
              setState(() {
                _enable3DMode = !_enable3DMode;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _constellations.isEmpty
                  ? const Center(child: Text('No constellation data available', style: TextStyle(color: Colors.white)))
                  : _isOverviewMode
                    // Use our truly inside-looking-out sky view
                    ? InsideSkyView(
                        constellations: _constellations,
                        onConstellationSelected: (name) {
                          setState(() {
                            _currentConstellation = name;
                            _isOverviewMode = false;
                          });
                        },
                        onControllerCreated: (controller) {
                          _insideViewController = controller;
                          
                          // Enable auto-rotation by default for better visibility
                          Future.delayed(Duration(milliseconds: 500), () {
                            if (_insideViewController != null && _isOverviewMode) {
                              print("DEBUG: Enabling auto-rotation for inside view");
                              _insideViewController!.toggleAutoRotate();
                            }
                          });
                        },
                      )
                    // Use our new enhanced celestial view
                    : CelestialSkyView(
                        constellations: _constellations,
                        currentConstellation: _currentConstellation,
                        showConstellationLines: _showConstellationLines,
                        showStarNames: _showStarNames,
                        showMagnitudes: _showMagnitudes,
                        enable3DMode: _enable3DMode,
                        onStarTapped: _showStarDetails,
                      ),
            ),
          ),
          if (!_isOverviewMode)
            Column(
              children: [
                // Full Sky View Button at the top
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isOverviewMode = true;
                      });
                    },
                    icon: const Icon(Icons.zoom_out),
                    label: const Text('Full Sky View'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey[800],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(200, 45),
                    ),
                  ),
                ),
                // Controls
                _buildControls(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    // Find the current constellation for additional info
    final currentConstellation = _constellations.firstWhere(
      (c) => c.name == _currentConstellation,
      orElse: () => _constellations.first,
    );
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.black87,
        border: Border(top: BorderSide(color: Colors.blueGrey.shade800, width: 1)),
      ),
      child: Column(
        children: [
          // Constellation selection dropdown
          if (_constellations.isNotEmpty) 
            DropdownButton<String>(
              isExpanded: true,
              value: _currentConstellation,
              dropdownColor: Colors.blueGrey[900],
              items: _constellations.map<DropdownMenuItem<String>>((constellation) {
                return DropdownMenuItem<String>(
                  value: constellation.name,
                  child: Text(
                    constellation.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _currentConstellation = newValue;
                  });
                }
              },
            ),
          
          // Constellation additional info
          if (currentConstellation.abbreviation != null ||
              currentConstellation.season != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.blueGrey[900]?.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (currentConstellation.abbreviation != null)
                      Text(
                        'Abbreviation: ${currentConstellation.abbreviation}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    if (currentConstellation.season != null)
                      Text(
                        'Best viewing season: ${currentConstellation.season}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    // Show RA/Dec for the constellation center if available
                    if (currentConstellation.rightAscension != null && 
                        currentConstellation.declination != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Center RA: ${ConstellationService.formatRA(currentConstellation.rightAscension!)}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            'Center Dec: ${ConstellationService.formatDec(currentConstellation.declination!)}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          
          // Display controls
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: const Text('Show Lines', style: TextStyle(color: Colors.white)),
                  value: _showConstellationLines,
                  onChanged: (bool? value) {
                    if (value != null) {
                      setState(() {
                        _showConstellationLines = value;
                      });
                    }
                  },
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  title: const Text('Show Names', style: TextStyle(color: Colors.white)),
                  value: _showStarNames,
                  onChanged: (bool? value) {
                    if (value != null) {
                      setState(() {
                        _showStarNames = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: const Text('Show Magnitudes', style: TextStyle(color: Colors.white)),
                  value: _showMagnitudes,
                  onChanged: (bool? value) {
                    if (value != null) {
                      setState(() {
                        _showMagnitudes = value;
                      });
                    }
                  },
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  title: const Text('3D Mode', style: TextStyle(color: Colors.white)),
                  value: _enable3DMode,
                  onChanged: (bool? value) {
                    if (value != null) {
                      setState(() {
                        _enable3DMode = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          
          // Description
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              currentConstellation.description,
              style: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}