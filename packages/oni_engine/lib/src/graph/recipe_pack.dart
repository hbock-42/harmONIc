import 'dart:convert';

import '../model/item.dart';
import '../model/process_spec.dart';

/// A set of hand-written recipes, packed up to hand to somebody else.
///
/// The wiki lags every pack and never publishes some figures at all, so the app
/// lets people write their own. Until now each of them had to write the same
/// one: measuring a Smoker's cycle time in game is half an hour's work, and
/// there was no way to spend it once.
///
/// The encoded form is base64url of JSON, the same shape the library saves and
/// the same convention a shared build uses — so a pack can be pasted into a
/// forum post, and somebody handed a `recipes.json` can paste that instead and
/// be right to expect it to work.
class RecipePack {
  const RecipePack({this.items = const [], this.processes = const []});

  /// Items the recipes need that the app may not have — a material nobody has
  /// modelled yet is the usual reason a recipe cannot be written at all.
  final List<Item> items;
  final List<ProcessSpec> processes;

  bool get isEmpty => items.isEmpty && processes.isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': 1,
        'items': [for (final item in items) item.toJson()],
        'processes': [for (final spec in processes) spec.toJson()],
      };

  static RecipePack fromJson(Map<String, dynamic> json) => RecipePack(
        items: [
          for (final entry in json['items'] as List<dynamic>? ?? const [])
            Item.fromJson(entry as Map<String, dynamic>),
        ],
        processes: [
          for (final entry in json['processes'] as List<dynamic>? ?? const [])
            ProcessSpec.fromJson(entry as Map<String, dynamic>),
        ],
      );

  /// A single-line code, safe to paste into a forum post or a chat message.
  String encode() => base64Url.encode(utf8.encode(jsonEncode(toJson())));

  /// Accepts a pack code or the raw JSON.
  ///
  /// Throws [FormatException] with something a person can act on. A pack that
  /// decodes to nothing throws too: "imported 0 recipes" reads like a bug in
  /// the app rather than like the wrong thing on the clipboard.
  static RecipePack decode(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) throw const FormatException('Nothing to import.');

    final String json;
    if (trimmed.startsWith('{')) {
      json = trimmed;
    } else {
      try {
        json = utf8.decode(base64Url.decode(_padded(trimmed)));
      } on Object {
        throw const FormatException(
            'That does not look like a recipe pack: expected a pack code or '
            'JSON.');
      }
    }

    final RecipePack pack;
    try {
      pack = fromJson(jsonDecode(json) as Map<String, dynamic>);
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException('That pack could not be read.');
    }
    if (pack.isEmpty) {
      throw const FormatException('That pack has no recipes in it.');
    }
    return pack;
  }

  /// base64url without padding is common in the wild; put it back.
  static String _padded(String value) {
    final stripped = value.replaceAll(RegExp(r'\s'), '');
    final remainder = stripped.length % 4;
    return remainder == 0
        ? stripped
        : stripped.padRight(stripped.length + (4 - remainder), '=');
  }
}
