import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedDotsBackground extends StatefulWidget {
  final Widget child;

  const AnimatedDotsBackground({super.key, required this.child});

  @override
  State<AnimatedDotsBackground> createState() => _AnimatedDotsBackgroundState();
}

class _AnimatedDotsBackgroundState extends State<AnimatedDotsBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background color - matching app background
        Container(color: const Color(0xFF212121)),
        // Animated dots
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: DotsPainter(animation: _controller.value),
              size: Size.infinite,
            );
          },
        ),
        // Content
        widget.child,
      ],
    );
  }
}

class DotsPainter extends CustomPainter {
  final double animation;

  DotsPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    // White dots and connections on dark background
    final dotColor = Colors.white.withValues(alpha: .6);
    final lineColor = Colors.white.withValues(alpha: .15);

    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const dotSpacing = 60.0;
    const dotRadius = 2.0;
    const connectionDistance = 120.0;

    // Calculate offset based on animation to create movement
    final offsetX = (animation * dotSpacing) % dotSpacing;
    final offsetY = (animation * dotSpacing * 0.7) % dotSpacing;

    // Store dot positions for drawing connections
    final List<Offset> dotPositions = [];

    for (double x = -dotSpacing; x < size.width + dotSpacing; x += dotSpacing) {
      for (
        double y = -dotSpacing;
        y < size.height + dotSpacing;
        y += dotSpacing
      ) {
        // Add some randomness to dot positions
        final random = Random((x * 1000 + y).toInt());
        final jitterX = random.nextDouble() * 8 - 4;
        final jitterY = random.nextDouble() * 8 - 4;

        final position = Offset(x + offsetX + jitterX, y + offsetY + jitterY);
        dotPositions.add(position);
      }
    }

    // Track connections per dot - each dot should have exactly 2 connections
    final Map<int, List<int>> connections = {};
    for (int i = 0; i < dotPositions.length; i++) {
      connections[i] = [];
    }

    // Find nearest neighbors for each dot and ensure exactly 2 connections
    for (int i = 0; i < dotPositions.length; i++) {
      // Skip if this dot already has 2 connections
      if (connections[i]!.length >= 2) continue;

      // Find all nearby dots within connection distance
      final List<MapEntry<int, double>> nearbyDots = [];
      for (int j = 0; j < dotPositions.length; j++) {
        if (i == j) continue;
        final distance = (dotPositions[i] - dotPositions[j]).distance;
        if (distance < connectionDistance) {
          nearbyDots.add(MapEntry(j, distance));
        }
      }

      // Sort by distance
      nearbyDots.sort((a, b) => a.value.compareTo(b.value));

      // Connect to nearest dots that don't already have 2 connections
      for (final nearby in nearbyDots) {
        if (connections[i]!.length >= 2) break;
        if (connections[nearby.key]!.length >= 2) continue;

        // Create bidirectional connection
        if (!connections[i]!.contains(nearby.key)) {
          connections[i]!.add(nearby.key);
          connections[nearby.key]!.add(i);
        }
      }
    }

    // Draw connections
    final drawnConnections = <String>{};
    for (int i = 0; i < dotPositions.length; i++) {
      for (final j in connections[i]!) {
        // Ensure we don't draw the same connection twice
        final connectionKey = i < j ? '$i-$j' : '$j-$i';
        if (!drawnConnections.contains(connectionKey)) {
          // Create curved connections using quadratic Bézier curves
          final start = dotPositions[i];
          final end = dotPositions[j];

          // Calculate a random control point for the curve
          final random = Random((i * 1000 + j).hashCode);
          final midX = (start.dx + end.dx) / 2;
          final midY = (start.dy + end.dy) / 2;

          // Add random offset to the midpoint perpendicular to the line
          final dx = end.dx - start.dx;
          final dy = end.dy - start.dy;
          final perpX = -dy;
          final perpY = dx;
          final length = sqrt(perpX * perpX + perpY * perpY);

          // Normalize and scale by random amount
          final curvature =
              (random.nextDouble() - 0.5) * 40; // Random curve strength
          final offsetX = (perpX / length) * curvature;
          final offsetY = (perpY / length) * curvature;

          final controlPoint = Offset(midX + offsetX, midY + offsetY);

          // Draw quadratic Bézier curve
          final path = Path();
          path.moveTo(start.dx, start.dy);
          path.quadraticBezierTo(
            controlPoint.dx,
            controlPoint.dy,
            end.dx,
            end.dy,
          );
          canvas.drawPath(path, linePaint);

          drawnConnections.add(connectionKey);
        }
      }
    }

    // Draw dots on top of connections
    for (final position in dotPositions) {
      canvas.drawCircle(position, dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(DotsPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}
