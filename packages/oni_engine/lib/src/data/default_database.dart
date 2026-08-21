import '../model/game_database.dart';
import '../model/item.dart';
import '../model/port.dart';
import '../model/process_spec.dart';
import 'oni_data.g.dart';

/// The bundled ONI reference data, plus a generated `source:`/`sink:` process
/// for every item so a pipeline can always start and end somewhere.
///
/// A source is defined as **1 unit per second per running unit**, so its solved
/// count *is* the rate: pin `source:water` to 10000 and you have said
/// "I have 10 kg/s of water".
GameDatabase loadDefaultDatabase() {
  final base = GameDatabase.fromJsonString(oniDataJson);
  final extra = <ProcessSpec>[];
  for (final item in base.items) {
    extra.add(ProcessSpec(
      id: sourceSpecId(item.id),
      name: '${item.name} supply',
      kind: ProcessKind.source,
      description: 'Whatever brings ${item.name} into this build: a geyser, '
          'a stockpile, another design. One unit = 1 ${item.unit.symbol}.',
      tags: const {'source'},
      ports: [
        Port(
          id: 'out',
          itemId: item.id,
          direction: PortDirection.output,
          ratePerSecond: 1,
        ),
      ],
    ));
    extra.add(ProcessSpec(
      id: sinkSpecId(item.id),
      name: '${item.name} output',
      kind: ProcessKind.sink,
      description: 'Where ${item.name} leaves this build: storage, a vent, '
          'the rest of the base. One unit = 1 ${item.unit.symbol}.',
      tags: const {'sink'},
      ports: [
        Port(
          id: 'in',
          itemId: item.id,
          direction: PortDirection.input,
          ratePerSecond: 1,
        ),
      ],
    ));

    // A pump is the same building whatever it moves, so rather than a spec per
    // fluid written by hand there is one generated per fluid. Their power is
    // easily the largest hidden cost in a plumbed build: two gas pumps to fill
    // one gas pipe is 480 W before anything has been done with the gas.
    final pump = _pumpFor(item);
    if (pump != null) extra.add(pump);
  }
  return GameDatabase(
    dataVersion: base.dataVersion,
    gameBuild: base.gameBuild,
    items: base.items,
    processes: [...base.processes, ...extra],
  )..assertConsistent();
}

/// Moves a fluid along, at the cost of power and a little heat.
///
/// Returns null for anything a pump cannot move: solids ride a conveyor, and
/// power, heat, growth and grooming are not fluids at all.
ProcessSpec? _pumpFor(Item item) {
  final (double rate, double heat) = switch (item.category) {
    ItemCategory.liquid => (10000, 2),
    ItemCategory.gas => (500, 0),
    _ => (0, 0),
  };
  if (rate == 0) return null;

  return ProcessSpec(
    id: pumpSpecId(item.id),
    name: '${item.name} pump',
    kind: ProcessKind.building,
    description: item.category == ItemCategory.gas
        ? 'Moves 500 g/s for 240 W. A gas pipe holds twice that, so filling one '
            'takes two pumps and 480 W.'
        : 'Moves 10 kg/s for 240 W, which is exactly one liquid pipe full.',
    tags: const {'pumping', 'verified'},
    footprintWidth: 2,
    footprintHeight: 2,
    ports: [
      Port(
        id: 'in',
        itemId: item.id,
        direction: PortDirection.input,
        ratePerSecond: rate,
      ),
      Port(
        id: 'out',
        itemId: item.id,
        direction: PortDirection.output,
        ratePerSecond: rate,
      ),
      const Port(
        id: 'power_in',
        itemId: WellKnownItems.power,
        direction: PortDirection.input,
        ratePerSecond: 240,
      ),
      if (heat > 0)
        Port(
          id: 'heat_out',
          itemId: WellKnownItems.heat,
          direction: PortDirection.output,
          ratePerSecond: heat,
        ),
    ],
  );
}

String sourceSpecId(String itemId) => 'source:$itemId';
String sinkSpecId(String itemId) => 'sink:$itemId';
String pumpSpecId(String itemId) => 'pump:$itemId';

/// The single port id every generated source/sink uses.
const String sourcePortId = 'out';
const String sinkPortId = 'in';
