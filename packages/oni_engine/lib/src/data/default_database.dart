import '../model/conduits.dart';
import '../model/build_material.dart';
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
    // A supply node is only as base-game as the thing it supplies. Without
    // this, "Coquina supply" turned up in a palette with the Aquatic pack
    // switched off, which is the same mistake as offering the Tidal Turbine.
    final packs = {
      for (final tag in item.tags)
        if (contentPackTags.contains(tag)) tag,
    };
    extra.add(ProcessSpec(
      id: sourceSpecId(item.id),
      name: '${item.name} supply',
      kind: ProcessKind.source,
      description: 'Whatever brings ${item.name} into this build: a geyser, '
          'a stockpile, another design. One unit = 1 ${item.unit.symbol}.',
      tags: {'source', ...packs},
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
      tags: {'sink', ...packs},
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

    // And a filter, for the same reason: separating a gas out of a shared pipe
    // costs a building and 120 W, and neither shows up anywhere in a graph
    // where every port already carries one thing.
    final filter = _filterFor(item);
    if (filter != null) extra.add(filter);

    // And the machine that cools it. What it moves is arithmetic on the
    // coolant, so there is one per fluid rather than the two somebody happened
    // to write out by hand.
    final cooler = _coolerFor(item);
    if (cooler != null) extra.add(cooler);
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
    tags: {
      'pumping',
      'verified',
      for (final tag in item.tags)
        if (contentPackTags.contains(tag)) tag,
    },
    footprintWidth: 2,
    footprintHeight: 2,
    // A Liquid Pump is 400 kg of ore, a Gas Pump 50 kg — one of the larger
    // gaps in the game, and worth seeing when a build needs eight of them.
    buildCost: {
      BuildMaterials.metalOre:
          item.category == ItemCategory.liquid ? 400 : 50,
    },
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

/// Pulls one gas or liquid out of a pipe carrying several.
///
/// This app has no notion of a mixture: every port carries one thing, and an
/// Electrolyzer's oxygen and hydrogen leave by different ports because that is
/// the only way the model can say it. So a filter cannot be modelled as the
/// separation it performs — there is nothing here for it to separate.
///
/// What it *can* say is what the separation costs, which is the part a plan
/// gets wrong: a building, 120 W while it runs, and a pipe's worth of
/// throughput. Put one on the wire you would have to filter in game and the
/// power turns up in the total. The gas it does not want goes on down the pipe,
/// which this does not track.
ProcessSpec? _filterFor(Item item) {
  // A filter handles whatever the pipe delivers, and the pipe is the limit:
  // 1 kg/s of gas, 10 kg/s of liquid. Neither page publishes a throughput.
  final (double rate, double heat) = switch (item.category) {
    ItemCategory.liquid => (10000, 4),
    ItemCategory.gas => (1000, 0),
    _ => (0, 0),
  };
  if (rate == 0) return null;
  final liquid = item.category == ItemCategory.liquid;

  return ProcessSpec(
    id: filterSpecId(item.id),
    name: '${item.name} filter',
    kind: ProcessKind.building,
    description: liquid
        ? 'Separates ${item.name} from a pipe carrying more than one liquid, '
            'for 120 W and 4 kDTU/s. The throughput here is a full pipe, '
            '10 kg/s, because the page does not publish one and a filter can '
            'only take what the pipe brings it.'
        : 'UNVERIFIED: separates ${item.name} from a pipe carrying more than '
            'one gas, for 120 W. The throughput here is a full pipe, 1 kg/s, '
            'because the page does not publish one; nor does it publish the '
            'heat, which is modelled as none.',
    tags: {
      'filtering',
      if (liquid) 'verified' else 'unverified',
      // As optional as the fluid it filters, the same as a supply node.
      for (final tag in item.tags)
        if (contentPackTags.contains(tag)) tag,
    },
    footprintWidth: 1,
    footprintHeight: 2,
    buildCost: {BuildMaterials.metalOre: liquid ? 200 : 50},
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
        ratePerSecond: 120,
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

/// An Aquatuner, or a Thermo Regulator for a gas.
///
/// Both take 14 °C out of every packet that passes and put it into the machine,
/// so what they move is the coolant's specific heat times fourteen degrees
/// times a full pipe. That is not a rule invented here: it is how the wiki's
/// own figures are reached, and both of the ones it prints come back exactly —
/// 10 kg/s of water at 4.179 is the 585.06 kDTU/s on the Aquatuner page, and
/// 1 kg/s of hydrogen at 2.4 is the 33.6 on the Thermo Regulator's.
///
/// Which is why there is one per fluid. Two were written out by hand, water and
/// hydrogen, and the other twenty were simply missing — a petroleum loop is as
/// ordinary a thing to plan as a water one.
ProcessSpec? _coolerFor(Item item) {
  final specificHeat = item.specificHeat;
  if (specificHeat == null) return null;
  final liquid = item.category == ItemCategory.liquid;
  if (!liquid && item.category != ItemCategory.gas) return null;

  // A full pipe, as with the filters: the machine takes what reaches it.
  final rate = liquid
      ? Conduits.liquidPipe.capacity
      : Conduits.gasPipe.capacity;
  const degrees = 14.0;
  final moved = rate * specificHeat * degrees / 1000;

  return ProcessSpec(
    id: liquid ? 'aquatuner_${item.id}' : 'thermo_regulator_${item.id}',
    name: liquid
        ? 'Aquatuner (${item.name})'
        : 'Thermo Regulator (${item.name})',
    kind: ProcessKind.building,
    buildingId: liquid ? 'aquatuner' : 'thermo_regulator',
    description: 'Takes 14 °C out of every packet and puts it into the '
        'machine, which is why one usually stands in a steam room with a '
        'turbine over it. It moves heat rather than destroying it. '
        '${item.name} holds $specificHeat DTU per gram per degree, so a full '
        'pipe of it carries ${moved.toStringAsFixed(2)} kDTU/s — a colder-'
        'running coolant moves less, which is the whole reason the choice '
        'matters.',
    tags: {
      'cooling',
      'verified',
      for (final tag in item.tags)
        if (contentPackTags.contains(tag)) tag,
    },
    footprintWidth: 2,
    footprintHeight: 2,
    buildCost: {BuildMaterials.metalOre: liquid ? 1200 : 200},
    ports: [
      Port(
        id: 'coolant_in',
        itemId: item.id,
        direction: PortDirection.input,
        ratePerSecond: rate,
      ),
      Port(
        id: 'coolant_out',
        itemId: item.id,
        direction: PortDirection.output,
        ratePerSecond: rate,
      ),
      Port(
        id: 'heat_in',
        itemId: WellKnownItems.heat,
        direction: PortDirection.input,
        ratePerSecond: moved,
      ),
      Port(
        id: 'heat_out',
        itemId: WellKnownItems.heat,
        direction: PortDirection.output,
        ratePerSecond: moved,
      ),
      Port(
        id: 'power_in',
        itemId: WellKnownItems.power,
        direction: PortDirection.input,
        ratePerSecond: liquid ? 1200 : 240,
      ),
    ],
  );
}

/// The packs whose content is optional, named by the tag the data uses.
///
/// Kept here rather than in the app because it is a fact about the data: a
/// synthesised supply node has to inherit its item's pack, and that decision
/// cannot wait for a widget to be built.
const Set<String> contentPackTags = {'aquatic', 'frosty', 'prehistoric'};

String filterSpecId(String itemId) => 'filter:$itemId';

String sourceSpecId(String itemId) => 'source:$itemId';
String sinkSpecId(String itemId) => 'sink:$itemId';
String pumpSpecId(String itemId) => 'pump:$itemId';

/// The single port id every generated source/sink uses.
const String sourcePortId = 'out';
const String sinkPortId = 'in';
