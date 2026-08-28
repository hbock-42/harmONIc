import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// A figure that does not belong beside its neighbours.
///
/// Every wrong rate found this month was found by a person reading one table
/// against another: the Marine Drill's sulfur four times low, the Orehull's
/// iron ore ten times high, the grazed Arbor Tree ten times low, the Pip's
/// dirt half what it should be. Not one of them was caught by a test, because
/// every test asked whether a figure was plausible *on its own* — and a Pip
/// making 10 kg of dirt a cycle is perfectly plausible until you notice the
/// Cuddle Pip beside it making 13.
///
/// So this one asks the question that actually worked: is this figure in line
/// with the others of its kind making the same thing?
///
/// It is a net rather than a proof, and a coarse one. Two thirds of the app's
/// figures have nothing of their own kind to be compared with at all — the
/// Orehull is the only critter that sheds iron ore, so no amount of reading
/// the column beside it would have caught the ten times it was out for weeks.
/// Of the third that can be compared, a tenfold slip is spotted about a sixth
/// of the time. Worth having because it costs nothing to run and cries wolf at
/// nothing today; not worth trusting further than that.
void main() {
  final db = loadDefaultDatabase();

  test('every rate is in line with the others of its kind', () {
    expect(figuresOutOfLine(db), isEmpty,
        reason: 'a figure out of line with its neighbours is how every wrong '
            'one this month was found. Correct it, or write it into '
            'checkedAndCorrect with the reason');
  });

  test('and it says so when one is moved out of line', () {
    // A Slogo sheds 50 kg of dirt a cycle, four times a Shatter Flox and
    // twice again a Pip. Put a decimal point in the wrong place and it has
    // nothing within four times of it among the ten critters that make dirt,
    // which is what a person notices when they read the column.
    //
    // Twenty rather than ten, because every tame critter here has a wild twin
    // at the same figure: move one by ten and it lands exactly ten times from
    // its own twin, which is the boundary rather than past it.
    final slipped = _withRate(db, 'slogo', 'dirt', 83.333 * 20);
    expect(figuresOutOfLine(slipped).join(), contains('slogo'));

    // And it does not cry wolf over the figure put back.
    expect(figuresOutOfLine(_withRate(db, 'slogo', 'dirt', 83.333)).join(),
        isNot(contains('slogo')));
  });

  test('and it is honest about how much it can see', () {
    // Two thirds of the app's figures have nothing of their own kind to be
    // compared with — the Orehull is the only critter that sheds iron ore, so
    // no amount of reading the column beside it would have caught the ten
    // times it was out for weeks. This audit is a net, not a proof.
    var comparable = 0;
    var total = 0;
    for (final made in madeBy(db)) {
      final byKind = <ProcessKind, int>{};
      for (final maker in made.makers) {
        byKind[maker.spec.kind] = (byKind[maker.spec.kind] ?? 0) + 1;
      }
      for (final count in byKind.values) {
        total += count;
        if (count >= 3) comparable += count;
      }
    }
    expect(comparable * 3, lessThan(total * 2),
        reason: 'if this ever stops being true the audit has grown teeth and '
            'this test should say so instead');
  });
}

/// The same database with one rate changed, for asking what the audit would
/// have said about a figure that got through.
GameDatabase _withRate(
  GameDatabase db,
  String specId,
  String itemId,
  double ratePerSecond,
) {
  final json = db.toJson();
  for (final process in json['processes']! as List<dynamic>) {
    final map = process as Map<String, dynamic>;
    if (map['id'] != specId) continue;
    for (final port in map['ports']! as List<dynamic>) {
      final p = port as Map<String, dynamic>;
      if (p['item'] == itemId && p['direction'] == 'output') {
        p['rate'] = ratePerSecond;
      }
    }
  }
  return GameDatabase.fromJson(json);
}

