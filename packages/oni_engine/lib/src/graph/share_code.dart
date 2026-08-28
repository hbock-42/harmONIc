import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'pipeline.dart';

/// Turns a pipeline into a string you can paste somewhere, and back.
///
/// base64url of the gzipped JSON the app saves, so a code still carries its
/// schema version with it and still travels as one line of text.
///
/// It used to be the plain JSON, on the grounds that gzip lives in `dart:io`
/// and pulling that in would cost this package the web. True of `dart:io` and
/// not of the problem: `package:archive` is pure Dart and runs anywhere. The
/// saving is not small, either -- every build anybody has reported this month
/// arrived as a file attachment because its code was 16 to 21 thousand
/// characters, which is past what a chat message or a URL will carry. Gzipped
/// they are three to four thousand, and a link holds them.
abstract final class PipelineShareCode {
  /// A single-line code, safe to paste into a forum post or a chat message.
  static String encode(Pipeline pipeline) => base64Url.encode(
        GZipEncoder().encode(utf8.encode(jsonEncode(pipeline.toJson()))),
      );

  /// Accepts a share code *or* the raw JSON, because someone handed a
  /// `pipelines.json` will paste that and be right to expect it to work.
  static Pipeline decode(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Nothing to import.');
    }
    if (trimmed.startsWith('{')) {
      return Pipeline.fromJsonString(trimmed);
    }
    final String json;
    try {
      final bytes = base64Url.decode(_padded(trimmed));
      // Every code written before this was compressed is still a code, and
      // there are months of them in chat logs and issue threads. Gzip's own
      // two-byte header says which this is, so nothing had to be stamped on
      // the front of the new ones to tell them apart.
      json = utf8.decode(_isGzip(bytes)
          ? GZipDecoder().decodeBytes(bytes)
          : bytes);
    } on Object {
      throw const FormatException(
          'That does not look like a pipeline: expected a share code or JSON.');
    }
    return Pipeline.fromJsonString(json);
  }

  /// Whether [source] looks importable, for enabling a button without throwing.
  static bool looksValid(String source) {
    try {
      decode(source);
      return true;
    } on Object {
      return false;
    }
  }

  /// The two bytes every gzip stream starts with.
  static bool _isGzip(Uint8List bytes) =>
      bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;

  /// base64url without padding is common in the wild; put it back.
  static String _padded(String value) {
    final stripped = value.replaceAll(RegExp(r'\s'), '');
    final remainder = stripped.length % 4;
    return remainder == 0 ? stripped : stripped.padRight(
        stripped.length + (4 - remainder), '=');
  }
}
