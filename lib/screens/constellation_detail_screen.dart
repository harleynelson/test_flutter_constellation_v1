import 'package:flutter/material.dart';
import '../models/enhanced_constellation.dart';
import '../services/constellation_data_service.dart';
import '../controllers/star_display_controller.dart';
import '../utils/star_renderer.dart';
import 'dart:math';

class ConstellationDetailScreen extends StatefulWidget {
  final EnhancedConstellation constellation;
  
  const ConstellationDetailScreen({
    super.key,
    required this.constellation,
  });

  @override
  State<ConstellationDetailScreen> createState() => _ConstellationDetailScreenState();
}

class _ConstellationDetailScreenState extends State<ConstellationDetailScreen> with TickerProviderStateMixin {
  bool _showLines = true;
  bool _showNames = true;
  bool _showMagnitudes = false;
  bool _showSpectralTypes = false;
  
  // For star selection (fixed to prevent multiple windows)
  CelestialStar? _selectedStar;
  
  // Star display controller for rendering
  late StarDisplayController _starController;
  
  @override
  void initState() {
    super.initState();
    _starController = StarDisplayController(
      tickerProvider: this,
      showConstellationLines: _showLines,
      showConstellationStars: true,
      showStarNames: _showNames,
      showBackgroundStars: true,
    );
  }
  
