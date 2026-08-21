import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/auto_layout.dart';
import 'package:oni_pipeline/canvas/geometry.dart';

import '../support/harness.dart';

void main() {
  Map<String, Offset> layoutOf(Pipeline pipeline) =>
      AutoLayout(pipeline: pipeline, database: testDatabase).positions();

  Pipeline build(void Function(PipelineBuilder) setUp) {
    final b = PipelineBuilder(testDatabase, name: 'layout test');
    setUp(b);
    return b.build();
  }

  test('an empty pipeline lays out to nothing', () {
    expect(layoutOf(build((b) {})), isEmpty);
  });

  test('a chain reads left to right, in order', () {
    final pipeline = build((b) => b
      ..addSource('water')
      ..add('electrolyzer', nodeId: 'elec')
      ..add('hydrogen_generator', nodeId: 'hgen')
      ..connectItem('src_water', 'elec', 'water')
      ..connectItem('elec', 'hgen', 'hydrogen'));

    final at = layoutOf(pipeline);
    expect(at['src_water']!.dx, lessThan(at['elec']!.dx));
    expect(at['elec']!.dx, lessThan(at['hgen']!.dx));
  });

  test('a node sits right of everything that feeds it, not just the first', () {
    final pipeline = build((b) => b
      ..addSource('water')
      ..add('coal_generator', nodeId: 'gen')
      ..add('electrolyzer', nodeId: 'elec')
      ..connectItem('src_water', 'elec', 'water')
      ..connectItem('gen', 'elec', 'power'));

    final at = layoutOf(pipeline);
    expect(at['elec']!.dx, greaterThan(at['src_water']!.dx));
    expect(at['elec']!.dx, greaterThan(at['gen']!.dx));
  });

  test('consumers of one output share a column', () {
    final pipeline = build((b) => b
      ..add('electrolyzer', nodeId: 'elec')
      ..add('duplicant', nodeId: 'dupes')
      ..add('hydrogen_generator', nodeId: 'hgen')
      ..connectItem('elec', 'dupes', 'oxygen')
      ..connectItem('elec', 'hgen', 'hydrogen'));

    final at = layoutOf(pipeline);
    expect(at['dupes']!.dx, at['hgen']!.dx);
    expect(at['dupes']!.dy, isNot(at['hgen']!.dy));
  });

  test('a recycling loop still terminates and reads forwards', () {
    // The generator powers the Electrolyzer that feeds it: something has to
    // point backwards, and the layout must not stretch to avoid it.
    final pipeline = build((b) => b
      ..addSource('water')
      ..add('electrolyzer', nodeId: 'elec')
      ..add('hydrogen_generator', nodeId: 'hgen')
      ..connectItem('src_water', 'elec', 'water')
      ..connectItem('elec', 'hgen', 'hydrogen')
      ..connectItem('hgen', 'elec', 'power'));

    final at = layoutOf(pipeline);
    expect(at, hasLength(3));
    expect(at['elec']!.dx, lessThan(at['hgen']!.dx),
        reason: 'the loop is broken at the edge that closes it');
    for (final position in at.values) {
      expect(position.dx.abs(), lessThan(10000));
    }
  });

  test('every position lands on the grid', () {
    final pipeline = build((b) => b
      ..addSource('water')
      ..add('electrolyzer', nodeId: 'elec')
      ..connectItem('src_water', 'elec', 'water'));

    for (final position in layoutOf(pipeline).values) {
      expect(position.dx % NodeLayout.gridSize, 0);
      expect(position.dy % NodeLayout.gridSize, 0);
    }
  });

  test('nodes in a column do not overlap', () {
    final pipeline = build((b) {
      b.add('electrolyzer', nodeId: 'elec');
      for (var i = 0; i < 5; i++) {
        b
          ..addSink('oxygen', nodeId: 'out$i')
          ..connect('elec', 'oxygen', 'out$i', sinkPortId,
              mode: EdgeMode.push, share: 0.2);
      }
    });

    final at = layoutOf(pipeline);
    final column = [for (var i = 0; i < 5; i++) at['out$i']!.dy]..sort();
    final height =
        NodeLayout.sizeOf(testDatabase.processOrThrow('sink:oxygen')).height;
    for (var i = 1; i < column.length; i++) {
      expect(column[i] - column[i - 1], greaterThanOrEqualTo(height));
    }
  });

  test('disconnected islands are still placed somewhere sensible', () {
    final pipeline = build((b) => b
      ..add('electrolyzer', nodeId: 'elec')
      ..add('coal_generator', nodeId: 'island'));

    final at = layoutOf(pipeline);
    expect(at, hasLength(2));
    expect(at['elec']!.dx, at['island']!.dx, reason: 'neither feeds the other');
    expect(at['elec']!.dy, isNot(at['island']!.dy));
  });

  test('a simple chain runs straight across', () {
    final pipeline = build((b) => b
      ..addSource('water')
      ..add('electrolyzer', nodeId: 'elec')
      ..connectItem('src_water', 'elec', 'water'));

    final at = layoutOf(pipeline);
    double portY(String id, String specId, String portId) =>
        at[id]!.dy +
        NodeLayout.portOffset(testDatabase.processOrThrow(specId), portId).dy;

    // Straight means the *wire* is flat, not that the two cards are centred on
    // each other. Those were the same thing while every node sat at the middle
    // of its column; now that a node slides to meet its wire, an Electrolyzer
    // whose water arrives at its first port row sits a little lower than the
    // supply feeding it, and the wire between them is level.
    expect(
      (portY('src_water', 'source:water', 'out') -
              portY('elec', 'electrolyzer', 'water'))
          .abs(),
      lessThanOrEqualTo(NodeLayout.gridSize),
    );
  });

  group('two builds on one canvas', () {
    /// Two chains that share nothing but the page, drawn interleaved so a
    /// naive layout would mix them.
    Pipeline twoBuilds() => build((b) => b
      ..addSource('water', x: 0, y: 0)
      ..add('electrolyzer', nodeId: 'elec', x: 300, y: 0)
      ..connectItem('src_water', 'elec', 'water')
      ..addSource('coquina', x: 0, y: 60)
      ..add('starnacle_grazed', nodeId: 'plants', x: 300, y: 60)
      ..connectItem('src_coquina', 'plants', 'coquina'));

    test('neither build has a node in the other one\'s rows', () {
      final at = layoutOf(twoBuilds());
      final first = {'src_water', 'elec'};

      double lowest(Iterable<String> ids) =>
          ids.map((id) => at[id]!.dy).reduce((a, b) => a > b ? a : b);
      double highest(Iterable<String> ids) =>
          ids.map((id) => at[id]!.dy).reduce((a, b) => a < b ? a : b);

      final other = at.keys.where((id) => !first.contains(id));
      // Every node of one build sits above every node of the other. Sharing a
      // row is exactly what made two tidy builds read as one tangled one.
      expect(lowest(first), lessThan(highest(other)));
    });

    test('both builds still read left to right from the same margin', () {
      final at = layoutOf(twoBuilds());
      expect(at['src_water']!.dx, lessThan(at['elec']!.dx));
      expect(at['src_coquina']!.dx, lessThan(at['plants']!.dx));
      expect(at['src_water']!.dx, at['src_coquina']!.dx);
    });

    test('tidying keeps the builds in the order they were already in', () {
      final at = layoutOf(twoBuilds());
      // The water build was drawn above the coquina one, and stays above it,
      // so tidying does not shuffle which build is which.
      expect(at['src_water']!.dy, lessThan(at['src_coquina']!.dy));
    });
  });
}