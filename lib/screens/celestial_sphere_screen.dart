import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, HapticFeedback;
import '../models/constellation.dart';
import '../widgets/celestial_sphere_view.dart';

class CelestialSphereScreen extends StatefulWidget {
  const CelestialSphereScreen({Key? key}) : super(key: key);

  @override
  State<CelestialSphereScreen> createState() => _CelestialSphereScreenState();
}

class _CelestialSphereScreenState extends State<CelestialSphereScreen> {
  String _currentConstellation = "Ursa Major";
  bool _showConstellationLines = true;
  bool _showConstellationStars = true;
  bool _showBackgroundStars = true;
  bool _showStarNames = true;
  bool _showCelestialGrid = false;
  bool _isOverviewMode = false;
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
    HapticFeedback.lightImpact();
    
    // For logging example:
    print('Star selected: ${starData['name']} (${starData['id']})');
    
    // Could show a more detailed dialog here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isOverviewMode 
            ? 'Night Sky Overview' 
            : 'Constellation: $_currentConstellation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About 3D View',
            onPressed: _showInfoDialog,
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
                : CelestialSphereView(
                    constellations: _constellations,
                    currentConstellation: _currentConstellation,
                    showConstellationLines: _showConstellationLines,
                    showConstellationStars: _showConstellationStars,
                    showBackgroundStars: _showBackgroundStars,
                    showStarNames: _showStarNames,
                    showCelestialGrid: _showCelestialGrid,
                    onStarTapped: _showStarDetails,
                  ),
            ),
          ),
          _buildControls(),
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
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: const Text('Show Lines'),
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
                  title: const Text('Show Stars'),
                  value: _showConstellationStars,
                  onChanged: (bool? value) {
                    if (value != null) {
                      setState(() {
                        _showConstellationStars = value;
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
                  title: const Text('Background Stars'),
                  value: _showBackgroundStars,
                  onChanged: (bool? value) {
                    if (value != null) {
                      setState(() {
                        _showBackgroundStars = value;
                      });
                    }
                  },
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  title: const Text('Star Names'),
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
          CheckboxListTile(
            title: const Text('Show Celestial Grid'),
            value: _showCelestialGrid,
            onChanged: (bool? value) {
              if (value != null) {
                setState(() {
                  _showCelestialGrid = value;
                });
              }
            },
          ),
        ],
      ),
    );
  }
  
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('3D Celestial Sphere'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You are viewing a 3D simulation of the night sky.'),
              SizedBox(height: 12),
              Text('• Pan: Drag to rotate the view'),
              Text('• Zoom: Pinch to zoom in/out'),
              Text('• Tap a star: View star details'),
              SizedBox(height: 12),
              Text('The celestial grid shows lines of right ascension (vertical) and declination (horizontal).'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}