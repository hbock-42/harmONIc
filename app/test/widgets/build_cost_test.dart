import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

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

  Pipeline spom(double electrolyzers) =>
      (PipelineBuilder(testDatabase, name: 'SPOM')
            ..addSource('water', x: 0, y: 0)
            ..add('electrolyzer', nodeId: 'elec', x: 340, y: 0)
            ..connectItem('src_water', 'elec', 'water')
            ..pinCount('elec', electrolyzers))
          .build();

  testWidgets('the whole build says what it costs to put up', (tester) async {
    await pumpEditor(tester, spom(4));

    expect(find.text('TO BUILD'), findsWidgets);
    // Four Electrolyzers at 200 kg of ore each.
    expect(textContaining('800 kg'), findsWidgets);
  });

  testWidgets('a node priced in the inspector names the material',
      (tester) async {
    final controller = await pumpEditor(tester, spom(4));
    controller.select(const NodeSelection('elec'));
    await tester.pump();

    expect(textContaining('800 kg Metal Ore'), findsOneWidget);
  });

  testWidgets('half a building still costs a whole one', (tester) async {
    final controller = await pumpEditor(tester, spom(1.5));
    controller.select(const NodeSelection('elec'));
    await tester.pump();

    // 1.5 Electrolyzers means two get built, and two get paid for.
    expect(textContaining('400 kg Metal Ore'), findsOneWidget);
  });

  testWidgets('a build of nothing but supply asks for no materials',
      (tester) async {
    final bare = (PipelineBuilder(testDatabase, name: 'bare')
          ..addSource('water', x: 0, y: 0)
          ..addSink('water', x: 340, y: 0)
          ..connectItem('src_water', 'sink_water', 'water')
          ..pinRate('src_water', sourcePortId, 1000))
        .build();
    await pumpEditor(tester, bare);

    expect(find.text('TO BUILD'), findsNothing);
  });

  testWidgets('a material counted in things is not weighed in kilograms',
      (tester) async {
    // An Aquatic Milking Station wants 400 kg of refined metal and four
    // gaskets. Gaskets are things.
    final controller = await pumpEditor(
      tester,
      (PipelineBuilder(testDatabase, name: 'Milking')
            ..add('aquatic_milking_station', nodeId: 'station', x: 0, y: 0)
            ..pinCount('station', 1))
          .build(),
    );
    controller.select(const NodeSelection('station'));
    await tester.pump();

    expect(textContaining('4 Gaskets'), findsOneWidget);
    expect(textContaining('4 kg Gaskets'), findsNothing);

    // And the headline figure is a weight, so it leaves them out rather than
    // adding four to twelve hundred and calling the result kilograms.
    expect(textContaining('400 kg'), findsWidgets);
  });

  testWidgets('a part counted in ones says what one costs', (tester) async {
    final pipeline = (PipelineBuilder(testDatabase, name: 'Milk')
          ..add('aquatic_milking_station', nodeId: 'station', x: 0, y: 0)
          ..pinCount('station', 1))
        .build();
    final controller = await pumpEditor(tester, pipeline);
    controller.select(const NodeSelection('station'));
    await tester.pumpAndSettle();

    // Four gaskets, and a gasket is 50 kg of plastic: the app has been able to
    // say the first since gaskets were seeded and the second only since the
    // Crafting Station's recipe was published.
    expect(textContaining('4 Gaskets'), findsOneWidget);
    expect(textContaining('200 kg Plastic'), findsOneWidget);
  });

  testWidgets('a building nobody has priced is said, not skipped',
      (tester) async {
    // The reachable case: a recipe you wrote yourself has no build cost until
    // you give it one, and the total was quietly leaving it out.
    final library = testLibrary();
    final mine = ProcessSpec(
      id: 'my_smoker',
      name: 'My Smoker',
      kind: ProcessKind.building,
      tags: const {'custom', 'unverified'},
      description: 'UNVERIFIED: measured by hand.',
      ports: const [
        Port(
          id: 'wood',
          itemId: 'lumber',
          direction: PortDirection.input,
          ratePerSecond: 100,
        ),
        Port(
          id: 'calories',
          itemId: 'calories',
          direction: PortDirection.output,
          ratePerSecond: 20,
        ),
      ],
    );
    await library.save(mine);

    final pipeline = (PipelineBuilder(library.database, name: 'Mine')
          ..addSource('lumber', x: 0, y: 0)
          ..add('my_smoker', nodeId: 'smoker', x: 340, y: 0)
          ..add('electrolyzer', nodeId: 'elec', x: 340, y: 260)
          ..connectItem('src_lumber', 'smoker', 'lumber')
          ..pinCount('smoker', 2)
          ..pinCount('elec', 1))
        .build();

    await useDesktopSurface(tester);
    final controller = PipelineController(library.database, initial: pipeline);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: library,
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));

    // The bar still totals what it can, and admits what it could not.
    expect(textContaining('NOT PRICED'), findsOneWidget);

    // And the node itself says why it is missing from that total.
    controller.select(const NodeSelection('smoker'));
    await tester.pumpAndSettle();
    expect(textContaining('Nobody has said what this costs'), findsOneWidget);
  });

  testWidgets('and a build of shipped buildings says nothing of the kind',
      (tester) async {
    // Every building in the shipped data has a price, so this must not appear
    // on an ordinary build.
    await pumpEditor(tester, spom(4));
    expect(textContaining('NOT PRICED'), findsNothing);
  });
}