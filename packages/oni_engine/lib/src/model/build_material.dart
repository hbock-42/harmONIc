/// What a building costs to *put up*, as opposed to what it runs on.
///
/// The game asks for a class of material rather than a particular one: an
/// Electrolyzer takes 200 kg of any metal ore, and which ore you feed it
/// changes its heat tolerance and nothing else. So these are not items that
/// flow through a pipeline — they are a shopping list, and they are counted
/// once per building rather than per second.
abstract final class BuildMaterials {
  static const String metalOre = 'metal_ore';
  static const String refinedMetal = 'refined_metal';
  static const String rawMineral = 'raw_mineral';
  static const String plastic = 'plastic';
  static const String cultivableSoil = 'cultivable_soil';
  static const String wood = 'wood';

  /// A crafted part rather than a raw class: 50 kg of plastic or rubber makes
  /// one, and the Aquatic buildings want a few.
  static const String gasket = 'gasket';

  static const Map<String, String> names = <String, String>{
    metalOre: 'Metal Ore',
    refinedMetal: 'Refined Metal',
    rawMineral: 'Raw Mineral',
    plastic: 'Plastic',
    cultivableSoil: 'Cultivable Soil',
    wood: 'Wood',
    gasket: 'Gaskets',
  };

  static String nameOf(String id) => names[id] ?? id;

  static bool isKnown(String id) => names.containsKey(id);
}

/// Kilograms, written the way a shopping list would be.
///
/// A build wanting 3 200 kg of ore is easier to judge as 3.2 t, and one wanting
/// four gaskets should not be told it needs 4.0 kg of them.
String formatMass(double kg) {
  if (kg.abs() >= 1000) {
    final tonnes = kg / 1000;
    return '${tonnes.toStringAsFixed(tonnes.abs() >= 10 ? 0 : 1)} t';
  }
  return '${kg.toStringAsFixed(kg == kg.roundToDouble() ? 0 : 1)} kg';
}
