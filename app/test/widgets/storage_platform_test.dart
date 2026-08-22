import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/storage/json_store.dart';

/// Which store this platform gets.
void main() {
  test('a desktop build keeps things in a file', () {
    // These tests run on the Dart VM, which has dart:io — the same answer the
    // macOS app gets.
    expect(kJsonStorePersists, isTrue);
    expect(jsonStoreNamed('pipelines.json'), isA<FileJsonStore>());
    expect((jsonStoreNamed('pipelines.json') as FileJsonStore).fileName,
        'pipelines.json');
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
