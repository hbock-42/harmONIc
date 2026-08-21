import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

/// The one dark palette. Colour is *data* here, not decoration: if something is
/// coloured, the colour means something.
abstract final class OniColors {
  static const Color background = Color(0xFF0E1116);
  static const Color surface = Color(0xFF151A21);
  static const Color surfaceRaised = Color(0xFF1B222B);
  static const Color surfaceHover = Color(0xFF222C38);
  static const Color border = Color(0xFF263041);
  static const Color borderStrong = Color(0xFF3A4757);

  static const Color text = Color(0xFFE6EDF3);
  static const Color textMuted = Color(0xFF9AA7B4);
  static const Color textFaint = Color(0xFF6B7A8A);

  static const Color accent = Color(0xFF3FB8AF);
  static const Color danger = Color(0xFFE5534B);
  static const Color warning = Color(0xFFD29922);
  static const Color ok = Color(0xFF3FB950);
}

/// One hue per item category, used identically on ports, edges and legends.
/// This is the most important visual rule in the app: if you learn that blue is
/// liquid once, you never have to read a label again.
abstract final class OniItemColors {
  static const Map<ItemCategory, Color> _byCategory = {
    ItemCategory.solid: Color(0xFFB08968),
    ItemCategory.liquid: Color(0xFF4C9AFF),
    ItemCategory.gas: Color(0xFF4FD1C5),
    ItemCategory.power: Color(0xFFF2C744),
    ItemCategory.heat: Color(0xFFFF7A59),
    ItemCategory.entity: Color(0xFFB084F5),
    ItemCategory.other: Color(0xFF8B98A5),
  };

  static Color of(ItemCategory category) =>
      _byCategory[category] ?? OniColors.textFaint;

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

  static const TextStyle body = TextStyle(
    fontSize: 13,
    height: 1.35,
    color: OniColors.text,
  );
  static const TextStyle label = TextStyle(
    fontSize: 11,
    height: 1.2,
    letterSpacing: 0.4,
    color: OniColors.textMuted,
  );
  static const TextStyle title = TextStyle(
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: OniColors.text,
  );
  static const TextStyle heading = TextStyle(
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: OniColors.text,
  );
  static const TextStyle number = TextStyle(
    fontSize: 12,
    height: 1.2,
    color: OniColors.text,
    fontFamily: 'SF Mono',
    fontFamilyFallback: _mono,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const TextStyle numberSmall = TextStyle(
    fontSize: 10.5,
    height: 1.1,
    color: OniColors.textMuted,
    fontFamily: 'SF Mono',
    fontFamilyFallback: _mono,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}
