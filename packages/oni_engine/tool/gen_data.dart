// Regenerates lib/src/data/oni_data.g.dart from lib/data/oni_data.json.
//
//   dart run tool/gen_data.dart
//
// The JSON is the source of truth; embedding it as a Dart constant keeps the
// engine free of file I/O and asset plumbing, so it works identically in tests,
// on the CLI, on Flutter web and on desktop.
import 'dart:convert';
import 'dart:io';

void main() {
  final source = File('lib/data/oni_data.json').readAsStringSync();
  // Validate before embedding.
  jsonDecode(source);
  final escaped = source.replaceAll(r'$', r'\$');
  final out = StringBuffer()
    ..writeln('// GENERATED FILE — do not edit.')
    ..writeln('// Run `dart run tool/gen_data.dart` after editing '
        'lib/data/oni_data.json.')
    ..writeln()
    ..writeln('const String oniDataJson = r"""')
    ..write(escaped)
    ..writeln('""";');
  File('lib/src/data/oni_data.g.dart').writeAsStringSync(out.toString());
  stdout.writeln('Wrote lib/src/data/oni_data.g.dart '
      '(${source.length} bytes of JSON)');
}
