import 'item.dart';
import 'port.dart';

/// What sort of thing this process is. Affects presentation and how `count`
/// should be read ("3 buildings" vs "3 dupes" vs "3 g/s of supply").
enum ProcessKind {
  building,
  critter,
  plant,
  duplicant,

  /// A raw resource entering the build from outside (a geyser, a cold biome,
  /// a stockpile). Defined as **1 g/s per unit**, so its solved count *is* g/s.
  source,

  /// Somewhere output goes and stops mattering (a vent, storage, the void).
  sink,
  custom;

  /// A supply or an output: the edge of a build rather than a thing in it.
  ///
  /// Written out as `kind == source || kind == sink` in nine places before
  /// this existed, which is nine chances to write one of them as `&&`.
  bool get isBoundary => this == ProcessKind.source || this == ProcessKind.sink;

  static ProcessKind parse(String raw) => ProcessKind.values.firstWhere(
        (k) => k.name == raw,
        orElse: () => throw FormatException('Unknown process kind "$raw"'),
      );
}

/// A building (or critter, plant, dupe…) **in one operating mode**.
///
/// One building can have several specs: a Metal Refinery has one per metal, a
/// generator has "on demand" and "100 % uptime" variants. That is deliberate —
/// it keeps every spec a plain constant-ratio recipe, which is what makes the
/// whole pipeline linear.
class ProcessSpec {
  ProcessSpec({
    required this.id,
    required this.name,
    required this.kind,
    required List<Port> ports,
    this.buildingId,
    this.family,
    this.description,
    this.dupeLabourSecondsPerCycle = 0,
    this.unattended = false,
    this.locomotion,
    this.amphibious = false,
    this.footprintWidth = 0,
    this.footprintHeight = 0,
    this.buildCost = const {},
    this.overheatCelsius,
    this.tags = const {},
  }) : ports = List.unmodifiable(ports) {
    final seen = <String>{};
    for (final port in this.ports) {
      if (!seen.add(port.id)) {
        throw ArgumentError('Duplicate port id "${port.id}" in spec "$id"');
      }
      if (port.ratePerSecond < 0) {
        throw ArgumentError('Negative rate on port "${port.id}" of spec "$id"');
      }
    }
  }

  /// Parses a spec. Supports the `power` / `heat` shorthand fields, which expand
  /// into ordinary ports so the solver can balance a power grid like anything else.
  factory ProcessSpec.fromJson(Map<String, dynamic> json) {
    final ports = <Port>[
      for (final raw in (json['ports'] as List<dynamic>? ?? const []))
        Port.fromJson(raw as Map<String, dynamic>),
    ];

    final powerW = (json['powerWatts'] as num?)?.toDouble() ?? 0;
    if (powerW > 0) {
      ports.add(Port(
        id: 'power_in',
        itemId: WellKnownItems.power,
        direction: PortDirection.input,
        ratePerSecond: powerW,
      ));
    } else if (powerW < 0) {
      ports.add(Port(
        id: 'power_out',
        itemId: WellKnownItems.power,
        direction: PortDirection.output,
        ratePerSecond: -powerW,
      ));
    }

    final heat = (json['heatKdtuPerSecond'] as num?)?.toDouble() ?? 0;
    if (heat != 0) {
      ports.add(Port(
        id: heat > 0 ? 'heat_out' : 'heat_in',
        itemId: WellKnownItems.heat,
        direction: heat > 0 ? PortDirection.output : PortDirection.input,
        ratePerSecond: heat.abs(),
      ));
    }

    return ProcessSpec(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: ProcessKind.parse(json['kind'] as String),
      buildingId: json['buildingId'] as String?,
      family: json['family'] as String?,
      description: json['description'] as String?,
      ports: ports,
      dupeLabourSecondsPerCycle:
          (json['dupeLabourSecondsPerCycle'] as num?)?.toDouble() ?? 0,
      unattended: json['unattended'] as bool? ?? false,
      locomotion: json['locomotion'] as String?,
      amphibious: json['amphibious'] as bool? ?? false,
      footprintWidth: (json['footprintWidth'] as num?)?.toInt() ?? 0,
      footprintHeight: (json['footprintHeight'] as num?)?.toInt() ?? 0,
      buildCost: {
        for (final entry
            in (json['build'] as Map<String, dynamic>? ?? const {}).entries)
          entry.key: (entry.value as num).toDouble(),
      },
      overheatCelsius: (json['overheat'] as num?)?.toDouble(),
      tags: {...(json['tags'] as List<dynamic>? ?? const []).cast<String>()},
    );
  }

