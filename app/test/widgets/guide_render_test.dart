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

  testWidgets('every topic is listed, and every topic opens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(harness(GuidePanel(
      onClose: () {},
      // The asset is real I/O, which a widget test cannot wait for; the file
      // on disk is the same bytes and the other test proves it.
      load: () async => markdown,
    )));
    await tester.pumpAndSettle();

    final guide = splitGuide(markdown);
    expect(guide.topics.length, greaterThan(5));

    for (final topic in guide.topics) {
      // Listed, with a line saying what it is about — taken from the topic's
      // own first sentence, so it cannot say something the topic does not.
      await tester.scrollUntilVisible(find.text(topic.title), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(topic.title), findsOneWidget, reason: topic.title);
      // The hint is the topic's own first sentence with the Markdown taken
      // out, so it cannot say something the topic does not — but it does have
      // to say something.
      expect(topic.hint, isNotEmpty, reason: '${topic.title} says nothing');
      expect(topic.body, contains(topic.hint.split(' ').first));

      // And it opens: the words under that heading really reach the screen,
      // which is what the list would otherwise be hiding.
      await tester.tap(find.text(topic.title));
      await tester.pumpAndSettle();
      final firstWords = topic.body
          .split('\n')
          .map((line) => line.trim())
          .firstWhere((line) =>
              line.isNotEmpty && !line.startsWith('- ') && !line.contains('*'));
      expect(find.textContaining(firstWords.split('.').first.trim()),
          findsWidgets,
          reason: '${topic.title} opened on nothing');

      await tester.tap(find.text('← All topics'));
      await tester.pumpAndSettle();
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
