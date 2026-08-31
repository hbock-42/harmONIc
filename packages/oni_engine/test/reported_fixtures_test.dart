import 'dart:io';

import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// The builds people actually sent in, and what the app makes of them.
///
/// Two of these were only ever round-tripped through the share code and never
/// asked what they *do*. They are here because somebody reported them, so what
/// the app says about them is the thing worth holding still — a data change or
/// a reworded message can turn a useful diagnosis into a useless one and no
/// other test would notice.
void main() {
  final db = loadDefaultDatabase();

  Pipeline load(String name) => PipelineShareCode.decode(
      File('test/fixtures/$name.txt').readAsStringSync().trim());

  PipelineSolution solve(String name) => PipelineSolver(db).solve(load(name));

  String said(PipelineSolution s) => s.issues.map((i) => i.message).join(' ');

  group('the ethanol loop, 54 nodes', () {
    test('still will not balance, which is why it is here', () {
      expect(solve('reported_ethanol_loop').status, SolveStatus.inconsistent);
    });

    test('and says the shares nobody has divided', () {
      // Four ports where two lines split something evenly because nothing
      // said otherwise. That guess is the reason the build surprises people.
      final message = said(solve('reported_ethanol_loop'));
      expect(message, contains('bring dirt into the Arbor Tree'));
      expect(message, contains('which is a guess'));
    });

    test('and does not pretend to know which ports are at fault', () {
      // Venting any four of them still leaves it unsolvable — checked by
      // raising the search's own limit — so naming a set would be a guess
      // dressed as an answer. Saying there is no single culprit is the
      // honest reading and it is what this must keep saying.
      final message = said(solve('reported_ethanol_loop'));
      expect(message, contains('No one of these is the problem on its own'));
      expect(message, isNot(contains('No one port explains this')));
    });

    test('and still names them, so there is somewhere to start', () {
      final targets = solve('reported_ethanol_loop')
          .issues
          .expand((i) => i.places)
          .where((p) => p.portId != null)
          .toList();
      expect(targets.length, greaterThan(4));
    });
  });

  group('the petroleum fuel loop, 14 nodes', () {
    test('still will not balance', () {
      expect(solve('reported_petroleum_fuel').status,
          SolveStatus.inconsistent);
    });

    test('and here one port does explain it', () {
      // The other half of the pair: this one has a single culprit, so the
      // app must name it rather than hand over a list. If both builds ever
      // read the same way, one of the two answers has stopped working.
      final message = said(solve('reported_petroleum_fuel'));
      expect(message, contains('Slickster’s crude oil'));
      expect(message, isNot(contains('No one of these')));
    });
  });

  test('and every saved build in here still opens', () {
    // Including the ones under found/, which are compressed and which the
    // size test deliberately skips.
    final files = [
      ...Directory('test/fixtures').listSync().whereType<File>(),
      ...Directory('test/fixtures/found').listSync().whereType<File>(),
    ].where((f) => f.path.endsWith('.txt'));
    expect(files, hasLength(greaterThan(4)));
    for (final file in files) {
      expect(() => PipelineShareCode.decode(file.readAsStringSync().trim()),
          returnsNormally, reason: file.path);
    }
  });
}