  final String id;
  final String name;
  final ProcessKind kind;

  /// Groups the operating modes of the same physical building together.
  final String? buildingId;

  /// The id every version of this thing shares.
  ///
  /// A Hatch and a Hatch (wild) are one creature kept two ways, and an Arbor
  /// Tree comes four ways once grazing is counted. Buildings have always had
  /// this through [buildingId] -- the twenty-two Aquatuners are one building
  /// with a coolant chosen -- and critters and plants had nothing, so changing
  /// your mind about grooming meant deleting the card and drawing its wires
  /// again.
  final String? family;
  final String? description;
  final List<Port> ports;
  final double dupeLabourSecondsPerCycle;

  /// What this supplies costs nobody any time.
  ///
  /// A critter's Duplicant time is booked on the critter rather than on the
  /// station, because it differs by species -- twelve seconds for a Hatch,
  /// twenty-four for a Drecko -- and a station serving eight of them cannot
  /// carry one figure. But that time is *for the grooming*, so a critter kept
  /// happy by something nobody has to attend does not cost it.
  ///
  /// A Critter Fountain is the case: five kilograms of brackene a cycle buys
  /// the same happiness a brushing does, and its whole point is that nobody is
  /// standing there. Without this the app charged for the Duplicant anyway,
  /// which made the building pointless in the one respect it exists for.
  final bool unattended;

  /// How this critter gets about: `walker`, `flyer`, `swimmer` or `hoverer`.
  ///
  /// The game's own tag, off each critter's page, and null for everything that
  /// is not a critter. Recorded because a Critter Condo comes in three and a
  /// Grooming Station in two, and this app had no way to say which one a given
  /// animal wants -- so nothing stopped a Pacu being groomed at a land
  /// station.
  ///
  /// It does not settle the question on its own, which is why it is the tag
  /// rather than a habitat of this project's invention. A Pokeshell is a
  /// walker that uses the *aquatic* Condo, the terrestrial one saying in so
  /// many words that it excludes Pokeshell species; and nothing anywhere says
  /// which Condo a hoverer uses, so both Slicksters are still open. See E4-74.
  final String? locomotion;

  /// Walks, and is at home in liquid as well.
  ///
  /// Five of them: the Gildgo, Plug Slug, Slogo, Pokeshell and Oakshell. A
  /// second tag rather than a fifth kind of [locomotion], because the game
  /// carries both on the same critter and they answer different questions.
  final bool amphibious;

  final int footprintWidth;
  final int footprintHeight;

  /// What it takes to put one up: [BuildMaterials] id → kilograms.
  ///
  /// Empty for anything that is not a building — nobody constructs a Hatch —
  /// and empty, too, for a building whose cost has not been checked yet, which
  /// is why the total says how many buildings it could not price.
  final Map<String, double> buildCost;

  /// The temperature this building overheats at, when the game states one of
  /// its own.
  ///
  /// Null is the usual case and means the ordinary rule: 75 °C plus whatever
  /// the material you built it from adds. A few buildings are rated instead —
  /// a Steam Turbine sits in steam and overheats at 1 000 °C, which no choice
  /// of metal changes — and for those the material question does not arise,
  /// which is worth being able to say rather than warning about a choice that
  /// does not exist.
  final double? overheatCelsius;

  final Set<String> tags;

  Iterable<Port> get inputs => ports.where((p) => p.isInput);
  Iterable<Port> get outputs => ports.where((p) => p.isOutput);

  /// Inputs that can be left unsupplied, because something only they bring
  /// would go with them.
  ///
  /// Derived rather than declared: a port is switchable exactly when some
  /// output says it needs it, or when it buys happiness and some output is
  /// priced in happiness. Nothing else about a thing is optional — a Hatch
  /// that is not fed is not a Hatch on short rations, it is a dead Hatch.
  Iterable<Port> get switchablePorts sync* {
    final needed = {
      for (final port in ports)
        if (port.needsPortId case final String id) id,
    };
    final anyPricedInHappiness =
        ports.any((port) => port.happinessAt != null);
    for (final port in ports) {
      if (!port.isInput) continue;
      if (needed.contains(port.id) ||
          (anyPricedInHappiness && port.happiness != 0)) {
        yield port;
      }
    }
  }

