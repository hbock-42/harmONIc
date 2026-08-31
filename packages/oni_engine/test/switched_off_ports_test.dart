import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// An input you can decline, and the output that goes with it.
///
/// Asked for as "dynamic output based on provided input lines". This is the
/// part of that which can be said exactly: one input turns one output on and
/// off. A Glo Squid gives squid ink because somebody milks it — stop milking
/// and it still eats, still grows, still sheds abyssalite, and gives no ink.
/// A ranch run that way is a real ranch and there was no way to draw one.
///
/// What this deliberately does not do is change a rate. A Critter Condo gives
/// a critter one point of happiness where grooming gives five, which is full
/// output and about a quarter of the eggs, and that is a different mechanism.
void main() {
  final db = loadDefaultDatabase();

  test('a port is switchable exactly when something needs it', () {
    // A Glo Squid has two: its milking, which is the whole of why there is
    // ink, and its grooming, which is most of why there are eggs.
    final squid = db.processOrThrow('glo_squid');
    expect(squid.switchablePorts.map((p) => p.id),
        containsAll(['grooming', 'milking']));

    // A critter's grooming, since what it buys is eggs and an ungroomed one
    // still lays some.
    expect(db.processOrThrow('hatch').switchablePorts.map((p) => p.id),
        ['grooming']);

    // And being fed is still not optional, nor is anything a building takes:
    // a Hatch that is not fed is not a Hatch on short rations.
    expect(
        db
            .processOrThrow('hatch')
            .switchablePorts
            .map((p) => p.id)
            .contains('raw_mineral'),
        isFalse);
    expect(db.processOrThrow('electrolyzer').switchablePorts, isEmpty);
  });

  Pipeline ranch({bool milked = true}) {
    final base = (PipelineBuilder(db, name: 'squid ranch')
          ..add('glo_squid', nodeId: 'squid')
          ..addSource('grooming')
          ..addSource('milking')
          ..addSource('tublia_growth')
          ..addSink('squid_ink')
          ..addSink('abyssalite')
          ..addSink('calamari')
          ..connectItem('src_grooming', 'squid', 'grooming')
          ..connectItem('src_milking', 'squid', 'milking')
          ..connectItem('src_tublia_growth', 'squid', 'tublia_growth')
          ..connectItem('squid', 'sink_squid_ink', 'squid_ink')
          ..connectItem('squid', 'sink_abyssalite', 'abyssalite')
          ..connectItem('squid', 'sink_calamari', 'calamari')
          ..pinCount('squid', 10))
        .build();
    if (milked) return base;
    return base.copyWith(nodes: [
      for (final node in base.nodes)
        if (node.id == 'squid')
          node.copyWith(portsSwitchedOff: {'milking'})
        else
          node,
    ]);
  }

  double into(PipelineSolution s, String sink) => s.portBalances
      .firstWhere((b) => b.ref.nodeId == sink && b.direction ==
          PortDirection.input)
      .rate;

  test('milked, it gives ink', () {
    final solved = PipelineSolver(db).solve(ranch());
    expect(solved.status, SolveStatus.solved);
    expect(into(solved, 'sink_squid_ink'), greaterThan(0));
  });

  test('unmilked, it gives none — and everything else is unchanged', () {
    final milked = PipelineSolver(db).solve(ranch());
    final not = PipelineSolver(db).solve(ranch(milked: false));
    expect(not.status, SolveStatus.solved);
    expect(into(not, 'sink_squid_ink'), 0);
    expect(into(not, 'sink_abyssalite'),
        closeTo(into(milked, 'sink_abyssalite'), 1e-9));
    expect(into(not, 'sink_calamari'),
        closeTo(into(milked, 'sink_calamari'), 1e-9));
  });

  test('and it stops asking for the milking too', () {
    // The half that makes it worth having: a ranch nobody milks should not be
    // told it needs a Milking Station.
    final not = PipelineSolver(db).solve(ranch(milked: false));
    final asked = not.portBalances.firstWhere(
        (b) => b.ref.nodeId == 'squid' && b.ref.portId == 'milking');
    expect(asked.rate, 0);
  });

  test('the choice travels in a share code', () {
    final code = PipelineShareCode.encode(ranch(milked: false));
    final back = PipelineShareCode.decode(code);
    expect(back.nodeOrThrow('squid').portsSwitchedOff, {'milking'});
    expect(back.nodeOrThrow('squid').switchedOff('milking'), isTrue);
  });
}
