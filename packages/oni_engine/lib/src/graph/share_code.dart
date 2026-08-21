import 'dart:convert';

import 'pipeline.dart';

/// Turns a pipeline into a string you can paste somewhere, and back.
///
/// The encoded form is base64url of the same JSON the app saves, so it carries
/// its schema version with it and stays readable to anything that can decode
/// base64. Deliberately not compressed: gzip lives in `dart:io`, and pulling
/// that in would cost this package its ability to run on the web for a saving
/// nobody is short of.
abstract final class PipelineShareCode {
  /// A single-line code, safe to paste into a forum post or a chat message.
  static String encode(Pipeline pipeline) =>
      base64Url.encode(utf8.encode(jsonEncode(pipeline.toJson())));

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
      json = utf8.decode(base64Url.decode(_padded(trimmed)));
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

  /// base64url without padding is common in the wild; put it back.
  static String _padded(String value) {
    final stripped = value.replaceAll(RegExp(r'\s'), '');
    final remainder = stripped.length % 4;
    return remainder == 0 ? stripped : stripped.padRight(
        stripped.length + (4 - remainder), '=');
  }
}
