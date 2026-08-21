import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

void main() {
  final db = loadDefaultDatabase();
  final solver = PipelineSolver(db);

  group('mixing', () {
    test('two flows of the same thing meet in the middle', () {
      expect(
        mixTemperature([
          (grams: 1000, specificHeat: 4.179, celsius: 90),
          (grams: 1000, specificHeat: 4.179, celsius: 20),
        ]),
        closeTo(55, 1e-9),
      );
    });

    test('the heavier flow wins in proportion', () {
      expect(
        mixTemperature([
          (grams: 3000, specificHeat: 4.179, celsius: 20),
          (grams: 1000, specificHeat: 4.179, celsius: 100),
        ]),
        closeTo(40, 1e-9),
      );
    });

    test('specific heat decides it, not mass alone', () {
      // A kilogram of hot water against a kilogram of cold oil: water holds
      // 4.179 per gram-degree and crude oil 1.69, so the mixture lands much
      // nearer the water than halfway.
      final mixed = mixTemperature([
        (grams: 1000, specificHeat: 4.179, celsius: 90),
        (grams: 1000, specificHeat: 1.69, celsius: 20),
      ]);
      expect(mixed, greaterThan(65));
      expect(mixed, closeTo((4.179 * 90 + 1.69 * 20) / (4.179 + 1.69), 1e-9));
    });
  });

  group('temperatures through a build', () {
    test('nothing is known until somebody says', () {
      final pipeline = (PipelineBuilder(db, name: 'cold start')
            ..addSource('polluted_water')
            ..add('water_sieve', nodeId: 'sieve')
            ..connectItem('src_polluted_water', 'sieve', 'polluted_water')
            ..pinCount('sieve', 1))
          .build();

      final temps =
          temperaturesOf(pipeline, db, solver.solve(pipeline));
      expect(temps.at(const PortRef('sieve', 'polluted_water')), isNull);
    });

    test('a supply node sets where the temperatures start', () {
      final pipeline = Pipeline(
        id: 'p',
        name: 'warm start',
        nodes: [
          PipelineNode(
              id: 'src_water',
              specId: sourceSpecId('polluted_water'),
              temperatureC: 30),
          PipelineNode(id: 'sieve', specId: 'water_sieve'),
        ],
        edges: [
          PipelineEdge(
            id: 'e',
            fromNodeId: 'src_water',
            fromPortId: sourcePortId,
            toNodeId: 'sieve',
            toPortId: 'polluted_water',
          ),
        ],
        pins: [const BuildingCountPin(nodeId: 'sieve', count: 1)],
      );

      final temps = temperaturesOf(pipeline, db, solver.solve(pipeline));
      expect(temps.at(const PortRef('sieve', 'polluted_water')), 30);
      // The sieve publishes no output temperature, so what it gives back is
      // what it was given.
      expect(temps.at(const PortRef('sieve', 'water')), closeTo(30, 1e-9));
    });

    test('a published figure beats whatever came in', () {
      final pipeline = Pipeline(
        id: 'p',
        name: 'electrolysis',
        nodes: [
          PipelineNode(
              id: 'src_water',
              specId: sourceSpecId('water'),
              temperatureC: 10),
          PipelineNode(id: 'elec', specId: 'electrolyzer'),
        ],
        edges: [
          PipelineEdge(
            id: 'e',
            fromNodeId: 'src_water',
            fromPortId: sourcePortId,
            toNodeId: 'elec',
            toPortId: 'water',
          ),
        ],
        pins: [const BuildingCountPin(nodeId: 'elec', count: 1)],
      );

      final temps = temperaturesOf(pipeline, db, solver.solve(pipeline));
      // 10 °C water in, 70 °C oxygen out, because that is what the game does
      // regardless of what you feed it.
      expect(temps.at(const PortRef('elec', 'water')), 10);
      expect(temps.at(const PortRef('elec', 'oxygen')), 70);
    });

    test('two streams meeting at one port are mixed by heat, not by mass', () {
      // A Water Sieve fed by two supplies at different temperatures, one three
      // times the size of the other.
      final pipeline = Pipeline(
        id: 'p',
        name: 'two taps',
        nodes: [
          PipelineNode(
              id: 'hot', specId: sourceSpecId('polluted_water'), temperatureC: 90),
          PipelineNode(
              id: 'cold', specId: sourceSpecId('polluted_water'), temperatureC: 20),
          PipelineNode(id: 'sieve', specId: 'water_sieve'),
        ],
        edges: [
          PipelineEdge(
            id: 'e1',
            fromNodeId: 'hot',
            fromPortId: sourcePortId,
            toNodeId: 'sieve',
            toPortId: 'polluted_water',
            mode: EdgeMode.pull,
            share: 0.25,
          ),
          PipelineEdge(
            id: 'e2',
            fromNodeId: 'cold',
            fromPortId: sourcePortId,
            toNodeId: 'sieve',
            toPortId: 'polluted_water',
            mode: EdgeMode.pull,
            share: 0.75,
          ),
        ],
        pins: [const BuildingCountPin(nodeId: 'sieve', count: 1)],
      );

      final solution = solver.solve(pipeline);
      expect(solution.status, SolveStatus.solved);
      final temps = temperaturesOf(pipeline, db, solution);
      // A quarter at 90 and three quarters at 20, same liquid: 37.5 °C.
      expect(temps.at(const PortRef('sieve', 'polluted_water')),
          closeTo(37.5, 1e-6));
    });
  });

  test('every fluid this app moves knows its specific heat', () {
    // Anything a pipe can carry has to have one, or a mixture involving it is
    // silently dropped rather than wrongly averaged.
    final missing = [
      for (final item in db.items)
        if ((item.category == ItemCategory.liquid ||
                item.category == ItemCategory.gas) &&
            item.specificHeat == null)
          item.id,
    ];
    // The ones left are DLC exotica and molten metals — nothing a build plumbs
    // into a mixing point today. The list is written out so that adding a
    // liquid without measuring it fails here rather than being quietly left
    // out of every mixture it takes part in.
    expect(missing, [
      'molten_zinc', 'zinc_gas', 'ovolene', 'mucin', 'squid_ink', 'latex',
      'liquid_sulfur', 'phyto_oil', 'mercury', 'mercury_gas', 'nectar',
      'liquid_chlorine', 'molten_glass',
    ]);
  });
}
