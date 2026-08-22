import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// What a hot building has to be *made of*.
///
/// The wire already said "95 °C is hotter than a bare building tolerates, and
/// here is the whole table". A building cannot use the whole table: it is put
/// up out of the class the game asks for, so the useful sentence names which
/// members of that class hold.
void main() {
  Future<PipelineController> pumpEditor(
    WidgetTester tester,
    Pipeline pipeline,
  ) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: pipeline);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    return controller;
  }

  Pipeline electrolyzerOn(double celsius) =>
      (PipelineBuilder(testDatabase, name: 'Hot')
            ..addSource('water', x: 0, y: 0)
            ..add('electrolyzer', nodeId: 'elec', x: 340, y: 0)
            ..connect('src_water', sourcePortId, 'elec', 'water')
            ..pinCount('elec', 1))
          .build();

  Future<void> select(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  testWidgets('95 °C water makes the ore a decision', (tester) async {
    final controller = await pumpEditor(tester, electrolyzerOn(95));
    controller.setNodeTemperature('src_water', 95);
    await tester.pumpAndSettle();

    await select(tester, 'Electrolyzer');

    // An Electrolyzer is 200 kg of metal ore. Of the seven ores only Gold
    // Amalgam carries the +50 bonus, so it is the only one that holds.
    final advice = tester
        .widgetList<Text>(find.textContaining('gives up first'))
        .map((t) => t.data ?? '')
        .join();
    expect(advice, contains('metal ore'));
    expect(advice, contains('Gold Amalgam'));
    expect(advice, contains('95 °C'));
  });

  testWidgets('and cool water leaves it alone', (tester) async {
    final controller = await pumpEditor(tester, electrolyzerOn(30));
    controller.setNodeTemperature('src_water', 30);
    await tester.pumpAndSettle();

    await select(tester, 'Electrolyzer');

    // Below 75 °C every ore holds, and a line about a free choice on every
    // node of a cool build is noise.
    expect(find.textContaining('gives up first'), findsNothing);
    expect(find.text('TO BUILD'), findsWidgets);
  });

  testWidgets('a turbine the game rates itself is not asked about metal',
      (tester) async {
    final pipeline = (PipelineBuilder(testDatabase, name: 'Steam')
          ..addSource('heat', x: 0, y: 0)
          ..add('steam_turbine', nodeId: 'turbine', x: 340, y: 0)
          ..connect('src_heat', sourcePortId, 'turbine', 'heat_in')
          ..pinCount('turbine', 1))
        .build();
    await pumpEditor(tester, pipeline);

    await select(tester, 'Steam Turbine');

    // It overheats at 1 000 °C whatever it is made of, and its 95 °C water
    // must not be turned into a choice nobody gets to make.
    expect(find.textContaining('gives up first'), findsNothing);
    expect(find.textContaining('gasket'), findsNothing);
  });
}
