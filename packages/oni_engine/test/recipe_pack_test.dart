import 'dart:convert';

import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// Handing your own recipes to somebody else.
void main() {
  final db = loadDefaultDatabase();

  RecipePack packOf(List<String> specIds) => RecipePack(
        processes: [for (final id in specIds) db.processOrThrow(id)],
      );

  test('a pack survives the round trip whole', () {
    final pack = packOf(['smoker_brisket', 'metal_refinery_galena']);
    final back = RecipePack.decode(pack.encode());

    expect(back.processes.map((p) => p.id),
        ['smoker_brisket', 'metal_refinery_galena']);

    // The parts a recipe is actually made of, not just its name.
    final smoker = back.processes.first;
    final original = db.processOrThrow('smoker_brisket');
    expect(smoker.ports.length, original.ports.length);
    expect(smoker.ports.firstWhere((p) => p.id == 'fuel').accepted,
        ['wood', 'peat']);
    expect(smoker.description, original.description);
    expect(smoker.footprintTiles, original.footprintTiles);
  });

  test('an item nobody has yet travels with the recipe that needs it', () {
    // The usual reason a recipe cannot be written at all is that the app has
    // never heard of the material, so a pack that carried only processes
    // would arrive broken.
    const unobtanium = Item(
        id: 'unobtanium', name: 'Unobtanium', category: ItemCategory.solid);
    final pack = RecipePack(
      items: const [unobtanium],
      processes: [db.processOrThrow('smoker_brisket')],
    );

    final back = RecipePack.decode(pack.encode());
    expect(back.items.single.id, 'unobtanium');
    expect(back.items.single.category, ItemCategory.solid);
  });

  test('raw JSON is accepted too, because somebody will paste the file', () {
    final pack = packOf(['compost']);
    final back = RecipePack.decode(jsonEncode(pack.toJson()));
    expect(back.processes.single.id, 'compost');
  });

  test('and padding that fell off a chat message is put back', () {
    final code = packOf(['compost']).encode().replaceAll('=', '');
    expect(RecipePack.decode(code).processes.single.id, 'compost');
  });

  group('what it refuses, and what it says', () {
    void refuses(String source, Matcher says) {
      expect(() => RecipePack.decode(source),
          throwsA(isA<FormatException>().having((e) => e.message, 'says', says)));
    }

    test('nothing at all', () => refuses('   ', contains('Nothing to import')));

    test('the wrong thing off the clipboard',
        () => refuses('have you seen my hatch', contains('recipe pack')));

    test('a build, which is the near miss', () {
      // A share code decodes cleanly and holds a pipeline, not recipes. The
      // message has to be about what it is rather than about base64.
      final build = PipelineShareCode.encode(
          (PipelineBuilder(db, name: 'x')..addSource('water')).build());
      refuses(build, contains('no recipes in it'));
    });

    test('an empty pack, rather than importing nothing quietly', () {
      // "Imported 0 recipes" reads like a bug in the app instead of like the
      // wrong thing on the clipboard.
      refuses(const RecipePack().encode(), contains('no recipes in it'));
    });
  });
}
