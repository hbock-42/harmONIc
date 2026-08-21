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

/// Formatting helpers. Deliberately in the engine so the CLI/tests and the app
/// print numbers the same way.
extension UnitFormatting on Unit {
  /// Formats a per-second [value] using the friendliest magnitude.
  String format(double value, {int precision = 2}) {
    switch (this) {
      case Unit.gramsPerSecond:
        final abs = value.abs();
        if (abs >= 1000) {
          return '${(value / 1000).toStringAsFixed(precision)} kg/s';
        }
        return '${value.toStringAsFixed(precision)} g/s';
      case Unit.watts:
        final abs = value.abs();
        if (abs >= 1000) {
          return '${(value / 1000).toStringAsFixed(precision)} kW';
        }
        return '${value.toStringAsFixed(precision)} W';
      case Unit.kdtuPerSecond:
        return '${value.toStringAsFixed(precision)} kDTU/s';
      case Unit.count:
        return value.toStringAsFixed(precision);
    }
  }

  /// Same value expressed per cycle, for the "per cycle" display toggle.
  double perCycle(double perSecond) => perSecond * secondsPerCycle;
}
