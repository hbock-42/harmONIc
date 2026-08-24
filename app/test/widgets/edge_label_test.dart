import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/canvas/edge_painter.dart';
import 'package:oni_engine/oni_engine.dart';

PipelineEdge _edge(String id, String from, String to) => PipelineEdge(
      id: id,
      fromNodeId: from,
      fromPortId: 'out',
      toNodeId: to,
      toPortId: 'in',
    );

Pipeline _of(List<PipelineEdge> edges) => Pipeline(
      id: 'p',
      name: 'p',
      nodes: const [],
      edges: edges,
    );

void main() {
  test('a wire on its own carries its number in the middle', () {
    final fractions = EdgePainter.labelFractions(_of([_edge('a', 'x', 'y')]));
    expect(fractions['a'], EdgePainter.labelPosition);
  });

  test('two wires between the same pair do not print over each other', () {
    // An Electrolyzer feeding a Hydrogen Generator that powers it back: both
    // wires run the same corridor, and both labels at the middle was one
    // number drawn on top of another.
    final fractions = EdgePainter.labelFractions(_of([
      _edge('h', 'elec', 'gen'),
      _edge('p', 'gen', 'elec'),
    ]));

    // Each is a fraction along its *own* path, and the two paths run in
    // opposite directions — so the same number would be the same place.
    final hydrogen = fractions['h']!;
    final power = 1 - fractions['p']!;
    expect((hydrogen - power).abs(), greaterThan(0.3));
  });

  test('and neither ends up on a port', () {
    final fractions = EdgePainter.labelFractions(_of([
      for (var i = 0; i < 4; i++) _edge('e$i', 'a', 'b'),
    ]));
    for (final along in fractions.values) {
      expect(along, inInclusiveRange(0.15, 0.85));
    }
    expect(fractions.values.toSet(), hasLength(4));
  });
}
