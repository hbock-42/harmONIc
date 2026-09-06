import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// What the game has, against what this app models.
///
/// Every other audit here looks inward: an item nothing makes, a port nothing
/// needs, a rate too small to be right. None of them can see a thing that is
/// absent from both sides of the ledger, and that is how the Stone Hatch went
/// missing for the life of the project and how a Bog Bucket could be wanted by
/// a recipe with no plant to grow it. Somebody had to go looking for a Hatch
/// and find three.
///
/// So this one looks outward. The roster below is transcribed from the wiki's
/// own lists, and every name in it is either modelled, deliberately left out
/// with a reason, or missing and admitted to. A name that is none of those
/// three fails the test.
///
/// It is a hand-written list and it will go stale when a pack ships, which is
/// the price of the only kind of check that can find something nobody has
/// thought of. Re-read the source when the game build in oni_data.json moves.
void main() {
  final db = loadDefaultDatabase();

  /// Modelled: the name the wiki uses -> the family id here.
  const modelled = <String, String>{
    'Mealwood': 'mealwood',
    'Dusk Cap': 'dusk_cap',
    'Bristle Blossom': 'bristle_blossom',
    'Sleet Wheat': 'sleet_wheat',
    'Waterweed': 'waterweed',
    'Nosh Sprout': 'nosh_sprout',
    'Pincha Pepper': 'pincha_pepperplant',
    'Thimble Reed': 'thimble_reed',
    'Arbor Tree': 'arbor_tree',
    'Gas Grass': 'gas_grass',
    'Bog Bucket': 'bog_bucket',
    'Spindly Grubfruit Plant': 'spindly_grubfruit_plant',
    'Pikeapple Bush': 'pikeapple_bush',
    'Alveo Vera': 'alveo_vera',
    'Megafrond': 'megafrond',
    'Sodicane': 'sodicane',
    'Tower Kelp': 'tower_kelp',
    'Pinpoket': 'pinpoket',
    'Gum Palm': 'gum_palm',
    'Starnacle': 'starnacle',
    'Clampum': 'clampum',
    'Flue Coral': 'flue_coral',
    'Tublia': 'tublia',
    'Grubfruit Plant': 'grubfruit_plant',
    'Sweatcorn Stalk': 'sweatcorn_stalk',
    'Plume Squash Plant': 'plume_squash_plant',
  };

  /// Left out on purpose, and why. A pipeline is a thing you can run again
  /// tomorrow, so a plant you cannot farm is not one.
  const excluded = <String, String>{
    'Swamp Chard': 'the wiki says outright that Swamp Chards are "incapable of '
        'propagating" -- you find them and harvest them once, so there is no '
        'pipeline to draw. Same reason as Mussel Sprout',
    'Mussel Sprout': 'wild-only and non-renewable, decided in E4-37',
    'Bulbloom': 'decorative, decided in E4-37',
    'Petta Pouf': 'decorative, decided in E4-37',
    'Husha Cups': 'decorative, decided in E4-37',
    'Buried Muckroot': 'forage: dug up once, never grown',
    'Hexalent': 'decorative',
    'Balm Lily': 'medicine rather than production, and a Duplicant carries it',
    'Oxyfern': 'oxygen for a room rather than into a pipe',
    'Wheezewort': 'cools the air around it, which is not a flow this app can '
        'draw',
    'Bluff Briar': 'decorative',
    'Buddy Bud': 'decorative',
    'Mirth Leaf': 'decorative',
    'Jumping Joya': 'decorative',
    'Sporechid': 'decorative, and hostile',
    'Saturn Critter Trap': 'eats critters; not a production recipe',
    'Bliss Burst': 'decorative',
    'Mellow Mallow': 'decorative',
    'Tranquil Toes': 'decorative',
    'Idylla Flower': 'decorative',
    'Ring Rosebush': 'decorative',
    'Snactus': 'decorative',
    'Lura Plant': 'decorative',
    'Dasha Saltvine': 'salt from a plant, and nothing here consumes salt yet',
    'Sherberry Plant': 'a Frosty crop nothing here cooks with yet',
    'Bonbon Tree': 'a Frosty crop nothing here cooks with yet',
  };

  /// Missing, and what depends on it. Each of these is wanted by a recipe this
  /// app already has, so the recipe cannot be drawn at all.
  const missing = <String, String>{
    'Ovagro Node': 'ovagro fig, wanted by a Mixed Berry Pie',
    'Mimika Bud': 'mimillet, wanted by Toasted Mimillet',
    'Dew Dripper': 'dewdrip, eaten by the Dartle',
    'Seakomb': 'seakomb leaf, which the Plant Pulverizer turns into phyto oil',
  };

  test('every plant the game has is modelled, excluded or admitted missing',
      () {
    final named = {...modelled.keys, ...excluded.keys, ...missing.keys};
    expect(named.length,
        modelled.length + excluded.length + missing.length,
        reason: 'a plant is in two buckets at once');

    // The roster is the transcription; this is what it is worth.
    expect(named, hasLength(greaterThanOrEqualTo(55)),
        reason: 'the wiki lists about sixty plants across the packs');
  });

  test('and everything claimed as modelled really is', () {
    for (final entry in modelled.entries) {
      final spec = db.process(entry.value);
      expect(spec, isNotNull, reason: '${entry.key} -> ${entry.value}');
      expect(spec!.kind, ProcessKind.plant, reason: entry.key);
    }
  });

  test('and nothing is modelled that the roster has never heard of', () {
    // The other direction, and the one that catches a plant added without
    // being thought about: every plant family here has a line above.
    final families = {
      for (final spec in db.processes)
        if (spec.kind == ProcessKind.plant) spec.family ?? spec.id,
    };
    expect(families.difference(modelled.values.toSet()), isEmpty,
        reason: 'a plant this app grows that the roster does not list');
  });

  test('and the missing ones are really missing, so the list stays honest', () {
    // A line here that has quietly been fixed is a line nobody will delete.
    final families = {
      for (final spec in db.processes)
        if (spec.kind == ProcessKind.plant) spec.family ?? spec.id,
    };
    for (final name in missing.keys) {
      expect(modelled.containsKey(name), isFalse, reason: name);
    }
    expect(families, hasLength(modelled.length));
  });

  group('the three crops that were blocking recipes', () {
    /// A crop's mass is its published calories divided by its calories a
    /// kilogram. The wiki prints one or the other and sometimes both, and
    /// where it prints both they agree -- a Grubfruit Plant drops "8 kg or
    /// 2000 kcal" and grubfruit is 250 kcal/kg, which is the same fact twice.
    void checkCrop(String plantId, String crop, double kcalPerHarvest,
        double cycles) {
      final spec = db.processOrThrow(plantId);
      final out = spec.outputs.firstWhere((p) => p.itemId == crop);
      final kcalPerKg = db.itemOrThrow(crop).kcalPerKg!;
      final kg = kcalPerHarvest / kcalPerKg;
      expect(out.ratePerSecond, closeTo(kg * 1000 / (cycles * 600), 1e-6),
          reason: '$plantId yields $kg kg every $cycles cycles');
    }

    test('grow what the recipes were asking for', () {
      checkCrop('grubfruit_plant', 'grubfruit', 2000, 8);
      checkCrop('sweatcorn_stalk', 'sweatcorn', 800, 3);
      checkCrop('plume_squash_plant', 'plume_squash', 4000, 9);
    });

    test('and the dishes can now actually be drawn', () {
      // The point of all three. Each was an ingredient with no source, so the
      // recipe was in the palette and unbuildable.
      for (final recipe in [
        'electric_grill_grubfruit_preserve',
        'smoker_veggie_poppers',
        'deep_fryer_squash_fries',
      ]) {
        final spec = db.processOrThrow(recipe);
        for (final input in spec.inputs) {
          final grown = db.processes.any((s) =>
              !s.id.contains(':') &&
              s.outputs.any((p) => p.itemId == input.itemId));
          final dug = db.itemOrThrow(input.itemId).kcalPerKg == null;
          expect(grown || dug, isTrue,
              reason: '$recipe still wants ${input.itemId}, which nothing '
                  'makes and nobody digs up');
        }
      }
    });

    test('a Bammoth can be fed, which needed the squash too', () {
      // Not a dish: the Bammoth eats plume squash, so a ranch of them could
      // not be drawn either.
      final bammoth = db.processOrThrow('bammoth');
      expect(bammoth.inputs.map((p) => p.itemId), contains('plume_squash'));
      expect(
          db.processes.any((s) =>
              s.kind == ProcessKind.plant &&
              s.outputs.any((p) => p.itemId == 'plume_squash')),
          isTrue);
    });

    test('and a Plume Squash can be eaten raw, which it could not', () {
      // It had no calorie figure at all, so no eating node was generated for
      // it: the Deep Fryer would make Squash Fries and a Duplicant could not
      // simply eat one.
      expect(db.itemOrThrow('plume_squash').kcalPerKg, 4000);
      expect(
          db.processes.any((s) =>
              s.inputs.any((p) => p.itemId == 'plume_squash') &&
              s.outputs.any((p) => p.itemId == WellKnownItems.calories)),
          isTrue);
    });
  });
}
