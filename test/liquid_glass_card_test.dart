import 'package:expence_tracker/widgets/liquid_glass_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('glass preserves nested actions in $brightness', (tester) async {
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
}
