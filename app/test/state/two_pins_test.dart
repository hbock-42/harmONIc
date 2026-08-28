import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';

import '../support/harness.dart';

/// Two amounts set in one build, which issue #2 had to use an external tool
/// to get.
///
/// "Given that I actually have 3 Oil Wells and 8 Duplicants, what is left
/// over?" is a fair question and the solver answers it happily. Whether the
/// app lets you ask it is a different matter.
void main() {
  /// Water in, oxygen out, Duplicants breathing it: one amount anywhere
  /// settles the whole chain.
  Pipeline chain() => (PipelineBuilder(testDatabase, name: 'two pins')
        ..addSource('water', x: 0, y: 0)
        ..add('electrolyzer', nodeId: 'elec', x: 320, y: 0)
        ..add('duplicant', nodeId: 'dupes', x: 640, y: 0)
        ..addSink('hydrogen', nodeId: 'h2', x: 640, y: 240)
        ..connectItem('src_water', 'elec', 'water')
        ..connectItem('elec', 'dupes', 'oxygen')
        ..connectItem('elec', 'h2', 'hydrogen'))
      .build();

  test('the second amount replaces the first once the build is settled', () {
    final c = testController(pipeline: chain());
    expect(c.solution.status, SolveStatus.underdetermined);

    c.pin(const BuildingCountPin(nodeId: 'dupes', count: 8));
    expect(c.solution.status, SolveStatus.solved);
    expect(c.pipeline.pins, hasLength(1));

    // Now say how many Electrolyzers as well, which is the shape of "I have
    // three Oil Wells *and* eight Duplicants".
    c.pin(const BuildingCountPin(nodeId: 'elec', count: 2));

    expect(c.pinFor('dupes'), isNull,
        reason: 'the first amount is gone: this is what sent somebody to an '
            'external tool to force two of them');
    expect(c.pipeline.pins, hasLength(1));
    // And it says so, which it did not: an amount that disappears without a
    // word reads as the app losing it rather than deciding something.
    expect(c.notice, contains('The amount on the Duplicant is gone'));
    expect(c.notice, contains('⌘Z'));
  });

  test('and in a chain with no slack the two would have disagreed anyway', () {
    // Worth being straight about: eight Duplicants need 0.9 of an
    // Electrolyzer, so saying "and two Electrolyzers" is a contradiction
    // rather than extra information. Loaded straight past the app, both pins
    // survive and the build says it cannot hold them.
    final both = chain().copyWith(pins: const [
      BuildingCountPin(nodeId: 'dupes', count: 8),
      BuildingCountPin(nodeId: 'elec', count: 2),
    ]);
    final c = testController(pipeline: both);

    expect(c.pipeline.pins, hasLength(2));
    expect(c.solution.status, SolveStatus.inconsistent);
  });

  test('and where there is slack, both are kept and both hold', () {
    // Which is the case issue #2 is about: a spare output takes the
    // difference, so two amounts are two facts rather than an argument.
    final base = (PipelineBuilder(testDatabase, name: 'with slack')
          ..add('water_sieve', nodeId: 'sieve', x: 0, y: 0)
          ..addSource('polluted_water')
          ..add('electrolyzer', nodeId: 'elec', x: 320, y: 0)
          ..add('duplicant', nodeId: 'dupes', x: 640, y: 0)
          ..addSink('hydrogen', nodeId: 'h2', x: 640, y: 240)
          ..addSink('water', nodeId: 'spare', x: 320, y: 240)
          ..connectItem('src_polluted_water', 'sieve', 'polluted_water')
          ..connectItem('elec', 'dupes', 'oxygen')
          ..connectItem('elec', 'h2', 'hydrogen'))
        .build();
    final withSpare = base.copyWith(edges: [
      ...base.edges,
      const PipelineEdge(
        id: 'to_elec',
        fromNodeId: 'sieve',
        fromPortId: 'water',
        toNodeId: 'elec',
        toPortId: 'water',
      ),
      const PipelineEdge(
        id: 'to_spare',
        fromNodeId: 'sieve',
        fromPortId: 'water',
        toNodeId: 'spare',
        toPortId: 'in',
        mode: EdgeMode.rest,
      ),
    ]);

    final c = testController(pipeline: withSpare);
    c.pin(const BuildingCountPin(nodeId: 'dupes', count: 8));
    // Still loose: the spare line means the sieve is not sized by what draws
    // from it, so there is a second amount to give.
    expect(c.solution.status, SolveStatus.underdetermined);

    c.pin(const BuildingCountPin(nodeId: 'sieve', count: 1));
    expect(c.pipeline.pins, hasLength(2),
        reason: 'both kept, because the build was not settled by the first');
    expect(c.notice, isNull, reason: 'nothing was taken away');
    expect(c.solution.status, SolveStatus.solved);
    expect(c.solution.nodes['dupes']!.count, closeTo(8, 1e-9));
    expect(c.solution.nodes['sieve']!.count, closeTo(1, 1e-9));
  });
}
