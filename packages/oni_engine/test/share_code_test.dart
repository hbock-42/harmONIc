import 'dart:convert';

import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

void main() {
  final db = loadDefaultDatabase();

  Pipeline sample() => (PipelineBuilder(db, name: 'Shared build')
        ..addSource('water', x: 8, y: 16)
        ..add('electrolyzer', nodeId: 'elec', x: 320, y: 16)
        ..add('duplicant', nodeId: 'dupes', x: 640, y: 16)
        ..connectItem('src_water', 'elec', 'water')
        ..connectItem('elec', 'dupes', 'oxygen')
        ..pinCount('dupes', 9))
      .build();

  test('a build survives the round trip whole', () {
    final original = sample();
    final restored = PipelineShareCode.decode(
        PipelineShareCode.encode(original));

    expect(restored.name, original.name);
    expect(restored.nodes.length, original.nodes.length);
    expect(restored.edges.length, original.edges.length);
    expect(restored.pins.length, original.pins.length);
    expect(restored.nodeOrThrow('elec').x, 320);
  });

  test('it still solves to the same numbers', () {
    final solver = PipelineSolver(db);
    final before = solver.solve(sample());
    final after =
        solver.solve(PipelineShareCode.decode(PipelineShareCode.encode(sample())));

    expect(after.status, before.status);
    for (final id in before.nodes.keys) {
      expect(after.nodes[id]!.count, closeTo(before.nodes[id]!.count, 1e-9));
    }
  });

  test('the code is one line, so it pastes anywhere', () {
    final code = PipelineShareCode.encode(sample());
    expect(code, isNot(contains('\n')));
    expect(code, isNot(contains(' ')));
  });

  test('raw JSON is accepted too', () {
    // Someone handed a pipelines.json will paste that, and should be right to.
    final json = jsonEncode(sample().toJson());
    expect(PipelineShareCode.decode(json).name, 'Shared build');
  });

  test('padding stripped by a chat client is put back', () {
    final code = PipelineShareCode.encode(sample());
    final mangled = code.replaceAll('=', '');
    expect(PipelineShareCode.decode(mangled).name, 'Shared build');
  });

  test('whitespace from a line-wrapped paste is tolerated', () {
    final code = PipelineShareCode.encode(sample());
    final wrapped = '${code.substring(0, 20)}\n${code.substring(20)}';
    expect(PipelineShareCode.decode(wrapped).name, 'Shared build');
  });

  group('rejecting nonsense', () {
    test('empty input', () {
      expect(() => PipelineShareCode.decode('   '), throwsFormatException);
      expect(PipelineShareCode.looksValid(''), isFalse);
    });

    test('a paste that is not a pipeline at all', () {
      expect(() => PipelineShareCode.decode('hello there'),
          throwsFormatException);
      expect(PipelineShareCode.looksValid('hello there'), isFalse);
    });

    test('valid base64 that decodes to something else', () {
      final notAPipeline = base64Url.encode(utf8.encode('{"a":1}'));
      expect(() => PipelineShareCode.decode(notAPipeline), throwsA(anything));
      expect(PipelineShareCode.looksValid(notAPipeline), isFalse);
    });

    test('a real code is recognised', () {
      expect(PipelineShareCode.looksValid(PipelineShareCode.encode(sample())),
          isTrue);
    });
  });
}
