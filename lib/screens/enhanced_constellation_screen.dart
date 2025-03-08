// lib/screens/enhanced_constellation_screen.dart
import 'package:flutter/material.dart';
import '../models/enhanced_constellation.dart';
import '../services/constellation_data_service.dart';
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
      final constellations = await ConstellationDataService.loadConstellations();
      
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
}