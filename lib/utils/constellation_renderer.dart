// lib/utils/constellation_renderer.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/enhanced_constellation.dart';
import '../utils/star_renderer.dart';

/// Utility class for rendering constellations with consistent appearance and behavior
class ConstellationRenderer {
  // Make this a utility class with only static methods
  // Private constructor prevents instantiation
  ConstellationRenderer._();
  
  /// Draw a constellation's lines connecting stars
  static void drawConstellationLines(
    Canvas canvas, 
    List<List<String>> lines, 
    Map<String, Offset> starPositions,
    {
      Color color = Colors.blue,
      double opacity = 0.5,
      double strokeWidth = 1.0,
      bool isHighlighted = false
    }
  ) {
    final Paint linePaint = Paint()
      ..color = isHighlighted 
          ? color.withOpacity(min(1.0, opacity + 0.3)) // Ensure opacity doesn't exceed 1.0
          : color.withOpacity(opacity)
      ..strokeWidth = isHighlighted ? strokeWidth * 1.5 : strokeWidth
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
  
  /// Draw a constellation's name at the center of its stars
  static void drawConstellationName(
    Canvas canvas, 
    String name,
    String? abbreviation,
    List<Offset> starPositions,
    {
      double fontSize = 18.0,
      Color color = Colors.white,
      bool withShadow = true,
      Offset offset = const Offset(0, -30)
    }
  ) {
    if (starPositions.isEmpty) return;
    
    // Find the center position of the visible stars
    double sumX = 0, sumY = 0;
    for (final position in starPositions) {
      sumX += position.dx;
      sumY += position.dy;
    }
    
    final Offset center = Offset(sumX / starPositions.length, sumY / starPositions.length);
    
    // Draw constellation name
    final TextPainter nameTextPainter = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          shadows: withShadow ? const [
            Shadow(
              blurRadius: 3.0,
              color: Colors.black,
              offset: Offset(1, 1),
            ),
          ] : null,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    nameTextPainter.layout();
    nameTextPainter.paint(canvas, Offset(
      center.dx - nameTextPainter.width / 2 + offset.dx,
      center.dy - nameTextPainter.height / 2 + offset.dy,
    ));
    
    // Draw constellation abbreviation if available
    if (abbreviation != null) {
      final TextPainter abbrTextPainter = TextPainter(
        text: TextSpan(
          text: '($abbreviation)',
          style: TextStyle(
            color: color.withOpacity(0.7),
            fontSize: fontSize * 0.8,
            shadows: withShadow ? const [
              Shadow(
                blurRadius: 2.0,
                color: Colors.black,
                offset: Offset(1, 1),
              ),
            ] : null,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      abbrTextPainter.layout();
      abbrTextPainter.paint(canvas, Offset(
        center.dx - abbrTextPainter.width / 2 + offset.dx,
        center.dy + nameTextPainter.height / 2 + 4 + offset.dy,
      ));
    }
  }
  
  /// Draw a constellation with its stars and lines
  static void drawConstellation(
    Canvas canvas,
    EnhancedConstellation constellation,
    Map<String, Offset> starPositions,
    double twinklePhase,
    Size size,
    {
      bool drawLines = true,
      bool drawStarNames = true,
      bool drawConstellationName = false,
      bool isHighlighted = false,
      Color lineColor = Colors.blue,
      double starSizeMultiplier = 1.0
    }
  ) {
    // First draw lines if enabled
    if (drawLines && constellation.lines.isNotEmpty) {
      ConstellationRenderer.drawConstellationLines(
        canvas,
        constellation.lines,
        starPositions,
        color: lineColor,
        opacity: isHighlighted ? 0.8 : 0.4,
        strokeWidth: isHighlighted ? 2.0 : 1.0,
        isHighlighted: isHighlighted
      );
    }
    
    // Draw stars
    List<Offset> visibleStarPositions = [];
    
    for (final star in constellation.stars) {
      if (starPositions.containsKey(star.id)) {
        // Add to visible positions for constellation name positioning
        visibleStarPositions.add(starPositions[star.id]!);
        
        // Draw the star
        StarRenderer.drawStar(
          canvas,
          star.id,
          starPositions[star.id]!,
          star.magnitude,
          twinklePhase,
          size,
          spectralType: star.spectralType,
          sizeMultiplier: isHighlighted ? starSizeMultiplier * 1.3 : starSizeMultiplier,
          twinkleIntensity: isHighlighted ? 0.3 : 0.2
        );
        
        // Draw star name if enabled and important enough
        if (drawStarNames && (star.magnitude < 2.5 || isHighlighted)) {
          ConstellationRenderer._drawStarLabel(
            canvas,
            star,
            starPositions[star.id]!,
            isHighlighted: isHighlighted
          );
        }
      }
    }
    
    // Draw constellation name if enabled
    if (drawConstellationName && visibleStarPositions.isNotEmpty) {
      ConstellationRenderer.drawConstellationName(
        canvas,
        constellation.name,
        constellation.abbreviation,
        visibleStarPositions,
        fontSize: isHighlighted ? 20.0 : 18.0,
        color: isHighlighted ? Colors.white : Colors.white.withOpacity(0.8)
      );
    }
  }
  
  /// Draw a star's name label
  static void _drawStarLabel(
    Canvas canvas,
    CelestialStar star,
    Offset position,
    {
      bool isHighlighted = false,
      double fontSize = 12.0
    }
  ) {
    // Calculate the star radius for positioning
    final double starSize = StarRenderer.calculateStarSize(star.magnitude, Size(10, 10)) *
        (isHighlighted ? 1.5 : 1.0);
        
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: star.name,
        style: TextStyle(
          color: Colors.white.withOpacity(isHighlighted ? 0.9 : 0.7),
          fontSize: isHighlighted ? fontSize * 1.2 : fontSize,
          fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
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
    
    textPainter.layout();
    textPainter.paint(canvas, Offset(
      position.dx + starSize + 4,
      position.dy - textPainter.height / 2,
    ));
  }
  
  /// Calculate the bounding box of a constellation
  static Rect calculateBounds(List<Offset> starPositions) {
    if (starPositions.isEmpty) {
      return Rect.zero;
    }
    
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;
    
    for (final position in starPositions) {
      minX = min(minX, position.dx);
      minY = min(minY, position.dy);
      maxX = max(maxX, position.dx);
      maxY = max(maxY, position.dy);
    }
    
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}