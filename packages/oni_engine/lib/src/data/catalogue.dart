import '../model/game_database.dart';
import '../model/port.dart';
import '../model/process_spec.dart';

/// One thing that makes an item, and how much of it.
class Maker {
  const Maker({required this.spec, required this.made, required this.takes});

  final ProcessSpec spec;

  /// The port it comes out of.
  final Port made;

  /// What it costs, leaving out Duplicant time — grooming, shearing, milking
  /// are not things you have.
  final List<Port> takes;
}

/// One thing that uses an item, and how much of it.
class Taker {
  const Taker({required this.spec, required this.takes, required this.makes});

  final ProcessSpec spec;

  /// The port it goes into.
  final Port takes;

  /// What comes out of that, so a row says what the cost buys.
  final List<Port> makes;
}

/// Everything that uses one item, biggest first.
class UsedBy {
  const UsedBy({required this.itemId, required this.takers});

  final String itemId;
  final List<Taker> takers;
}

/// Everything that makes one item, biggest first.
class MadeBy {
  const MadeBy({required this.itemId, required this.makers});

  final String itemId;
  final List<Maker> makers;
}

const _care = {'grooming', 'shearing', 'milking'};

/// What goes into a recipe and what comes out, by weight.
///
/// Grams a second of anything that has mass, which is most things and not
/// power, heat, calories or a plant's growth. Both nought where nothing here
/// is weighable.
({double input, double output}) massOf(GameDatabase database, ProcessSpec spec) {
  var input = 0.0;
  var output = 0.0;
  for (final port in spec.ports) {
    final item = database.item(port.itemId);
    if (item == null || !item.hasMass) continue;
    if (port.isInput) {
      input += port.ratePerSecond;
    } else {
      output += port.ratePerSecond;
    }
  }
  return (input: input, output: output);
}

/// How far a recipe is from conserving matter, as a fraction of the larger
/// side: 0.5 makes half again as much as it consumes, -0.5 destroys half.
///
/// Null where the question is not asked. A geyser creates matter, a grill
/// turns grain into calories, a grazed plant turns water into growth — none of
/// those are meant to balance, and a number beside them would read as a fault.
///
/// The same arithmetic the mass-balance audit runs, so what somebody checking
/// a recipe sees is what the test sees.
double? massDrift(GameDatabase database, ProcessSpec spec) {
  if (spec.kind == ProcessKind.source || spec.kind == ProcessKind.sink) {
    return null;
  }
  final mass = massOf(database, spec);
  if (mass.input <= 0 || mass.output <= 0) return null;
  final biggest = mass.input > mass.output ? mass.input : mass.output;
  return (mass.output - mass.input) / biggest;
}

/// The catalogue, grouped by what comes out and sorted by how much.
///
/// Not alphabetical, and the difference is the whole point. Every wrong figure
/// found in this data so far was found by a person reading like against like —
/// a Pip gives 20 kg of dirt a cycle and a Cuddle Pip five eighths of that, so
/// the Pip belongs above it, and while the Pip was wrong at 10 kg it sat below
/// where anybody could see it did not belong. An alphabetical list hides that
/// and a sorted one shows it without the reader knowing either figure.
///
/// A wild twin appears only where it differs from its tame one, which is eggs
/// and nothing else: two identical rows are worse than one, because the eye
/// stops reading a column it has already read.
List<MadeBy> madeBy(GameDatabase database, {bool Function(ProcessSpec)? where}) {
  final specs = [
    for (final spec in database.processes)
      if (where == null || where(spec)) spec,
  ];
  final byId = {for (final spec in specs) spec.id: spec};

  final grouped = <String, List<Maker>>{};
  for (final spec in specs) {
    final takes = [
      for (final port in spec.inputs)
        if (!_care.contains(port.itemId)) port,
    ];
    for (final port in spec.outputs) {
      if (_care.contains(port.itemId)) continue;
      if (spec.id.endsWith('_wild')) {
        final tame = byId[spec.id.substring(0, spec.id.length - 5)];
        final same =
            tame?.outputs.where((p) => p.itemId == port.itemId).firstOrNull;
        if (same != null &&
            (same.ratePerSecond - port.ratePerSecond).abs() < 1e-12) {
          continue;
        }
      }
      (grouped[port.itemId] ??= [])
          .add(Maker(spec: spec, made: port, takes: takes));
    }
  }

  final out = [
    for (final entry in grouped.entries)
      MadeBy(
        itemId: entry.key,
        makers: entry.value
          ..sort((a, b) =>
              b.made.ratePerSecond.compareTo(a.made.ratePerSecond)),
      ),
  ]..sort((a, b) {
      final byName = (database.item(a.itemId)?.name ?? a.itemId)
          .compareTo(database.item(b.itemId)?.name ?? b.itemId);
      return byName;
    });
  return out;
}

/// The catalogue the other way round: what *eats* each thing.
///
/// The half that was missing. Checking that an Orehull eats 20 kg of nori a
/// cycle means finding everything else that eats nori and seeing whether 20 is
/// a number that belongs among them — and there was nowhere to look.
List<UsedBy> usedBy(GameDatabase database, {bool Function(ProcessSpec)? where}) {
  final specs = [
    for (final spec in database.processes)
      if (where == null || where(spec)) spec,
  ];
  final byId = {for (final spec in specs) spec.id: spec};

  final grouped = <String, List<Taker>>{};
  for (final spec in specs) {
    final makes = [
      for (final port in spec.outputs)
        if (!_care.contains(port.itemId)) port,
    ];
    for (final port in spec.inputs) {
      if (_care.contains(port.itemId)) continue;
      if (spec.id.endsWith('_wild')) {
        final tame = byId[spec.id.substring(0, spec.id.length - 5)];
        final same =
            tame?.inputs.where((p) => p.itemId == port.itemId).firstOrNull;
        if (same != null &&
            (same.ratePerSecond - port.ratePerSecond).abs() < 1e-12) {
          continue;
        }
      }
      (grouped[port.itemId] ??= [])
          .add(Taker(spec: spec, takes: port, makes: makes));
    }
  }

  return [
    for (final entry in grouped.entries)
      UsedBy(
        itemId: entry.key,
        takers: entry.value
          ..sort((a, b) =>
              b.takes.ratePerSecond.compareTo(a.takes.ratePerSecond)),
      ),
  ]..sort((a, b) => (database.item(a.itemId)?.name ?? a.itemId)
      .compareTo(database.item(b.itemId)?.name ?? b.itemId));
}