/// Every figure with nothing near it, among the others of its kind that make
/// the same thing.
List<String> figuresOutOfLine(GameDatabase db) {
  /// How far out of line a figure has to be before it is worth a second look.
  ///
  /// Tenfold: a decimal point in the wrong place, or kilograms typed into a
  /// field measured in grams.
  ///
  /// Four was tried and cost seven false alarms — a Sludge Press and a Compost
  /// both make dirt and one is thirty times the other, which is what they are
  /// rather than a mistake. So the net is a coarse one, and the Marine Drill's
  /// sulfur, out by four, would still go straight through it.
  const double outOfLine = 10;

  final odd = <String>[];
    for (final made in madeBy(db)) {
      // Heat and power span orders of magnitude on purpose: a lamp and an
      // Aquatuner are both buildings and one of them is four hundred times the
      // other, which is the point of them rather than a mistake.
      if (made.itemId == WellKnownItems.heat ||
          made.itemId == WellKnownItems.power) {
        continue;
      }
      // Compared with its own sort: a Rock Crusher and a critter both make
      // sand, and one of them is a machine.
      final byKind = <ProcessKind, List<Maker>>{};
      for (final maker in made.makers) {
        // A pump, a filter and an Aquatuner do not *make* what comes out of
        // them, they move it, and they move it by the tonne. Anything with the
        // same thing on both sides is carrying rather than producing.
        final carries = maker.spec.inputs
            .any((port) => port.itemId == made.itemId);
        if (carries) continue;
        // Only where this is what the recipe is *for*. A Natural Gas
        // Generator's polluted water and a Water Sieve's water are both water
        // and only one of them is the point of the machine, so lining them up
        // beside each other says nothing about either.
        if (!isTheProduct(db, maker.spec, made.itemId)) continue;
        byKind.putIfAbsent(maker.spec.kind, () => []).add(maker);
      }
      for (final entry in byKind.entries) {
        final makers = entry.value;
        // Two figures cannot tell you which of them is the odd one.
        if (makers.length < 3) continue;
        final rates = [for (final m in makers) m.made.ratePerSecond];

        // Not a median: nine Dehydrators making the same 20 g/s of water drag
        // one down, and a Steam Turbine is then the odd one out for making
        // water at the rate water machines make it. What a person actually
        // notices is a figure with *nothing near it* — the Orehull ten times
        // above every other critter, with no company in between.
        for (var i = 0; i < makers.length; i++) {
          final rate = rates[i];
          if (rate <= 0) continue;
          var nearest = double.infinity;
          for (var j = 0; j < rates.length; j++) {
            // By position, not by value: three Kilns making refined carbon at
            // the same rate are each other's company, and comparing a double
            // with itself by value threw all three away.
            if (i == j || rates[j] <= 0) continue;
            final ratio =
                rates[j] > rate ? rates[j] / rate : rate / rates[j];
            if (ratio < nearest) nearest = ratio;
          }
          if (nearest < outOfLine) continue;
          final spec = makers[i].spec;
          if (checkedAndCorrect.containsKey(spec.id)) continue;
          odd.add('${spec.id} makes ${made.itemId} at '
              '${rate.toStringAsFixed(4)} g/s, with nothing within '
              '${nearest.toStringAsFixed(0)}× of it among the '
              '${makers.length} ${entry.key.name}s that make it');
        }
      }
    }

  return odd;
}

/// Whether this is what the recipe is for, rather than what falls out of it.
///
/// A tenth of the biggest thing it makes: below that it is a byproduct, and a
/// byproduct's size is a fact about the main product rather than about itself.
bool isTheProduct(GameDatabase db, ProcessSpec spec, String itemId) {
  var biggest = 0.0;
  for (final port in spec.outputs) {
    final item = db.item(port.itemId);
    if (item == null || !item.hasMass) continue;
    if (port.ratePerSecond > biggest) biggest = port.ratePerSecond;
  }
  if (biggest <= 0) return false;
  for (final port in spec.outputs) {
    if (port.itemId != itemId) continue;
    final item = db.item(itemId);
    if (item == null || !item.hasMass) return false;
    return port.ratePerSecond >= biggest / 10;
  }
  return false;
}

/// Figures that stand out and are right anyway, with why.
const Map<String, String> checkedAndCorrect = <String, String>{};
