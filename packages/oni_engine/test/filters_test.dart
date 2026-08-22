import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

void main() {
  final db = loadDefaultDatabase();
  final solver = PipelineSolver(db);

  group('filters', () {
    test('there is one per fluid, and none for anything else', () {
      expect(db.process(filterSpecId('oxygen')), isNotNull);
      expect(db.process(filterSpecId('water')), isNotNull);
      // A conveyor rail carries one solid at a time; there is nothing to sort.
      expect(db.process(filterSpecId('coal')), isNull);
      expect(db.process(filterSpecId('power')), isNull);
      expect(db.process(filterSpecId('grooming')), isNull);
    });

    test('one takes a pipe\'s worth, because that is all a pipe brings it', () {
      final gas = db.processOrThrow(filterSpecId('oxygen'));
      final liquid = db.processOrThrow(filterSpecId('water'));

      expect(gas.inputs.firstWhere((p) => p.itemId == 'oxygen').ratePerSecond,
          Conduits.gasPipe.capacity);
      expect(
          liquid.inputs.firstWhere((p) => p.itemId == 'water').ratePerSecond,
          Conduits.liquidPipe.capacity);
    });

    test('what it gives back is what it was given', () {
      // It sorts rather than converts: the mass through it is unchanged, which
      // is the one thing this model can say about a filter with certainty.
      final filter = db.processOrThrow(filterSpecId('oxygen'));
      expect(
        filter.outputs.firstWhere((p) => p.itemId == 'oxygen').ratePerSecond,
        filter.inputs.firstWhere((p) => p.itemId == 'oxygen').ratePerSecond,
      );
    });

    test('the power it costs turns up in the build', () {
      // The whole point. Filtering the hydrogen out of a SPOM's pipe is a
      // building and 120 W, and neither appeared anywhere before.
      final pipeline = (PipelineBuilder(db, name: 'filtered spom')
            ..addSource('water')
            ..add('electrolyzer', nodeId: 'elec')
            ..add(filterSpecId('hydrogen'), nodeId: 'filter')
            ..add('hydrogen_generator', nodeId: 'hgen')
            ..connectItem('src_water', 'elec', 'water')
            ..connectItem('elec', 'filter', 'hydrogen')
            ..connectItem('filter', 'hgen', 'hydrogen')
            ..pinCount('elec', 4))
          .build();
      final solution = solver.solve(pipeline);

      expect(solution.status, SolveStatus.solved);
      // Four Electrolyzers make 448 g/s of hydrogen; a filter passes 1 kg/s, so
      // not even half of one is needed — but it still draws its share.
      expect(solution.nodes['filter']!.count, closeTo(0.448, 1e-6));
      expect(solution.nodes['filter']!.wholeCount, 1);
      expect(solution.powerConsumedWatts,
          closeTo(120 * 4 + 120 * 0.448, 1e-6));
      expect(solution.constructionMaterials(db)[BuildMaterials.metalOre],
          greaterThan(0));
    });

    test('a filter is honest about not modelling the mixture', () {
      final filter = db.processOrThrow(filterSpecId('oxygen'));
      expect(filter.description, contains('more than one gas'));
      // It has two ports for its own gas and nothing for the rest, which is
      // the limitation, and it is said rather than hidden.
      expect(filter.ports.map((p) => p.itemId).toSet(),
          {'oxygen', WellKnownItems.power});
    });

    test('and it is as optional as what it filters', () {
      // Polluted brine is Aquatic, so its filter is too — the palette hides
      // both together.
      expect(db.processOrThrow(filterSpecId('polluted_brine')).tags,
          contains('aquatic'));
      expect(db.processOrThrow(filterSpecId('water')).tags,
          isNot(contains('aquatic')));
    });
  });
}
