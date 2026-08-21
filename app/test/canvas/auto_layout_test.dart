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
    double centreOf(String id, String specId) =>
        at[id]!.dy +
        NodeLayout.sizeOf(testDatabase.processOrThrow(specId)).height / 2;

    expect(
      (centreOf('src_water', 'source:water') - centreOf('elec', 'electrolyzer'))
          .abs(),
      lessThanOrEqualTo(NodeLayout.gridSize),
    );
  });
}
