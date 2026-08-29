import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// Float noise must read as nothing, not as a very precise nothing.
///
/// Reported from a 46-node build full of them: wires carrying no flow at all
/// showed "0.000000 kJ/cycle", and some of them "-0.000000 g/cycle", which
/// reads as a flow going backwards. Both come from the same place — the
/// per-cycle figures were formatted straight instead of through the rounding
/// that the per-second ones have always used, and the digit escalation that
/// exists so a real trickle is not printed as "0.00" kept widening a zero.
void main() {
  final db = loadDefaultDatabase();
  final power = db.itemOrThrow('power');
  final water = db.itemOrThrow('water');
  final egg = db.itemOrThrow('egg');

  test('a wire carrying nothing says so plainly', () {
    for (final display in RateDisplay.values) {
      expect(power.formatRate(0, display), isNot(contains('000000')),
          reason: '$display');
      expect(water.formatRate(0, display), isNot(contains('000000')),
          reason: '$display');
    }
  });

  test('and so does one carrying float noise', () {
    for (final display in RateDisplay.values) {
      for (final noise in [1e-12, 1e-9, -1e-12, -1e-9]) {
        final said = power.formatRate(noise, display);
        expect(said, isNot(contains('000000')), reason: '$noise $display');
      }
    }
  });

  test('and never with a minus sign in front of a nothing', () {
    // "-0.0" reads as a flow going the wrong way, which is a thing a person
    // will go and look for and not find.
    for (final display in RateDisplay.values) {
      for (final item in [power, water, egg]) {
        for (final noise in [-1e-12, -1e-9, -0.0]) {
          expect(item.formatRate(noise, display), isNot(startsWith('-')),
              reason: '${item.id} $noise $display');
        }
      }
    }
  });

  test('though a flow that really does run backwards keeps its sign', () {
    // Which is the point of the rule above being about rounding rather than
    // about being small: a build running backwards is a thing worth seeing,
    // and the solver already says so in words.
    expect(water.formatRate(-2000, RateDisplay.perSecond), startsWith('-'));
    expect(water.formatRate(-0.001, RateDisplay.perCycle), startsWith('-'),
        reason: '0.6 g a cycle backwards is small and it is not nothing');
  });

  test('but a real trickle still gets the digits it needs', () {
    // The reason the escalation is there: a Hatch lays an egg every 1.4
    // cycles, and "0.00" would say it lays none.
    final laid = egg.formatRate(0.0024 / 600, RateDisplay.perCycle);
    expect(double.parse(laid.split(' ').first), greaterThan(0),
        reason: 'reads as some eggs rather than no eggs: $laid');
  });

  test('and an ordinary figure is not made ugly by any of this', () {
    expect(water.formatRate(1000, RateDisplay.perSecond), '1.00 kg/s');
    expect(power.formatRate(850, RateDisplay.perSecond), '850.00 W');
  });
}
