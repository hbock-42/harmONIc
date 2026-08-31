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
    this.alternatives = const [],
    this.excludes = const [],
    this.needsPortId,
    this.withoutFactor = 0,
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
      alternatives: [
        ...(json['alternatives'] as List<dynamic>? ?? const []).cast<String>(),
      ],
      excludes: [
        ...(json['excludes'] as List<dynamic>? ?? const []).cast<String>(),
      ],
      needsPortId: json['needs'] as String?,
      withoutFactor: (json['withoutFactor'] as num?)?.toDouble() ?? 0,
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

  /// Other materials this port will take, at the same rate.
  ///
  /// A Smoker burns "either Peat or Wood", 100 kg of it whichever you use. That
  /// is not a class — the game has no "peat or wood" material, and inventing
  /// one puts a supply node in the palette that nobody could ever own — and it
  /// is not two recipes either, since the recipe is the same recipe.
  ///
  /// The rate has to be identical for every option. Where it is not, the
  /// alternatives are genuinely different recipes: a Plug Slug eats 60 kg of
  /// ore a cycle or 30 kg of refined metal, and that is two specs.
  final List<String> alternatives;

  /// Members of the class this port asks for that it will *not* take.
  ///
  /// A Metal Refinery takes any metal ore and gives back the metal it came
  /// from, kilogram for kilogram — except galena, which is 87 % lead and 13 %
  /// sulfur and is therefore a different recipe with its own spec. Without
  /// this the class would be a small lie: "any ore" would include the one ore
  /// the figures beside it do not describe.
  ///
  /// An exception, and meant to stay one. A class riddled with exclusions is a
  /// class that was drawn wrong.
  final List<String> excludes;

  /// Every material this port would accept, the declared one first.
  List<String> get accepted => [itemId, ...alternatives];

  /// The input port whose material decides this one's.
  ///
  /// A Metal Refinery fed copper ore gives back copper, not "some metal". The
  /// choice is made once, on the input, and the output follows it — nobody
  /// should have to say it twice, and saying it twice would let them disagree.
  final String? followsPortId;

  /// The input port this output only exists because of.
  ///
  /// A Glo Squid gives squid ink because somebody milks it. Stop milking and
  /// it still eats, still grows, still sheds abyssalite — and gives no ink. A
  /// ranch run that way is a real ranch, and until this there was no way to
  /// draw one: both ports were simply there, so the ink came whether anybody
  /// went to the trouble or not.
  ///
  /// Asked for as "dynamic output based on provided input lines". It is one
  /// input turning one output on and off, which is narrower than that and is
  /// the part that can be said exactly. A Critter Condo, which changes a rate
  /// rather than removing an output, still cannot be said.
  final String? needsPortId;

  /// What is left of this port when [needsPortId] is declined, as a fraction.
  ///
  /// Zero for a thing that simply stops: no milking, no ink. But most of what
  /// an input buys is a matter of degree rather than of presence. A groomed
  /// critter lays at 1225 % and an ungroomed one at 100 %, so stopping the
  /// grooming leaves the eggs at 100/1225 of what they were and everything
  /// else about the animal exactly as it was — it eats the same and produces
  /// the same, because metabolism does not care how happy it is.
  ///
  /// An unattended ranch is a real and common way to keep critters, and until
  /// this there was no way to draw one: declining the grooming was not
  /// possible, and not wiring it meant "somebody outside is doing it".
  final double withoutFactor;

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
        if (alternatives.isNotEmpty) 'alternatives': alternatives,
        if (excludes.isNotEmpty) 'excludes': excludes,
        if (needsPortId != null) 'needs': needsPortId,
        if (withoutFactor != 0) 'withoutFactor': withoutFactor,
      };

  @override
  String toString() => 'Port($id ${direction.name} $ratePerSecond)';
}
