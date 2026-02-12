import 'package:flutter/material.dart';
import '../utils/app_design_system.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget child;
  final bool useContainer;

  const ResponsiveLayout({
    super.key,
    required this.child,
    this.useContainer = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: AppDesignSystem.maxContentWidth,
        ),
        decoration: useContainer &&
                MediaQuery.of(context).size.width >
                    AppDesignSystem.maxContentWidth
            ? BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              )
            : null,
        child: child,
      ),
    );
  }
}
