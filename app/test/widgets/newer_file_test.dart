import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/panels/pipelines_menu.dart';
import 'package:oni_pipeline/state/workspace_controller.dart';
import 'package:oni_pipeline/storage/json_store.dart';

import '../support/harness.dart';

/// What the app does with a build saved by a newer version of itself.
void main() {
  Map<String, dynamic> fromTheFuture(String id) {
    final pipeline = (PipelineBuilder(testDatabase, name: 'Later')
          ..addSource('water')
          ..add('electrolyzer', nodeId: 'elec')
          ..connectItem('src_water', 'elec', 'water')
          ..pinCount('elec', 2))
        .build();
    return {...pipeline.toJson(), 'id': id, 'schemaVersion': 99};
  }

  test('one unreadable build does not cost you the others', () async {
    // The saved file holds two: one this app understands and one it does not.
    // Losing the second is right; losing the first with it would not be.
    final ours = (PipelineBuilder(testDatabase, name: 'Mine')
          ..addSource('water')
          ..pinRate('src_water', sourcePortId, 1000))
        .build();
    final store = MemoryJsonStore(<String, dynamic>{
      'pipelines': [ours.toJson(), fromTheFuture('later')],
      'lastOpenedId': ours.id,
    });

    final controller = testController();
    final workspace = WorkspaceController(
      store: store,
      controller: controller,
      debounce: Duration.zero,
    );
    addTearDown(workspace.dispose);
    await workspace.load();

    expect(workspace.saved.map((p) => p.name), contains('Mine'));
    expect(workspace.saved.map((p) => p.name), isNot(contains('Later')));
  });

  testWidgets('and pasting one says what to do about it', (tester) async {
    final code = base64Url.encode(utf8.encode(jsonEncode(fromTheFuture('x'))));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': code};
      }
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await useDesktopSurface(tester);
    final controller = testController();
    final workspace = await testWorkspace(controller);
    await tester.pumpWidget(harness(PipelinesMenu(
      workspace: workspace,
      controller: controller,
      library: testLibrary(),
      rateDisplay: RateDisplay.perSecond,
      onClose: () {},
    )));

    await tester.tap(find.text('Paste build'));
    await tester.pumpAndSettle();

    // Not "that build could not be read", which would send somebody looking
    // for a corrupt clipboard.
    expect(textContaining('newer version'), findsOneWidget);
  });

  test('a copy keeps everything the original had', () async {
    // Both this and import used to rebuild the pipeline field by field, which
    // means forgetting whatever somebody adds next — and they had already
    // forgotten the recipe snapshot, so a copy lost the baseline that tells
    // you a recipe moved underneath it.
    final controller = testController();
    final workspace = await testWorkspace(controller);

    // Imported rather than adopted, because importing repairs — and repairing
    // is what writes the baseline that says what the recipes were.
    final id = await workspace.import(
      (PipelineBuilder(testDatabase, name: 'Shared')
            ..addSource('water')
            ..add('electrolyzer', nodeId: 'elec')
            ..connectItem('src_water', 'elec', 'water')
            ..pinCount('elec', 2))
          .build(),
    );
    final original = workspace.pipelineFor(id)!;
    expect(original.recipeSnapshot, isNotEmpty,
        reason: 'importing writes the baseline');

    final copyId = await workspace.duplicate(id);
    final copy = workspace.pipelineFor(copyId)!;

    expect(copy.id, isNot(original.id));
    expect(copy.name, '${original.name} copy');
    expect(copy.nodes.length, original.nodes.length);
    expect(copy.pins.length, original.pins.length);
    expect(copy.recipeSnapshot, original.recipeSnapshot);
  });
}
