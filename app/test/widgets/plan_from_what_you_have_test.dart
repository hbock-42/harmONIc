import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// "What can I make from what I have?"
///
/// Asked twice in a week, in different words: "I know my inputs, not my
/// outputs", and an issue about three Oil Wells and eight Duplicants. The
/// answer — put a ceiling on each supply, then ask an output for the most —
/// has been possible for a while, is written down in the guide, and has never
/// once been found there.
void main() {
  Future<PipelineController> pumpEditor(
      WidgetTester tester, Pipeline pipeline) async {
    await useDesktopSurface(tester);
    final controller = testController()..load(pipeline);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    await tester.pumpAndSettle();
    return controller;
  }

  /// Water in, oxygen out, and an amount on the water: "this is what I have".
  Pipeline whatIHave() => (PipelineBuilder(testDatabase, name: 'what I have')
        ..addSource('water', x: 0, y: 0)
        ..add('electrolyzer', nodeId: 'elec', x: 320, y: 0)
        ..addSink('oxygen', nodeId: 'o2', x: 640, y: 0)
        ..addSink('hydrogen', nodeId: 'h2', x: 640, y: 240)
        ..connectItem('src_water', 'elec', 'water')
        ..connectItem('elec', 'o2', 'oxygen')
        ..connectItem('elec', 'h2', 'hydrogen')
        ..pinRate('src_water', 'out', 2000))
      .build();

  testWidgets('the button is offered where the build is that shape',
      (tester) async {
    final controller = await pumpEditor(tester, whatIHave());
    controller.select(const NodeSelection('o2'));
    await tester.pumpAndSettle();

    expect(find.text('What can I make from what I have?'), findsOneWidget);
  });

  testWidgets('and one press answers it', (tester) async {
    final controller = await pumpEditor(tester, whatIHave());
    controller.select(const NodeSelection('o2'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('What can I make from what I have?'));
    await tester.pumpAndSettle();

    // 2 kg/s of water through an Electrolyzer is 2 of them, and each makes
    // 888 g/s of oxygen.
    expect(controller.solution.status, SolveStatus.solved);
    expect(controller.solution.nodes['o2']!.count, closeTo(2 * 888, 1e-6));
    // Said in the banner, because the button goes: once the supplies are
    // ceilings there is nothing left to reread.
    expect(controller.notice, contains('the most you have rather than'));
    expect(find.text('What can I make from what I have?'), findsNothing);
  });

  testWidgets('and it is one undo, not one per supply', (tester) async {
    final controller = await pumpEditor(tester, whatIHave());
    final before = controller.pipeline.toJson().toString();
    controller.select(const NodeSelection('o2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('What can I make from what I have?'));
    await tester.pumpAndSettle();

    controller.undo();
    expect(controller.pipeline.toJson().toString(), before);
  });

  testWidgets('and it is not offered when there is nothing to reread',
      (tester) async {
    // No amount on the supply means nothing to read as a ceiling, and the
    // ordinary "get as much as possible" already says why.
    final loose = whatIHave().copyWith(pins: const []);
    final controller = await pumpEditor(tester, loose);
    controller.select(const NodeSelection('o2'));
    await tester.pumpAndSettle();

    expect(find.text('What can I make from what I have?'), findsNothing);
  });
}
