import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// The geothermal sour gas boiler, which is not a building.
///
/// Asked for on Discord: "I wanted to check out how efficient i could make
/// geothermal sour gas boiler with 1kg/s pipeline" — and there was no magma in
/// the database at all, let alone a volcano to get it from. The suggestion
/// that came with it was the right one: add the volcano, put the numbers in,
/// use it in the arithmetic.
///
/// Nothing here is a building. Petroleum past 541.85 °C becomes sour gas
/// because that is what petroleum does, and magma freezing at 1409.85 °C gives
/// up its heat because that is what magma does. Both are written as processes
/// so the solver can weigh one against the other.
void main() {
  final db = loadDefaultDatabase();

  /// Volcano → magma → heat → boiler ← petroleum, then condensed.
  Pipeline boiler({required double petroleumPerSecond}) =>
      (PipelineBuilder(db, name: 'geothermal sour gas boiler')
            ..add('volcano', nodeId: 'volcano')
            ..add('magma_cooling', nodeId: 'cooling')
            ..addSink('igneous_rock')
            ..add('sour_gas_boiler', nodeId: 'boiler')
            ..addSource('petroleum')
            ..add('sour_gas_condenser', nodeId: 'condenser')
            ..addSink('natural_gas')
            ..addSink('sulfur')
            ..addSink('heat')
            ..connectItem('volcano', 'cooling', 'magma')
            ..connectItem('cooling', 'sink_igneous_rock', 'igneous_rock')
            ..connect('cooling', 'heat_out', 'boiler', 'heat_in')
            ..connectItem('src_petroleum', 'boiler', 'petroleum')
            ..connectItem('boiler', 'condenser', 'sour_gas')
            ..connectItem('condenser', 'sink_natural_gas', 'natural_gas')
            ..connectItem('condenser', 'sink_sulfur', 'sulfur')
            ..connect('condenser', 'heat_out', 'sink_heat', 'in')
            ..pinRate('boiler', 'petroleum', petroleumPerSecond))
          .build();

  test('a kilogram a second of petroleum takes rather more than one volcano',
      () {
    final solution = PipelineSolver(db).solve(boiler(petroleumPerSecond: 1000));
    expect(solution.status, SolveStatus.solved);

    // 466.85 °C to climb at 1.76 DTU/g/°C is 821.66 kDTU/s, and a kilogram of
    // magma falling to its freezing point gives 317 — so 2.59 kg/s of magma,
    // and a volcano averages 1.2.
    expect(solution.nodes['cooling']!.count, closeTo(2.592, 0.01),
        reason: 'kilograms of magma a second');
    expect(solution.nodes['volcano']!.count, closeTo(2.16, 0.01),
        reason: 'which is more than two volcanoes for one pipe of oil');
  });

  test('and gives back two thirds natural gas, one third sulfur', () {
    final solution = PipelineSolver(db).solve(boiler(petroleumPerSecond: 1000));
    double into(String sink) => solution.portBalances
        .firstWhere((b) => b.ref.nodeId == sink && b.direction ==
            PortDirection.input)
        .rate;
    expect(into('sink_natural_gas'), closeTo(670, 0.01));
    expect(into('sink_sulfur'), closeTo(330, 0.01));
    expect(into('sink_natural_gas') + into('sink_sulfur'), closeTo(1000, 0.01),
        reason: 'nothing is lost turning sour gas into its two halves');
  });

  test('and leaves a great deal of rock and a great deal of heat to shift', () {
    final solution = PipelineSolver(db).solve(boiler(petroleumPerSecond: 1000));
    double into(String sink) => solution.portBalances
        .firstWhere((b) => b.ref.nodeId == sink && b.direction ==
            PortDirection.input)
        .rate;
    expect(into('sink_igneous_rock'), closeTo(2592, 1),
        reason: 'every gram of magma is a gram of rock afterwards');
    // More than goes in at the hot end, which is the whole reason a real
    // boiler runs the two against each other rather than paying for both.
    expect(into('sink_heat'), greaterThan(821.66));
  });

  test('scaling the pipe scales the volcanoes', () {
    final half = PipelineSolver(db).solve(boiler(petroleumPerSecond: 500));
    expect(half.nodes['volcano']!.count, closeTo(1.08, 0.01));
  });

  test('the magma is as hot as the wiki says, and the rock is not', () {
    final specs = db;
    final magma = specs.processOrThrow('volcano').ports.single;
    expect(magma.itemId, 'magma');
    expect(magma.ratePerSecond, 1200);
    expect(magma.temperatureC, 1726.85);
    expect(specs.itemOrThrow('magma').specificHeat, 1.0);
    expect(specs.itemOrThrow('sour_gas').specificHeat, 1.898);
  });
}
