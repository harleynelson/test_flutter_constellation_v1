// lib/painters/sky_painter.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/celestial_data.dart';
import '../controllers/sky_view_controller.dart';
import '../utils/color_utils.dart';

/// Custom painter for rendering the night sky with stars and constellations
class SkyPainter extends CustomPainter {
  final CelestialData data;
  final SkyViewController controller;
  
  // Display options
  final bool showStarNames;
  final bool showConstellationNames;
  final bool showConstellationLines;
  final bool showConstellationBoundaries;
  final bool showGrid;
  final bool brightStarsOnly;
  final bool showBackground;
  final bool showConstellationStars;
  
  // Highlighted constellation
  final String? hoveredConstellation;
  final String? selectedConstellation;
  
  // Random number generator with fixed seed for consistent background stars
  final Random _random = Random(42);
  
  SkyPainter({
    required this.data,
    required this.controller,
    this.showStarNames = false,
    this.showConstellationNames = false,
    this.showConstellationLines = true,
    this.showConstellationBoundaries = false,
    this.showGrid = false,
    this.brightStarsOnly = false,
    this.showBackground = true,
    this.showConstellationStars = true,
    this.hoveredConstellation,
    this.selectedConstellation,
  }) : super(repaint: controller);
  
  @override
  void paint(Canvas canvas, Size size) {
    // Draw background gradient
    _drawBackground(canvas, size);
    
    // Draw background stars if enabled
    if (showBackground) {
      _drawBackgroundStars(canvas, size);
    }
    
    // Draw celestial grid if enabled
    if (showGrid) {
      _drawCelestialGrid(canvas, size);
    }
    
    // Calculate visible stars and their screen positions
    final Map<int, Offset> starPositions = _calculateStarPositions(size);
    
    // Draw constellation lines
    if (showConstellationLines) {
      _drawConstellationLines(canvas, size, starPositions);
    }
    
    // Draw constellation boundaries if enabled
    if (showConstellationBoundaries) {
      _drawConstellationBoundaries(canvas, size);
    }
    
    // Draw stars
    if (showConstellationStars) {
      _drawStars(canvas, size, starPositions);
    }
    
    // Draw labels last so they appear on top
    if (showStarNames || showConstellationNames) {
      _drawLabels(canvas, size, starPositions);
    }
  }
  
  /// Draw a gradient background representing the night sky
  void _drawBackground(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    
    final Paint paint = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          Color(0xFF111B2A), // Dark blue
          Color(0xFF000510), // Very dark blue
          Colors.black,
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(rect);
    
    canvas.drawRect(rect, paint);
  }
  
