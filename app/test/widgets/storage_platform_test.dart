import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/storage/json_store.dart';

/// Which store this platform gets.
void main() {
  test('a desktop build keeps things in a file', () {
    // These tests run on the Dart VM, which has a file system — the same
    // answer the macOS app gets. Run under `--platform chrome` this file gets
    // the browser store instead, which is the point of the seam.
    expect(storeSurvivesRestart, isTrue);
    final store = jsonStoreNamed('pipelines.json');
    expect(store.runtimeType.toString(), contains('JsonStore'));
    expect(store, isNot(isA<MemoryJsonStore>()));
  });

  test('and a store is a store either way', () async {
    // The point of the seam: whatever the platform hands back, the app talks
    // to it the same way. A browser build gets a memory store rather than a
    // file store that throws on the first autosave.
    final store = MemoryJsonStore();
    expect(await store.read(), isNull);
    await store.write({'pipelines': []});
    expect(await store.read(), isNotNull);
  });
}
