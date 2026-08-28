import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// Builds that could not be made in the editor, and arrive anyway.
///
/// Every check here guards a share code somebody hand-edited, one written by a
/// newer version of the app, or one damaged in transit — all three have
/// happened. The structural checks existed and none of them had ever been run:
/// forty-seven lines of message-writing that nobody had ever seen the output
/// of, which is exactly where the one crash found this week was hiding.
///
/// So each is checked twice over: that it says something, and that asking for
/// the solution does not throw. A build that arrives broken has to be
/// *readable* — an error you can see beats a red screen every time.
void main() {
  final db = loadDefaultDatabase();

  Pipeline whole() => (PipelineBuilder(db, name: 'fine')
        ..addSource('water', nodeId: 'src')
        ..add('electrolyzer', nodeId: 'elec')
        ..addSink('oxygen', nodeId: 'out')
        ..connectItem('src', 'elec', 'water')
        ..connectItem('elec', 'out', 'oxygen')
        ..pinCount('elec', 1))
      .build();

  /// What the checks say, and proof that the solver survives it.
  String complaintsAbout(Pipeline pipeline) {
    expect(() => PipelineSolver(db).solve(pipeline), returnsNormally,
        reason: 'a build that arrives broken still has to be readable');
    return validatePipeline(pipeline, db).map((i) => i.message).join('\n');
  }

  test('a build with nothing wrong is not complained about', () {
    expect(validatePipeline(whole(), db).where((i) => i.isError), isEmpty);
  });

  group('nodes', () {
    test('two nodes with the same id', () {
      final p = whole();
      final broken = p.copyWith(nodes: [...p.nodes, p.nodeOrThrow('elec')]);
      expect(complaintsAbout(broken), contains('Duplicate node id "elec"'));
    });

    test('a recipe this version has never heard of', () {
      // The likeliest of the lot: a build made in a newer version, or after a
      // recipe was renamed.
      final p = whole();
      final broken = p.copyWith(nodes: [
        for (final n in p.nodes)
          if (n.id == 'elec') n.copyWith(specId: 'flux_capacitor') else n,
      ]);
      expect(complaintsAbout(broken), contains('unknown process'));
    });

    test('an uptime outside nought to one', () {
      final p = whole();
      for (final bad in [0.0, -0.5, 1.5]) {
        final broken = p.copyWith(nodes: [
          for (final n in p.nodes)
            if (n.id == 'elec') n.copyWith(uptime: bad) else n,
        ]);
        expect(complaintsAbout(broken), contains('expected ]0, 1]'),
            reason: 'uptime $bad');
      }
    });
  });

  group('wires', () {
    PipelineEdge firstEdge(Pipeline p) => p.edges.first;

    test('two wires with the same id', () {
      final p = whole();
      final broken = p.copyWith(edges: [...p.edges, firstEdge(p)]);
      expect(complaintsAbout(broken), contains('Duplicate edge id'));
    });

    test('a wire onto a node that is not there', () {
      final p = whole();
      final broken = p.copyWith(edges: [
        for (final e in p.edges)
          PipelineEdge(
            id: e.id,
            fromNodeId: e.fromNodeId,
            fromPortId: e.fromPortId,
            toNodeId: 'nobody',
            toPortId: e.toPortId,
          ),
      ]);
      expect(complaintsAbout(broken), contains('references a missing node'));
    });

    test('a wire off a port the recipe does not have', () {
      final p = whole();
      final broken = p.copyWith(edges: [
        for (final e in p.edges)
          if (e.fromNodeId == 'elec') e.copyWith(fromPortId: 'nowhere') else e,
      ]);
      expect(complaintsAbout(broken), contains('has no port "nowhere"'));
    });

    test('a wire onto a port the recipe does not have', () {
      final p = whole();
      final broken = p.copyWith(edges: [
        for (final e in p.edges)
          if (e.toNodeId == 'elec') e.copyWith(toPortId: 'nowhere') else e,
      ]);
      expect(complaintsAbout(broken), contains('has no port "nowhere"'));
    });

    test('a wire that starts at an input', () {
      final p = whole();
      final broken = p.copyWith(edges: [
        for (final e in p.edges)
          if (e.fromNodeId == 'elec') e.copyWith(fromPortId: 'water') else e,
      ]);
      expect(complaintsAbout(broken), contains('starts at input port'));
    });

    test('a wire that ends at an output', () {
      final p = whole();
      final broken = p.copyWith(edges: [
        for (final e in p.edges)
          if (e.toNodeId == 'elec') e.copyWith(toPortId: 'oxygen') else e,
      ]);
      expect(complaintsAbout(broken), contains('ends at output port'));
    });

    test('the same two ports joined twice', () {
      final p = whole();
      final first = p.edges.first;
      final broken = p.copyWith(edges: [
        ...p.edges,
        PipelineEdge(
          id: 'another',
          fromNodeId: first.fromNodeId,
          fromPortId: first.fromPortId,
          toNodeId: first.toNodeId,
          toPortId: first.toPortId,
        ),
      ]);
      expect(complaintsAbout(broken), contains('Duplicate link'));
    });
  });

  group('amounts', () {
    test('an amount on a node that is not there', () {
      final p = whole();
      final broken =
          p.copyWith(pins: [const BuildingCountPin(nodeId: 'ghost', count: 2)]);
      expect(complaintsAbout(broken), contains('references missing node'));
    });

    test('an amount on a port the recipe does not have', () {
      final p = whole();
      final broken = p.copyWith(pins: [
        const PortRatePin(
            nodeId: 'elec', portId: 'nowhere', ratePerSecond: 100),
      ]);
      expect(complaintsAbout(broken), contains('unknown port "nowhere"'));
    });

    test('a stock over no time at all', () {
      final p = whole();
      final broken = p.copyWith(pins: [
        const StockPin(
            nodeId: 'elec', portId: 'oxygen', amount: 100, durationSeconds: 0),
      ]);
      expect(complaintsAbout(broken), contains('positive duration'));
    });
  });
}
