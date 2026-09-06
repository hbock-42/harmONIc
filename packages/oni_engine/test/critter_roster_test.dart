import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// What the game's critters are, against what this app keeps.
///
/// The companion to the plant roster, and written for the same reason: an
/// audit that looks inward cannot see a species absent from both sides. The
/// Stone Hatch was gone for the life of the project and no check could have
/// said so, because nothing referred to it. Somebody went looking for a Hatch
/// and found three.
///
/// Transcribed from the wiki's own species list. Every name is modelled, left
/// out with a reason, or admitted missing.
void main() {
  final db = loadDefaultDatabase();

  /// The wiki's name -> the family id here.
  const modelled = <String, String>{
    'Hatch': 'hatch',
    'Sage Hatch': 'sage_hatch',
    'Stone Hatch': 'stone_hatch',
    'Smooth Hatch': 'smooth_hatch',
    'Shine Bug': 'shine_bug',
    'Pip': 'pip',
    'Cuddle Pip': 'cuddle_pip',
    'Drecko': 'drecko',
    'Glossy Drecko': 'glossy_drecko',
    'Pokeshell': 'pokeshell',
    'Oakshell': 'oakshell',
    'Puft': 'puft',
    'Puft Prince': 'puft_prince',
    'Dense Puft': 'dense_puft',
    'Squeaky Puft': 'squeaky_puft',
    'Pacu': 'pacu',
    'Gulp Fish': 'gulp_fish',
    'Slickster': 'slickster',
    'Molten Slickster': 'molten_slickster',
    'Shove Vole': 'shove_vole',
    'Gassy Moo': 'gassy_moo',
    'Plug Slug': 'plug_slug',
    'Sweetle': 'sweetle',
    'Flox': 'flox',
    'Shatter Flox': 'shatter_flox',
    'Bammoth': 'bammoth',
    'Spigot Seal': 'spigot_seal',
    'Blum Lumb': 'blum_lumb',
    'Dartle': 'dartle',
    'Blowter': 'blowter',
    'Beakon': 'beakon',
    'Seaquine': 'seaquine',
    'Orehull': 'orehull',
    'Slogo': 'slogo',
    'Gildgo': 'gildgo',
    'Glo Squid': 'glo_squid',
    'Kelpole': 'kelpole',
    'Jawbo': 'jawbo',
  };

  /// Two of ours are a feeding choice rather than a species, so they have no
  /// line above: a Grubgrub fed sucrose or sulfur, and a Beakon grazing
  /// instead of being fed.
  const feedingModes = {
    'grubgrub_sucrose',
    'grubgrub_sulfur',
    'beakon_grazing',
  };

  const excluded = <String, String>{
    'Morb': 'untameable: it cannot be ranched, so there is no pipeline',
    'Beeta': 'untameable',
    'Mimika': 'untameable',
    'Gnit': 'untameable',
  };

  /// Missing, and what it would take. Split because they are not the same
  /// kind of gap: three are species this app has never heard of, and the rest
  /// are morphs of species it does keep.
  const missingSpecies = <String, String>{
    'Rhex': 'a Prehistoric critter, not modelled at all',
    'Lumb': 'the base form of the Blum Lumb, which is modelled without it',
  };

  const missingMorphs = <String, String>{
    'Sanishell': 'a Pokeshell morph, and the one that makes sand',
    'Tropical Pacu': 'a Pacu morph',
    'Longhair Slickster': 'a Slickster morph',
    'Delecta Vole': 'a Shove Vole morph',
    'Husky Moo': 'a Gassy Moo morph',
    'Regal Bammoth': 'a Bammoth morph',
    'Sponge Slug': 'a Plug Slug morph',
    'Smog Slug': 'a Plug Slug morph',
    'Sun Bug': 'a Shine Bug colour',
    'Royal Bug': 'a Shine Bug colour',
    'Coral Bug': 'a Shine Bug colour',
    'Azure Bug': 'a Shine Bug colour',
    'Abyss Bug': 'a Shine Bug colour',
    'Radiant Bug': 'a Shine Bug colour',
  };

  test('every critter the game has is modelled, excluded or admitted missing',
      () {
    final named = {
      ...modelled.keys,
      ...excluded.keys,
      ...missingSpecies.keys,
      ...missingMorphs.keys,
    };
    expect(
        named.length,
        modelled.length +
            excluded.length +
            missingSpecies.length +
            missingMorphs.length,
        reason: 'a critter is in two buckets at once');
    expect(named, hasLength(greaterThanOrEqualTo(55)));
  });

  test('and everything claimed as modelled really is a critter here', () {
    for (final entry in modelled.entries) {
      final spec = db.process(entry.value);
      expect(spec, isNotNull, reason: '${entry.key} -> ${entry.value}');
      expect(spec!.kind, ProcessKind.critter, reason: entry.key);
    }
  });

  test('and nothing is kept that the roster has never heard of', () {
    final families = {
      for (final spec in db.processes)
        if (spec.kind == ProcessKind.critter) spec.family ?? spec.id,
    };
    expect(families.difference({...modelled.values, ...feedingModes}), isEmpty,
        reason: 'a critter this app keeps that the roster does not list');
  });

  test('the Kelpole is the odd one: untameable, and kept anyway', () {
    // It earns its place -- an Orehull ranch runs on Tower Kelp, and the
    // kelpoles the kelp spawns are what the Orehulls eat, so the chain cannot
    // be drawn without it. But the wiki lists it among the untameable, which
    // settles something left open when the Gassy Moo was fixed: its grooming
    // port buys nothing because nobody can groom a Kelpole at all.
    final kelpole = db.processOrThrow('kelpole');
    expect(kelpole.dupeLabourSecondsPerCycle, 0,
        reason: 'nobody tends it, and the card already books no time for it');
    expect(kelpole.baseHappiness, 0,
        reason: 'so it is not a tamed critter and does not start glum');
  });

  group('the Jawbo, which the Smoker had been asking for', () {
    test('makes the fillet nothing could make', () {
      final smoker = db.processOrThrow('smoker_smoked_fish');
      final catch_ = smoker.inputs.firstWhere((p) => p.id == 'catch');
      expect(catch_.accepted, contains('jawbo_fillet'),
          reason: 'the Smoker takes either fillet');
      expect(
          db.processes.any((s) =>
              !s.id.contains(':') &&
              s.outputs.any((p) => p.itemId == 'jawbo_fillet')),
          isTrue,
          reason: 'and now something makes one');
    });

    test('and is the only thing here that excretes rust', () {
      // Which the base-game Rust Deoxidizer has been waiting for. It is still
      // a base-game material you dig up -- the pack audit is told so -- but a
      // ranch is now a way to keep making it.
      final makers = [
        for (final spec in db.processes)
          if (!spec.id.contains(':') &&
              spec.outputs.any((p) => p.itemId == 'rust'))
            spec.family ?? spec.id,
      ];
      expect(makers.toSet(), {'jawbo'});
      expect(db.processOrThrow('rust_deoxidizer').inputs.map((p) => p.itemId),
          contains('rust'));
    });

    test('eats fillet because it cannot be shown eating a Pacu', () {
      // The published sentence offers two diets -- "1 unit of Pacu, or 1,000
      // kcal Fish Fillet" -- and only one of them is a flow. A critter eating
      // another critter is not something this app can draw at all.
      final jawbo = db.processOrThrow('jawbo');
      final food = jawbo.inputs.firstWhere((p) => p.itemId == 'fish_fillet');
      expect(food.ratePerSecond * 600 * db.itemOrThrow('fish_fillet').kcalPerKg!
              / 1000, closeTo(1000, 1e-6),
          reason: '1000 kcal a cycle, which at 1000 kcal/kg is a kilogram');
      expect(jawbo.tags, contains('unverified'),
          reason: 'because 60 kg of rust from a kilogram of fillet cannot be '
              'the whole story, and the card says so');
      expect(jawbo.description, contains('sixty times the mass'));
    });
  });
}
