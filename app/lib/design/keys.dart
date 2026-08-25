import 'package:flutter/foundation.dart';

/// Whether this machine holds its shortcuts with ⌘ or with Ctrl.
///
/// The app was written on a Mac and said ⌘ everywhere — in the labels *and*
/// in the bindings — so on Windows and Linux undo, redo, copy, paste and zoom
/// were not merely mislabelled. They did nothing at all. Which mattered the
/// day it went on the web, because that is most of the people who can open it.
bool get appleKeys =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// The Apple spelling is the one written down; this is the other one.
///
/// Both the glyphs and the order differ: ⇧⌘Z reads Ctrl+Shift+Z. Anything
/// with neither modifier in it — `esc`, `arrow keys`, `space + drag` — is the
/// same everywhere and comes back untouched.
String chord(String appleChord, {required bool apple}) {
  if (apple) return appleChord;
  return appleChord
      .split('  ')
      .map((one) {
        final control = one.contains('⌘');
        final shift = one.contains('⇧');
        final key = one.replaceAll('⌘', '').replaceAll('⇧', '');
        if (!control && !shift) return key;
        return [if (control) 'Ctrl', if (shift) 'Shift', key].join('+');
      })
      .join('  ');
}
