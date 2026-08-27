import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// The catalogue: everything the app knows, grouped by what comes out.
///
/// For somebody checking the figures. It is not a list of recipes — it is the
/// same thing beside itself, sorted, because that is how every wrong figure in
/// this data has been found.
void main() {
  final db = loadDefaultDatabase();
  final critters =
      madeBy(db, where: (spec) => spec.kind == ProcessKind.critter);

  MadeBy of(String itemId) =>
      critters.firstWhere((entry) => entry.itemId == itemId);

  test('groups by what comes out, and sorts by how much', () {
    final dirt = of('dirt');
    final rates = [for (final m in dirt.makers) m.made.ratePerSecond];

    expect(rates.length, greaterThan(2));
    for (var i = 1; i < rates.length; i++) {
      expect(rates[i], lessThanOrEqualTo(rates[i - 1]));
    }
  });

  test('so a figure that cannot be right sits where it cannot be', () {
    // A Cuddle Pip gives five eighths of a Pip's dirt, so the Pip is above it.
    // While the Pip was wrong at half what it makes, it sat below — which
    // anybody can see is impossible without knowing either number.
    final order = [for (final m in of('dirt').makers) m.spec.id];

    expect(order.indexOf('pip'), isNonNegative);
    expect(order.indexOf('cuddle_pip'), greaterThan(order.indexOf('pip')));
  });

  test('and a wild twin only appears where it differs', () {
    // Its dirt is its tame one's, so one row; its eggs are a tenth, so two.
    expect(
      [for (final m in of('dirt').makers) m.spec.id],
      isNot(contains('pip_wild')),
    );
    expect(
      [for (final m in of('egg').makers) m.spec.id],
      contains('pip_wild'),
    );
  });

  test('Duplicant time is not a thing you have', () {
    // Grooming and shearing are ports, and listing them as what a critter
    // "takes" would put a Duplicant's hands in a column of kilograms.
    for (final entry in critters) {
      for (final maker in entry.makers) {
        expect(
          [for (final port in maker.takes) port.itemId],
          isNot(anyElement(isIn(['grooming', 'shearing', 'milking']))),
        );
      }
    }
    expect(critters.map((e) => e.itemId), isNot(contains('grooming')));
  });

  test('and every critter that makes anything is in it', () {
    final listed = {
      for (final entry in critters)
        for (final maker in entry.makers) maker.spec.id,
    };
    for (final spec in db.processes) {
      if (spec.kind != ProcessKind.critter) continue;
      if (spec.outputs.every((p) => p.itemId == 'grooming')) continue;
      if (spec.id.endsWith('_wild')) continue;
      expect(listed, contains(spec.id), reason: spec.id);
    }
  });
}
