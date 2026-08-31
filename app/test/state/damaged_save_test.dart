import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';
import 'package:oni_pipeline/state/workspace_controller.dart';
import 'package:oni_pipeline/storage/json_store.dart';

import '../support/harness.dart';

/// A save that is valid JSON and the wrong shape.
///
/// The store already refuses to hand over anything that will not parse. What
/// gets past it is a file that parses and means something else: written by a
/// version that is not this one, half flushed when a tab closed, or edited by
/// hand. That lands in the loader, and the loader runs at start-up — so
/// something that throws here is not a lost build, it is an app that will not
/// open.
void main() {
  Future<WorkspaceController> loadFrom(Map<String, dynamic> saved) async {
    final controller = PipelineController(testDatabase);
    final workspace = WorkspaceController(
      store: MemoryJsonStore(saved),
      controller: controller,
      debounce: Duration.zero,
    );
    addTearDown(workspace.dispose);
    await workspace.load();
    return workspace;
  }

  test('nothing saved at all', () async {
    final workspace = await loadFrom(<String, dynamic>{});
    expect(workspace.saved, isEmpty);
  });

  test('the list of builds is not a list', () async {
    await loadFrom(<String, dynamic>{'pipelines': 'oops'});
  });

  test('the last opened id is not a string', () async {
    await loadFrom(<String, dynamic>{'lastOpenedId': 7, 'pipelines': []});
  });

  test('an open id is not a string', () async {
    // With an empty list of builds the loader gives up before it reads these,
    // so this needs a real build beside it or it passes without looking.
    final good = PipelineController(testDatabase)
      ..addNode('electrolyzer', const Offset(0, 0));
    final workspace = await loadFrom(<String, dynamic>{
      'pipelines': [good.pipeline.toJson()],
      'openIds': [7, good.pipeline.id],
    });
    expect(workspace.saved, hasLength(1));
  });

  test('a build naming a recipe this version has never heard of', () async {
    // What a save written by a newer app looks like. The card cannot be
    // modelled, so it goes -- but not quietly: the build survives without it
    // and the editor is told to say what it lost.
    final good = PipelineController(testDatabase)
      ..addNode('electrolyzer', const Offset(0, 0));
    final json = good.pipeline.toJson();
    (json['nodes'] as List<dynamic>).add(<String, dynamic>{
      'id': 'from_the_future',
      'specId': 'flux_capacitor',
      'x': 100,
      'y': 100,
    });
    final workspace = await loadFrom(<String, dynamic>{'pipelines': [json]});
    expect(workspace.saved, hasLength(1));
    expect(workspace.saved, hasLength(1), reason: 'the build survives');
    expect(workspace.saved.single.nodeCount, 1,
        reason: 'without the card it cannot draw');
    expect(workspace.repairNotes, isNotEmpty,
        reason: 'and it says so rather than losing it quietly');
  });

  test('a build in the list is not a map', () async {
    await loadFrom(<String, dynamic>{'pipelines': ['not a build']});
  });

  test('a build in the list is missing everything', () async {
    await loadFrom(<String, dynamic>{
      'pipelines': [<String, dynamic>{}],
    });
  });

  test('one build is unreadable and the others are not', () async {
    final good = PipelineController(testDatabase)..addNode('electrolyzer',
        const Offset(0, 0));
    final workspace = await loadFrom(<String, dynamic>{
      'pipelines': [
        'rubbish',
        good.pipeline.toJson(),
      ],
    });
    expect(workspace.saved, hasLength(1),
        reason: 'the readable one survives its neighbour');
  });
}
