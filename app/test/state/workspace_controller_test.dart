import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';
import 'package:oni_pipeline/state/workspace_controller.dart';
import 'package:oni_pipeline/storage/json_store.dart';

import '../support/harness.dart';

void main() {
  late MemoryJsonStore store;
  late PipelineController controller;
  late WorkspaceController workspace;

  setUp(() {
    store = MemoryJsonStore();
    controller = PipelineController(testDatabase, initial: testPipeline());
    workspace = WorkspaceController(
      store: store,
      controller: controller,
      debounce: Duration.zero,
    );
  });

  tearDown(() => workspace.dispose());

  /// Lets a zero-length debounce timer fire.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('first run', () {
    test('reports that there is nothing saved', () async {
      expect(await workspace.load(), isFalse);
      expect(workspace.saved, isEmpty);
    });

    test('adopting the starter build saves it', () async {
      await workspace.load();
      await workspace.adopt(controller.pipeline);

      expect(workspace.saved, hasLength(1));
      expect(workspace.currentId, controller.pipeline.id);
      expect(store.data, isNotNull);
    });
  });

  group('autosave', () {
    setUp(() async {
      await workspace.load();
      await workspace.adopt(controller.pipeline);
    });

    test('an edit is written without anyone pressing save', () async {
      final before = store.writes;
      controller.addNode('coal_generator', const Offset(10, 10));
      await settle();

      expect(store.writes, greaterThan(before));
      final saved = (store.data!['pipelines'] as List<dynamic>).single
          as Map<String, dynamic>;
      expect((saved['nodes'] as List<dynamic>).length,
          controller.pipeline.nodes.length);
    });

    test('selecting a node is not an edit', () async {
      final before = store.writes;
      controller.select(const NodeSelection('elec'));
      await settle();

      expect(store.writes, before,
          reason: 'clicking around must not churn the disk');
    });

    test('a burst of edits collapses into one write', () async {
      // Its own controller and store: the workspace from setUp is still
      // listening, and would count as a second writer.
      final ownStore = MemoryJsonStore();
      final ownController =
          PipelineController(testDatabase, initial: testPipeline());
      final slow = WorkspaceController(
        store: ownStore,
        controller: ownController,
        debounce: const Duration(milliseconds: 50),
      );
      await slow.load();
      await slow.adopt(ownController.pipeline);
      final before = ownStore.writes;

      ownController.beginNodeDrag();
      for (var i = 0; i < 20; i++) {
        ownController.moveNode('elec', Offset(300 + i * 8, 100));
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(ownStore.writes - before, 1,
          reason: 'a drag is one save, not sixty');
      slow.dispose();
    });

    test('renaming is saved', () async {
      controller.rename('Oxygen for the crew');
      await settle();

      final saved = (store.data!['pipelines'] as List<dynamic>).single
          as Map<String, dynamic>;
      expect(saved['name'], 'Oxygen for the crew');
    });
  });

  group('reopening', () {
    test('restores the pipeline that was on screen, wiring and all', () async {
      await workspace.load();
      await workspace.adopt(controller.pipeline);
      controller.pin(const BuildingCountPin(nodeId: 'dupes', count: 33));
      await settle();

      // A fresh app, same disk.
      final reopenedController = PipelineController(testDatabase);
      final reopened = WorkspaceController(
        store: store,
        controller: reopenedController,
        debounce: Duration.zero,
      );
      expect(await reopened.load(), isTrue);

      expect(reopenedController.pipeline.nodes.length,
          controller.pipeline.nodes.length);
      expect(reopenedController.pipeline.edges.length,
          controller.pipeline.edges.length);
      expect(reopenedController.pinFor('dupes'), isA<BuildingCountPin>());
      expect(reopenedController.solution.status, SolveStatus.solved);
      expect(reopenedController.solution.nodes['elec']!.count,
          closeTo(3300 / 888, 1e-9));
      reopened.dispose();
    });

    test('node positions survive the round trip', () async {
      await workspace.load();
      await workspace.adopt(controller.pipeline);
      controller.beginNodeDrag();
      controller.moveNode('elec', const Offset(888, 424));
      await settle();

      final other = PipelineController(testDatabase);
      final reopened = WorkspaceController(
        store: store, controller: other, debounce: Duration.zero);
      await reopened.load();

      expect(other.pipeline.nodeOrThrow('elec').x, 888);
      expect(other.pipeline.nodeOrThrow('elec').y, 424);
      reopened.dispose();
    });
  });

  group('several pipelines', () {
    setUp(() async {
      await workspace.load();
      await workspace.adopt(controller.pipeline);
    });

    test('a new one starts empty and does not disturb the old', () async {
      await workspace.createNew(name: 'Petroleum');

      expect(workspace.saved, hasLength(2));
      expect(controller.pipeline.nodes, isEmpty);
      expect(controller.pipeline.name, 'Petroleum');
    });

    test('switching back brings the first one with it', () async {
      final firstId = controller.pipeline.id;
      await workspace.createNew(name: 'Petroleum');
      await workspace.open(firstId);

      expect(controller.pipeline.id, firstId);
      expect(controller.pipeline.nodes, isNotEmpty);
    });

    test('duplicating copies the contents under a new id', () async {
      final sourceId = controller.pipeline.id;
      final copyId = await workspace.duplicate(sourceId);

      expect(copyId, isNot(sourceId));
      expect(controller.pipeline.name, endsWith('copy'));
      expect(controller.pipeline.nodes.length, 4);
      expect(workspace.saved, hasLength(2));
    });

    test('deleting removes it and opens another', () async {
      final firstId = controller.pipeline.id;
      await workspace.createNew(name: 'Petroleum');
      await workspace.delete(firstId);

      expect(workspace.saved.map((s) => s.id), isNot(contains(firstId)));
      expect(workspace.currentId, isNot(firstId));
    });

    test('deleting the last one leaves a fresh pipeline, not nothing',
        () async {
      await workspace.delete(controller.pipeline.id);

      expect(workspace.saved, hasLength(1));
      expect(controller.pipeline.nodes, isEmpty);
    });
  });

  group('bad data', () {
    test('one unreadable pipeline does not lose the others', () async {
      final corrupt = MemoryJsonStore(<String, dynamic>{
        'schemaVersion': 1,
        'pipelines': [
          {'id': 'broken'},
          testPipeline().toJson(),
        ],
      });
      final other = PipelineController(testDatabase);
      final ws = WorkspaceController(
          store: corrupt, controller: other, debounce: Duration.zero);

      expect(await ws.load(), isTrue);
      expect(ws.saved, hasLength(1));
      expect(other.pipeline.nodes, isNotEmpty);
      ws.dispose();
    });
  });
}
