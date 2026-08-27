import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/changelog_panel.dart';
import 'package:oni_pipeline/panels/guide_panel.dart';
import 'package:oni_pipeline/state/news_controller.dart';
import 'package:oni_pipeline/storage/json_store.dart';

import '../support/harness.dart';

/// Being told the app has changed, and being able to read what changed.
void main() {
  const log = '''
# What's new

What has changed, newest first.

## 28 August 2026 — Wires

Two wires into one port say what they are doing.

## 27 August 2026 — The one with the critters

An Oakshell. A Cuddle Pip.

## 26 August 2026 — Food

Plants grow crops rather than calories.
''';

  Future<NewsController> newsWith(String? seen) async {
    final news = NewsController(
      store: MemoryJsonStore(seen == null ? null : {'seen': seen}),
      load: () async => log,
    );
    await news.load();
    return news;
  }

  Future<void> pumpEditor(WidgetTester tester, NewsController news) async {
    await useDesktopSurface(tester);
    final controller = testController();
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
      news: news,
    )));
    await tester.pump();
  }

  test('the newest entry is what "seen" means', () {
    expect(latestRelease(log), '28 August 2026 — Wires');
    // A changelog with no entries has no news, rather than some empty news.
    expect(latestRelease('# What\'s new\n\nNothing yet.\n'), isNull);
  });

  test('somebody arriving for the first time is not told anything', () async {
    // "What's new" to them is all of it, and a notice on a canvas they have
    // never seen is noise. Where they came in is recorded silently.
    final store = MemoryJsonStore();
    final news = NewsController(store: store, load: () async => log);
    await news.load();

    expect(news.unread, isNull);
    expect(store.data?['seen'], '28 August 2026 — Wires');
  });

  test('and somebody who was last here a release ago is', () async {
    final news = await newsWith('27 August 2026 — The one with the critters');
    expect(news.unread, '28 August 2026 — Wires');
    expect(news.unreadCount, 1);
  });

  test('and two releases ago is told how many', () async {
    final news = await newsWith('26 August 2026 — Food');
    expect(news.unreadCount, 2);
  });

  test('an entry that has since been renamed cannot be counted', () async {
    // A wrong count is worse than none, and a wrong cut would hide entries.
    final news = await newsWith('25 August 2026 — A release that was renamed');
    expect(news.unread, isNotNull);
    expect(news.unreadCount, isNull);
  });

  test('a changelog that will not load says nothing at all', () async {
    // It is the least urgent thing on the page. Somebody came here to plan a
    // base, not to be told the news could not be fetched.
    final news = NewsController(
      store: MemoryJsonStore(),
      load: () async => throw const FileSystemException('no such asset'),
    );
    await news.load();

    expect(news.unread, isNull);
  });

  testWidgets('the notice names the release and opens it', (tester) async {
    await pumpEditor(tester, await newsWith('26 August 2026 — Food'));

    // Two of them, and it says two: counting how much is new is most of what
    // somebody wants from a changelog.
    expect(textContaining('2 changes to harmONIc'), findsOneWidget);

    await tester.tap(find.text("What's new"));
    await tester.pumpAndSettle();

    expect(find.byType(ChangelogPanel), findsOneWidget);
    expect(textContaining('2 changes since you were last here'),
        findsOneWidget);
    // The two they have not read, and not the one they have.
    expect(find.text('28 August 2026 — Wires'), findsOneWidget);
    expect(find.text('27 August 2026 — The one with the critters'),
        findsOneWidget);
    expect(find.text('26 August 2026 — Food'), findsNothing);

    // The rest is a click away rather than gone.
    await tester.tap(find.text('Show everything'));
    await tester.pumpAndSettle();
    expect(find.text('26 August 2026 — Food'), findsOneWidget);
  });

  testWidgets('and reading it means it is read', (tester) async {
    final news = await newsWith('26 August 2026 — Food');
    await pumpEditor(tester, news);

    await tester.tap(find.text("What's new"));
    await tester.pumpAndSettle();

    expect(news.unread, isNull);
    // But what they opened is still on screen: marking it read must not empty
    // the thing they just asked to read.
    expect(find.text('28 August 2026 — Wires'), findsOneWidget);
  });

  testWidgets('dismissing counts as reading it', (tester) async {
    // Somebody who does not care that there is news should not be asked twice.
    final news = await newsWith('26 August 2026 — Food');
    await pumpEditor(tester, news);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(news.unread, isNull);
    expect(find.byType(ChangelogPanel), findsNothing);
  });

  testWidgets('and there is a way in when there is no notice', (tester) async {
    // The notice is dismissible and never comes back, and somebody arriving
    // for the first time never gets one at all — so without this the history
    // would be unreachable for everybody who most wanted it.
    await pumpEditor(tester, await newsWith(null));
    expect(find.text('Dismiss'), findsNothing);

    await tester.ensureVisible(find.text('Guide'));
    await tester.pump();
    await tester.tap(find.text('Guide'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("What's new"));
    await tester.pumpAndSettle();

    expect(find.byType(ChangelogPanel), findsOneWidget);
    expect(textContaining('26 August 2026 — Food'), findsWidgets);

    // On top of the guide, not under it. Opened from the guide's own footer,
    // it went into the stack before the guide did and the guide painted over
    // it — so it was there, and reading it meant closing the thing that had
    // just offered it. Tapping an entry proves it is the one taking clicks.
    await tester.tap(find.text('26 August 2026 — Food').first);
    await tester.pumpAndSettle();
    // The body is rich text — the renderer builds spans so bold and code
    // work — so a plain text finder cannot see it.
    expect(
      find.textContaining('Plants grow crops rather than calories',
          findRichText: true),
      findsWidgets,
    );
  });

  test('the shipped changelog is the one in docs, to the byte', () {
    // The same rule as the guide: docs/CHANGELOG.md is the copy people read in
    // the repository, and tool/copy_docs.sh makes the second one.
    expect(
      File('assets/changelog.md').readAsStringSync(),
      File('../docs/CHANGELOG.md').readAsStringSync(),
      reason: 'run tool/copy_docs.sh — the app ships a stale changelog',
    );
  });

  test('and it stays inside the Markdown the renderer knows', () {
    // Headings, paragraphs, bullets, bold, italic and code. A table or a link
    // would reach the reader as a row of pipes or a pair of brackets.
    final text = File('../docs/CHANGELOG.md').readAsStringSync();
    expect(text, isNot(contains('|')));
    expect(text, isNot(matches(RegExp(r'\[[^\]]+\]\([^)]+\)'))));

    final entries = splitGuide(text).topics;
    expect(entries.length, greaterThan(1));
    for (final entry in entries) {
      expect(entry.hint, isNotEmpty, reason: entry.title);
    }
  });
}
