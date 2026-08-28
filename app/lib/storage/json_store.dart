export 'file_store.dart' if (dart.library.js_interop) 'browser_store.dart';

/// A named blob of JSON on disk: the player's own recipes, their saved
/// pipelines, anything else worth keeping between runs.
///
/// Behind an interface so tests never touch the disk, and so each platform can
/// keep it wherever it keeps things: a file where there is a file system, a
/// `localStorage` key in a browser. [jsonStoreNamed] hands back whichever, and
/// nothing above this line knows which it got.
abstract class JsonStore {
  /// What was last written, or null when there is nothing to read or it
  /// cannot be read. Never throws: a corrupt or unreachable store must not
  /// stop the app from starting, and the bundled data alone is usable.
  Future<Map<String, dynamic>?> read();

  /// Keeps [data] if it can, and does nothing if it cannot. Never throws.
  ///
  /// Both halves of that matter. Saving happens as a side effect of ordinary
  /// editing, sometimes without anybody waiting for it, so a store that threw
  /// would turn a full disk into an unhandled error in the middle of a build.
  /// Losing the save is bad; taking the app down with it is worse.
  Future<void> write(Map<String, dynamic> data);
}

/// For tests, and for a first run before anything has been saved.
class MemoryJsonStore implements JsonStore {
  MemoryJsonStore([this._data]);

  Map<String, dynamic>? _data;

  /// How many times [write] has been called, so a test can prove that editing
  /// saves — and that it does not save on every keystroke.
  int writes = 0;

  /// What was last written, so a test can assert on it.
  Map<String, dynamic>? get data => _data;

  @override
  Future<Map<String, dynamic>?> read() async => _data;

  @override
  Future<void> write(Map<String, dynamic> data) async {
    writes++;
    _data = data;
  }
}
