// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:flutter/scheduler.dart';
// import '../painters/sky_painter.dart';

// class AnimatedSkyView extends StatefulWidget {
//   final List<Map<String, dynamic>> constellations;
//   final String currentConstellation;
//   final bool showConstellationLines;
//   final bool showConstellationStars;
//   final bool showBackgroundStars;
//   final bool showStarNames;
//   final Function(Map<String, dynamic>)? onStarTapped;

//   const AnimatedSkyView({
//     Key? key,
//     required this.constellations,
//     required this.currentConstellation,
//     required this.showConstellationLines,
//     required this.showConstellationStars,
//     required this.showBackgroundStars,
//     this.showStarNames = true,
//     this.onStarTapped,
//   }) : super(key: key);

//   @override
//   State<AnimatedSkyView> createState() => _AnimatedSkyViewState();
// }

// class _AnimatedSkyViewState extends State<AnimatedSkyView> with SingleTickerProviderStateMixin {
//   late Ticker _ticker;
//   double _twinklePhase = 0.0;
//   Offset? _tapPosition;
//   Map<String, dynamic>? _selectedStar;

//   @override
//   void initState() {
//     super.initState();
    
//     // Create a ticker for the animation
//     _ticker = createTicker((elapsed) {
//       // Update the twinkle phase based on elapsed time
//       // We use a slow animation for natural twinkling (complete cycle every 5 seconds)
//       setState(() {
//         _twinklePhase = elapsed.inMilliseconds / 5000 * pi;
//       });
//     });
    
//     // Start the animation
//     _ticker.start();
//   }

//   @override
//   void dispose() {
//     _ticker.dispose();
//     super.dispose();
//   }

//   void _handleTap(TapDownDetails details) {
//     setState(() {
//       _tapPosition = details.localPosition;
//     });
//   }

//   void _handleStarTapped(Map<String, dynamic> starData) {
//     // Clear tap position to prevent repeated detection
//     setState(() {
//       _tapPosition = null;
//       _selectedStar = starData;
//     });
    
//     // Call parent callback if provided
//     if (widget.onStarTapped != null) {
//       widget.onStarTapped!(starData);
//     }
//   }

//   void _clearSelection() {
//     if (_selectedStar != null) {
//       setState(() {
//         _selectedStar = null;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTapDown: _handleTap,
//       onTap: _clearSelection, // Clear selection when tapping empty space
//       child: Stack(
//         children: [
//           CustomPaint(
//             painter: SkyPainter(
//               constellations: widget.constellations,
//               currentConstellation: widget.currentConstellation,
//               showConstellationLines: widget.showConstellationLines,
//               showConstellationStars: widget.showConstellationStars,
//               showBackgroundStars: widget.showBackgroundStars,
//               showStarNames: widget.showStarNames,
//               ticker: _ticker,
//               twinklePhase: _twinklePhase,
//               tapPosition: _tapPosition,
//               onStarTapped: _handleStarTapped,
//             ),
//             size: Size.infinite,
//           ),
          
//           // Show star information card when a star is selected
//           if (_selectedStar != null)
//             Positioned(
//               bottom: 20,
//               left: 20,
//               right: 20,
//               child: Card(
//                 color: Colors.black.withOpacity(0.7),
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Text(
//                         _selectedStar!['name'] as String,
//                         style: const TextStyle(
//                           fontSize: 24,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.white,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       Text(
//                         'Magnitude: ${(_selectedStar!['magnitude'] as double).toStringAsFixed(2)}',
//                         style: const TextStyle(
//                           fontSize: 16,
//                           color: Colors.white,
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       Text(
//                         'ID: ${_selectedStar!['id'] as String}',
//                         style: const TextStyle(
//                           fontSize: 16,
//                           color: Colors.white70,
//                         ),
//                       ),
//                       const SizedBox(height: 16),
//                       const Text(
//                         'Tap anywhere to close',
//                         style: TextStyle(
//                           fontSize: 14,
//                           color: Colors.white70,
//                           fontStyle: FontStyle.italic,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }