import '../graph/builder.dart';
import '../graph/pipeline.dart';
import '../model/game_database.dart';
import 'default_database.dart';

/// A build worth starting from.
///
/// Every one of these is a shape people actually make, and each is checked by
/// the golden tests in `test/golden_builds_test.dart` — so a template that
/// stops making sense because a recipe was corrected fails there first.
///
/// Templates carry no positions. Laying a graph out is the canvas's job and it
/// already does it better than a hand-placed guess, so the app tidies one on
/// the way in.
class PipelineTemplate {
  const PipelineTemplate({
    required this.id,
    required this.name,
    required this.summary,
    required this.build,
  });

  final String id;
  final String name;

  /// One line saying what it is *for*, in the terms somebody choosing between
  /// them would use.
  final String summary;
  final Pipeline Function(GameDatabase database) build;
}

/// The starting points offered when a build is made from scratch.
List<PipelineTemplate> pipelineTemplates = [
  PipelineTemplate(
    id: 'spom',
    name: 'Oxygen for the crew',
    summary: 'Water to oxygen, with the hydrogen paying the power bill. '
        'A crew of eight, and 700 W left over.',
    build: (db) => (PipelineBuilder(db, name: 'Oxygen for the crew')
          ..addSource('water')
          ..add('electrolyzer', nodeId: 'elec')
          ..add('duplicant', nodeId: 'dupes')
          ..add('hydrogen_generator', nodeId: 'hgen')
          ..addSink('power', nodeId: 'spare')
          ..addSink('carbon_dioxide')
          ..connectItem('src_water', 'elec', 'water')
          ..connectItem('elec', 'dupes', 'oxygen')
          ..connectItem('elec', 'hgen', 'hydrogen')
          ..connectItem('hgen', 'elec', 'power')
          ..connectItem('hgen', 'spare', 'power')
          ..connectItem('dupes', 'sink_carbon_dioxide', 'carbon_dioxide')
          ..pinCount('dupes', 8))
        .build(),
  ),
  PipelineTemplate(
    id: 'petroleum_boiler',
    name: 'Petroleum power',
    summary: 'Crude oil to petroleum to power. Eats twice the oil it burns, '
        'and hands back polluted water you will have to do something with.',
    build: (db) => (PipelineBuilder(db, name: 'Petroleum power')
          ..addSource('crude_oil')
          ..add('oil_refinery', nodeId: 'refinery')
          ..add('petroleum_generator', nodeId: 'gen')
          ..addSink('natural_gas')
          ..addSink('polluted_water')
          ..addSink('carbon_dioxide')
          ..addSink('power')
          ..connectItem('src_crude_oil', 'refinery', 'crude_oil')
          ..connectItem('refinery', 'gen', 'petroleum')
          ..connectItem('refinery', 'sink_natural_gas', 'natural_gas')
          ..connectItem('gen', 'sink_polluted_water', 'polluted_water')
          ..connectItem('gen', 'sink_carbon_dioxide', 'carbon_dioxide')
          ..connectItem('gen', 'sink_power', 'power')
          ..pinCount('gen', 4))
        .build(),
  ),
  PipelineTemplate(
    id: 'coal_farm',
    name: 'Hatch ranch',
    summary: 'Rock in, coal out, and the Duplicant time it costs to keep them '
        'groomed. One generator needs nine Hatches and two stations.',
    build: (db) => (PipelineBuilder(db, name: 'Hatch ranch')
          ..addSource('sedimentary_rock')
          ..add('hatch', nodeId: 'hatches')
          ..add('grooming_station', nodeId: 'station')
          ..add('coal_generator', nodeId: 'gen')
          ..addSink('power')
          ..addSink('egg')
          ..addSink('meat')
          ..connectItem('src_sedimentary_rock', 'hatches', 'sedimentary_rock')
          ..connectItem('station', 'hatches', 'grooming')
          ..connectItem('hatches', 'gen', 'coal')
          ..connectItem('hatches', 'sink_egg', 'egg')
          ..connectItem('hatches', 'sink_meat', 'meat')
          ..connectItem('gen', 'sink_power', 'power')
          ..pinCount('gen', 1))
        .build(),
  ),
  PipelineTemplate(
    id: 'cooling_loop',
    name: 'Cooling loop',
    summary: 'An Aquatuner taking heat out of a build and a Steam Turbine '
        'deleting it. The one arrangement that gets rid of heat rather than '
        'moving it somewhere else.',
    build: (db) => (PipelineBuilder(db, name: 'Cooling loop')
          ..addSource('heat')
          ..addSource('water')
          ..addSource('steam')
          ..add('aquatuner_water', nodeId: 'tuner')
          ..add('steam_turbine', nodeId: 'turbine')
          ..addSink('power')
          ..addSink('heat')
          ..connect('src_heat', sourcePortId, 'tuner', 'heat_in')
          ..connectItem('src_water', 'tuner', 'water')
          ..connect('tuner', 'heat_out', 'turbine', 'heat_in')
          ..connectItem('src_steam', 'turbine', 'steam')
          ..connectItem('turbine', 'sink_power', 'power')
          ..connect('turbine', 'heat_out', 'sink_heat', sinkPortId)
          ..pinCount('turbine', 1))
        .build(),
  ),
];
