import 'dart:io';

import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// A share code you can send, and every code ever sent before it.
///
/// Every build reported this month arrived as a file attachment, because its
/// code ran to sixteen or twenty thousand characters and neither a chat
/// message nor a URL will carry that.
void main() {
  final db = loadDefaultDatabase();

  /// The real ones, exactly as they were pasted into chat and into issue #2.
  ///
  /// Only the top of the directory, and that is the point of it: everything
  /// here was written by the old encoder and is checked as such. Builds found
  /// some other way -- a fuzz run, say -- are saved under a subdirectory,
  /// because a code this app wrote today is compressed and would fail every
  /// assertion below for a reason that says nothing about anything.
  final reported = Directory('test/fixtures')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.txt'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('every code written before compression still opens', () {
    expect(reported, isNotEmpty);
    for (final file in reported) {
      final code = file.readAsStringSync().trim();
      // Written by the old encoder, so plain base64 of the JSON.
      expect(code.startsWith('H4sI'), isFalse, reason: file.path);
      expect(() => PipelineShareCode.decode(code), returnsNormally,
          reason: file.path);
    }
  });

  test('and comes back as the same build, field for field', () {
    for (final file in reported) {
      final was = PipelineShareCode.decode(file.readAsStringSync().trim());
      final now = PipelineShareCode.decode(PipelineShareCode.encode(was));
      expect(now.toJson(), equals(was.toJson()), reason: file.path);
    }
  });

  test('and solves to the same figures either way', () {
    // The reason to care: a code that decodes but answers differently is
    // worse than one that fails outright.
    final solver = PipelineSolver(db);
    for (final file in reported) {
      final was = PipelineShareCode.decode(file.readAsStringSync().trim());
      final now = PipelineShareCode.decode(PipelineShareCode.encode(was));
      final before = solver.solve(was);
      final after = solver.solve(now);
      expect(after.status, before.status, reason: file.path);
      for (final entry in before.nodes.entries) {
        expect(after.nodes[entry.key]!.count,
            closeTo(entry.value.count, 1e-9), reason: '${file.path} ${entry.key}');
      }
    }
  });

  test('and a real build now fits in a link', () {
    // The point of the exercise. The report form carries a build in its URL
    // when it fits, and before this it never did for a build worth reporting.
    for (final file in reported) {
      final was = PipelineShareCode.decode(file.readAsStringSync().trim());
      final code = PipelineShareCode.encode(was);
      expect(code.length, lessThan(file.readAsStringSync().trim().length ~/ 3),
          reason: '${file.path} should be under a third of what it was');
      expect(shareCodeFitsInAUrl(code), isTrue, reason: file.path);
    }
  });
}

/// The budget the report link works to, measured against github.com rather
/// than guessed: 6 000 characters for the whole URL.
bool shareCodeFitsInAUrl(String code) => code.length <= 6000;
