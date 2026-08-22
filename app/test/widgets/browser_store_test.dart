@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/storage/json_store.dart';

/// The browser half of the store, run in a browser.
///
/// `flutter test --platform chrome test/widgets/browser_store_test.dart`.
/// Not in `tool/test_all.sh`: it needs a browser, and the suite has to run on
/// a machine that has none. It is here so that the claim "web keeps your
/// builds" is something somebody checked rather than something somebody wrote.
void main() {
  test('a browser gets a store that survives a reload', () async {
    expect(storeSurvivesRestart, isTrue);
    final store = jsonStoreNamed('pipelines.json');
    expect(store, isNot(isA<MemoryJsonStore>()));

    // Nothing saved yet reads as nothing, rather than as an error.
    await store.write(<String, dynamic>{});
    expect(await store.read(), isNotNull);

    await store.write(<String, dynamic>{
      'pipelines': [
        {'id': 'a', 'name': 'Oxygen'},
      ],
    });

    // A second store on the same name is what the next visit gets.
    final next = jsonStoreNamed('pipelines.json');
    final read = await next.read();
    expect(read, isNotNull);
    expect((read!['pipelines'] as List<dynamic>).single,
        containsPair('name', 'Oxygen'));

    // And two names do not collide, since the app keeps three of them.
    final settings = jsonStoreNamed('settings.json');
    expect(await settings.read(), isNull);
  });
}
