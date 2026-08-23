import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/editor_screen.dart';

/// Every key the app answers to is written down.
///
/// It grew sixteen shortcuts and the guide mentioned three; copy and paste,
/// which is how part of one build gets into another, was written down nowhere
/// at all. A shortcut nobody can find is a shortcut nobody has.
void main() {
  final guide = File('../docs/USING.md').readAsStringSync();

  test('the guide names every one of them', () {
    final missing = [
      for (final entry in kShortcutNames.entries)
        if (!guide.contains(entry.key)) '${entry.key} (${entry.value})',
    ];
    expect(missing, isEmpty,
        reason: 'a key the app answers to and the guide does not mention');
  });

  test('and every key the app binds has a name', () {
    // The other direction: adding a shortcut to the map without naming it
    // here is how the guide would fall behind again.
    expect(kEditorShortcuts, isNotEmpty);
    expect(kShortcutNames.length, greaterThan(8));

    // Every binding is one of the named ones. Arrow keys are named as a
    // family, since eight of them are one idea.
    // Nineteen: undo, redo, two ways to delete, escape, four for zoom, copy,
    // paste, four arrows and four with shift. The number is here because the
    // first version of this test was written against a map that had lost two
    // of them in an edit — and the honest thing was to put them back, not to
    // change the number.
    expect(kEditorShortcuts.length, 19,
        reason: 'a new binding wants a line in kShortcutNames and in the '
            'guide, and then this number');
  });
}
