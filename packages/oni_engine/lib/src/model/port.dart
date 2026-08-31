/// The temperature most buildings stop working at.
///
/// Nearly everything in the game shares this figure — Electrolyzers, pumps,
/// sieves, refineries — so a flow hotter than this is worth a second look
/// wherever it lands. It is not a promise that something *will* overheat: that
/// depends on the building's own temperature, its material and what else is
/// touching it, none of which a flow model can see.
const double commonOverheatCelsius = 75;

/// How fast a critter lays at [happiness] points, against laying at none.
///
/// The game's table, and it is a straight line only on the happy side: each
/// point above zero is worth another 225 %, so 0 lays at 100 %, 1 at 325 % and
/// 5 at 1225 %. Below zero it is flat -- a glum critter lays at 100 % like a
/// contented one -- until -10, where it stops laying altogether.
///
/// The flat part matters more than it looks, because **a tamed critter starts
/// at -1**. That is the fact this was written without, and getting it wrong
/// made every figure here too generous: grooming buys five points, so a
/// groomed critter sits at 4 and lays at 1000 %, not the 1225 % this said. A
/// Critter Condo buys one point, which takes an ungroomed critter from -1 to
/// 0 -- and 0 lays exactly what -1 lays. The Condo alone is worth no eggs at
/// all. What it is worth is [metabolismAt].
double layingAt(double happiness) {
  if (happiness <= -10) return 0;
  if (happiness < 0) return 1;
  return 1 + 2.25 * happiness;
}

/// What a critter eats and makes at [happiness] points, as a fraction.
///
/// The other column of the same table, and it is a cliff rather than a slope:
/// "Glum, tame, critters have -80 % metabolism offset", so anything below zero
/// eats a fifth and produces a fifth, and zero and above eats and produces the
/// whole of it.
///
/// This is the whole point of a Critter Condo, and the reason it is worth
/// building for a critter nobody grooms: one point takes a critter from -1 to
/// 0, which is no more eggs but five times the coal. It is also what an
/// unattended ranch really costs -- this app used to say a critter eats the
/// same however it is kept, which is what the game says about a *happy* one.
double metabolismAt(double happiness) => happiness < 0 ? 0.2 : 1;

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
    this.happiness = 0,
    this.happinessAt,
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
      happiness: (json['happiness'] as num?)?.toDouble() ?? 0,
      happinessAt: (json['happinessAt'] as num?)?.toDouble(),
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
  /// input turning one output on and off, which is narrower than that: an
  /// input that changes a rate rather than removing an output is [happiness]
  /// instead, which came later and for the Critter Condo.
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

  /// Happiness points this input buys, when somebody supplies it.
  ///
  /// Grooming is worth five and a Critter Condo one, and they add on top of
  /// the -1 a tamed critter starts at: ungroomed is -1, a Condo alone 0,
  /// groomed 4, and both 5. See [layingAt] and [metabolismAt] for what each of
  /// those is worth.
  ///
  /// Adding rather than multiplying is the point. A Condo is worth nothing on
  /// its own and a quarter as many eggs again on top of grooming, which is not
  /// a factor: no number multiplies 1 by itself and 10 into 12.25.
  final double happiness;

  /// The happiness this output's stated rate is the rate *at*.
  ///
  /// Null for everything that reads off [metabolismAt] instead, which is every
  /// other port a critter has. Four for an egg: four is groomed -- five points
  /// of grooming on top of the -1 a tamed critter starts at -- and a groomed
  /// rate is the figure the wiki publishes and the one worth writing down.
  ///
  /// This says which point on the curve the number came from rather than
  /// stating the curve, so a rate copied off the wiki goes in unchanged and
  /// nothing has to be re-derived to a base nobody quotes.
  final double? happinessAt;

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
        if (happiness != 0) 'happiness': happiness,
        if (happinessAt != null) 'happinessAt': happinessAt,
      };

  @override
  String toString() => 'Port($id ${direction.name} $ratePerSecond)';
}
