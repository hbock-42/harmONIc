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
    'Grubfruit Plant': 'grubfruit, wanted by a preserve and all three Mixed '
        'Berry Pies',
    'Plume Squash Plant': 'plume squash, wanted by Squash Fries and eaten by '
        'the Bammoth',
    'Sweatcorn Stalk': 'sweatcorn, wanted by Veggie Poppers',
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
}
