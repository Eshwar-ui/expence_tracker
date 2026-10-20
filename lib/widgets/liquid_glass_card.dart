import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../utils/app_design_system.dart';

/// Refracts only the backdrop; text and controls remain sharp and interactive.
class LiquidGlassCard extends StatefulWidget {
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;

  @override
  State<LiquidGlassCard> createState() => _LiquidGlassCardState();
}

class _LiquidGlassCardState extends State<LiquidGlassCard> {
  static Future<ui.FragmentProgram>? _program;
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    if (ui.ImageFilter.isShaderFilterSupported) _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program = await (_program ??=
          ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag'));
      if (!mounted) return;
      setState(() => _shader = program.fragmentShader());
    } catch (error) {
      // Blur remains available on renderers without runtime shader support.
      debugPrint('Liquid glass using blur fallback: $error');
    }
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final radius = BorderRadius.circular(AppDesignSystem.r24);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final shader = _shader;
    ui.ImageFilter filter = ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4);
    if (shader != null && !highContrast) {
      shader
        ..setFloat(2, AppDesignSystem.r24 * pixelRatio)
        ..setFloat(3, AppDesignSystem.s8 * pixelRatio);
      filter = ui.ImageFilter.compose(
        outer: ui.ImageFilter.shader(shader),
        inner: filter,
      );
    }

    return Padding(
      padding: widget.margin ?? EdgeInsets.zero,
      child: CustomPaint(
        painter: _GlassShadow(dark: dark),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: filter,
            child: CustomPaint(
              foregroundPainter: _GlassRim(dark: dark),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: (dark
                          ? AppDesignSystem.darkBg
                          : AppDesignSystem.lightCanvas)
                      .withValues(
                          alpha: highContrast ? 0.88 : (dark ? 0.30 : 0.48)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: dark ? 0.12 : 0.26),
                      Colors.white.withValues(alpha: dark ? 0.02 : 0.04),
                      Colors.white.withValues(alpha: dark ? 0.04 : 0.14),
                    ],
                    stops: const [0, 0.48, 1],
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onTap,
                    borderRadius: radius,
                    child: Padding(
                      padding: widget.padding ??
                          const EdgeInsets.all(AppDesignSystem.s24),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassRim extends CustomPainter {
  const _GlassRim({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: dark ? 0.55 : 0.90),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: dark ? 0.12 : 0.28),
          Colors.white.withValues(alpha: dark ? 0.38 : 0.65),
        ],
        stops: const [0, 0.4, 0.65, 1],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(0.6),
        const Radius.circular(AppDesignSystem.r24 - 0.6),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GlassRim oldDelegate) => oldDelegate.dark != dark;
}

/// Clip the shadow out of the pane so translucent glass never samples grey fill.
class _GlassShadow extends CustomPainter {
  const _GlassShadow({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(AppDesignSystem.r24),
    );
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect.inflate(AppDesignSystem.s48))
      ..addRRect(shape);
    canvas.save();
    canvas.clipPath(outside);
    canvas.drawShadow(
      Path()..addRRect(shape),
      AppDesignSystem.darkBg.withValues(alpha: dark ? 0.22 : 0.09),
      AppDesignSystem.s8,
      false,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassShadow oldDelegate) => oldDelegate.dark != dark;
}
