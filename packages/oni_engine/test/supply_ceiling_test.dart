import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// A ceiling belongs to the supply, not to each of its lines.
///
/// Written onto every line it was a ceiling *per line*, so a supply feeding
/// two things gave twice what was allowed. Found by asking a demo build what
/// it could make from ten kilograms of ore a second and being told fifteen
/// kilograms of iron.
void main() {
  final db = loadDefaultDatabase();

  /// Ore divided between a refinery, which is one for one, and a crusher,
  /// which is half. Ten kilograms a second at most.
  Pipeline oreYard({double? nodeCap, double? perLineCap}) {
    final base = (PipelineBuilder(db, name: 'ore yard')
          ..addSource('iron_ore')
          ..add('metal_refinery', nodeId: 'refinery')
          ..add('rock_crusher_metal', nodeId: 'crusher')
          ..addSink('iron', nodeId: 'iron_out')
          ..connect('src_iron_ore', 'out', 'refinery', 'metal_ore',
              mode: EdgeMode.push)
          ..connect('src_iron_ore', 'out', 'crusher', 'metal_ore',
              mode: EdgeMode.push)
          ..connectItem('refinery', 'iron_out', 'refined_metal')
          ..connectItem('crusher', 'iron_out', 'refined_metal'))
        .build();
    return base.copyWith(
      nodes: [
        for (final node in base.nodes)
          if (node.id == 'src_iron_ore' && nodeCap != null)
            node.copyWith(capPerSecond: nodeCap)
          else
            node,
      ],
      edges: [
        for (final edge in base.edges)
          if (edge.fromNodeId == 'src_iron_ore' && perLineCap != null)
            edge.copyWith(capPerSecond: perLineCap)
          else
            edge,
      ],
    );
  }

  test('ten kilograms of ore cannot make more than ten of iron', () {
    final best = mostOf(oreYard(nodeCap: 10000), db, 'iron');
    expect(best.isAnswer, isTrue);
    // All of it to the refinery, which is one for one; the crusher would
    // throw half of it away.
    expect(best.ratePerSecond, closeTo(10000, 1e-6));
  });

  test('and the per-line version is what gave fifteen', () {
    // Kept as a test rather than deleted: it is what the old ceiling meant,
    // and builds saved with it still carry it.
    final best = mostOf(oreYard(perLineCap: 10000), db, 'iron');
    expect(best.ratePerSecond, closeTo(15000, 1e-6),
        reason: 'each line allowed ten, so the supply gave twenty');
  });

  test('and a build that needs more than the ceiling says so', () {
    // The ordinary solver cannot hold an inequality, so like a valve this is
    // a warning after the fact rather than a wall.
    final base = (PipelineBuilder(db, name: 'over the ceiling')
          ..addSource('iron_ore')
          ..add('metal_refinery', nodeId: 'refinery')
          ..addSink('iron', nodeId: 'iron_out')
          ..connect('src_iron_ore', 'out', 'refinery', 'metal_ore')
          ..connectItem('refinery', 'iron_out', 'refined_metal')
          ..pinCount('refinery', 4))
        .build();
    final tight = base.copyWith(nodes: [
      for (final node in base.nodes)
        if (node.id == 'src_iron_ore')
          node.copyWith(capPerSecond: 1000)
        else
          node,
    ]);

    final said =
        PipelineSolver(db).solve(tight).issues.map((i) => i.message).join(' ');
    expect(said, contains('you have said you have at most'));
    expect(said, contains('Iron Ore supply'));
  });

  test('and it survives being written down and read back', () {
    final there = oreYard(nodeCap: 10000);
    final back = PipelineShareCode.decode(PipelineShareCode.encode(there));
    expect(back.nodeOrThrow('src_iron_ore').capPerSecond, 10000);
  });
}