  @override
  void dispose() {
    _starController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    
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
            child: Stack(
              children: [
                // Background and stars
                _buildStarVisualization(screenSize),
                
                // Star info overlay (when selected)
                if (_selectedStar != null)
                  _buildStarInfoOverlay(),
              ],
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
                      setState(() {
                        _showLines = value;
                        _starController.updateSettings(
                          showConstellationLines: value,
                        );
                      });
                    }),
                    _buildToggleButton('Names', _showNames, (value) {
                      setState(() {
                        _showNames = value;
                        _starController.updateSettings(
                          showStarNames: value,
                        );
                      });
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
  
  Widget _buildStarVisualization(Size screenSize) {
    return GestureDetector(
      onTapDown: (details) {
        // Clear existing selection first
        setState(() {
          _selectedStar = null;
        });
        
        // Find if a star was tapped
        final Offset tapPosition = details.localPosition;
        
        // Calculate star positions on screen
        final starPositions = _calculateStarPositions(screenSize);
        
        // Check each star
        for (final star in widget.constellation.stars) {
          if (starPositions.containsKey(star.id)) {
            final Offset starPos = starPositions[star.id]!;
            final double distance = (starPos - tapPosition).distance;
            final double starSize = StarRenderer.calculateStarSize(star.magnitude, screenSize) * 2; // Larger tap area
            
            if (distance <= starSize) {
              setState(() {
                _selectedStar = star;
              });
              break;
            }
          }
        }
      },
      child: CustomPaint(
        painter: _ConstellationDetailPainter(
          constellation: widget.constellation,
          showLines: _showLines,
          showStarNames: _showNames,
          showMagnitudes: _showMagnitudes,
          showSpectralTypes: _showSpectralTypes,
          twinklePhase: _starController.twinklePhase,
          selectedStar: _selectedStar,
        ),
        size: Size.infinite,
      ),
    );
  }
  
  Map<String, Offset> _calculateStarPositions(Size size) {
    final Map<String, Offset> positions = {};
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    
    // Find constellation bounds
    double minRa = double.infinity, maxRa = double.negativeInfinity;
    double minDec = double.infinity, maxDec = double.negativeInfinity;
    
    for (final star in widget.constellation.stars) {
      minRa = min(minRa, star.rightAscension);
      maxRa = max(maxRa, star.rightAscension);
      minDec = min(minDec, star.declination);
      maxDec = max(maxDec, star.declination);
    }
    
    // Calculate scale to fit the screen (with padding)
    final double raRange = maxRa - minRa;
    final double decRange = maxDec - minDec;
    final double padding = 0.2; // 20% padding
    
    // Adjust for aspect ratio
    final double scaleX = size.width * (1 - padding * 2) / raRange;
    final double scaleY = size.height * (1 - padding * 2) / decRange;
    final double scale = min(scaleX, scaleY);
    
    // Center constellation
    final double midRa = (minRa + maxRa) / 2;
    final double midDec = (minDec + maxDec) / 2;
    
    for (final star in widget.constellation.stars) {
      final double x = centerX + (star.rightAscension - midRa) * scale;
      final double y = centerY - (star.declination - midDec) * scale; // Flip y-axis
      positions[star.id] = Offset(x, y);
    }
    
    return positions;
  }
  
  Widget _buildStarInfoOverlay() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Card(
        color: Colors.black.withOpacity(0.7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.blue.withOpacity(0.5), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _selectedStar!.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              _buildStarDetail('Magnitude', _selectedStar!.magnitude.toStringAsFixed(2)),
              if (_selectedStar!.spectralType != null)
                _buildStarDetail('Spectral Type', _selectedStar!.spectralType!),
              if (_selectedStar!.distance != null)
                _buildStarDetail('Distance', '${_selectedStar!.distance!.toStringAsFixed(1)} light years'),
              _buildStarDetail('Right Ascension', 
                  ConstellationDataService.formatRA(_selectedStar!.rightAscension)),
              _buildStarDetail('Declination', 
                  ConstellationDataService.formatDec(_selectedStar!.declination)),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedStar = null;
                  });
                },
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.blue.withOpacity(0.3),
                  ),
                  child: const Text(
                    'Tap to close',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
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

/// Custom painter for detailed constellation view
class _ConstellationDetailPainter extends CustomPainter {
  final EnhancedConstellation constellation;
  final bool showLines;
  final bool showStarNames;
  final bool showMagnitudes;
  final bool showSpectralTypes;
  final double twinklePhase;
  final CelestialStar? selectedStar;
  
  _ConstellationDetailPainter({
    required this.constellation,
    required this.showLines,
    required this.showStarNames,
    required this.showMagnitudes,
    required this.showSpectralTypes,
    required this.twinklePhase,
    this.selectedStar,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black,
    );
    
    // Draw background stars
    _drawBackgroundStars(canvas, size);
    
    // Calculate star positions
    final Map<String, Offset> starPositions = _calculateStarPositions(size);
    
    // Draw constellation lines
    if (showLines && constellation.lines.isNotEmpty) {
      _drawConstellationLines(canvas, constellation.lines, starPositions);
    }
    
    // Draw stars
    for (final star in constellation.stars) {
      if (starPositions.containsKey(star.id)) {
        final bool isSelected = selectedStar?.id == star.id;
        _drawStar(canvas, star, starPositions[star.id]!, size, isSelected);
      }
    }
  }
  
  // Draw random background stars
  void _drawBackgroundStars(Canvas canvas, Size size) {
    final Random random = Random(42); // Fixed seed for consistent pattern
    final int starCount = (size.width * size.height / 1000).round().clamp(200, 800);
    
    for (int i = 0; i < starCount; i++) {
      final double x = random.nextDouble() * size.width;
      final double y = random.nextDouble() * size.height;
      final double radius = random.nextDouble() * 1.0 + 0.3;
      final double opacity = random.nextDouble() * 0.5 + 0.2;
      
      // Subtle twinkling effect
      final double twinkleFactor = max(0, sin((twinklePhase + i * 0.1) % (2 * pi))) * 0.3;
      final double currentOpacity = min(1.0, opacity * (1.0 + twinkleFactor * 0.1));
      
      // Draw star
      final Paint starPaint = Paint()
        ..color = Colors.white.withOpacity(currentOpacity);
      
      canvas.drawCircle(Offset(x, y), radius, starPaint);
    }
  }
  
  // Calculate optimal positions for stars
  Map<String, Offset> _calculateStarPositions(Size size) {
    final Map<String, Offset> positions = {};
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    
    // Find constellation bounds
    double minRa = double.infinity, maxRa = double.negativeInfinity;
    double minDec = double.infinity, maxDec = double.negativeInfinity;
    
    for (final star in constellation.stars) {
      minRa = min(minRa, star.rightAscension);
      maxRa = max(maxRa, star.rightAscension);
      minDec = min(minDec, star.declination);
      maxDec = max(maxDec, star.declination);
    }
    
    // Calculate scale to fit the screen (with padding)
    final double raRange = maxRa - minRa;
    final double decRange = maxDec - minDec;
    final double padding = 0.2; // 20% padding
    
    // Adjust for aspect ratio
    final double scaleX = size.width * (1 - padding * 2) / raRange;
    final double scaleY = size.height * (1 - padding * 2) / decRange;
    final double scale = min(scaleX, scaleY);
    
    // Center constellation
    final double midRa = (minRa + maxRa) / 2;
    final double midDec = (minDec + maxDec) / 2;
    
    for (final star in constellation.stars) {
      final double x = centerX + (star.rightAscension - midRa) * scale;
      final double y = centerY - (star.declination - midDec) * scale; // Flip y-axis
      positions[star.id] = Offset(x, y);
    }
    
    return positions;
  }
  
  // Draw constellation lines
  void _drawConstellationLines(Canvas canvas, List<List<String>> lines, Map<String, Offset> starPositions) {
    final Paint linePaint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    
    for (final line in lines) {
      if (line.length == 2) {
        final String star1Id = line[0];
        final String star2Id = line[1];
        
        if (starPositions.containsKey(star1Id) && starPositions.containsKey(star2Id)) {
          canvas.drawLine(
            starPositions[star1Id]!,
            starPositions[star2Id]!,
            linePaint
          );
        }
      }
    }
  }
  
  // Draw a star with all its info
  void _drawStar(Canvas canvas, CelestialStar star, Offset position, Size size, bool isSelected) {
    // Calculate star size based on magnitude
    double magnitude = star.magnitude;
    final double baseSize = max(2.0, 12.0 - magnitude * 1.2);
    final double starSize = isSelected ? baseSize * 1.5 : baseSize;
    
    // Get star color based on spectral type
    final Color starColor = _getStarColor(star.spectralType);
    
    // Twinkling effect
    final double starSeed = position.dx * position.dy;
    final double twinkleSpeed = 0.5 + (sin(starSeed) + 1) * 0.5;
    final double twinkleFactor = max(0, sin((twinklePhase * twinkleSpeed) % (2 * pi))) * 0.3;
    
    // Draw glow
    final Paint glowPaint = Paint()
      ..color = starColor.withOpacity(0.3 + twinkleFactor * 0.1)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
    
    canvas.drawCircle(position, starSize * 1.5, glowPaint);
    
    // Draw star
    final Paint starPaint = Paint()
      ..color = _adjustBrightness(starColor, twinkleFactor * 0.1);
    
    canvas.drawCircle(position, starSize, starPaint);
    
    // Draw star information
    if (showStarNames || isSelected) {
      _drawStarLabels(canvas, star, position, starSize, isSelected);
    }
  }
  
  // Draw labels for a star
  void _drawStarLabels(Canvas canvas, CelestialStar star, Offset position, double starSize, bool isSelected) {
    double offsetY = 0;
    
    // Draw star name
    final TextPainter namePainter = TextPainter(
      text: TextSpan(
        text: star.name,
        style: TextStyle(
          color: Colors.white.withOpacity(isSelected ? 1.0 : 0.9),
          fontSize: isSelected ? 14.0 : 12.0,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          shadows: const [
            Shadow(
              blurRadius: 2.0,
              color: Colors.black,
              offset: Offset(1, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    namePainter.layout();
    namePainter.paint(canvas, Offset(
      position.dx + starSize + 4,
      position.dy - namePainter.height / 2 + offsetY,
    ));
    
    // Draw additional info if enabled or star is selected
    if (showMagnitudes || isSelected) {
      offsetY += 14;
      final TextPainter magPainter = TextPainter(
        text: TextSpan(
          text: 'Mag: ${star.magnitude.toStringAsFixed(1)}',
          style: TextStyle(
            color: Colors.grey.withOpacity(0.8),
            fontSize: 10.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      magPainter.layout();
      magPainter.paint(canvas, Offset(
        position.dx + starSize + 4,
        position.dy - magPainter.height / 2 + offsetY,
      ));
    }
    
    if ((showSpectralTypes || isSelected) && star.spectralType != null) {
      offsetY += 14;
      final TextPainter specPainter = TextPainter(
        text: TextSpan(
          text: 'Type: ${star.spectralType}',
          style: TextStyle(
            color: Colors.grey.withOpacity(0.8),
            fontSize: 10.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      specPainter.layout();
      specPainter.paint(canvas, Offset(
        position.dx + starSize + 4,
        position.dy - specPainter.height / 2 + offsetY,
      ));
    }
  }
  
  // Get color based on spectral type
  Color _getStarColor(String? spectralType) {
    if (spectralType == null || spectralType.isEmpty) {
      return Colors.white;
    }
    
    final String mainClass = spectralType[0].toUpperCase();
    
    switch (mainClass) {
      case 'O': // Blue
        return const Color(0xFFCAE8FF);
      case 'B': // Blue-white
        return const Color(0xFFE6F0FF);
      case 'A': // White
        return Colors.white;
      case 'F': // Yellow-white
        return const Color(0xFFFFF8E8);
      case 'G': // Yellow (Sun-like)
        return const Color(0xFFFFEFB3);
      case 'K': // Orange
        return const Color(0xFFFFD2A1);
      case 'M': // Red
        return const Color(0xFFFFBDAD);
      default:
        return Colors.white;
    }
  }
  
  // Adjust color brightness
  Color _adjustBrightness(Color color, double factor) {
    return Color.fromRGBO(
      min(255, color.red + ((255 - color.red) * factor).round()),
      min(255, color.green + ((255 - color.green) * factor).round()),
      min(255, color.blue + ((255 - color.blue) * factor).round()),
      color.opacity
    );
  }
  
  @override
  bool shouldRepaint(covariant _ConstellationDetailPainter oldDelegate) {
    return oldDelegate.constellation != constellation ||
           oldDelegate.showLines != showLines ||
           oldDelegate.showStarNames != showStarNames ||
           oldDelegate.showMagnitudes != showMagnitudes ||
           oldDelegate.showSpectralTypes != showSpectralTypes ||
           oldDelegate.twinklePhase != twinklePhase ||
           oldDelegate.selectedStar != selectedStar;
  }
}