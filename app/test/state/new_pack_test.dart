import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/state/display_controller.dart';
import 'package:oni_pipeline/storage/json_store.dart';

/// A pack added after somebody last used the app.
///
/// The settings remember which packs are on by listing them, and loading
/// replaces the set with that list. So a pack that did not exist when the list
/// was written is absent from it, which reads as "turned off" — and everything
/// in it disappears for everybody who has ever used the app, with nothing said.
///
/// This is the harm the pack tags exist to avoid, arrived at from the other
/// side: a tag decides what a player is shown, and here the tag was right and
/// the settings hid it anyway.
void main() {
  test('is on, for somebody whose settings predate it', () async {
    // A save written when only the four planet packs existed.
    final store = MemoryJsonStore(<String, dynamic>{
      'packs': ['aquatic', 'frosty', 'prehistoric', 'spacedout'],
    });
    final display = DisplayController(store);
    await display.load();

    expect(display.packEnabled('bionic'), isTrue,
        reason: 'nobody turned it off; it did not exist to turn off');
  });

  test('and a pack somebody did turn off stays off', () async {
    final store = MemoryJsonStore(<String, dynamic>{
      'packs': ['aquatic', 'frosty', 'prehistoric', 'spacedout'],
      'knownPacks': ['aquatic', 'bionic', 'frosty', 'prehistoric', 'spacedout'],
    });
    final display = DisplayController(store);
    await display.load();

    expect(display.packEnabled('bionic'), isFalse,
        reason: 'this save knew about it and did not list it');
  });

  test('and a decision survives the session, as it always did', () async {
    final store = MemoryJsonStore();
    final first = DisplayController(store);
    await first.load();
    await first.setPack('bionic', enabled: false);

    final second = DisplayController(store);
    await second.load();
    expect(second.packEnabled('bionic'), isFalse);
    expect(second.packEnabled('frosty'), isTrue);
  });
}
