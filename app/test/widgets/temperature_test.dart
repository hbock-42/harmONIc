import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/inspector_panel.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  /// A geyser at 95 °C feeding an Electrolyzer whose oxygen leaves at 70 °C.
  Pipeline hotAndCool() => (PipelineBuilder(testDatabase, name: 'Hot water')
        ..add('water_geyser', nodeId: 'geyser', x: 0, y: 0)
        ..add('electrolyzer', nodeId: 'elec', x: 360, y: 0)
        ..addSink('oxygen', x: 720, y: 0)
        ..addSink('hydrogen', x: 720, y: 200)
        ..connectItem('geyser', 'elec', 'water')
        ..connectItem('elec', 'sink_oxygen', 'oxygen')
        ..connectItem('elec', 'sink_hydrogen', 'hydrogen')
        ..pinCount('geyser', 1))
      .build();

  Future<PipelineController> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: hotAndCool());
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    return controller;
  }

  testWidgets('a port shows the temperature the game fixes for it',
      (tester) async {
    final controller = await pumpEditor(tester);
    controller.select(const NodeSelection('elec'));
    await tester.pump();

    // The Electrolyzer's gases leave at 70 °C.
    expect(find.text('70 °C'), findsNWidgets(2));
  });

  testWidgets('a port with no stated temperature is worked out instead',
      (tester) async {
    final controller = await pumpEditor(tester);
    controller.select(const NodeSelection('elec'));
    await tester.pump();

    // The Electrolyzer publishes nothing about its water inlet, but the geyser
    // feeding it does, so the figure is arrived at rather than quoted — and it
    // says which it is with a tilde.
    expect(find.byType(InspectorPanel), findsOneWidget);
    expect(find.text('~95 °C'), findsOneWidget);
    expect(find.text('70 °C'), findsNWidgets(2));
  });

  testWidgets('a build with no temperature anywhere claims none',
      (tester) async {
    await useDesktopSurface(tester);
    final controller = testController(
      pipeline: (PipelineBuilder(testDatabase, name: 'Plain')
            ..addSource('water', x: 0, y: 0)
            ..add('electrolyzer', nodeId: 'elec', x: 360, y: 0)
            ..connectItem('src_water', 'elec', 'water')
            ..pinCount('elec', 1))
          .build(),
    );
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    controller.select(const NodeSelection('elec'));
    await tester.pump();

    // Only the two published 70 °C outputs. Nobody has said what temperature
    // the water is, so nothing pretends to know.
    //
    // In the inspector, not on the screen: the palette says what each recipe
    // is for now, and several of those sentences have a temperature in them.
    expect(
      find.descendant(
        of: find.byType(InspectorPanel),
        matching: find.textContaining('°C'),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('saying what the supply arrives at carries it downstream',
      (tester) async {
    await useDesktopSurface(tester);
    final controller = testController(
      pipeline: (PipelineBuilder(testDatabase, name: 'Warm')
            ..addSource('polluted_water', x: 0, y: 0)
            ..add('water_sieve', nodeId: 'sieve', x: 360, y: 0)
            ..connectItem('src_polluted_water', 'sieve', 'polluted_water')
            ..pinCount('sieve', 1))
          .build(),
    );
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    controller.select(const NodeSelection('src_polluted_water'));
    await tester.pump();

    expect(find.text('ARRIVES AT'), findsOneWidget);
    await tester.enterText(find.byKey(supplyTemperatureFieldKey), '40');
    await tester.pump();

    controller.select(const NodeSelection('sieve'));
    await tester.pump();
    // A Water Sieve publishes no output temperature, so it hands back what it
    // was given — which is the assumption, and it is marked as one. The
    // inspector is a list and only the first of its port rows is on screen, so
    // the second is checked where it is decided rather than where it is drawn.
    expect(find.text('~40 °C'), findsWidgets);
    expect(controller.temperatures.at(const PortRef('sieve', 'water')),
        closeTo(40, 1e-9));
    expect(
        controller.temperatures.at(const PortRef('sieve', 'polluted_water')),
        closeTo(40, 1e-9));
  });

  testWidgets('an edge says what temperature the flow arrives at',
      (tester) async {
    final controller = await pumpEditor(tester);
    final water = controller.pipeline.edges
        .firstWhere((e) => e.fromNodeId == 'geyser');
    controller.select(EdgeSelection(water.id));
    await tester.pump();

    expect(find.text('ARRIVES AT'), findsOneWidget);
    expect(find.text('95 °C'), findsOneWidget);
  });

  testWidgets('a flow past the common overheat point is called out',
      (tester) async {
    final controller = await pumpEditor(tester);
    final water = controller.pipeline.edges
        .firstWhere((e) => e.fromNodeId == 'geyser');
    controller.select(EdgeSelection(water.id));
    await tester.pump();

    // It used to say only that 95 °C is hot. It now says what to do about it:
    // the coolest material that holds, and the range above it.
    expect(textContaining('75 °C a plain building tolerates'), findsOneWidget);
    expect(textContaining('Copper (125 °C)'), findsOneWidget);
    expect(textContaining('Iridium (575 °C)'), findsOneWidget);
  });

  testWidgets('something nothing can hold is said as plainly as that',
      (tester) async {
    await useDesktopSurface(tester);
    // A Glass Forge sends molten glass out at 1 942 °C. No material in this
    // app survives it, and naming the best of a hopeless list would be worse
    // than saying so.
    final controller = testController(
      pipeline: (PipelineBuilder(testDatabase, name: 'Glass')
            ..add('glass_forge', nodeId: 'forge', x: 0, y: 0)
            ..addSink('molten_glass', x: 340, y: 0)
            ..connectItem('forge', 'sink_molten_glass', 'molten_glass')
            ..pinCount('forge', 1))
          .build(),
    );
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    controller.select(EdgeSelection(controller.pipeline.edges.first.id));
    await tester.pump();

    expect(textContaining('nothing this app knows about will hold it'),
        findsOneWidget);
  });

  testWidgets('a cool flow is not called out', (tester) async {
    final controller = await pumpEditor(tester);
    final oxygen = controller.pipeline.edges
        .firstWhere((e) => e.toNodeId == 'sink_oxygen');
    controller.select(EdgeSelection(oxygen.id));
    await tester.pump();

    expect(find.text('70 °C'), findsOneWidget);
    expect(textContaining('overheat'), findsNothing);
  });

  testWidgets('the warning is about attention, not a prediction',
      (tester) async {
    final controller = await pumpEditor(tester);
    final water = controller.pipeline.edges
        .firstWhere((e) => e.fromNodeId == 'geyser');
    controller.select(EdgeSelection(water.id));
    await tester.pump();

    // It must not claim something will overheat: the model cannot know.
    expect(textContaining('cannot see'), findsOneWidget);
  });
}
