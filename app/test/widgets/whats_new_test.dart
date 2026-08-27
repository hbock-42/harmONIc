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

  test('somebody who was already here is told, even with nothing read',
      () async {
    // The day this shipped, nobody had read anything — so everybody counted
    // as arriving for the first time and nobody was told about the release
    // that added the telling. Saved builds are the evidence otherwise.
    final store = MemoryJsonStore();
    final news = NewsController(
      store: store,
      beenHereBefore: () async => true,
      load: () async => log,
    );
    await news.load();

    expect(news.unread, '28 August 2026 — Wires');
    // And nothing recorded on their behalf, so the panel shows the lot.
    expect(store.data, isNull);
    expect(news.since, isNull);
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

  test('two releases in one day are two releases', () async {
    // Reported before it could bite: several ships in a day is normal, and
    // the day is not what tells them apart.
    const sameDay = '''
# What's new

What has changed, newest first.

## 28 August 2026 — The changelog only shows what is new

Opening the notice shows what you have not read.

## 28 August 2026 — Wires

Two wires into one port say what they are doing.

## 27 August 2026 — Food

Plants grow crops rather than calories.
''';
    final news = NewsController(
      store: MemoryJsonStore({'seen': '28 August 2026 — Wires'}),
      load: () async => sameDay,
    );
    await news.load();

    expect(news.unread, '28 August 2026 — The changelog only shows what is new');
    expect(news.unreadCount, 1);
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
  group('the shape an entry has to have', () {
    // The panel reads this file rather than being told about it, so the
    // conventions are load-bearing rather than tidy: the cut between read and
    // unread is a heading, and the line under each entry in the list is its
    // own first sentence. A malformed entry does not look wrong in the
    // repository — it looks wrong to somebody who has just reloaded the app.
    final text = File('../docs/CHANGELOG.md').readAsStringSync();
    final entries = splitGuide(text).topics;

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    DateTime? dateOf(String title) {
      final match = RegExp(r'^(\d{1,2}) (\w+) (\d{4}) — .+').firstMatch(title);
      if (match == null) return null;
      final month = months.indexOf(match.group(2)!) + 1;
      if (month == 0) return null;
      return DateTime(int.parse(match.group(3)!), month,
          int.parse(match.group(1)!));
    }

    test('a date, an em dash and a title', () {
      for (final entry in entries) {
        // "Earlier" is the one exception, and it is the last one: everything
        // before the app had readers is one paragraph, not a series of dates
        // nobody was there for.
        if (entry.title == 'Earlier') {
          expect(entry, entries.last, reason: '"Earlier" comes last');
          continue;
        }
        expect(dateOf(entry.title), isNotNull,
            reason: '"${entry.title}" should read like '
                '"27 August 2026 — What the players found"');
      }
    });

    test('newest first, which is what the cut depends on', () {
      // Everything above the entry somebody last read is what is new to them.
      // Out of order, that shows them things they have already seen and hides
      // things they have not.
      //
      // Same day is allowed, and has to be: there can be several releases in
      // one day. What separates them is the title, which is why a heading is
      // a date *and* a title — the date alone was never the identifier.
      final dates = [
        for (final entry in entries)
          if (dateOf(entry.title) case final DateTime date) date,
      ];
      expect(dates, isNotEmpty);
      for (var i = 1; i < dates.length; i++) {
        expect(dates[i].isAfter(dates[i - 1]), isFalse,
            reason: '${entries[i].title} is newer than '
                '${entries[i - 1].title}');
      }
    });

    test('and no two entries share a heading', () {
      // The heading is how the app tells what somebody has already read. Two
      // the same would make one of them unreachable and the other permanent.
      final titles = [for (final entry in entries) entry.title];
      expect(titles.toSet(), hasLength(titles.length));
    });

    test('and a sentence before any bullets', () {
      // The list shows each entry's first sentence under its heading. An entry
      // that opens with a bullet has nothing to show there, and an entry whose
      // first sentence is 200 characters long has too much.
      for (final entry in entries) {
        expect(entry.hint, isNotEmpty, reason: entry.title);
        expect(entry.hint.length, lessThan(160),
            reason: '${entry.title} opens with a paragraph, not a sentence');
        expect(entry.hint.startsWith('- '), isFalse, reason: entry.title);
      }
    });
  });

}
