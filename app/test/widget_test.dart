import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/main.dart';

void main() {
  testWidgets('pinning a node re-solves the pipeline', (tester) async {
    await tester.pumpWidget(const OniPipelineApp());

    expect(find.textContaining('Electrolyzer'), findsWidgets);
    expect(find.textContaining('4.00 × Electrolyzer'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '8');
    await tester.pump();

    expect(find.textContaining('8.00 × Electrolyzer'), findsOneWidget);
    expect(find.textContaining('Water: 8.00 kg/s'), findsOneWidget);
  });
}
