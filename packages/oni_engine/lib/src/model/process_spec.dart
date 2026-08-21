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
    this.description,
    this.dupeLabourSecondsPerCycle = 0,
    this.footprintWidth = 0,
    this.footprintHeight = 0,
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
      description: json['description'] as String?,
      ports: ports,
      dupeLabourSecondsPerCycle:
          (json['dupeLabourSecondsPerCycle'] as num?)?.toDouble() ?? 0,
      footprintWidth: (json['footprintWidth'] as num?)?.toInt() ?? 0,
      footprintHeight: (json['footprintHeight'] as num?)?.toInt() ?? 0,
      tags: {...(json['tags'] as List<dynamic>? ?? const []).cast<String>()},
    );
  }

  final String id;
  final String name;
  final ProcessKind kind;

  /// Groups the operating modes of the same physical building together.
  final String? buildingId;
  final String? description;
  final List<Port> ports;
  final double dupeLabourSecondsPerCycle;
  final int footprintWidth;
  final int footprintHeight;
  final Set<String> tags;

  Iterable<Port> get inputs => ports.where((p) => p.isInput);
  Iterable<Port> get outputs => ports.where((p) => p.isOutput);

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
        if (description != null) 'description': description,
        'ports': [for (final p in ports) p.toJson()],
        if (dupeLabourSecondsPerCycle != 0)
          'dupeLabourSecondsPerCycle': dupeLabourSecondsPerCycle,
        if (footprintWidth != 0) 'footprintWidth': footprintWidth,
        if (footprintHeight != 0) 'footprintHeight': footprintHeight,
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
