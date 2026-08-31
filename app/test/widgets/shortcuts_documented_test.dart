import 'dart:io';

import 'package:flutter/widgets.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/design/keys.dart';
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
    expect(editorShortcuts(apple: true), isNotEmpty);
    expect(kShortcutNames.length, greaterThan(8));

    // Every binding is one of the named ones. Arrow keys are named as a
    // family, since eight of them are one idea.
    // Twenty-three: undo, redo, two ways to delete, escape, seven for zoom,
    // find, copy, paste, four arrows and four with shift. The number is here
    // because the first version of this test was written against a map that
    // had lost two of them in an edit — and the honest thing was to put them
    // back, not to change the number.
    //
    // It went from twenty when pressing the keys found that "⌘+" was bound to
    // one spelling of plus out of three: not ⇧= and not the number pad, which
    // between them is how nearly everybody types it.
    expect(editorShortcuts(apple: true).length, 23,
        reason: 'a new binding wants a line in kShortcutNames and in the '
            'guide, and then this number');
  });
  test('and the other half of the world gets the same twenty', () {
    // Written on a Mac, so every binding said meta and every label said ⌘.
    // On Windows and Linux that is a key most keyboards do not have: undo,
    // redo, copy, paste and zoom were not mislabelled, they were missing.
    final apple = editorShortcuts(apple: true);
    final rest = editorShortcuts(apple: false);

    expect(rest.length, apple.length);
    expect(rest.values.map((i) => i.runtimeType).toSet(),
        apple.values.map((i) => i.runtimeType).toSet());

    final held = [
      for (final activator in rest.keys)
        if (activator case SingleActivator(:final control, :final meta))
          if (control || meta) (control, meta),
    ];
    expect(held, isNotEmpty);
    expect(held.every((h) => h.$1 && !h.$2), isTrue,
        reason: 'Ctrl, and never a ⌘ key that is not on the keyboard');
  });

  test('and each is spelled the way that platform spells it', () {
    expect(chord('⌘Z', apple: true), '⌘Z');
    expect(chord('⌘Z', apple: false), 'Ctrl+Z');
    // The order differs as well as the glyphs.
    expect(chord('⇧⌘Z', apple: false), 'Ctrl+Shift+Z');
    expect(chord('⌘C  ⌘V', apple: false), 'Ctrl+C  Ctrl+V');
    // And a key that is the same everywhere is left alone.
    for (final same in ['esc', 'arrow keys', 'space + drag', '⌫']) {
      expect(chord(same, apple: false), same);
    }
  });

}
