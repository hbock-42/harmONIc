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

/// Everything that makes one item, biggest first.
class MadeBy {
  const MadeBy({required this.itemId, required this.makers});

  final String itemId;
  final List<Maker> makers;
}

const _care = {'grooming', 'shearing', 'milking'};

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
