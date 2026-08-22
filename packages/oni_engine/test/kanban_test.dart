import 'dart:io';

import 'package:test/test.dart';

/// The kanban has to agree with itself.
///
/// It has drifted twice, in the same way both times: work gets done, the epic
/// table is ticked, and the entry in **Ready** describing the work stays where
/// it is. Nine of twenty-eight Ready entries were things already finished when
/// this was written — including two that had been finished for weeks — and the
/// only reason anybody noticed is that picking the next task kept turning up
/// tasks that were done.
///
/// A board nobody trusts is worse than no board, so the disagreements it can
/// have are checked here rather than re-read by hand.
///
/// It lives in the engine package for want of anywhere better: the repository
/// has no test runner of its own, and this is the one that costs nothing to
/// start. It reads the file from the disk, so it is checking the real thing.
void main() {
  final markdown = File('../../KANBAN.md').readAsStringSync();

  String section(String from, String to) {
    final start = markdown.indexOf(from);
    if (start < 0) throw StateError('KANBAN.md has no "$from" heading');
    final end = markdown.indexOf(to, start);
    if (end < 0) throw StateError('KANBAN.md has no "$to" after "$from"');
    return markdown.substring(start, end);
  }

  final board = section('## Board', '\n## E');
  final ready = section('### 📋 Ready', '### 🚧 In Progress');
  final done = section('### ✅ Done', '\n## E');

  final idPattern = RegExp(r'`(E\d+-\d+[a-z]?)`');
  Set<String> idsIn(String text) =>
      {for (final m in idPattern.allMatches(text)) m.group(1)!};

  // "| E4-11a | ✅ | …" — the id and the status column of every table row.
  final status = <String, String>{};
  final duplicates = <String>[];
  for (final match
      in RegExp(r'^\| (E\d+-\d+[a-z]?) \| ([^|]*) \|', multiLine: true)
          .allMatches(markdown)) {
    final id = match.group(1)!;
    if (status.containsKey(id)) duplicates.add(id);
    status.putIfAbsent(id, () => match.group(2)!.trim());
  }

  test('every id has exactly one row in its epic table', () {
    // E12 and E7-14 were each handed out twice, and both took a while to
    // notice, which is why this is checked rather than trusted.
    expect(duplicates, isEmpty);
  });

  test('every id on the board has a row', () {
    // The board says what happened; the tables say what each id *is*. A board
    // entry with no row is a piece of work nobody can look up.
    final orphans = idsIn(board).difference(status.keys.toSet());
    expect(orphans, isEmpty);
  });

  test('nothing in Ready is already done', () {
    // The drift this file exists for.
    final finished = [
      for (final id in idsIn(ready))
        if (status[id] == '✅' || status[id] == '❌') '$id (${status[id]})',
    ];
    expect(finished, isEmpty,
        reason: 'Ready is offering work its own table calls finished');
  });

  test('everything on the Done board is ticked in its table', () {
    final unticked = [
      for (final id in idsIn(done))
        if (status[id] != '✅' && status[id] != '❌') '$id (${status[id]})',
    ];
    expect(unticked, isEmpty);
  });

  test('every status is one the legend explains', () {
    const known = {'✅', '❌', 'P0', 'P1', 'P2', 'P3', 'spike'};
    final unknown = {
      for (final entry in status.entries)
        if (!known.contains(entry.value)) '${entry.key}: "${entry.value}"',
    };
    expect(unknown, isEmpty);
  });
}