  /// Where this thing starts before anybody does anything for it.
  ///
  /// "Tamed critters have a base happiness of -1", which is the fact the first
  /// version of this was written without. It is why an ungroomed critter is
  /// glum rather than merely unimproved, and why a Critter Condo -- one point,
  /// -1 to 0 -- buys no eggs at all and yet is worth building.
  ///
  /// Derived rather than declared: a thing starts at -1 exactly when something
  /// can make it happier, which is only ever a tamed critter. A wild one has
  /// no happiness ports and so no base, which is right -- it lays what it lays
  /// and nobody grooms it.
  double get baseHappiness =>
      ports.any((port) => port.isInput && port.happiness != 0) ? -1 : 0;

  /// Happiness points this thing has when [supplied] says which inputs are.
  ///
  /// Adding is the whole point: grooming is five, a Critter Condo one, and
  /// both on top of the -1 makes five. Nothing multiplies here, which is what
  /// made the Condo impossible to express before.
  double happinessWhen(bool Function(String portId) supplied) {
    var points = baseHappiness;
    for (final port in ports) {
      if (port.isInput && port.happiness != 0 && supplied(port.id)) {
        points += port.happiness;
      }
    }
    return points;
  }

  Port? portById(String portId) {
    for (final port in ports) {
      if (port.id == portId) return port;
    }
    return null;
  }

  Port portByIdOrThrow(String portId) =>
      portById(portId) ??
      (throw ArgumentError('Spec "$id" has no port "$portId"'));

  /// Tiles one of these takes up, or zero when the size is not recorded.
  ///
  /// Critters and boundary nodes have none: a Hatch occupies a stable, which is
  /// counted where the stable is, and a supply node is not a thing you build.
  int get footprintTiles => footprintWidth * footprintHeight;

  bool get hasFootprint => footprintTiles > 0;

  /// Net watts consumed per running unit (negative = generation).
  double get netPowerWatts => _net(WellKnownItems.power);

  /// Net kDTU/s emitted per running unit (positive = heats the base).
  double get netHeatKdtu => -_net(WellKnownItems.heat);

  double _net(String itemId) {
    var total = 0.0;
    for (final port in ports) {
      if (port.itemId != itemId) continue;
      total += port.isInput ? port.ratePerSecond : -port.ratePerSecond;
    }
    return total;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'kind': kind.name,
        if (buildingId != null) 'buildingId': buildingId,
        if (family != null) 'family': family,
        if (description != null) 'description': description,
        'ports': [for (final p in ports) p.toJson()],
        if (dupeLabourSecondsPerCycle != 0)
          'dupeLabourSecondsPerCycle': dupeLabourSecondsPerCycle,
        if (unattended) 'unattended': true,
        if (locomotion != null) 'locomotion': locomotion,
        if (amphibious) 'amphibious': true,
        if (footprintWidth != 0) 'footprintWidth': footprintWidth,
        if (footprintHeight != 0) 'footprintHeight': footprintHeight,
        if (buildCost.isNotEmpty) 'build': buildCost,
        if (overheatCelsius != null) 'overheat': overheatCelsius,
        if (tags.isNotEmpty) 'tags': tags.toList(),
      };

  @override
  String toString() => 'ProcessSpec($id)';
}

/// How much of its life a geyser spends erupting.
///
/// Every geyser rolls its own numbers when the world is generated: an emission
/// rate, an eruption duty, and an active share of a dormancy cycle that runs
/// 25–225 cycles. The active share is always between 40 % and 80 %, and lands
/// in the middle fifth — 56–64 % — about half the time.
///
/// The rates shipped with this app are lifetime averages at a typical roll, so
/// these factors say how far a particular geyser may sit either side of it.
abstract final class GeyserActivity {
  /// The dullest geyser you can be dealt.
  static const double minimumActiveFraction = 0.40;

  /// What the shipped figures assume.
  static const double typicalActiveFraction = 0.60;

  /// The luckiest roll.
  static const double maximumActiveFraction = 0.80;

  /// Scale for a given active share, relative to the shipped figure.
  static double scaleFor(double activeFraction) =>
      activeFraction / typicalActiveFraction;

  /// While it is actually erupting, dormancy ignored — the number that matters
  /// for sizing storage and pipes rather than long-run supply.
  static double get whileActiveScale => 1 / typicalActiveFraction;

  /// Presets offered in the app, worst to best.
  static const Map<String, double> presets = <String, double>{
    'Worst': minimumActiveFraction,
    'Typical': typicalActiveFraction,
    'Best': maximumActiveFraction,
  };
}
