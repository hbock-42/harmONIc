export 'file_store.dart' if (dart.library.js_interop) 'browser_store.dart';

/// A named blob of JSON on disk: the player's own recipes, their saved
/// pipelines, anything else worth keeping between runs.
///
/// Behind an interface so tests never touch the disk, and so each platform can
/// keep it wherever it keeps things: a file where there is a file system, a
/// `localStorage` key in a browser. [jsonStoreNamed] hands back whichever, and
/// nothing above this line knows which it got.
abstract class JsonStore {
  Future<Map<String, dynamic>?> read();

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
