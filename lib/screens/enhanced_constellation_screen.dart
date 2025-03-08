// lib/screens/enhanced_constellation_screen.dart
import 'package:flutter/material.dart';
import '../models/enhanced_constellation.dart';
import '../services/constellation_centers_service.dart';
import '../services/constellation_data_service.dart';
import '../models/constellation_center.dart';
import '../widgets/sky_view.dart';
import '../controllers/inside_view_controller.dart';
import 'constellation_detail_screen.dart';

class EnhancedConstellationScreen extends StatefulWidget {
  const EnhancedConstellationScreen({super.key});

  @override
  State<EnhancedConstellationScreen> createState() => _EnhancedConstellationScreenState();
}

class _EnhancedConstellationScreenState extends State<EnhancedConstellationScreen> 
    with WidgetsBindingObserver {
  final String _currentConstellation = "Ursa Major";
  bool _enable3DMode = true;  // Default to 3D mode
  bool _isLoading = true;
  List<EnhancedConstellation> _constellations = [];
  List<ConstellationCenter> _constellationCenters = [];
  
  // Reference to the inside view controller
  InsideViewController? _insideViewController;
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Enable auto-rotation for better visibility
      if (_insideViewController != null) {
        // This will be called after the view is visible
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _insideViewController!.toggleAutoRotate();
        });
      }
    }
  }
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Load both enhanced constellations and centers
      final constellations = await ConstellationDataService.loadConstellations();
      final centers = await ConstellationCentersService.loadConstellationCenters();
      
      setState(() {
        _constellations = constellations;
        _constellationCenters = centers;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      // Show error state
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Navigate to the constellation detail screen
  void _showConstellationDetail(String constellationName) {
    final constellation = _constellations.firstWhere(
      (c) => c.name == constellationName,
      orElse: () => _constellations.first,
    );
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ConstellationDetailScreen(
          constellation: constellation,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_enable3DMode ? '3D Night Sky Overview' : 'Night Sky Overview'),
        actions: [
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
          
          // Info button for constellation centers
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About Constellation Centers',
            onPressed: () {
              _showCentersInfoDialog();
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
                  : SkyView(
                      constellations: _constellations,
                      onConstellationSelected: _showConstellationDetail,
                      onControllerCreated: (controller) {
                        _insideViewController = controller;
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Show an informational dialog about constellation centers
  void _showCentersInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text(
          'Constellation Centers',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The yellow labels show the official center coordinates of each constellation. These are marked with their IAU abbreviation.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              
              // Show some stats about the centers
              Text(
                'Total Constellations: ${_constellationCenters.length}',
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              
              if (_constellationCenters.isNotEmpty)
                const Text(
                  'Constellation Abbreviations:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              
              // Show a grid of constellation abbreviations
              if (_constellationCenters.isNotEmpty)
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8, // 8 items per row
                      childAspectRatio: 1.5,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: _constellationCenters.length,
                    itemBuilder: (context, index) {
                      final center = _constellationCenters[index];
                      return Tooltip(
                        message: 'RA: ${center.rightAscension}h, Dec: ${center.declination}°',
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            center.abbreviation,
                            style: const TextStyle(color: Colors.yellow),
                          ),
                        ),
                      );
                    },
                  ),
                ),
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