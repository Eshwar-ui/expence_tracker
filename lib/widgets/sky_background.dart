import 'package:flutter/material.dart';

import '../utils/app_design_system.dart';

/// A fixed sky shared by the dashboard and profile, with a readability veil.
class SkyBackground extends StatelessWidget {
  const SkyBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          dark ? 'assets/home_night_sky.png' : 'assets/home_morning_sky.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          excludeFromSemantics: true,
          gaplessPlayback: true,
        ),
        ColoredBox(
          color: dark
              ? AppDesignSystem.darkBg.withValues(alpha: 0.18)
              : AppDesignSystem.lightCanvas.withValues(alpha: 0.32),
        ),
      ],
    );
  }
}
