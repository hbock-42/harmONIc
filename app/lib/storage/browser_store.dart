import 'dart:convert';

import 'package:web/web.dart' as web;

import 'json_store.dart';

/// The store a browser gets.
JsonStore jsonStoreNamed(String fileName) => BrowserJsonStore(fileName);

/// True: `localStorage` is still there when the tab comes back.
const bool storeSurvivesRestart = true;

/// A key in the browser's `localStorage`.
///
/// The same shape as the file store, and the reason the [JsonStore] interface
/// exists at all: a few kilobytes of JSON under a name, read once at start-up
/// and written when something changes. `localStorage` holds a handful of
/// megabytes, and the largest thing here is a canvas of a few hundred nodes.
///
/// Failures are swallowed on the way in and out, as they are for a file. A
/// browser with storage turned off, or a quota that has run out, should cost
/// somebody their saved builds and not their session.
class BrowserJsonStore implements JsonStore {
  const BrowserJsonStore(this.fileName);

  /// The file name the rest of the app thinks in, used as the key. Keeping the
  /// ".json" makes it obvious in a browser's inspector what it is looking at.
  final String fileName;

  String get _key => 'oni_pipeline/$fileName';

  @override
  Future<Map<String, dynamic>?> read() async {
    try {
      final text = web.window.localStorage.getItem(_key);
      if (text == null || text.trim().isEmpty) return null;
      return jsonDecode(text) as Map<String, dynamic>;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(Map<String, dynamic> data) async {
    try {
      web.window.localStorage.setItem(_key, jsonEncode(data));
    } on Object {
      // Out of quota, or a browser told not to keep anything. Losing the save
      // is bad; taking the app down with it is worse.
    }
  }
}
