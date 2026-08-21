import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

void main() {
  group('how many runs a flow needs', () {
    test('a liquid pipe carries 10 kg/s', () {
      expect(Conduits.runsNeeded(10000, ItemCategory.liquid), 1);
      expect(Conduits.runsNeeded(10001, ItemCategory.liquid), 2);
      // An Electrolyzer's kilogram a second is comfortably one pipe.
      expect(Conduits.runsNeeded(1000, ItemCategory.liquid), 1);
    });

    test('a gas pipe carries only 1 kg/s, which bites sooner', () {
      // One Electrolyzer makes 888 g/s of oxygen: one pipe.
      expect(Conduits.runsNeeded(888, ItemCategory.gas), 1);
      // Three of them do not fit down one.
      expect(Conduits.runsNeeded(2664, ItemCategory.gas), 3);
    });

    test('a conveyor rail carries 20 kg/s', () {
      expect(Conduits.runsNeeded(20000, ItemCategory.solid), 1);
      expect(Conduits.runsNeeded(40000, ItemCategory.solid), 2);
    });

    test('nothing flowing needs no pipe', () {
      expect(Conduits.runsNeeded(0, ItemCategory.liquid), 0);
      expect(Conduits.describe(0, ItemCategory.liquid), isNull);
    });

    test('things that travel by no pipe at all say so', () {
      for (final category in [ItemCategory.heat, ItemCategory.service,
          ItemCategory.entity, ItemCategory.other]) {
        expect(Conduits.forCategory(category), isNull);
        expect(Conduits.runsNeeded(5000, category), 0);
      }
    });
  });

  group('wires', () {
    test('the cheapest one that carries the load is chosen', () {
      expect(Conduits.wireFor(800).name, 'Wire');
      expect(Conduits.wireFor(1000).name, 'Wire');
      expect(Conduits.wireFor(1200).name, 'Conductive Wire');
      expect(Conduits.wireFor(5000).name, 'Heavi-Watt Wire');
      expect(Conduits.wireFor(30000).name, 'Heavi-Watt Conductive Wire');
    });

    test('a load past the biggest wire needs more than one run', () {
      expect(Conduits.wireRunsNeeded(120000), 3);
      expect(Conduits.describe(120000, ItemCategory.power),
          '3 × Heavi-Watt Conductive Wire');
    });

    test('a hydrogen generator fits on plain wire', () {
      expect(Conduits.describe(800, ItemCategory.power), 'Wire');
    });
  });

  group('the sentence it produces', () {
    test('singular and plural', () {
      expect(Conduits.describe(5000, ItemCategory.liquid), 'liquid pipe');
      expect(Conduits.describe(25000, ItemCategory.liquid), '3 liquid pipes');
    });

    test('a real build: one water geyser into Electrolyzers', () {
      // 1800 g/s of water is one pipe; the 1598 g/s of oxygen it becomes is
      // two, because gas pipes carry a tenth of what liquid ones do.
      expect(Conduits.describe(1800, ItemCategory.liquid), 'liquid pipe');
      expect(Conduits.describe(1598.4, ItemCategory.gas), '2 gas pipes');
    });
  });
}
