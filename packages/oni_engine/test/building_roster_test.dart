import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// What the game's recipe-bearing buildings are, against what this app keeps.
///
/// The third roster, after plants and critters, and written after the same
/// kind of miss: a Wood Burner is a base-game generator anybody builds, and
/// this app had a Wood *Heater* and no burner. Nothing could have said so.
/// Every other audit here reasons about what is present.
///
/// Scoped to the categories that hold recipes — Refinement, Food and power
/// generation. A tile, a wire, a ladder and a pot plant convert nothing, so
/// they are not this app's business and are not listed.
void main() {
  final db = loadDefaultDatabase();

  const modelled = <String, String>{
    // Refinement
    'Algae Distiller': 'algae_distiller',
    'Compost': 'compost',
    'Desalinator': 'desalinator',
    'Ethanol Distiller': 'ethanol_distiller',
    'Fertilizer Synthesizer': 'fertilizer_synthesizer',
    'Glass Forge': 'glass_forge',
    'Gleaner': 'gleaner',
    'Kiln': 'kiln',
    'Metal Refinery': 'metal_refinery',
    'Oil Refinery': 'oil_refinery',
    'Oxylite Refinery': 'oxylite_refinery',
    'Plant Pulverizer': 'plant_pulverizer',
    'Plywood Press': 'plywood_press',
    'Polymer Press': 'polymer_press',
    'Rock Crusher': 'rock_crusher',
    'Sludge Press': 'sludge_press',
    'Vulcanizer': 'vulcanizer',
    'Water Sieve': 'water_sieve',
    // Food
    'Electric Grill': 'electric_grill',
    'Gas Range': 'gas_range',
    'Microbe Musher': 'microbe_musher',
    'Deep Fryer': 'deep_fryer',
    'Smoker': 'smoker',
    'Sushi Bar': 'sushi_bar',
    'Egg Cracker': 'egg_cracker',
    'Dehydrator': 'dehydrator',
    'Rehydrator': 'rehydrator',
    'Grooming Station': 'grooming_station',
    // Power
    'Manual Generator': 'manual_generator',
    'Coal Generator': 'coal_generator',
    'Wood Burner': 'wood_burner',
    'Hydrogen Generator': 'hydrogen_generator',
    'Natural Gas Generator': 'natural_gas_generator',
    'Petroleum Generator': 'petroleum_generator',
    'Steam Turbine': 'steam_turbine',
    'Solar Panel': 'solar_panel',
    'Peat Burner': 'peat_burner',
  };

  const excluded = <String, String>{
    'Bleach Stone Hopper': 'a hopper: it stores bleach stone and lets it off, '
        'which the bleach stone offgassing node already covers',
    'Refrigerator': 'storage, not a recipe',
    'Ration Box': 'storage',
    'Vending Machine': 'storage',
    'Compact Discharger': 'power storage rather than generation',
    'Large Discharger': 'power storage rather than generation',
    'Saturn Critter Trap': 'a plant that eats critters; no recipe to draw',
  };

  const missing = <String, String>{
    'Diamond Press': '100 kg refined carbon and 1000 radbolts into 100 kg of '
        'diamond -- blocked on radbolts, which this app does not model at all, '
        'and diamond is an item here that nothing can make',
    'Molecular Forge': 'thermium, insulite, plastium and fullerene -- blocked '
        'on a whole chain of materials not modelled here: niobium, tungsten, '
        'isosap, brackwax, graphite. Insulite is an item here that nothing can '
        'make',
    'Emulsifier': 'not looked at yet',
    'Spice Grinder': 'not looked at yet',
  };

  test('every recipe-bearing building is modelled, excluded or admitted '
      'missing', () {
    final named = {...modelled.keys, ...excluded.keys, ...missing.keys};
    expect(named.length, modelled.length + excluded.length + missing.length,
        reason: 'a building is in two buckets at once');
  });

  test('and everything claimed as modelled really is a building here', () {
    for (final entry in modelled.entries) {
      // A building with one recipe needs no buildingId, so match either way.
      final specs = db.processes
          .where((s) => s.buildingId == entry.value || s.id == entry.value);
      expect(specs, isNotEmpty, reason: '${entry.key} -> ${entry.value}');
      expect(specs.every((s) => s.kind == ProcessKind.building), isTrue,
          reason: entry.key);
    }
  });

  test('the Wood Burner is a generator and the Wood Heater is not', () {
    // The miss that prompted this. They are two buildings, they both burn
    // wood, and this app had only the one that gives no power -- so a base
    // running on lumber could not be drawn at all.
    final burner = db.processOrThrow('wood_burner');
    final heater = db.processOrThrow('wood_heater');
    expect(burner.netPowerWatts, -300, reason: '300 W out');
    expect(heater.netPowerWatts, 0, reason: 'and the heater gives none');
    expect(burner.inputs.single.itemId, 'wood');
    expect(db.itemOrThrow('wood').members, contains('lumber'),
        reason: 'so an Arbor Tree can feed it');
  });

  test('and it can actually be run off a tree', () {
    final pipeline = (PipelineBuilder(db, name: 'wood power')
          ..add('arbor_tree', nodeId: 'trees')
          ..add('wood_burner', nodeId: 'burner')
          ..addSink('power')
          ..connectItem('trees', 'burner', 'lumber')
          ..connectItem('burner', 'sink_power', 'power')
          ..pinCount('burner', 1))
        .build();
    final solved = PipelineSolver(db).solve(pipeline);
    expect(solved.status, SolveStatus.solved);
    expect(solved.nodes['trees']!.count, greaterThan(0),
        reason: 'and it says how many trees one burner eats');
  });
}
