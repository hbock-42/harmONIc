import 'port.dart';

/// What a building survives, given what it is made of.
///
/// Every building starts at [commonOverheatCelsius] and its material moves that
/// up or down. The figures are the game's own, from the Overheating page; the
/// base of 75 °C is on the same page.
///
/// This is not a promise that something *will* break. A building's temperature
/// comes from what is inside it, what is touching it and how fast it can shed
/// heat, and a flow model can see only the first of those. What it can say is
/// the useful half: a 95 °C loop is not going down a granite pipe, whatever
/// else is true.
abstract final class Overheating {
  /// Material id → degrees added to the 75 °C a bare building tolerates.
  ///
  /// Only materials this app has an item for are listed. The game's table also
  /// gives Plastium and Thermium at +900, Niobium at +500, Steel and Diamond at
  /// +200, Granite, Igneous Rock at +15, Lead at −20 — none of which are
  /// modelled here yet, and inventing items for them so a table could be
  /// complete would be inventing items.
  static const Map<String, double> modifiers = <String, double>{
    'iridium': 500,
    'ceramic': 200,
    'diamond': 200,
    'copper': 50,
    'gold_amalgam': 50,
    'gold': 50,
    'iron': 50,
    'nickel': 50,
    'zinc': 50,
    'obsidian': 15,
    'dirt': -10,
  };

  /// What a building made of this survives, in °C.
  static double toleranceOf(String materialId) =>
      commonOverheatCelsius + (modifiers[materialId] ?? 0);

  /// Everything that would survive [celsius], hottest-tolerating last.
  ///
  /// Empty means nothing this app knows about will do, which is a real answer:
  /// molten glass leaves its forge at 1 942 °C and there is no pipe for it.
  static List<String> survivors(double celsius) {
    final ok = [
      for (final entry in modifiers.entries)
        if (toleranceOf(entry.key) >= celsius) entry.key,
    ]..sort((a, b) => toleranceOf(a).compareTo(toleranceOf(b)));
    return ok;
  }

  /// True when a plain building — no clever material — would be in trouble.
  static bool isTrouble(double celsius) => celsius > commonOverheatCelsius;
}
