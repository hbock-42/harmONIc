import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// Ranching without a Duplicant.
///
/// Asked for as "toggles for grooming, Condos, Ink and Brackene". Brackene
/// turned out not to need a toggle at all: five kilograms of it a cycle makes
/// a critter as happy as grooming does, and grooming is already a thing one
/// building hands to another. A Critter Fountain is simply a second place to
/// get it — so every critter in the app can be kept either way, and none of
/// them had to change.
void main() {
  final db = loadDefaultDatabase();

  test('a fountain gives the same thing a grooming station does', () {
    final station = db.processOrThrow('grooming_station');
    final fountain = db.processOrThrow('critter_fountain');
    for (final spec in [station, fountain]) {
      expect(spec.outputs.map((p) => p.itemId), contains('grooming'),
          reason: spec.id);
    }
    expect(fountain.inputs.map((p) => p.itemId), contains('brackene'));
  });

  test('so a ranch can run on a pipe instead of somebody’s time', () {
    final byPipe = (PipelineBuilder(db, name: 'fountain ranch')
          ..add('critter_fountain', nodeId: 'fountain')
          ..addSource('brackene')
          ..add('hatch', nodeId: 'hatches')
          ..addSource('raw_mineral')
          ..addSink('coal')
          ..connectItem('src_brackene', 'fountain', 'brackene')
          ..connectItem('fountain', 'hatches', 'grooming')
          ..connectItem('src_raw_mineral', 'hatches', 'raw_mineral')
          ..connectItem('hatches', 'sink_coal', 'coal')
          ..pinCount('hatches', 8))
        .build();

    final solution = PipelineSolver(db).solve(byPipe);
    expect(solution.status, SolveStatus.solved);
    expect(solution.nodes['fountain']!.count, closeTo(1, 1e-6),
        reason: 'one fountain keeps the eight it is built for');

    // The point of the exercise: nobody is standing there doing it.
    expect(solution.nodes['fountain']!.dupeLabourSecondsPerCycle, 0);
  });

  test('and the brackene has somewhere to come from', () {
    final made = db.processOrThrow('plant_pulverizer_nosh_bean');
    expect(made.inputs.map((p) => p.itemId), containsAll(['nosh_bean', 'water']));
    // The heat it gives off is an output too, so this has to say which one it
    // means.
    final brackene =
        made.outputs.firstWhere((p) => p.itemId == 'brackene');
    // 2 kg of beans and 18 of water make 20 kg, which is a batch that keeps
    // its weight -- unlike the gum wood one, which loses half.
    final inMass = made.inputs.fold<double>(0, (sum, p) => sum + p.ratePerSecond);
    expect(inMass, closeTo(brackene.ratePerSecond, 1e-6));
  });

  test('the Plant Pulverizer is one building with four recipes now', () {
    final recipes = db.processes.where((s) => s.buildingId == 'plant_pulverizer');
    expect(recipes.map((s) => s.id), containsAll([
      'plant_pulverizer_gum_wood',
      'plant_pulverizer_slime',
      'plant_pulverizer_nosh_bean',
      'plant_pulverizer_amber',
    ]));
    // And they are offered to each other, so picking the wrong one costs a
    // click rather than a rebuild.
    expect(db.variantsOf(db.processOrThrow('plant_pulverizer_amber')).length,
        greaterThan(3));
  });

  test('and it says why it is allowed to stand in for grooming', () {
    // The whole design rests on one published number. Grooming is +5
    // happiness and a fountain is +5 happiness, so they are the same thing to
    // a critter, and a fountain can hand over the very item a Grooming
    // Station hands over. If that were ever found to be wrong, this model is
    // wrong and not merely imprecise -- so the reason is on the card.
    final said = db.processOrThrow('critter_fountain').description ?? '';
    expect(said, contains('+5 happy'));
    expect(said, contains('1225'));
    // And it says what a Condo is not, because the obvious next thought is
    // that a Condo would do as well.
    expect(said, contains('Condo'));
    expect(said, contains('325'));
  });
}
