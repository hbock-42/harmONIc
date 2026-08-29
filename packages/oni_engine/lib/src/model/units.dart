/// Canonical internal units. The solver *only* ever sees these; every
/// human-facing conversion (kg/s, t/cycle, kW) happens at the presentation edge.
enum Unit {
  /// Mass flow. Solids, liquids and gases are all grams per second.
  gramsPerSecond('g/s'),

  /// Electrical power.
  watts('W'),

  /// Heat production (ONI's own unit).
  kdtuPerSecond('kDTU/s'),

  /// A count of entities (duplicants, critters, plants) that simply exist.
  count('');

  const Unit(this.symbol);

  final String symbol;
}

/// One ONI cycle in seconds.
const double secondsPerCycle = 600;

/// Whether rates read per second or per cycle.
///
/// Both are right, and which one is useful depends on the question: pipes and
/// vents are sized per second, while the wiki, the game's own tooltips and any
/// sentence beginning "how much do I get out of this" are per cycle.
enum RateDisplay {
  perSecond,
  perCycle;

  RateDisplay get other =>
      this == RateDisplay.perSecond ? RateDisplay.perCycle : RateDisplay.perSecond;

  String get label => this == RateDisplay.perSecond ? 'g/s' : 'kg/cycle';
}

/// Formatting helpers. Deliberately in the engine so the CLI/tests and the app
/// Fixed-point, without the minus sign on a number that rounds to nothing.
///
/// A trickle of -0.004 g/s is float noise, and "-0.0 g/s" reads as a flow
/// going the wrong way. Reported from a build full of them: "-0.000000
/// g/cycle" on wires that were carrying nothing at all, because the per-cycle
/// figures were formatted straight rather than through here.
String fixedRate(double value, int precision) {
  final text = value.toStringAsFixed(precision);
  return text.startsWith('-') && double.parse(text) == 0
      ? text.substring(1)
      : text;
}

/// print numbers the same way.
extension UnitFormatting on Unit {
  /// Formats a per-second [value] using the friendliest magnitude.
  String format(double value, {int precision = 2}) {
    switch (this) {
      case Unit.gramsPerSecond:
        final abs = value.abs();
        if (abs >= 1000) {
          return '${_fixed(value / 1000, precision)} kg/s';
        }
        return '${_fixed(value, precision)} g/s';
      case Unit.watts:
        final abs = value.abs();
        if (abs >= 1000) {
          return '${_fixed(value / 1000, precision)} kW';
        }
        return '${_fixed(value, precision)} W';
      case Unit.kdtuPerSecond:
        return '${_fixed(value, precision)} kDTU/s';
      case Unit.count:
        return _fixed(value, precision);
    }
  }

  static String _fixed(double value, int precision) =>
      fixedRate(value, precision);

  /// Same value expressed per cycle, for the "per cycle" display toggle.
  double perCycle(double perSecond) => perSecond * secondsPerCycle;
}
