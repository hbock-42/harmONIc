import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'json_store.dart';

/// The store a platform with a file system gets.
JsonStore jsonStoreNamed(String fileName) => FileJsonStore(fileName);

/// True: what is written here is still here next time.
const bool storeSurvivesRestart = true;

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
