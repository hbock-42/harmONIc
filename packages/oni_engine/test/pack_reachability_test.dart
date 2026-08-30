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

  test('no recipe needs a material from a pack it does not come with', () {
    // Found one: Swampy Delights, tagged Spaced Out, cooked from Bog Jelly
    // that was tagged Prehistoric. The jelly is Spaced Out; the Prehistoric
    // note on its page is about the two critters that eat it, which is the
    // same mistake as tagging an item for the pack this app first met it in.
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

  test('an item only a pack can make carries that pack', () {
    // The other direction, and the one that let Sulfur hide: if every recipe
    // making a thing belongs to a pack, the thing belongs to it too — unless
    // it is lying about the pack, which is what this asks.
    final missing = <String>[];
    for (final item in db.items) {
      if (item.isClass || itemPack[item.id]!.isNotEmpty) continue;
      final makers = [
        for (final spec in db.processes)
          if (spec.ports.any((p) =>
              p.itemId == item.id && p.direction == PortDirection.output))
            spec,
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
}
