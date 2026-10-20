import 'package:expence_tracker/widgets/liquid_glass_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'package:expence_tracker/utils/app_design_system.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('glass preserves nested actions in $brightness',
        (tester) async {
      var cardTaps = 0;
      var buttonTaps = 0;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: LiquidGlassCard(
                onTap: () => cardTaps++,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Net balance'),
                    TextButton(
                      onPressed: () => buttonTaps++,
                      child: const Text('Review'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Review'));
      await tester.pump();
      expect(buttonTaps, 1);
      expect(cardTaps, 0);
      await tester.tap(find.text('Net balance'));
      await tester.pump();
      expect(cardTaps, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('light glass keeps a white backdrop free of grey shadow fill',
      (tester) async {
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.light(),
      home: Center(
          child: RepaintBoundary(
        key: boundaryKey,
        child: const ColoredBox(
          color: Colors.white,
          child: SizedBox(
            width: 280,
            height: 200,
            child: Center(
                child: SizedBox(
              width: 200,
              height: 140,
              child: LiquidGlassCard(child: SizedBox.shrink()),
            )),
          ),
        ),
      )),
    ));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes =
          (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final offset = (100 * image.width + 140) * 4;
      for (var channel = 0; channel < 3; channel++) {
        expect(bytes.getUint8(offset + channel), greaterThanOrEqualTo(253),
            reason: 'The shadow must not tint the inside of the glass pane');
      }
      image.dispose();
    });
  });

  test('secondary and payment text maintain contrast on pale sky glass', () {
    final sky = Color.alphaBlend(
        Colors.white.withValues(alpha: 0.32), const Color(0xFF89B6DB));
    final pane = Color.alphaBlend(Colors.white.withValues(alpha: 0.48), sky);
    for (final ink in [
      AppDesignSystem.textHigh,
      AppDesignSystem.textMed,
      AppDesignSystem.incomeTextLight,
      AppDesignSystem.expenseTextLight
    ]) {
      final ratio =
          (pane.computeLuminance() + 0.05) / (ink.computeLuminance() + 0.05);
      expect(ratio, greaterThanOrEqualTo(4.5));
    }
  });
}
