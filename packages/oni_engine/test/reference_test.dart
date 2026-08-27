import 'dart:io';

import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

import '../tool/gen_reference.dart' as reference;

/// The reference pages are the shipped data, written out.
///
/// A page that has drifted from the data is worse than no page: somebody
/// checking a figure against it would be checking it against the wrong thing,
/// and the whole point of writing them down is that a person can catch what a
/// test cannot.
void main() {
  final db = loadDefaultDatabase();

  test('the critters page is the one the generator makes', () {
    expect(
      File('../../docs/reference/critters.md').readAsStringSync(),
      reference.critters(db),
      reason: 'run dart run tool/gen_reference.dart',
    );
  });

  test('and it holds every critter the app has', () {
    final page = File('../../docs/reference/critters.md').readAsStringSync();
    final critters = db.processes.where((p) => p.kind == ProcessKind.critter);

    expect(critters, isNotEmpty);
    for (final spec in critters) {
      // A wild twin only earns a row where it differs, so it is the tame ones
      // that must all be there.
      if (spec.id.endsWith('_wild')) continue;
      // And one that gives nothing but Duplicant time has nothing to compare.
      if (spec.outputs.isEmpty) continue;
      expect(page, contains('| ${spec.name} '),
          reason: '${spec.id} is not on the page');
    }
  });

  test('and sorts each thing by the figure, which is the point of it', () {
    // Alphabetical hides a ten-times slip. A column of the same item, biggest
    // first, puts it at the top where it does not belong — which is how every
    // wrong figure in this data has been found so far.
    final page = File('../../docs/reference/critters.md').readAsStringSync();
    final dirt = page
        .split('### Dirt\n')[1]
        .split('###')
        .first
        .split('\n')
        .where((line) => line.startsWith('| ') && !line.startsWith('|---'))
        .skip(1) // the header row
        .toList();

    expect(dirt.length, greaterThan(2));
    // A Pip makes 20 kg of dirt a cycle and a Cuddle Pip five eighths of that,
    // so the Pip comes first. It was the other way round for a week.
    final pip = dirt.indexWhere((line) => line.startsWith('| Pip '));
    final cuddle = dirt.indexWhere((line) => line.startsWith('| Cuddle Pip '));
    expect(pip, isNonNegative);
    expect(cuddle, greaterThan(pip));
  });
}
