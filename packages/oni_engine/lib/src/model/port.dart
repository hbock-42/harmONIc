/// The temperature most buildings stop working at.
///
/// Nearly everything in the game shares this figure — Electrolyzers, pumps,
/// sieves, refineries — so a flow hotter than this is worth a second look
/// wherever it lands. It is not a promise that something *will* overheat: that
/// depends on the building's own temperature, its material and what else is
/// touching it, none of which a flow model can see.
const double commonOverheatCelsius = 75;

/// Which way an item moves through a port.
enum PortDirection {
  input,
  output;

  static PortDirection parse(String raw) => PortDirection.values.firstWhere(
        (d) => d.name == raw,
        orElse: () => throw FormatException('Unknown port direction "$raw"'),
      );
}

/// One item stream of a process, expressed **per running unit, per second**.
///
/// An Electrolyzer has `input(water, 1000 g/s)`, `output(oxygen, 888 g/s)`,
/// `output(hydrogen, 112 g/s)`, `input(power, 120 W)`.
class Port {
  const Port({
    required this.id,
    required this.itemId,
    required this.direction,
    required this.ratePerSecond,
    this.temperatureC,
    this.followsPortId,
  });

  factory Port.fromJson(Map<String, dynamic> json) {
    final itemId = json['item'] as String;
    return Port(
      id: json['id'] as String? ?? itemId,
      itemId: itemId,
      direction: PortDirection.parse(json['direction'] as String),
      ratePerSecond: (json['rate'] as num).toDouble(),
      temperatureC: (json['temperatureC'] as num?)?.toDouble(),
      followsPortId: json['follows'] as String?,
    );
  }

  /// Unique within a [ProcessSpec]. Defaults to the item id, which is enough
  /// unless a process has two ports for the same item.
  final String id;
  final String itemId;
  final PortDirection direction;

  /// Always positive. The direction carries the sign.
  final double ratePerSecond;

  /// Output temperature in °C, when the game fixes it (Electrolyzer O2 = 70 °C).
  final double? temperatureC;

  /// The input port whose material decides this one's.
  ///
  /// A Metal Refinery fed copper ore gives back copper, not "some metal". The
  /// choice is made once, on the input, and the output follows it — nobody
  /// should have to say it twice, and saying it twice would let them disagree.
  final String? followsPortId;

  /// Hot enough to be worth noticing before you plumb it into something.
  bool get runsHot =>
      temperatureC != null && temperatureC! > commonOverheatCelsius;

  bool get isInput => direction == PortDirection.input;
  bool get isOutput => direction == PortDirection.output;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'item': itemId,
        'direction': direction.name,
        'rate': ratePerSecond,
        if (temperatureC != null) 'temperatureC': temperatureC,
        if (followsPortId != null) 'follows': followsPortId,
      };

  @override
  String toString() => 'Port($id ${direction.name} $ratePerSecond)';
}
