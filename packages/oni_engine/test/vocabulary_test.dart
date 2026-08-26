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
  'amber': 'the same, and the Plant Pulverizer takes it in a recipe nobody has '
      'published a cycle time for',
  'bristle_blossom': 'the crop, where the plant reports calories directly',
  'ovagro_fig': 'a Prehistoric crop with no numbers',
  'lumen_quartz': 'a decorative mineral',
  'iridium': 'a Prehistoric metal nothing here refines',
  'mercury_gas': 'mercury above 356.75 °C, which is a state a build can reach '
      'but not one anything here asks for',
  'solid_mercury': 'and below −38.85 °C: the frozen form, which is how a Frosty '
      'asteroid keeps it and not what a refinery hands you',
  'molten_zinc': 'and its gas: an Aquatic volcano product',
  'zinc_gas': 'the same, above its condensation point',
  'nectar': 'gathered from Aquatic flora this app does not model',
  'ovolene': 'and its frozen form: a Seaquine product at a rate nobody has '
      'published',
  'frozen_ovolene': 'the same, solid',
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
}
