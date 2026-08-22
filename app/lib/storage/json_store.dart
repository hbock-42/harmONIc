import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A named blob of JSON on disk: the player's own recipes, their saved
/// pipelines, anything else worth keeping between runs.
///
/// Behind an interface so tests never touch the disk, and so a future web build
/// can swap in browser storage without the rest of the app noticing.
abstract class JsonStore {
  Future<Map<String, dynamic>?> read();

  Future<void> write(Map<String, dynamic> data);
}

/// The store this platform can actually keep something in.
///
/// A file, everywhere this app has been run. On the web `dart:io` compiles —
/// it is stubbed there — and then throws the moment anything touches a file,
/// so a build served in a browser would lose the pipeline you were drawing at
/// the first autosave. Until somebody writes the browser half, saying so is
/// better than throwing: this keeps the session in memory and the app works
/// for as long as the tab is open.
///
/// [kJsonStorePersists] is how the app can say which it got.
JsonStore jsonStoreNamed(String fileName) =>
    kJsonStorePersists ? FileJsonStore(fileName) : MemoryJsonStore();

/// False where nothing written here survives a restart.
const bool kJsonStorePersists = bool.fromEnvironment('dart.library.io');

/// A JSON file in the platform's application-support directory.
class FileJsonStore implements JsonStore {
  const FileJsonStore(this.fileName);

  final String fileName;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    final folder = Directory('${dir.path}/oni_pipeline');
    if (!folder.existsSync()) folder.createSync(recursive: true);
    return File('${folder.path}/$fileName');
  }

  @override
  Future<Map<String, dynamic>?> read() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return null;
      final text = await file.readAsString();
      if (text.trim().isEmpty) return null;
      return jsonDecode(text) as Map<String, dynamic>;
    } on Object {
      // A corrupt or unreadable file must not stop the app from starting; the
      // bundled database alone is still perfectly usable.
      return null;
    }
  }

  @override
  Future<void> write(Map<String, dynamic> data) async {
    final file = await _file();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }
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
