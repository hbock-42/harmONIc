import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';

import '../support/harness.dart';

/// A build that could not have been made here still opens.
///
/// Share codes arrive hand-edited, written by a newer version, and damaged in
/// transit — all three have happened. The structural checks that catch them
/// were written and had never been run, and what matters is not that they
/// produce a message but that the editor is still standing to show it.
void main() {
  Future<void> open(WidgetTester tester, Pipeline pipeline) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: pipeline);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('a card naming a recipe this version has never heard of',
      (tester) async {
    final p = testPipeline();
    await open(
      tester,
      p.copyWith(nodes: [
        for (final n in p.nodes)
          if (n.id == 'elec') n.copyWith(specId: 'flux_capacitor') else n,
      ]),
    );
    expect(tester.takeException(), isNull);
    expect(textContaining('unknown process'), findsOneWidget);
  });

  testWidgets('a wire onto a port that is not there', (tester) async {
    final p = testPipeline();
    await open(
      tester,
      p.copyWith(edges: [
        for (final e in p.edges)
          if (e.toNodeId == 'elec') e.copyWith(toPortId: 'nowhere') else e,
      ]),
    );
    expect(tester.takeException(), isNull);
    expect(textContaining('has no port'), findsOneWidget);
  });

  testWidgets('an amount on a card that was deleted from the file',
      (tester) async {
    final p = testPipeline();
    await open(
      tester,
      p.copyWith(pins: [const BuildingCountPin(nodeId: 'ghost', count: 2)]),
    );
    expect(tester.takeException(), isNull);
    expect(textContaining('missing node'), findsOneWidget);
  });
}
