@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/storage/browser_store.dart';
import 'package:web/web.dart' as web;

/// The store the web build actually uses, which nothing had ever run.
///
/// It is twenty lines of logic and it holds every saved build, every recipe
/// somebody has edited, and every setting, for what is the primary way people
/// use this. Running it needs a browser, which is why it had been skipped.
void main() {
  test('what goes in comes back out', () async {
    const store = BrowserJsonStore('probe.json');
    await store.write({'a': 1, 'b': [1, 2, 3]});
    expect(await store.read(), {'a': 1, 'b': [1, 2, 3]});
  });

  test('a name never written reads as nothing', () async {
    const store = BrowserJsonStore('never-written.json');
    expect(await store.read(), isNull);
  });

  test('two names do not tread on each other', () async {
    await const BrowserJsonStore('one.json').write({'which': 'one'});
    await const BrowserJsonStore('two.json').write({'which': 'two'});
    expect(await const BrowserJsonStore('one.json').read(), {'which': 'one'});
  });

  test('rubbish under the key reads as nothing, not an exception', () async {
    // Somebody else's key collision, a value half written when the tab was
    // closed, or a version of this app that kept something different there.
    web.window.localStorage
        .setItem('oni_pipeline/rubbish.json', 'not json at all {');
    expect(await const BrowserJsonStore('rubbish.json').read(), isNull);
  });

  test('and so does an empty one', () async {
    web.window.localStorage.setItem('oni_pipeline/blank.json', '   ');
    expect(await const BrowserJsonStore('blank.json').read(), isNull);
  });

  test('a list where a map was expected reads as nothing too', () async {
    // Valid JSON and the wrong shape, which the cast would otherwise throw on.
    web.window.localStorage.setItem('oni_pipeline/list.json', '[1, 2, 3]');
    expect(await const BrowserJsonStore('list.json').read(), isNull);
  });
}
