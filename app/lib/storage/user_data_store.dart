import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Where the player's own process definitions live.
///
/// Behind an interface so tests never touch the disk, and so a future web build
/// can swap in browser storage without the rest of the app noticing.
abstract class UserDataStore {
  Future<Map<String, dynamic>?> read();

  Future<void> write(Map<String, dynamic> data);
}

/// A JSON file in the platform's application-support directory.
class FileUserDataStore implements UserDataStore {
  const FileUserDataStore({this.fileName = 'user_processes.json'});

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
class MemoryUserDataStore implements UserDataStore {
  MemoryUserDataStore([this._data]);

  Map<String, dynamic>? _data;

  /// What was last written, so a test can assert on it.
  Map<String, dynamic>? get data => _data;

  @override
  Future<Map<String, dynamic>?> read() async => _data;

  @override
  Future<void> write(Map<String, dynamic> data) async => _data = data;
}
