import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// Two diets reported as wrong, and both were.
///
/// "Some info on harmONIc is entirely false. Sweetles cannot eat liquid sulfur
/// and you don't have the full hatch diet useable."
///
/// The first was wrong in words only — the app refused the wire and then told
/// you the opposite in the description, which is the worst way to be wrong.
/// The second was wrong in the model: four of the ten rocks the game will
/// crush and a Hatch will eat were missing from the class.
void main() {
  final db = loadDefaultDatabase();

  group('a Sweetle eats solid sulfur', () {
    test('and the wire from a liquid sulfur geyser is refused', () {
      expect(db.accepts('sulfur', 'liquid_sulfur'), isFalse);
      expect(db.accepts('liquid_sulfur', 'sulfur'), isFalse);
    });

    test('and nothing claims otherwise any more', () {
      for (final id in ['sweetle', 'sweetle_wild']) {
        final said = db.processOrThrow(id).description ?? '';
        expect(said.toLowerCase(), isNot(contains('solid or liquid')),
            reason: id);
        expect(said, isNot(contains('of liquid sulfur for')), reason: id);
      }
    });

    test('and there is a way to say "freeze it first"', () {
      // Which is what a ranch fed from a geyser actually does, and without it
      // the build simply cannot be drawn.
      final freezing = db.processOrThrow('liquid_sulfur_freezing');
      expect(freezing.inputs.single.itemId, 'liquid_sulfur');
      expect(freezing.outputs.map((p) => p.itemId), contains('sulfur'));

      final ranch = (PipelineBuilder(db, name: 'sulfur ranch')
            ..add('liquid_sulfur_geyser', nodeId: 'geyser')
            ..add('liquid_sulfur_freezing', nodeId: 'freezing')
            ..add('sweetle', nodeId: 'sweetles')
            ..addSource('grooming')
            ..addSink('sucrose')
            ..addSink('heat')
            ..connectItem('geyser', 'freezing', 'liquid_sulfur')
            ..connectItem('freezing', 'sweetles', 'sulfur')
            ..connectItem('src_grooming', 'sweetles', 'grooming')
            ..connectItem('sweetles', 'sink_sucrose', 'sucrose')
            ..connect('freezing', 'heat_out', 'sink_heat', 'in'))
          .build();
      expect(PipelineSolver(db).solve(ranch).status,
          isNot(SolveStatus.invalid));
    });
  });

  group('a Hatch eats rock of any sort', () {
    // The Rock Crusher's sand recipes are the same list, which is why the two
    // share a class — and why the four that were missing were missing from
    // both at once.
    const everyRock = [
      'basalt', 'coquina', 'granite', 'igneous_rock', 'insulite', 'obsidian',
      'sandstone', 'sedimentary_rock', 'shale', 'siltstone',
    ];

    test('all ten of them', () {
      final rocks = db.itemOrThrow('raw_mineral').members;
      for (final rock in everyRock) {
        expect(rocks, contains(rock), reason: rock);
      }
    });

    test('so a volcano can feed a ranch', () {
      // Which was not possible yesterday: igneous rock is what a volcano
      // leaves behind and nothing would take it.
      expect(db.accepts('raw_mineral', 'igneous_rock'), isTrue);
      final fed = (PipelineBuilder(db, name: 'volcano ranch')
            ..add('volcano', nodeId: 'volcano')
            ..add('magma_cooling', nodeId: 'cooling')
            ..add('hatch', nodeId: 'hatches')
            ..addSource('grooming')
            ..addSink('coal')
            ..addSink('heat')
            ..connectItem('volcano', 'cooling', 'magma')
            ..connectItem('cooling', 'hatches', 'igneous_rock')
            ..connectItem('src_grooming', 'hatches', 'grooming')
            ..connectItem('hatches', 'sink_coal', 'coal')
            ..connect('cooling', 'heat_out', 'sink_heat', 'in'))
          .build();
      expect(PipelineSolver(db).solve(fed).status, isNot(SolveStatus.invalid));
    });

    test('and the description says what it still does not model', () {
      final said = db.processOrThrow('hatch').description ?? '';
      expect(said, contains('dirt, sand, clay and regolith'),
          reason: 'eaten, and not part of this recipe');
    });
  });
}
