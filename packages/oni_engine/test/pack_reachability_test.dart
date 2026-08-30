import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// What you can build with the DLC you actually own.
///
/// Asked for as "verifying all materials by DLC" and "verifying all geysers /
/// vents by DLC". The existing check catches a base-game recipe reaching for a
/// pack-only material. It cannot catch one pack reaching into another, and it
/// only ever notices a mistagged item when some base-game recipe happens to
/// touch it — which is how Sulfur sat marked Aquatic until a base-game recipe
/// for it was added, years of builds later.
///
/// The packs are not a flat set. Frosty Planet, Prehistoric Planet and Aquatic
/// are all packs *for* Spaced Out, so owning any of them means owning that
/// too. They are siblings of each other, though, and a recipe from one that
/// needs a material from another is a recipe nobody can cook.
void main() {
  final db = loadDefaultDatabase();

  /// Everything owning this pack gets you.
  const implies = <String, Set<String>>{
    // The Bionic Booster Pack is not one of the three: it sits beside Spaced
    // Out rather than on it, and needs only the base game.
    'bionic': {'bionic'},
    'frosty': {'frosty', 'spacedout'},
    'prehistoric': {'prehistoric', 'spacedout'},
    'aquatic': {'aquatic', 'spacedout'},
    'spacedout': {'spacedout'},
  };

  Set<String> packsOf(Iterable<String> tags) =>
      implies.keys.toSet().intersection(tags.toSet());

  Set<String> ownedBy(Set<String> packs) =>
      {for (final pack in packs) ...implies[pack]!};

  final itemPack = {for (final item in db.items) item.id: packsOf(item.tags)};

  test('the hierarchy is the one the game has', () {
    // Stated rather than assumed, because every check below rests on it: the
    // three planet packs are content for Spaced Out and cannot be had alone.
    for (final pack in ['frosty', 'prehistoric', 'aquatic']) {
      expect(implies[pack], contains('spacedout'), reason: pack);
    }
    expect(implies['spacedout'], isNot(contains('frosty')));
  });

  test('a recipe carries every pack its materials need', () {
    // Found one, and the fix was on the material rather than the recipe:
    // Swampy Delights is Spaced Out and was cooked from Bog Jelly tagged
    // Prehistoric. The jelly is Spaced Out; the Prehistoric note on its page
    // is about the two critters that eat it.
    //
    // A recipe that genuinely wants two packs is allowed to say so, and the
    // filter agrees — it hides a spec if *any* of its packs is missing.
    final impossible = <String>[];
    for (final spec in db.processes) {
      final mine = packsOf(spec.tags);
      if (mine.isEmpty) continue;
      final owned = ownedBy(mine);
      for (final port in spec.ports) {
        final needed = itemPack[port.itemId] ?? const <String>{};
        if (needed.isEmpty) continue;
        if (needed.any(owned.contains)) continue;
        impossible.add('"${spec.id}" is ${mine.join("/")} but '
            '${port.direction == PortDirection.input ? "needs" : "makes"} '
            '"${port.itemId}", which is ${needed.join("/")}');
      }
    }
    expect(impossible, isEmpty);
  });

  /// Something that brings [itemId] into being, as opposed to moving it about.
  ///
  /// This distinction is the whole test. Every item in the app has a supply
  /// node, a pump and a filter synthesised for it, none of them carrying a
  /// pack — so "is every maker pack-tagged?" was always answered no, and the
  /// check below passed without ever looking at anything. It was written
  /// yesterday and found nothing, which is exactly what a vacuous test looks
  /// like from the outside.
  ///
  /// A pump, a filter and an Aquatuner all have the item on both sides. A
  /// supply node has it on one side and is not a real recipe at all.
  bool makes(ProcessSpec spec, String itemId) {
    if (spec.kind == ProcessKind.source) return false;
    final outputs =
        spec.ports.any((p) => p.itemId == itemId && !p.isInput);
    final passesThrough = spec.ports.any((p) => p.itemId == itemId && p.isInput);
    return outputs && !passesThrough;
  }

  test('the maker test does not count pumps and supply nodes', () {
    // Guarding the guard, because getting this wrong is silent.
    expect(makes(db.processOrThrow('source:water'), 'water'), isFalse);
    expect(makes(db.processOrThrow('pump:water'), 'water'), isFalse);
    expect(makes(db.processOrThrow('electrolyzer'), 'oxygen'), isTrue);
  });

  test('an item only a pack can make carries that pack', () {
    // The direction that would have caught Sulfur years before a base-game
    // recipe for it turned up. Exceptions are listed rather than let through,
    // because each one is a claim about the game and not about the code.
    //
    // It is also the direction that needs the most care. It flagged the Nosh
    // Bean, and the obvious reading — the bean is Frosty, like the Nosh Noms
    // made from it — is wrong. The bean and the sprout are both base game,
    // and Frosty covers the Deep Fryer recipe and the Bammoth that eats them.
    // Tagging the bean hid Tofu and Curried Beans from anybody without the
    // pack, and the older check caught that within a minute. The fault was in
    // the sprout's tag all along.
    //
    // Each of these is a base-game thing that this app happens to model only
    // one pack-owned way of getting. That is a gap in the modelling and not a
    // wrong tag, so the answer is to say so rather than to tag it and hide it
    // from the people who own it.
    const knownBaseGame = <String, String>{
      // Shipped with the Bionic Booster Pack and given to the base game when
      // the Prehistoric Planet Pack arrived. The only way of making it here is
      // a Plant Pulverizer running slime, which is Aquatic.
      'phyto_oil': 'base game since the Prehistoric Planet Pack',
      // Dug out of the Abyssalite biome of every base game. A Glo Squid is
      // simply the only thing here that excretes it.
      'abyssalite': 'base game, and mined rather than made',
      // A base-game ore. The only recipe here is crushing a Gildgo molt.
      'gold_amalgam': 'base game ore, mined',
      // Not a material at all — the time a Duplicant spends at a station, and
      // the only station modelled is the Aquatic one.
      'milking': 'a service, not a material',
    };

    final missing = <String>[];
    for (final item in db.items) {
      if (item.isClass || itemPack[item.id]!.isNotEmpty) continue;
      if (knownBaseGame.containsKey(item.id)) continue;
      final makers = [
        for (final spec in db.processes)
          if (makes(spec, item.id)) spec,
      ];
      if (makers.isEmpty || makers.any((s) => packsOf(s.tags).isEmpty)) {
        continue;
      }
      missing.add('"${item.id}" is untagged and only '
          '${makers.map((s) => s.id).take(3).join(", ")} make it');
    }
    expect(missing, isEmpty);
  });

  test('every geyser says which pack it belongs to, or to none', () {
    // Geysers are how a base gets anything at all, so one shown to somebody
    // who cannot have it is worse than most mistakes.
    final geysers =
        db.processes.where((s) => s.tags.contains('geyser')).toList();
    expect(geysers, hasLength(greaterThan(15)));
    for (final geyser in geysers) {
      final packs = packsOf(geyser.tags);
      expect(packs.length, lessThan(2),
          reason: '${geyser.id} claims to be from two packs at once');
      for (final port in geyser.ports) {
        final needed = itemPack[port.itemId] ?? const <String>{};
        if (needed.isEmpty) continue;
        expect(needed.any(ownedBy(packs).contains), isTrue,
            reason: '${geyser.id} (${packs.join("/")}) emits '
                '"${port.itemId}" (${needed.join("/")})');
      }
    }
  });

  test('and nothing is tagged for a pack this app has never heard of', () {
    // A list to keep up to date, deliberately. A pack tag with a letter wrong
    // is not a broken build or a wrong number — it is a thing quietly missing
    // from somebody's catalogue, or quietly present in a catalogue that
    // cannot use it, and nothing else here would notice either.
    const known = {
      'aquatic', 'frosty', 'prehistoric', 'spacedout',
      // Not packs: what a thing is, or how sure the figures are.
      'verified', 'unverified', 'geyser', 'ranching', 'farming', 'food',
      'wild', 'power', 'refining', 'oxygen', 'pumping', 'eating', 'filtering',
      'build', 'cooling', 'geothermal', 'plumbing', 'space', 'medical',
      'clothing', 'critter-comfort', 'radiation', 'bionic', 'liquid', 'gas',
      'oil', 'sublimation', 'colony', 'source', 'sink',
    };
    final unknown = <String>{
      for (final spec in db.processes)
        for (final tag in spec.tags)
          if (!known.contains(tag)) '${spec.id}: $tag',
    };
    expect(unknown, isEmpty);
  });

  test('the Bionic Booster Pack stands beside Spaced Out, not on it', () {
    // Unlike the three planet packs, it needs only the base game — somebody
    // can own it and nothing else. So a bionic recipe may not reach for a
    // Spaced Out material either, and the check above holds it to that.
    expect(implies['bionic'], {'bionic'});
    expect(implies['bionic'], isNot(contains('spacedout')));
  });

  test('a Bionic Duplicant eats nothing and drinks oil', () {
    final bionic = db.processOrThrow('bionic_duplicant');
    expect(bionic.tags, contains('bionic'));
    final eats = {for (final p in bionic.ports.where((p) => p.isInput)) p.itemId};
    expect(eats, contains('phyto_oil'));
    expect(eats, contains('power'));
    expect(eats, contains('oxygen'));
    expect(eats, isNot(contains('calories')),
        reason: 'which is the whole difference');

    // And it does not breathe out, which an ordinary one does.
    final ordinary = db.processOrThrow('duplicant');
    expect(ordinary.ports.map((p) => p.itemId), contains('carbon_dioxide'));
    expect(bionic.ports.map((p) => p.itemId), isNot(contains('carbon_dioxide')));
  });
}
