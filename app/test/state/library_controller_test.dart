import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/state/library_controller.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';
import 'package:oni_pipeline/storage/user_data_store.dart';

import '../support/harness.dart';

void main() {
  LibraryController library([MemoryUserDataStore? store]) => LibraryController(
        bundled: testDatabase,
        store: store ?? MemoryUserDataStore(),
      );

  /// The motivating case: a critter the wiki has not documented.
  ProcessSpec beakon() => ProcessSpec(
        id: 'beakon',
        name: 'Beakon',
        kind: ProcessKind.critter,
        tags: const {'custom', 'unverified'},
        description: 'UNVERIFIED: measured in game.',
        ports: const [
          Port(
            id: 'phosphorite',
            itemId: 'phosphorite',
            direction: PortDirection.input,
            ratePerSecond: 50,
          ),
          Port(
            id: 'lime',
            itemId: 'lime',
            direction: PortDirection.output,
            ratePerSecond: 25,
          ),
        ],
      );

  test('starts as the bundled database', () {
    final lib = library();
    expect(lib.database.process('electrolyzer'), isNotNull);
    expect(lib.customProcesses, isEmpty);
  });

  test('a saved process joins the catalogue', () async {
    final lib = library();
    await lib.save(beakon());

    expect(lib.database.process('beakon'), isNotNull);
    expect(lib.isCustom('beakon'), isTrue);
    expect(lib.isOverride('beakon'), isFalse);
  });

  test('saving notifies, so the canvas re-solves', () async {
    final lib = library();
    var notified = 0;
    lib.addListener(() => notified++);
    await lib.save(beakon());
    expect(notified, greaterThan(0));
  });

  test('a new item is saved alongside the process that needs it', () async {
    final lib = library();
    await lib.save(
      ProcessSpec(
        id: 'magma_maker',
        name: 'Magma Maker',
        kind: ProcessKind.building,
        tags: const {'custom', 'unverified'},
        description: 'UNVERIFIED: invented.',
        ports: const [
          Port(
            id: 'magma',
            itemId: 'magma',
            direction: PortDirection.output,
            ratePerSecond: 10,
          ),
        ],
      ),
      newItems: const [
        Item(id: 'magma', name: 'Magma', category: ItemCategory.liquid),
      ],
    );

    expect(lib.database.item('magma'), isNotNull);
    // Would throw if the port referenced an item nobody defined.
    lib.database.assertConsistent();
  });

  group('overriding', () {
    test('the player version wins over the bundled one', () async {
      final lib = library();
      final mine = ProcessSpec(
        id: 'electrolyzer',
        name: 'Electrolyzer',
        kind: ProcessKind.building,
        tags: const {'custom', 'verified'},
        ports: const [
          Port(
            id: 'water',
            itemId: 'water',
            direction: PortDirection.input,
            ratePerSecond: 500,
          ),
          Port(
            id: 'oxygen',
            itemId: 'oxygen',
            direction: PortDirection.output,
            ratePerSecond: 444,
          ),
        ],
      );
      await lib.save(mine);

      expect(lib.isOverride('electrolyzer'), isTrue);
      expect(
        lib.database
            .processOrThrow('electrolyzer')
            .inputs
            .single
            .ratePerSecond,
        500,
      );
    });

    test('reverting brings the bundled version back', () async {
      final lib = library();
      await lib.save(ProcessSpec(
        id: 'electrolyzer',
        name: 'Mine',
        kind: ProcessKind.building,
        tags: const {'custom'},
        ports: const [],
      ));
      await lib.revert('electrolyzer');

      expect(lib.isCustom('electrolyzer'), isFalse);
      expect(
        lib.database
            .processOrThrow('electrolyzer')
            .inputs
            .firstWhere((p) => p.itemId == 'water')
            .ratePerSecond,
        1000,
        reason: 'the shipped 1000 g/s is back',
      );
    });
  });

  group('persistence', () {
    test('survives a restart', () async {
      final store = MemoryUserDataStore();
      await library(store).save(beakon());

      final reopened = library(store);
      await reopened.load();

      expect(reopened.database.process('beakon'), isNotNull);
      expect(reopened.isCustom('beakon'), isTrue);
    });

    test('a corrupt file does not stop the app starting', () async {
      final store = MemoryUserDataStore(<String, dynamic>{
        'processes': [
          {'nonsense': true},
        ],
      });
      final lib = library(store);
      await lib.load();

      expect(lib.database.process('electrolyzer'), isNotNull,
          reason: 'the bundled data is still there');
    });

    test('nothing saved yet is not an error', () async {
      final lib = library(MemoryUserDataStore());
      await lib.load();
      expect(lib.customProcesses, isEmpty);
    });
  });

  test('a corrected recipe changes the answer on the canvas', () async {
    final lib = library();
    final controller = PipelineController(lib.database, initial: testPipeline());
    final before = controller.solution.nodes['elec']!.count;

    // Halve the Electrolyzer's oxygen output; twice as many are now needed.
    await lib.save(ProcessSpec(
      id: 'electrolyzer',
      name: 'Electrolyzer',
      kind: ProcessKind.building,
      tags: const {'custom', 'unverified'},
      description: 'UNVERIFIED: halved for the test.',
      ports: const [
        Port(
          id: 'water',
          itemId: 'water',
          direction: PortDirection.input,
          ratePerSecond: 1000,
        ),
        Port(
          id: 'oxygen',
          itemId: 'oxygen',
          direction: PortDirection.output,
          ratePerSecond: 444,
        ),
        Port(
          id: 'hydrogen',
          itemId: 'hydrogen',
          direction: PortDirection.output,
          ratePerSecond: 112,
        ),
      ],
    ));
    controller.useDatabase(lib.database);

    expect(controller.solution.nodes['elec']!.count, closeTo(before * 2, 1e-9));
  });
}
