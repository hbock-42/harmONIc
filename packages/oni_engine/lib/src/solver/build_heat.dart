import '../model/game_database.dart';
import '../model/units.dart';
import '../model/overheating.dart';
import '../model/process_spec.dart';

/// What a building has to be made of, given what runs through it.
///
/// [Overheating] answers the general question — what in the whole game holds
/// 95 °C — and that is the wrong question in front of a particular building.
/// The game does not let you choose freely: an Electrolyzer is built out of
/// 200 kg of *metal ore*, so "ceramic would do" is no use, and the real answer
/// is which of the ores will do.
///
/// So this narrows the table to what the building actually asks for. The
/// result is usually one of three shapes, and each is worth a different
/// sentence: anything in the class holds, only some of it does, or none of it
/// does and the building cannot be put here at all.
class MaterialVerdict {
  const MaterialVerdict({
    required this.materialId,
    required this.celsius,
    required this.holds,
    required this.fails,
  });

  /// What the build cost names — a class such as `metal_ore`, or a single
  /// material when the game asks for one thing.
  final String materialId;

  /// The temperature this was judged against.
  final double celsius;

  /// Members that survive it, coolest-tolerating first: the first name is the
  /// cheapest thing that works, which is the one anybody actually wants.
  final List<String> holds;

  /// Members that do not.
  final List<String> fails;

  /// Nothing you could build it from survives. A real answer, and the only one
  /// here that says *do not build this*.
  bool get isImpossible => holds.isEmpty;

  /// Every member holds, so the choice is free and not worth a warning.
  bool get isFree => fails.isEmpty;
}

/// The verdict on each material a building is put up with.
///
/// Only materials that have a choice to report come back: a cost with a single
/// candidate that holds says nothing anybody needs to read.
List<MaterialVerdict> materialVerdicts(
  ProcessSpec spec,
  GameDatabase database,
  double celsius,
) {
  // A building the game rates itself is not made safer or less safe by what
  // you build it out of, so there is no choice here to report.
  if (spec.overheatCelsius != null) return const [];

  final verdicts = <MaterialVerdict>[];
  for (final materialId in spec.buildCost.keys) {
    final item = database.item(materialId);
    // Counted parts are not what a building's tolerance comes from. Four
    // gaskets are four gaskets whatever the turbine is plumbed into, and
    // "no gasket holds 95 °C" is a sentence about nothing.
    if (item?.unit == Unit.count) continue;
    // A class stands for its members; anything else stands for itself. A
    // material the database has never heard of is skipped rather than guessed
    // at, since its tolerance would be the bare 75 °C by default and that would
    // read as a checked figure.
    final candidates = item == null
        ? const <String>[]
        : (item.members.isEmpty ? [materialId] : item.members);
    if (candidates.isEmpty) continue;

    final holds = Overheating.survivorsAmong(candidates, celsius);
    verdicts.add(MaterialVerdict(
      materialId: materialId,
      celsius: celsius,
      holds: holds,
      fails: [
        for (final id in candidates)
          if (!holds.contains(id)) id,
      ],
    ));
  }
  return verdicts;
}
