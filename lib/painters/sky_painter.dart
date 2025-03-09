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
  final bool showConstellationLines;
  final bool showConstellationBoundaries;
  final bool showGrid;
  final bool brightStarsOnly;
  
  // Highlighted constellation
  final String? hoveredConstellation;
  final String? selectedConstellation;
  
  SkyPainter({
    required this.data,
    required this.controller,
    this.showStarNames = false,
    this.showConstellationLines = true,
    this.showConstellationBoundaries = false,
    this.showGrid = false,
    this.brightStarsOnly = false,
    this.hoveredConstellation,
    this.selectedConstellation,
  }) : super(repaint: controller);
  
  @override
  void paint(Canvas canvas, Size size) {
    // Draw background gradient
    _drawBackground(canvas, size);
    
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
    
    // Draw stars
    _drawStars(canvas, size, starPositions);
    
    // Draw labels last so they appear on top
    if (showStarNames) {
      _drawStarLabels(canvas, size, starPositions);
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
  
  /// Draw star names for brighter stars
  void _drawStarLabels(Canvas canvas, Size size, Map<int, Offset> starPositions) {
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
  /// This uses an inside-out perspective as if viewer is at the center of the celestial sphere
  Offset? _projectToScreen(double ra, double dec, Size size) {
    // Convert to radians
    final double raRad = ra * (pi / 180.0);
    final double decRad = dec * (pi / 180.0);
    
    // Convert to 3D unit vector (points outward from center)
    final double x = cos(decRad) * cos(raRad);
    final double y = cos(decRad) * sin(raRad);
    final double z = sin(decRad);
    
    // Get camera parameters (viewer looking outward from center)
    final double headingRad = controller.heading * (pi / 180.0);
    final double pitchRad = controller.pitch * (pi / 180.0);
    
    // Compute direction vector of camera (where we're looking)
    final double dx = cos(pitchRad) * sin(headingRad);
    final double dy = sin(pitchRad);
    final double dz = cos(pitchRad) * cos(headingRad);
    
    // Compute dot product to check if star is in front of us
    final double dot = x * dx + y * dy + z * dz;
    
    // If dot product is negative, star is behind us
    if (dot < 0) return null;
    
    // Compute the field of view in radians
    final double fovRad = controller.fieldOfView * (pi / 180.0);
    
    // Calculate angle between view direction and star
    final double angle = acos(dot);
    
    // If angle is greater than half FOV, star is not visible
    if (angle > fovRad / 2) return null;
    
    // For the math below, it's easier if we define a proper view coordinate system
    // Up vector - perpendicular to viewing direction, points to zenith as much as possible
    final double upX = 0;
    final double upY = 1;
    final double upZ = 0;
    
    // Right vector is cross product of direction and up
    final double rightX = dy * upZ - dz * upY;
    final double rightY = dz * upX - dx * upZ;
    final double rightZ = dx * upY - dy * upX;
    
    // Normalize right vector
    final double rightLength = sqrt(rightX * rightX + rightY * rightY + rightZ * rightZ);
    final double nx = rightX / rightLength;
    final double ny = rightY / rightLength;
    final double nz = rightZ / rightLength;
    
    // The real up vector is perpendicular to both the view direction and right vector
    final double ux = dy * nz - dz * ny;
    final double uy = dz * nx - dx * nz;
    final double uz = dx * ny - dy * nx;
    
    // Project star direction onto right and up vectors
    final double projRight = x * nx + y * ny + z * nz;
    final double projUp = x * ux + y * uy + z * uz;
    
    // Calculate screen position
    // tan(angle) gives distance from center as proportion of distance to screen edge
    final double tanHalfFov = tan(fovRad / 2);
    final double screenX = size.width / 2 + size.width / 2 * (projRight / tanHalfFov);
    final double screenY = size.height / 2 - size.height / 2 * (projUp / tanHalfFov);
    
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
           oldDelegate.showConstellationLines != showConstellationLines ||
           oldDelegate.showConstellationBoundaries != showConstellationBoundaries ||
           oldDelegate.showGrid != showGrid ||
           oldDelegate.brightStarsOnly != brightStarsOnly ||
           oldDelegate.hoveredConstellation != hoveredConstellation ||
           oldDelegate.selectedConstellation != selectedConstellation;
  }
}