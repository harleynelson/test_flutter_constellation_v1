// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/celestial_data.dart';
import 'widgets/sky_view_consolidated.dart';
import 'services/celestial_data_service.dart';

void main() {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Run the app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Celestial Navigator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A237E),
          elevation: 0,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // State for loading data
  bool _isLoading = true;
  String? _errorMessage;
  CelestialData? _celestialData;
  
  // Selected constellation
  String? _selectedConstellation;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  // Load celestial data
  Future<void> _loadData() async {
    try {
      final data = await CelestialDataService().loadData();
      
      setState(() {
        _celestialData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load celestial data: $e';
        _isLoading = false;
      });
    }
  }
  
  // Handle constellation selection
  void _onConstellationSelected(String name) {
    setState(() {
      _selectedConstellation = name;
    });
    
    // Show constellation info
    _showConstellationInfo(name);
  }
  
  // Show information about a constellation
  void _showConstellationInfo(String name) {
    if (_celestialData == null) return;
    
    final constellation = _celestialData!.constellations[name];
    if (constellation == null) return;
    
    final brightestStar = constellation.getBrightestStar(_celestialData!.stars);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              constellation.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              constellation.description,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            if (brightestStar != null)
              Text(
                'Brightest star: ${brightestStar.name ?? 'HIP ${brightestStar.id}'} '
                '(Magnitude ${brightestStar.magnitude.toStringAsFixed(2)})',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Number of stars: ${constellation.starIds.length}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Celestial Navigator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showAboutDialog,
            tooltip: 'About',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    // Show loading indicator
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading celestial data...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }
    
    // Show error message
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _loadData();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    // Show the sky view
    return SkyViewConsolidated(
      data: _celestialData!,
      onConstellationSelected: _onConstellationSelected,
    );
  }
  
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text(
          'About Celestial Navigator',
          style: TextStyle(color: Colors.white),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Celestial Navigator is an interactive night sky viewer that displays '
              'stars and constellations based on astronomical data.',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 16),
            Text(
              'Features:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '• View stars and constellations\n'
              '• Rotate and zoom the sky view\n'
              '• Toggle grid lines and labels\n'
              '• Learn about each constellation',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}