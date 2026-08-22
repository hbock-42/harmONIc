import 'dart:convert';
import 'dart:io';

import 'package:oni_engine/oni_engine.dart';
import 'package:path_provider/path_provider.dart';

/// Writing a build out as a file you can keep.
///
/// The clipboard already carries a build to another copy of this app, and that
/// is the right tool for sending one to somebody. It is the wrong tool for
/// keeping one: a share code lives until the next thing you copy.
///
/// There is no file picker here and no dependency for one. An export lands in
/// the downloads folder — the place every browser puts a file without asking —
/// and the app says the full path, which is the part that matters. Anybody who
/// wants it elsewhere can move it, and moving a file is a thing people already
/// know how to do.
class BuildExporter {
  const BuildExporter({this.directory = _downloads});

  /// Where exports go. Injected so a test can point it at a temporary folder:
  /// a test that wrote to the real downloads folder would be a test that left
  /// litter on somebody's machine.
  final Future<Directory> Function() directory;

  static Future<Directory> _downloads() async =>
      // Null on a platform with no such folder, and the documents directory is
      // the one place every platform has.
      await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();

  /// Writes [pipeline] out and returns the file it wrote.
  ///
  /// Never overwrites: a second export of the same build is "Oxygen 2", the
  /// way a browser does it. Somebody exporting twice is usually keeping both,
  /// and the one who is not can delete a file.
  Future<File> export(Pipeline pipeline) async {
    final folder = await directory();
    if (!folder.existsSync()) folder.createSync(recursive: true);

    final file = _free(folder, _fileName(pipeline.name));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(pipeline.toJson()),
    );
    return file;
  }

  File _free(Directory folder, String stem) {
    var candidate = File('${folder.path}/$stem.oni.json');
    var n = 1;
    while (candidate.existsSync()) {
      n++;
      candidate = File('${folder.path}/$stem $n.oni.json');
    }
    return candidate;
  }

  /// A build's name is whatever the person typed, which can be anything at
  /// all. Everything a file system dislikes becomes a space, and a build named
  /// only in punctuation still gets a file.
  static String _fileName(String name) {
    final cleaned = name
        .replaceAll(RegExp(r'[/\\:*?"<>|\x00-\x1f]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return cleaned.isEmpty ? 'Build' : cleaned;
  }
}
