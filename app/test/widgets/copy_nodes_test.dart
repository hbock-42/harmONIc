import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';
import 'package:oni_pipeline/state/workspace_controller.dart';

import '../support/harness.dart';

void main() {
  late PipelineController controller;
  late WorkspaceController workspace;
  String? clipboard;

  setUp(() {
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard =
            (call.arguments as Map<Object?, Object?>)['text'] as String?;
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        return <String, Object?>{'text': clipboard};
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> pumpEditor(WidgetTester tester) async {

    await useDesktopSurface(tester);
    controller = testController();
    workspace = await testWorkspace(controller);
    await tester.pumpWidget(harness(EditorScreen(
      // These press ⌘; on Windows the same shortcuts are held with Ctrl.
      apple: true,
      controller: controller,
      library: testLibrary(),
      workspace: workspace,
      displaySettings: testDisplay(),
    )));
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pumpAndSettle();
  }

  testWidgets('copying takes the nodes and the wires between them',
      (tester) async {
    await pumpEditor(tester);
    controller.selectNodes(['src_water', 'elec']);
    await tester.pump();

    await press(tester, LogicalKeyboardKey.keyC);

    final copied = PipelineShareCode.decode(clipboard!);
    expect(copied.nodes, hasLength(2));
    expect(copied.edges, hasLength(1),
        reason: 'the water wire is between them and comes along');
  });

  testWidgets('a wire leaving the selection is not half-copied',
      (tester) async {
    await pumpEditor(tester);
    controller.selectNodes(['elec']);
    await tester.pump();

    await press(tester, LogicalKeyboardKey.keyC);

    expect(PipelineShareCode.decode(clipboard!).edges, isEmpty);
  });

  testWidgets('pasting adds them under new ids, leaving the originals',
      (tester) async {
    await pumpEditor(tester);
    controller.selectNodes(['src_water', 'elec']);
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyC);

    await press(tester, LogicalKeyboardKey.keyV);

    expect(controller.pipeline.nodes, hasLength(6));
    expect(controller.pipeline.node('elec'), isNotNull,
        reason: 'the original is untouched');
    expect(controller.selectedNodeIds, hasLength(2),
        reason: 'the new copy is what is now selected');
  });

  testWidgets('the pasted copy is a build of its own, with its own amount',
      (tester) async {
    await pumpEditor(tester);
    controller.selectNodes(['src_water', 'elec']);
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyC);
    await press(tester, LogicalKeyboardKey.keyV);

    final pasted = controller.selectedNodeIds.toList();
    final elecCopy = pasted.firstWhere(
      (id) => controller.specOf(controller.pipeline.nodeOrThrow(id)).id ==
          'electrolyzer',
    );
    controller.pin(BuildingCountPin(nodeId: elecCopy, count: 4));
    await tester.pump();

    // The original build keeps the ten duplicants it was given.
    expect(controller.solution.nodes['dupes']!.count, closeTo(10, 1e-9));
    expect(controller.solution.nodes[elecCopy]!.count, closeTo(4, 1e-9));
  });

  testWidgets('pasting into another build carries the nodes across',
      (tester) async {
    await pumpEditor(tester);
    controller.selectNodes(['elec']);
    await tester.pump();
    await press(tester, LogicalKeyboardKey.keyC);

    await workspace.createNew(name: 'Elsewhere');
    await tester.pumpAndSettle();
    expect(controller.pipeline.nodes, isEmpty);

    await press(tester, LogicalKeyboardKey.keyV);

    expect(controller.pipeline.nodes, hasLength(1));
    expect(controller.specOf(controller.pipeline.nodes.single).id,
        'electrolyzer');
  });

  testWidgets('a clipboard holding something else is ignored quietly',
      (tester) async {
    await pumpEditor(tester);
    clipboard = 'a shopping list';
    final before = controller.pipeline.nodes.length;

    await press(tester, LogicalKeyboardKey.keyV);

    expect(controller.pipeline.nodes, hasLength(before));
    expect(tester.takeException(), isNull);
  });
}
