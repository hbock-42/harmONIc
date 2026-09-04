import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// Items nothing makes and nothing takes, and why each is still here.
///
/// An item is not free. Every one generates a supply node, an output node and,
/// if it flows, a pump, a filter and a cooler — so a material nobody uses is
/// five entries in the palette for something that cannot happen. Three were
/// removed when this was written: two plant-growth links belonging to plants
/// with no grazed twin, and a mush bar invented for a recipe that reports
/// calories instead.
///
/// The rest earn their place by being things you might genuinely *have*, even
/// though nothing here makes them.
const Map<String, String> unusedOnPurpose = {
  'duplicant': 'the unit a crew is counted in',
  'liquid_oxygen': 'stored oxygen, and what a rocket runs on',
  'naphtha': 'a liquid you find rather than make',
  'super_coolant': 'an Emulsifier makes 100 kg of it out of a kilogram of '
      'fullerene, 49.5 of gold and 49.5 of petroleum, and nobody has published '
      'how long that takes — so it is here to be had and cooled with, and the '
      'recipe is not',
  'bristle_blossom': 'the crop, where the plant reports calories directly',
  'lumen_quartz': 'a decorative mineral',
  'iridium': 'a Prehistoric metal nothing here refines',
  'mercury_gas': 'mercury above 356.75 °C, which is a state a build can reach '
      'but not one anything here asks for',
  'solid_mercury': 'and below −38.85 °C: the frozen form, which is how a Frosty '
      'asteroid keeps it and not what a refinery hands you',
  'molten_zinc': 'and its gas: an Aquatic volcano product',
  'zinc_gas': 'the same, above its condensation point',
  'nectar': 'gathered from Aquatic flora this app does not model',
  // 'ovolene' was here, as "a Seaquine product at a rate nobody has
  // published". Two pages publish it -- 100 kg a milking -- so the Seaquine
  // makes it now and the note came out, which is what this list is for.
  'frozen_ovolene': 'what ovolene freezes into',
  'frozen_mucin': 'a Frosty solid',
  'frozen_squid_ink': 'an Aquatic solid',
  'polluted_brine_ice': 'what polluted brine freezes into',
};

void main() {
  final db = loadDefaultDatabase();

  /// The recipes somebody wrote, as opposed to the ones generated per item.
  ///
  /// A supply node, an output node, a pump, a filter and a cooler are all made
  /// *from* an item, so counting them as uses makes every item used and the
  /// question meaningless — which is exactly what the first draft of this did.
  Iterable<ProcessSpec> written() => db.processes.where((spec) =>
      spec.kind != ProcessKind.source &&
      spec.kind != ProcessKind.sink &&
      !spec.tags.contains('pumping') &&
      !spec.tags.contains('filtering') &&
      !spec.tags.contains('cooling'));

  test('every item is used, or says why it is not', () {
    final used = <String>{};
    for (final spec in written()) {
      for (final port in spec.ports) {
        used
          ..add(port.itemId)
          ..addAll(port.alternatives);
      }
      used.addAll(spec.buildCost.keys);
    }
    for (final item in db.items) {
      used.addAll(item.members);
      if (item.refinesTo case final String refined) used.add(refined);
    }

    final orphans = [
      for (final item in db.items)
        if (!used.contains(item.id) && !unusedOnPurpose.containsKey(item.id))
          item.id,
    ];

    expect(orphans, isEmpty,
        reason: 'either something should use it, or it belongs in '
            'unusedOnPurpose with a sentence saying what it is');
  });

  test('and the exceptions are still unused', () {
    // An entry that has since found a use is a note nobody will reread.
    final used = <String>{};
    for (final spec in written()) {
      for (final port in spec.ports) {
        used
          ..add(port.itemId)
          ..addAll(port.alternatives);
      }
      used.addAll(spec.buildCost.keys);
    }
    for (final item in db.items) {
      used.addAll(item.members);
      if (item.refinesTo case final String refined) used.add(refined);
    }
    for (final id in unusedOnPurpose.keys) {
      expect(used.contains(id), isFalse,
          reason: '"$id" is used now; take it out of unusedOnPurpose');
    }
  });

  group('food you could never obtain', () {
    /// Foods nothing in this database can produce, and what is missing.
    ///
    /// A material nobody makes is usually fine — you might have found it. Food
    /// is different: a dish names its ingredients, so an ingredient with no
    /// source is a recipe nobody can ever draw, and the app offers it anyway.
    ///
    /// Bog jelly was the fifth of these until the Bog Bucket was added, and it
    /// was found the way all of them will be found without this test: somebody
    /// tried to build the thing and could not.
    const missingSource = <String, String>{
      'grubfruit': 'the Grubfruit plant, which blocks four dishes — a preserve '
          'and all three Mixed Berry Pies',
      'ovagro_fig': 'the Ovagro, which blocks one of those pies',
      'sweatcorn': 'the Sweatcorn plant, which blocks Veggie Poppers',
      'jawbo_fillet': 'the Jawbo, an Aquatic critter this database has not got '
          '— and nothing here asks for the fillet either, so this one blocks '
          'nothing yet',
    };

    test('is listed, and the list is exactly what cannot be made', () {
      // Written recipes only. Every item gets a generated supply node, so
      // asking the whole database whether something can be obtained always
      // answers yes, and an audit built on that would pass forever.
      final written = db.processes.where((spec) => !spec.id.contains(':'));
      final made = <String>{
        for (final spec in written)
          for (final port in spec.outputs) port.itemId,
      };
      final unmakeable = <String>{
        for (final item in db.items)
          if ((item.kcalPerKg ?? 0) > 0 && !made.contains(item.id)) item.id,
      };
      expect(unmakeable, missingSource.keys.toSet(),
          reason: 'a food with no source is a dish nobody can draw; add what '
              'makes it, or say here what is missing');
    });

    test('and each of them is still worth having as an item', () {
      // The other direction: something on that list that nothing cooks with
      // either is not a gap, it is a word to delete. The Jawbo fillet is the
      // one nothing asks for, and it stays because the critter is real and
      // coming.
      for (final id in missingSource.keys) {
        expect(db.item(id), isNotNull, reason: id);
      }
    });
  });
}
