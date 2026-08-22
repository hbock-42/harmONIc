import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/state/library_controller.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';
import 'package:oni_pipeline/storage/json_store.dart';

import '../support/harness.dart';

/// A material you invent is a material you have.
///
/// This began as an attempt to put a "+ Write the recipe" button on the port
/// menu's dead end, and finding out *why* the list was ever empty found the
/// real bug: an item added by hand got no supply node, so nothing could feed
/// the recipe that asked for it — not even "I have some". The button was the
/// wrong fix for it and is not here; this is.
void main() {
  const unobtanium =
      Item(id: 'unobtanium', name: 'Unobtanium', category: ItemCategory.solid);

  ProcessSpec usingIt() => ProcessSpec(
        id: 'my_forge',
        name: 'My Forge',
        kind: ProcessKind.building,
        tags: const {'custom', 'unverified'},
        description: 'UNVERIFIED: measured by hand.',
        ports: const [
          Port(
            id: 'unobtanium',
            itemId: 'unobtanium',
            direction: PortDirection.input,
            ratePerSecond: 100,
          ),
          Port(
            id: 'iron',
            itemId: 'iron',
            direction: PortDirection.output,
            ratePerSecond: 100,
          ),
        ],
      );

  Future<LibraryController> withTheRecipe() async {
    final library = testLibrary();
    await library.save(usingIt(), newItems: const [unobtanium]);
    return library;
  }

  test('an invented material gets a supply and an output', () async {
    final library = await withTheRecipe();
    final db = library.database;

    expect(db.process(sourceSpecId('unobtanium')), isNotNull,
        reason: 'somewhere for it to come from');
    expect(db.process(sinkSpecId('unobtanium')), isNotNull,
        reason: 'and somewhere for it to go');
  });

  test('so the port menu can answer for it', () async {
    final library = await withTheRecipe();
    final controller = PipelineController(
      library.database,
      initial: (PipelineBuilder(library.database, name: 'mine')
            ..add('my_forge', nodeId: 'forge'))
          .build(),
    );

    final names = controller
        .candidatesFor(const PortRef('forge', 'unobtanium'))
        .map((s) => s.name);
    expect(names, contains('Unobtanium supply'));
  });

  test('and a build made of it solves', () async {
    final library = await withTheRecipe();
    final pipeline = (PipelineBuilder(library.database, name: 'mine')
          ..addSource('unobtanium')
          ..add('my_forge', nodeId: 'forge')
          ..connectItem('src_unobtanium', 'forge', 'unobtanium')
          ..pinCount('forge', 3))
        .build();

    final solution = PipelineSolver(library.database).solve(pipeline);
    expect(solution.status, SolveStatus.solved);
    expect(solution.nodes['src_unobtanium']!.count, closeTo(300, 1e-6));
  });

  test('and it survives being saved and read back', () async {
    final store = MemoryJsonStore();
    final first = LibraryController(bundled: testDatabase, store: store);
    await first.load();
    await first.save(usingIt(), newItems: const [unobtanium]);

    final second = LibraryController(bundled: testDatabase, store: store);
    await second.load();
    expect(second.database.process(sourceSpecId('unobtanium')), isNotNull);
  });
}