  /// Draw random background stars
  void _drawBackgroundStars(Canvas canvas, Size size) {
    // Number of stars based on screen size, clamped to a reasonable range
    final int starCount = (size.width * size.height / 1000).round().clamp(200, 2000);
    
    // Twinkling effect variables
    final double twinklePhase = controller.twinklePhase;
    
    for (int i = 0; i < starCount; i++) {
      // Position is random across the entire screen
      final double x = _random.nextDouble() * size.width;
      final double y = _random.nextDouble() * size.height;
      
      // Star properties are semi-deterministic based on position
      final int starSeed = ((x * 100) + y).round();
      final Random starRandom = Random(starSeed);
      
      // Size varies based on position to create depth effect
      double radius = starRandom.nextDouble() * 1.0 + 0.3; // 0.3-1.3 pixels
      
      // Brightness varies based on "distance"
      final double baseOpacity = starRandom.nextDouble() * 0.5 + 0.2; // 0.2-0.7 opacity
      
      // Twinkle effect based on position and time
      final double twinkleSpeed = 0.5 + starRandom.nextDouble(); // Random speed
      final double twinkleFactor = sin((twinklePhase * twinkleSpeed) % (2 * pi));
      
      // Apply twinkling - increase size and brightness slightly
      final double currentRadius = radius * (1.0 + max(0, twinkleFactor) * 0.1);
      final double currentOpacity = min(1.0, baseOpacity * (1.0 + max(0, twinkleFactor) * 0.2));
      
      // Draw star
      final Paint starPaint = Paint()
        ..color = Colors.white.withOpacity(currentOpacity);
      
      canvas.drawCircle(Offset(x, y), currentRadius, starPaint);
      
      // Draw subtle glow for brighter stars
      if (baseOpacity > 0.5 && twinkleFactor > 0.3) {
        final Paint glowPaint = Paint()
          ..color = Colors.white.withOpacity(currentOpacity * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
        
        canvas.drawCircle(Offset(x, y), currentRadius * 1.5, glowPaint);
      }
    }
  }
  
  /// Draw a celestial grid with RA/Dec lines
  void _drawCelestialGrid(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    
    final Paint equatorPaint = Paint()
      ..color = Colors.green.withOpacity(0.4)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    
    // Draw RA lines (meridians)
    for (int ra = 0; ra < 360; ra += 30) {
      final List<Offset> points = [];
      
      for (int dec = -80; dec <= 80; dec += 5) {
        final Offset? point = _projectToScreen(ra.toDouble(), dec.toDouble(), size);
        if (point != null) {
          points.add(point);
        }
      }
      
      _drawCurve(canvas, points, gridPaint);
    }
    
    // Draw Dec lines (parallels)
    for (int dec = -60; dec <= 60; dec += 20) {
      final List<Offset> points = [];
      
      for (int ra = 0; ra < 360; ra += 5) {
        final Offset? point = _projectToScreen(ra.toDouble(), dec.toDouble(), size);
        if (point != null) {
          points.add(point);
        }
      }
      
      final Paint paint = dec == 0 ? equatorPaint : gridPaint;
      _drawCurve(canvas, points, paint);
    }
  }
  
  /// Draw constellation lines connecting stars
  void _drawConstellationLines(Canvas canvas, Size size, Map<int, Offset> starPositions) {
    for (final constellation in data.constellations.values) {
      // Check if this constellation should be highlighted
      final bool isHighlighted = constellation.abbreviation == selectedConstellation || 
                              constellation.abbreviation == hoveredConstellation;
                               
      // Create a paint for this constellation
      final Paint linePaint = Paint()
        ..color = isHighlighted 
            ? Colors.lightBlue.withOpacity(0.8) 
            : Colors.blue.withOpacity(0.5)
        ..strokeWidth = isHighlighted ? 2.0 : 1.0
        ..style = PaintingStyle.stroke;
      
      // Draw each line segment
      for (final line in constellation.lines) {
        for (int i = 0; i < line.length - 1; i++) {
          final int starId1 = line[i];
          final int starId2 = line[i + 1];
          
          if (starPositions.containsKey(starId1) && starPositions.containsKey(starId2)) {
            final Offset p1 = starPositions[starId1]!;
            final Offset p2 = starPositions[starId2]!;
            
            // Don't draw lines that span more than half the screen (they're likely wrapping around)
            final double distance = (p1 - p2).distance;
            if (distance < size.width / 2) {
              canvas.drawLine(p1, p2, linePaint);
            }
          }
        }
      }
    }
  }
  
  /// Draw constellation boundaries (simplified placeholder)
  void _drawConstellationBoundaries(Canvas canvas, Size size) {
    // This is a placeholder for constellation boundaries
    // In a real implementation, this would load and draw actual IAU constellation boundaries
    
    final Paint boundaryPaint = Paint()
      ..color = Colors.purple.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
      
    // For now, just draw a simplified boundary around highlighted constellation
    if (selectedConstellation != null || hoveredConstellation != null) {
      final String constellationAbbr = selectedConstellation ?? hoveredConstellation!;
      final Constellation? constellation = data.findConstellationByAbbr(constellationAbbr);
      
      if (constellation != null) {
        final List<Offset> boundaryPoints = [];
        
        // Get all star positions for this constellation
        for (final starId in constellation.starIds) {
          final Offset? pos = _projectToScreen(
            data.stars[starId]?.ra ?? 0, 
            data.stars[starId]?.dec ?? 0, 
            size
          );
          
          if (pos != null) {
            boundaryPoints.add(pos);
          }
        }
        
        if (boundaryPoints.length >= 3) {
          // Calculate convex hull or just connect outer points
          // For simplicity, just draw a polygon connecting all points
          final Path path = Path();
          path.moveTo(boundaryPoints[0].dx, boundaryPoints[0].dy);
          
          for (int i = 1; i < boundaryPoints.length; i++) {
            path.lineTo(boundaryPoints[i].dx, boundaryPoints[i].dy);
          }
          
          path.close();
          canvas.drawPath(path, boundaryPaint);
        }
      }
    }
  }
  
  /// Draw all visible stars
  void _drawStars(Canvas canvas, Size size, Map<int, Offset> starPositions) {
    // Set cutoff magnitude based on user setting
    final double magnitudeCutoff = brightStarsOnly ? 4.0 : 6.0;
    
    for (final entry in starPositions.entries) {
      final int starId = entry.key;
      final Offset position = entry.value;
      final Star star = data.stars[starId]!;
      
      // Skip stars that are too dim
      if (star.magnitude > magnitudeCutoff) continue;
      
      // Check if this star is part of a highlighted constellation
      bool isHighlighted = false;
      if (selectedConstellation != null || hoveredConstellation != null) {
        final String constellationAbbr = selectedConstellation ?? hoveredConstellation!;
        final Constellation? constellation = data.findConstellationByAbbr(constellationAbbr);
        if (constellation != null) {
          isHighlighted = constellation.starIds.contains(starId);
        }
      }
      
      // Calculate star size based on magnitude and zoom level
      final double baseSize = 0.5;
      final double zoom = isHighlighted ? 1.5 : 1.0;
      final double radius = ColorUtils.calculateStarSize(
        star.magnitude, baseSize, zoom
      );
      
      // Get star color based on spectral type or B-V index
      final Color color = star.spectralType != null
          ? ColorUtils.getStarColorFromSpectralType(star.spectralType)
          : ColorUtils.getStarColorFromBV(star.bv);
      
      // Calculate twinkle effect
      final double twinkleFactor = ColorUtils.calculateTwinkle(
        starId, controller.twinklePhase, isHighlighted ? 0.15 : 0.1
      );
      
      // Draw the star
      ColorUtils.drawStar(canvas, position, radius, color, twinkleFactor);
    }
  }
  
  /// Draw star names and constellation labels
  void _drawLabels(Canvas canvas, Size size, Map<int, Offset> starPositions) {
    // Draw star names for brighter stars
    if (showStarNames) {
      // Only label stars brighter than magnitude 3
      for (final entry in starPositions.entries) {
        final int starId = entry.key;
        final Offset position = entry.value;
        final Star star = data.stars[starId]!;
        
        // Only label named stars brighter than magnitude 3
        if (star.name == null || star.magnitude > 3.0) continue;
        
        // Calculate star radius for positioning
        final double radius = ColorUtils.calculateStarSize(star.magnitude, 0.5, 1.0);
        
        // Create text painter
        final TextPainter textPainter = TextPainter(
          text: TextSpan(
            text: star.name,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              shadows: const [
                Shadow(
                  color: Colors.black,
                  offset: Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        
        textPainter.layout();
        textPainter.paint(canvas, Offset(
          position.dx + radius + 4,
          position.dy - textPainter.height / 2,
        ));
      }
    }
    
    // Draw constellation names if enabled
    if (showConstellationNames) {
      for (final constellation in data.constellations.values) {
        // Only display names for visible constellations
        bool isVisible = false;
        Offset centerPos = Offset.zero;
        int visibleStarCount = 0;
        
        for (final starId in constellation.starIds) {
          if (starPositions.containsKey(starId)) {
            isVisible = true;
            centerPos += starPositions[starId]!;
            visibleStarCount++;
          }
        }
        
        // Only display name if we have visible stars
        if (isVisible && visibleStarCount > 0) {
          // Calculate center position
          centerPos = Offset(
            centerPos.dx / visibleStarCount,
            centerPos.dy / visibleStarCount
          );
          
          // Check if this constellation is highlighted
          final bool isHighlighted = constellation.abbreviation == selectedConstellation || 
                                  constellation.abbreviation == hoveredConstellation;
          
          // Create text painter
          final TextPainter textPainter = TextPainter(
            text: TextSpan(
              text: constellation.name,
              style: TextStyle(
                color: isHighlighted 
                    ? Colors.lightBlue.withOpacity(0.9) 
                    : Colors.white.withOpacity(0.7),
                fontSize: isHighlighted ? 16 : 14,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                shadows: const [
                  Shadow(
                    color: Colors.black,
                    offset: Offset(1, 1),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          
          textPainter.layout();
          textPainter.paint(canvas, Offset(
            centerPos.dx - textPainter.width / 2,
            centerPos.dy - textPainter.height / 2,
          ));
        }
      }
    }
  }
  
  /// Calculate and project stars to screen coordinates
  Map<int, Offset> _calculateStarPositions(Size size) {
    final Map<int, Offset> positions = {};
    
    for (final star in data.stars.values) {
      final Offset? screenPos = _projectToScreen(star.ra, star.dec, size);
      if (screenPos != null) {
        positions[star.id] = screenPos;
      }
    }
    
    return positions;
  }
  
  /// Project celestial coordinates to screen coordinates
  /// This uses a true inside-out perspective with the viewer at the center of the celestial sphere
  Offset? _projectToScreen(double ra, double dec, Size size) {
    // Convert to radians
    final double raRad = ra * (pi / 180.0);
    final double decRad = dec * (pi / 180.0);
    
    // Convert celestial coordinates to 3D direction vector from center outward
    // Adjust the coordinate system to match expected orientation
    final double x = cos(decRad) * cos(raRad);
    final double y = cos(decRad) * sin(raRad);
    final double z = sin(decRad);
    
    // Camera view direction - where we're looking from the center
    // Adjust heading by 180 degrees to fix the pole orientation
    final double headingRad = (controller.heading + 180.0) * (pi / 180.0);
    final double pitchRad = controller.pitch * (pi / 180.0);
    
    // Calculate view direction vector
    final double dx = cos(pitchRad) * sin(headingRad);
    final double dy = cos(pitchRad) * cos(headingRad);
    final double dz = sin(pitchRad);
    
    // Dot product to determine if star is in front of viewer
    final double dot = x * dx + y * dy + z * dz;
    
    // If star is behind us, don't show it
    if (dot <= 0) return null;
    
    // Calculate angular distance from view center
    final double fovRad = controller.fieldOfView * (pi / 180.0);
    
    // If star is outside our field of view, don't show it
    if (acos(dot) > fovRad / 2) return null;
    
    // Create view-plane coordinate system
    // Right vector is perpendicular to view direction and world up (0,0,1)
    final double upX = 0;
    final double upY = 0;
    final double upZ = 1;
    
    double rightX = dy * upZ - dz * upY;
    double rightY = dz * upX - dx * upZ;
    double rightZ = dx * upY - dy * upX;
    
    // Normalize right vector
    final double rightLength = sqrt(rightX * rightX + rightY * rightY + rightZ * rightZ);
    if (rightLength > 0.0001) {
      rightX /= rightLength;
      rightY /= rightLength;
      rightZ /= rightLength;
    }
    
    // True up vector (perpendicular to both view and right)
    final double trueUpX = dy * rightZ - dz * rightY;
    final double trueUpY = dz * rightX - dx * rightZ;
    final double trueUpZ = dx * rightY - dy * rightX;
    
    // Project the star onto the view plane
    final double rightComponent = x * rightX + y * rightY + z * rightZ;
    final double upComponent = x * trueUpX + y * trueUpY + z * trueUpZ;
    
    // Convert to screen coordinates with perspective
    final double tanHalfFov = tan(fovRad / 2);
    final double screenX = size.width / 2 + size.width / 2 * (rightComponent / (dot * tanHalfFov));
    // Don't invert the Y coordinate - we want the natural orientation
    final double screenY = size.height / 2 + size.height / 2 * (upComponent / (dot * tanHalfFov));
    
    return Offset(screenX, screenY);
  }
  
  /// Draw a curve connecting points
  void _drawCurve(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    
    for (int i = 1; i < points.length; i++) {
      // Skip discontinuities (points that are too far apart)
      if ((points[i] - points[i - 1]).distance < 100) {
        path.lineTo(points[i].dx, points[i].dy);
      } else {
        // Start a new subpath
        path.moveTo(points[i].dx, points[i].dy);
      }
    }
    
    canvas.drawPath(path, paint);
  }
  
  @override
  bool shouldRepaint(covariant SkyPainter oldDelegate) {
    return oldDelegate.controller != controller ||
           oldDelegate.showStarNames != showStarNames ||
           oldDelegate.showConstellationNames != showConstellationNames ||
           oldDelegate.showConstellationLines != showConstellationLines ||
           oldDelegate.showConstellationBoundaries != showConstellationBoundaries ||
           oldDelegate.showGrid != showGrid ||
           oldDelegate.brightStarsOnly != brightStarsOnly ||
           oldDelegate.showBackground != showBackground ||
           oldDelegate.showConstellationStars != showConstellationStars ||
           oldDelegate.hoveredConstellation != hoveredConstellation ||
           oldDelegate.selectedConstellation != selectedConstellation;
  }
}