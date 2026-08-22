import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/panels/guide_panel.dart';

import '../support/harness.dart';

/// The guide is written for the repository and read in the app.
///
/// One test already checks the shipped copy is byte-for-byte the one in
/// `docs/`. This checks the other half: that what is written there survives
/// the thirty-line renderer that puts it on screen. The renderer knows
/// headings, paragraphs, bullets, bold, italic and code, and nothing else —
/// so a table or a link added to the guide would reach the reader as a row of
/// pipes or a pair of brackets, and nobody editing a Markdown file would
/// expect that.
void main() {
  final markdown = File('../docs/USING.md').readAsStringSync();

  testWidgets('every section reaches the screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(harness(GuidePanel(
      onClose: () {},
      // The asset is real I/O, which a widget test cannot wait for; the file
      // on disk is the same bytes and the other test proves it.
      load: () async => markdown,
    )));
    await tester.pumpAndSettle();

    final headings = [
      for (final line in markdown.split('\n'))
        if (line.startsWith('## ')) line.substring(3),
    ];
    expect(headings.length, greaterThan(5));
    for (final heading in headings) {
      await tester.scrollUntilVisible(find.text(heading), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(heading), findsOneWidget, reason: heading);
    }
  });

  test('and it stays inside the Markdown the renderer knows', () {
    final unsupported = <String>[];
    for (final (index, line) in markdown.split('\n').indexed) {
      final trimmed = line.trim();
      final at = 'line ${index + 1}';
      if (trimmed.startsWith('###')) unsupported.add('$at: a deeper heading');
      if (trimmed.startsWith('|')) unsupported.add('$at: a table');
      if (trimmed.startsWith('> ')) unsupported.add('$at: a quote');
      if (trimmed.startsWith('```')) unsupported.add('$at: a code fence');
      if (RegExp(r'^\d+\.\s').hasMatch(trimmed)) {
        unsupported.add('$at: a numbered list');
      }
      if (RegExp(r'\[[^\]]+\]\([^)]+\)').hasMatch(trimmed)) {
        unsupported.add('$at: a link');
      }
    }

    expect(unsupported, isEmpty,
        reason: 'the guide is rendered by a subset of Markdown, so this would '
            'reach the reader as punctuation. Either say it another way, or '
            'teach the renderer — which is the moment to reach for a package.');
  });
}
