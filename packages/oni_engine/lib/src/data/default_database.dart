import '../model/game_database.dart';
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
  }
  return GameDatabase(
    dataVersion: base.dataVersion,
    gameBuild: base.gameBuild,
    items: base.items,
    processes: [...base.processes, ...extra],
  )..assertConsistent();
}

String sourceSpecId(String itemId) => 'source:$itemId';
String sinkSpecId(String itemId) => 'sink:$itemId';

/// The single port id every generated source/sink uses.
const String sourcePortId = 'out';
const String sinkPortId = 'in';
