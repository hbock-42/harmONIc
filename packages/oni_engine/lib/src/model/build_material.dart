import 'item.dart';
import 'units.dart';

/// What a building costs to *put up*, as opposed to what it runs on.
///
/// The game asks for a class of material rather than a particular one: an
/// Electrolyzer takes 200 kg of any metal ore, and which ore you feed it
/// changes its heat tolerance and nothing else. Those classes are ordinary
/// items in the database with members — the same ones a recipe port names — so
/// there is one vocabulary here and not two.
///
/// What makes a build cost different from a flow is when it is paid: once, when
/// the building goes up, rather than every second it runs. That is why it lives
/// beside the ports instead of among them.
abstract final class BuildMaterials {
  static const String metalOre = 'metal_ore';
  static const String refinedMetal = 'refined_metal';
  static const String rawMineral = 'raw_mineral';
  static const String plastic = 'plastic';
  static const String cultivableSoil = 'cultivable_soil';
  static const String wood = 'wood';
  static const String glass = 'glass';

  /// A crafted part rather than a class: 50 kg of plastic or rubber makes some
  /// number of them, and the wiki does not say how many.
  static const String gasket = 'gasket';
}

/// A build cost, in whatever unit that material is counted in.
///
/// Almost everything is kilograms. Gaskets are not: they are things, and the
/// Aquatic Milking Station wants four of them rather than four kilograms of
/// them. Writing "4 kg Gaskets" is the sort of small wrongness that makes a
/// reader distrust the figures beside it.
String formatMaterial(Item? material, double amount) =>
    material?.unit == Unit.count
        ? amount.toStringAsFixed(0)
        : formatMass(amount);

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
