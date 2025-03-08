// lib/screens/constellation_detail_screen.dart
import 'package:flutter/material.dart';
import '../models/enhanced_constellation.dart';
import '../services/constellation_data_service.dart';
import '../widgets/star_visualization.dart';

class ConstellationDetailScreen extends StatefulWidget {
  final EnhancedConstellation constellation;
  
  const ConstellationDetailScreen({
    Key? key,
    required this.constellation,
  }) : super(key: key);

  @override
  State<ConstellationDetailScreen> createState() => _ConstellationDetailScreenState();
}

class _ConstellationDetailScreenState extends State<ConstellationDetailScreen> {
  bool _showLines = true;
  bool _showNames = true;
  bool _showMagnitudes = false;
  bool _showSpectralTypes = false;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.constellation.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
            tooltip: 'Constellation Information',
          ),
        ],
      ),
      body: Column(
        children: [
          // Main constellation view
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child: StarVisualization(
                stars: widget.constellation.stars,
                lines: widget.constellation.lines,
                showStarNames: _showNames,
                showMagnitudes: _showMagnitudes,
                showSpectralTypes: _showSpectralTypes,
                onStarTapped: _showStarDetails,
              ),
            ),
          ),
          
          // Controls and info
          Container(
            color: Colors.black87,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    widget.constellation.description,
                    style: const TextStyle(
                      color: Colors.white,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                // Display controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildToggleButton('Lines', _showLines, (value) {
                      setState(() => _showLines = value);
                    }),
                    _buildToggleButton('Names', _showNames, (value) {
                      setState(() => _showNames = value);
                    }),
                    _buildToggleButton('Magnitudes', _showMagnitudes, (value) {
                      setState(() => _showMagnitudes = value);
                    }),
                    _buildToggleButton('Spectral Types', _showSpectralTypes, (value) {
                      setState(() => _showSpectralTypes = value);
                    }),
                  ],
                ),
                
                // Basic constellation info
                _buildConstellationInfo(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildToggleButton(String label, bool value, Function(bool) onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: value ? Colors.blue.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: value ? Colors.blue : Colors.grey,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: value ? Colors.white : Colors.grey,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
  
  Widget _buildConstellationInfo() {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Abbreviation and Season
          Row(
            children: [
              if (widget.constellation.abbreviation != null)
                Expanded(
                  child: _buildInfoItem(
                    'Abbreviation', 
                    widget.constellation.abbreviation!
                  ),
                ),
              if (widget.constellation.season != null)
                Expanded(
                  child: _buildInfoItem(
                    'Best Viewing Season', 
                    widget.constellation.season!
                  ),
                ),
            ],
          ),
          
          // Coordinates
          if (widget.constellation.rightAscension != null && 
              widget.constellation.declination != null)
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Right Ascension',
                    ConstellationDataService.formatRA(
                      widget.constellation.rightAscension!
                    )
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    'Declination',
                    ConstellationDataService.formatDec(
                      widget.constellation.declination!
                    )
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
  
  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showStarDetails(CelestialStar star) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.85),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              star.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildStarDetail('Magnitude', star.magnitude.toStringAsFixed(2)),
            if (star.spectralType != null)
              _buildStarDetail('Spectral Type', star.spectralType!),
            if (star.distance != null)
              _buildStarDetail('Distance', '${star.distance!.toStringAsFixed(1)} light years'),
            _buildStarDetail('Right Ascension', 
                ConstellationDataService.formatRA(star.rightAscension)),
            _buildStarDetail('Declination', 
                ConstellationDataService.formatDec(star.declination)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStarDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: Text(
          widget.constellation.name,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.constellation.description,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              'Star Count: ${widget.constellation.stars.length}',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            _buildBrightestStar(),
          ],
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
  
  Widget _buildBrightestStar() {
    // Find the brightest star (lowest magnitude)
    CelestialStar brightestStar = widget.constellation.stars[0];
    for (var star in widget.constellation.stars) {
      if (star.magnitude < brightestStar.magnitude) {
        brightestStar = star;
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Brightest Star:',
          style: TextStyle(color: Colors.white70),
        ),
        Text(
          '${brightestStar.name} (magnitude ${brightestStar.magnitude.toStringAsFixed(2)})',
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}