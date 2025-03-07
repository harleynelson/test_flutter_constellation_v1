import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../painters/sky_painter.dart';
import '../models/constellation.dart';

class ConstellationScreen extends StatefulWidget {
  const ConstellationScreen({Key? key}) : super(key: key);

  @override
  State<ConstellationScreen> createState() => _ConstellationScreenState();
}

class _ConstellationScreenState extends State<ConstellationScreen> {
  String _currentConstellation = "Ursa Major";
  bool _showConstellationLines = true;
  bool _showConstellationStars = true;
  bool _showBackgroundStars = true;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Constellation Learning App'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              child: _constellations.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : CustomPaint(
                    painter: SkyPainter(
                      constellations: _constellations,
                      currentConstellation: _currentConstellation,
                      showConstellationLines: _showConstellationLines,
                      showConstellationStars: _showConstellationStars,
                      showBackgroundStars: _showBackgroundStars,
                    ),
                    size: Size.infinite,
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
        ],
      ),
    );
  }
}