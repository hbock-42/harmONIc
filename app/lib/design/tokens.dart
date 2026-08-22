import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

/// One set of colours. Colour is *data* here, not decoration: if something is
/// coloured, the colour means something, and both palettes have to say the same
/// things — a warning is amber in either, an item's hue is its category in
/// either.
class OniPalette {
  const OniPalette({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceHover,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.danger,
    required this.warning,
    required this.ok,
    required this.items,
  });

  final Color background;
  final Color surface;
  final Color surfaceRaised;
  final Color surfaceHover;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color textMuted;
  final Color textFaint;
  final Color accent;
  final Color danger;
  final Color warning;
  final Color ok;
  final Map<ItemCategory, Color> items;

  static const OniPalette dark = OniPalette(
    background: Color(0xFF0E1116),
    surface: Color(0xFF151A21),
    surfaceRaised: Color(0xFF1B222B),
    surfaceHover: Color(0xFF222C38),
    border: Color(0xFF263041),
    borderStrong: Color(0xFF3A4757),
    text: Color(0xFFE6EDF3),
    textMuted: Color(0xFF9AA7B4),
    textFaint: Color(0xFF6B7A8A),
    accent: Color(0xFF3FB8AF),
    danger: Color(0xFFE5534B),
    warning: Color(0xFFD29922),
    ok: Color(0xFF3FB950),
    items: {
      ItemCategory.solid: Color(0xFFB08968),
      ItemCategory.liquid: Color(0xFF4C9AFF),
      ItemCategory.gas: Color(0xFF4FD1C5),
      ItemCategory.power: Color(0xFFF2C744),
      ItemCategory.heat: Color(0xFFFF7A59),
      ItemCategory.entity: Color(0xFFB084F5),
      ItemCategory.other: Color(0xFF8B98A5),
    },
  );

  /// The same design in daylight.
  ///
  /// Not the dark one inverted: the item hues are darkened rather than
  /// lightened, because a colour that reads on near-black is usually too pale
  /// to read on near-white, and the whole point of them is that they are
  /// legible at the size of a port dot.
  static const OniPalette light = OniPalette(
    background: Color(0xFFF3F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceHover: Color(0xFFE8EEF6),
    border: Color(0xFFD3DCE7),
    borderStrong: Color(0xFFAEBCCC),
    text: Color(0xFF16202B),
    textMuted: Color(0xFF4A5A6B),
    textFaint: Color(0xFF74838F),
    accent: Color(0xFF12766F),
    danger: Color(0xFFB3352E),
    warning: Color(0xFF8A6200),
    ok: Color(0xFF1F7A32),
    items: {
      ItemCategory.solid: Color(0xFF7A5A38),
      ItemCategory.liquid: Color(0xFF1B63C4),
      ItemCategory.gas: Color(0xFF117C73),
      ItemCategory.power: Color(0xFF9A7400),
      ItemCategory.heat: Color(0xFFC24427),
      ItemCategory.entity: Color(0xFF6A44B8),
      ItemCategory.other: Color(0xFF5C6873),
    },
  );
}

/// Which palette is in force.
///
/// A global rather than something looked up from the tree, because a hundred
/// and seventy call sites read these as plain names and threading a context
/// through every one of them would be a worse app for the sake of a tidier
/// one. The app root sets it when the setting changes and rebuilds.
abstract final class OniTheme {
  static OniPalette current = OniPalette.dark;

  static bool get isLight => current == OniPalette.light;
}

/// The colours, resolved against whichever palette is in force.
abstract final class OniColors {
  static Color get background => OniTheme.current.background;
  static Color get surface => OniTheme.current.surface;
  static Color get surfaceRaised => OniTheme.current.surfaceRaised;
  static Color get surfaceHover => OniTheme.current.surfaceHover;
  static Color get border => OniTheme.current.border;
  static Color get borderStrong => OniTheme.current.borderStrong;

  static Color get text => OniTheme.current.text;
  static Color get textMuted => OniTheme.current.textMuted;
  static Color get textFaint => OniTheme.current.textFaint;

  static Color get accent => OniTheme.current.accent;
  static Color get danger => OniTheme.current.danger;
  static Color get warning => OniTheme.current.warning;
  static Color get ok => OniTheme.current.ok;
}

/// One hue per item category, used identically on ports, edges and legends.
/// This is the most important visual rule in the app: if you learn that blue is
/// liquid once, you never have to read a label again.
abstract final class OniItemColors {
  static Color of(ItemCategory category) =>
      OniTheme.current.items[category] ?? OniColors.textFaint;

  static Color ofItem(Item? item) =>
      item == null ? OniColors.textFaint : of(item.category);

  static const List<ItemCategory> legendOrder = [
    ItemCategory.gas,
    ItemCategory.liquid,
    ItemCategory.solid,
    ItemCategory.power,
    ItemCategory.heat,
    ItemCategory.entity,
  ];
}

abstract final class OniSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// Numbers are the hero, so they get a tabular monospace face and everything
/// else stays quiet.
abstract final class OniType {
  static const List<String> _mono = ['SF Mono', 'Menlo', 'Consolas', 'monospace'];

  // Getters rather than constants, because each carries a colour and the
  // colours now depend on which palette is in force.

  static TextStyle get body => TextStyle(
    fontSize: 13,
    height: 1.35,
    color: OniColors.text,
  );
  static TextStyle get label => TextStyle(
    fontSize: 11,
    height: 1.2,
    letterSpacing: 0.4,
    color: OniColors.textMuted,
  );
  static TextStyle get title => TextStyle(
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: OniColors.text,
  );
  static TextStyle get heading => TextStyle(
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: OniColors.text,
  );
  static TextStyle get number => TextStyle(
    fontSize: 12,
    height: 1.2,
    color: OniColors.text,
    fontFamily: 'SF Mono',
    fontFamilyFallback: _mono,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static TextStyle get numberSmall => TextStyle(
    fontSize: 10.5,
    height: 1.1,
    color: OniColors.textMuted,
    fontFamily: 'SF Mono',
    fontFamilyFallback: _mono,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
