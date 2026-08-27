import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// How many of a thing you are told to build.
///
/// Reported from the Discord: "Ethanol Distiller will say 4.00× Build 5, 80%".
/// The count printed had rounded down to 4.00 and the count built had rounded
/// up to 5, off the back of the same number.
void main() {
  NodeResult counting(double count) => NodeResult(
        nodeId: 'n',
        specId: 's',
        kind: ProcessKind.building,
        count: count,
        uptime: 1,
        powerWatts: 0,
        heatKdtu: 0,
        dupeLabourSecondsPerCycle: 0,
      );

  test('a count whole to within a rounding error is whole', () {
    // An Arbor Tree makes 555.55 g/s of lumber, which is six digits of a
    // number that does not end, so four distillers' worth arrives like this.
    final still = counting(4.0000024);

    expect(still.wholeCount, 4);
    expect(still.utilisation, closeTo(1, 1e-6));
  });

  test('and one that is genuinely over still rounds up', () {
    // The slack is a millionth, not a percent: no rate in this data carries
    // more than six significant digits, and 4.01 distillers is a fifth
    // distiller however inconvenient that is.
    expect(counting(4.01).wholeCount, 5);
    expect(counting(4.000005).wholeCount, 5);
  });

  test('the slack scales with the count, since the error does', () {
    // 200 kelpoles carry two hundred times one kelpole's rounding.
    expect(counting(200.00002).wholeCount, 200);
    expect(counting(200.5).wholeCount, 201);
  });

  test('nothing is still nothing, and a fraction is still one', () {
    expect(counting(0).wholeCount, 0);
    expect(counting(0.15).wholeCount, 1);
  });
}
