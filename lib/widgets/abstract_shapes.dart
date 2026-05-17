import 'package:flutter/material.dart';

class AbstractShapes extends StatelessWidget {
  final double height;
  final BorderRadius borderRadius;
  final List<Color> gradient;

  const AbstractShapes({
    super.key,
    required this.height,
    required this.borderRadius,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Soft abstract blobs
            Positioned(
              top: -40,
              left: -30,
              child: _blob(120, Colors.white.withValues(alpha: 0.06)),
            ),
            Positioned(
              bottom: -30,
              right: -20,
              child: _blob(140, Colors.white.withValues(alpha: 0.08)),
            ),
            Positioned(
              top: 30,
              right: -40,
              child: _blob(90, Colors.white.withValues(alpha: 0.05)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 40, spreadRadius: 10)],
      ),
    );
  }
}
