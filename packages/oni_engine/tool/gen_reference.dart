// Regenerates docs/reference/*.md from the shipped data.
//
//   dart run tool/gen_reference.dart
//
// A page nobody proofreads is worth nothing, and an alphabetical dump of 273
// recipes is a page nobody proofreads. What catches a wrong number is
// comparison: the same kind of thing beside itself, sorted by the figure, so
// an Orehull yielding ten times what it should sits at the top of a column
// where it does not belong. Every error found in this data so far has been
// found that way, by a person, reading one table against another.
//
// Generated rather than written, and checked by a test, so it cannot come to
// disagree with what the app actually uses.
import 'dart:io';

import 'package:oni_engine/oni_engine.dart';

void main() {
  final db = loadDefaultDatabase();
  Directory('../../docs/reference').createSync(recursive: true);
  File('../../docs/reference/critters.md')
      .writeAsStringSync(critters(db));
  stdout.writeln('wrote docs/reference/critters.md');
}

/// Per cycle, which is how the game quotes a critter and how anybody checking
/// one thinks. Grams a second is right for a pipe and wrong for a Hatch.
String _perCycle(GameDatabase db, String itemId, double ratePerSecond) {
  final item = db.item(itemId);
  final perCycle = ratePerSecond * secondsPerCycle;
  if (item?.unit == Unit.gramsPerSecond) {
    return perCycle >= 1000
        ? '${(perCycle / 1000).toStringAsFixed(perCycle >= 10000 ? 0 : 1)} kg'
        : '${perCycle.toStringAsFixed(perCycle >= 10 ? 0 : 2)} g';
  }
  if (perCycle >= 100) return perCycle.toStringAsFixed(0);
  return perCycle.toStringAsFixed(perCycle >= 1 ? 2 : 3);
}

String _name(GameDatabase db, String itemId) =>
    db.item(itemId)?.name ?? itemId;

/// The tended-by ports: not things, but Duplicant time.
const _care = {'grooming', 'shearing', 'milking'};

String critters(GameDatabase db) {
  final all = [
    for (final spec in db.processes)
      if (spec.kind == ProcessKind.critter) spec,
  ]..sort((a, b) => a.name.compareTo(b.name));

  final out = StringBuffer()
    ..writeln('# Critters')
    ..writeln()
    ..writeln('Every critter this app knows, and every figure it uses for '
        'them. Rates are **per cycle**, which is how the game quotes a critter '
        'and how anybody checking one thinks.')
    ..writeln()
    ..writeln('Generated from the shipped data by '
        '`dart run tool/gen_reference.dart`, so it cannot disagree with what '
        'the app uses. If a number here is wrong, the app is wrong: say so at '
        'https://github.com/hbock-42/harmONIc/issues and quote the row.')
    ..writeln()
    ..writeln('A row marked **unverified** is one where something is a '
        'judgement rather than a published figure; the recipe says which part.')
    ..writeln();

  // Sorted by what each thing makes, because that is where an error shows.
  // Alphabetical hides a ten-times slip; a column of the same item does not.
  final byId = {for (final spec in all) spec.id: spec};
  final byOutput = <String, List<(ProcessSpec, Port)>>{};
  for (final spec in all) {
    for (final port in spec.outputs) {
      if (_care.contains(port.itemId)) continue;
      // A wild twin that gives the same as its tame one is a second identical
      // row, and two identical rows are worse than one: the eye stops reading
      // a column it has already read. Where they differ — eggs, always — the
      // wild one earns its line.
      if (spec.id.endsWith('_wild')) {
        final tame = byId[spec.id.substring(0, spec.id.length - 5)];
        final same = tame?.outputs
            .where((p) => p.itemId == port.itemId)
            .firstOrNull;
        if (same != null &&
            (same.ratePerSecond - port.ratePerSecond).abs() < 1e-12) {
          continue;
        }
      }
      (byOutput[port.itemId] ??= []).add((spec, port));
    }
  }

  out
    ..writeln('## What they give, one thing at a time')
    ..writeln()
    ..writeln('Read down a column, not across the page. Two critters giving '
        'the same thing should be within reach of each other, and the one '
        'that is not is the one to check.')
    ..writeln();

  final items = byOutput.keys.toList()
    ..sort((a, b) => _name(db, a).compareTo(_name(db, b)));
  for (final itemId in items) {
    final rows = byOutput[itemId]!
      ..sort((a, b) => b.$2.ratePerSecond.compareTo(a.$2.ratePerSecond));
    out
      ..writeln('### ${_name(db, itemId)}')
      ..writeln()
      ..writeln('| Critter | Per cycle | Eats | Per cycle |')
      ..writeln('|---|--:|---|--:|')
    ;
    for (final (spec, port) in rows) {
      final food = spec.inputs
          .where((p) => !_care.contains(p.itemId))
          .toList();
      final eats = food.isEmpty
          ? 'nothing'
          : food.map((p) => _name(db, p.itemId)).join(', ');
      final eaten = food.isEmpty
          ? '—'
          : food.map((p) => _perCycle(db, p.itemId, p.ratePerSecond)).join(', ');
      final flag = spec.tags.contains('unverified') ? ' *(unverified)*' : '';
      out.writeln('| ${spec.name}$flag '
          '| ${_perCycle(db, itemId, port.ratePerSecond)} '
          '| $eats | $eaten |');
    }
    out.writeln();
  }

  return out.toString();
}
