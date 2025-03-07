import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import '../models/constellation.dart';
import '../widgets/enhanced_sky_view.dart';
import '../widgets/night_sky_view.dart'; // Keep using the existing overview widget

class ImprovedConstellationScreen extends StatefulWidget {
  const ImprovedConstellationScreen({Key? key}) : super(key: key);

  @override
  State<ImprovedConstellationScreen> createState() => _ImprovedConstellationScreenState();
}

class _ImprovedConstellationScreenState extends State<ImprovedConstellationScreen> {
  String _currentConstellation = "Ursa Major";
  bool _showConstellationLines = true;
  bool _showConstellationStars = true;
  bool _showBackgroundStars = true;
  bool _showStarNames = true;
  bool _isOverviewMode = true;
  final List<Map<String, dynamic>> _constellations = [];
  
  @override
  void initState() {
    super.initState();
    _loadConstellations();
  }

  Future<void> _loadConstellations() async {
    try {
      // Load from an asset file
      final String jsonString = await rootBundle.loadString('assets/constellations.json');
      final List<dynamic> jsonData = json.decode(jsonString);
      
      setState(() {
        for (var constellation in jsonData) {
          _constellations.add(constellation as Map<String, dynamic>);
        }
      });
    } catch (e) {
      // Fallback to hardcoded data if loading from assets fails
      print('Error loading constellations: $e');
      final List<dynamic> jsonData = Constellation.getSampleData();
      
      setState(() {
        for (var constellation in jsonData) {
          _constellations.add(constellation as Map<String, dynamic>);
        }
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
            ? 'Night Sky Overview' 
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
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              child: _constellations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _isOverviewMode
                  // Keep using the existing overview widget
                  ? NightSkyView(
                      constellations: _constellations,
                      onConstellationSelected: (name) {
                        setState(() {
                          _currentConstellation = name;
                          _isOverviewMode = false;
                        });
                      },
                    )
                  // Use our new enhanced sky view
                  : EnhancedSkyView(
                      constellations: _constellations,
                      currentConstellation: _currentConstellation,
                      showConstellationLines: _showConstellationLines,
                      showConstellationStars: _showConstellationStars,
                      showBackgroundStars: _showBackgroundStars,
                      showStarNames: _showStarNames,
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
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (_constellations.isNotEmpty) 
            DropdownButton<String>(
              isExpanded: true,
              value: _currentConstellation,
              items: _constellations.map<DropdownMenuItem<String>>((constellation) {
                return DropdownMenuItem<String>(
                  value: constellation['name'] as String,
                  child: Text(constellation['name'] as String),
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
          CheckboxListTile(
            title: const Text('Show Constellation Lines'),
            value: _showConstellationLines,
            onChanged: (bool? value) {
              if (value != null) {
                setState(() {
                  _showConstellationLines = value;
                });
              }
            },
          ),
          CheckboxListTile(
            title: const Text('Show Constellation Stars'),
            value: _showConstellationStars,
            onChanged: (bool? value) {
              if (value != null) {
                setState(() {
                  _showConstellationStars = value;
                });
              }
            },
          ),
          CheckboxListTile(
            title: const Text('Show Background Stars'),
            value: _showBackgroundStars,
            onChanged: (bool? value) {
              if (value != null) {
                setState(() {
                  _showBackgroundStars = value;
                });
              }
            },
          ),
          CheckboxListTile(
            title: const Text('Show Star Names'),
            value: _showStarNames,
            onChanged: (bool? value) {
              if (value != null) {
                setState(() {
                  _showStarNames = value;
                });
              }
            },
          ),
        ],
      ),
    );
  }
}