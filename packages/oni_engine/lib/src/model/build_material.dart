import 'game_database.dart';
import 'item.dart';
import 'process_spec.dart';
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

/// What one of a counted material costs, in the stuff it is made from.
///
/// Four gaskets is four gaskets, and that is the right way to say what a
/// Marine Drill needs — but it leaves you having to know that a gasket is
/// 50 kg of plastic before you can tell whether you can afford one. This finds
/// the recipe that makes it and reports the price of one.
///
/// Null unless there is exactly one recipe and exactly one thing that goes
/// into it. Two recipes and the answer depends on which you run; two inputs
/// and "the plastic behind it" is not a whole answer. Both are better said as
/// nothing than as half a figure.
({String materialId, double amountEach})? costOfOne(
  GameDatabase database,
  String itemId,
) {
  if (!(database.item(itemId)?.isCounted ?? false)) return null;

  ({String materialId, double amountEach})? found;
  for (final spec in database.processes) {
    // A supply node offers every item there is; being able to *have* a gasket
    // is not a recipe for one.
    if (spec.kind != ProcessKind.building) continue;
    for (final made in spec.outputs) {
      if (made.itemId != itemId || made.ratePerSecond <= 0) continue;
      final ingredients = [
        for (final port in spec.inputs)
          if (!(database.item(port.itemId)?.isCapacity ?? true) &&
              database.item(port.itemId)?.unit == Unit.gramsPerSecond)
            port,
      ];
      if (ingredients.length != 1) return null;
      if (found != null) return null; // a second recipe: which one did you run?
      // Both rates are thirds — one gasket every 30 s out of 50 kg — so the
      // division comes back as 50.000000051 kg. Rounded to the gram, because
      // the answer is a recipe figure and not a measurement.
      final kg = ingredients.single.ratePerSecond / made.ratePerSecond / 1000;
      found = (
        materialId: ingredients.single.itemId,
        amountEach: (kg * 1000).roundToDouble() / 1000,
      );
    }
  }
  return found;
}

/// A build cost, in whatever unit that material is counted in.
///
/// Almost everything is kilograms. Gaskets are not: they are things, and the
/// Aquatic Milking Station wants four of them rather than four kilograms of
/// them. Writing "4 kg Gaskets" is the sort of small wrongness that makes a
/// reader distrust the figures beside it.
String formatMaterial(Item? material, double amount) =>
    material?.isCounted ?? false
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
