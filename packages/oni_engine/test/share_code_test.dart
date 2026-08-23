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

  group('a build from a newer app', () {
    Map<String, dynamic> fromTheFuture() {
      final pipeline = (PipelineBuilder(db, name: 'later')
            ..addSource('water')
            ..add('electrolyzer', nodeId: 'elec')
            ..connectItem('src_water', 'elec', 'water')
            ..pinCount('elec', 2))
          .build();
      return pipeline.toJson()..['schemaVersion'] = 99;
    }

    test('is refused, rather than read as though it were this one', () {
      // It used to open: the version was recorded, ignored, and written back
      // unchanged — so an older app would quietly reinterpret a newer file and
      // then save it still claiming to be the newer format.
      expect(
        () => Pipeline.fromJson(fromTheFuture()),
        throwsA(isA<FormatException>().having(
          (e) => e.message,
          'says what to do',
          allOf(contains('newer version'), contains('Update')),
        )),
      );
    });

    test('and a share code carrying one says the same', () {
      final code = base64Url.encode(utf8.encode(jsonEncode(fromTheFuture())));
      expect(() => PipelineShareCode.decode(code),
          throwsA(isA<FormatException>()));
      expect(PipelineShareCode.looksValid(code), isFalse);
    });

    test('and this app writes the version it actually understands', () {
      final pipeline = (PipelineBuilder(db, name: 'now')..addSource('water'))
          .build();
      expect(pipeline.toJson()['schemaVersion'], Pipeline.currentSchemaVersion);
      // Round-tripping must not invent a version either.
      expect(Pipeline.fromJson(pipeline.toJson()).schemaVersion,
          Pipeline.currentSchemaVersion);
    });
  });
}
