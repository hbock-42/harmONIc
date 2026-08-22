import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/panels/pipelines_menu.dart';
import 'package:oni_pipeline/state/library_controller.dart';
import 'package:oni_pipeline/storage/json_store.dart';

import '../support/harness.dart';

/// Handing the recipes you measured to somebody who has not.
void main() {
  late List<MethodCall> clipboard;

  setUp(() {
    clipboard = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      clipboard.add(call);
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': _pasted};
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  ProcessSpec smoker(String id, {String name = 'Smoker (measured)'}) =>
      ProcessSpec(
        id: id,
        name: name,
        kind: ProcessKind.building,
        tags: const {'custom', 'verified'},
        ports: [
          Port(
            id: 'fuel',
            itemId: 'wood',
            direction: PortDirection.input,
            ratePerSecond: 166.6,
            alternatives: const ['peat'],
          ),
          const Port(
            id: 'calories',
            itemId: 'calories',
            direction: PortDirection.output,
            ratePerSecond: 26.6,
          ),
        ],
      );

  Future<LibraryController> pumpMenu(WidgetTester tester,
      {LibraryController? library}) async {
    await useDesktopSurface(tester);
    final controller = testController();
    final settings = library ?? testLibrary();
    await tester.pumpWidget(harness(PipelinesMenu(
      workspace: await testWorkspace(controller),
      controller: controller,
      library: settings,
      rateDisplay: RateDisplay.perSecond,
      onClose: () {},
    )));
    return settings;
  }

  Future<void> openRecipes(WidgetTester tester) async {
    await tester.tap(find.text('Recipes you wrote'));
    await tester.pumpAndSettle();
  }

  testWidgets('with nothing written, there is nothing to copy', (tester) async {
    await pumpMenu(tester);
    // Folded away, like the other two sections in this menu: the list of
    // saved builds is what it is for.
    expect(find.text('Copy recipes'), findsNothing);
    await openRecipes(tester);
    expect(textContaining('Nothing yet'), findsOneWidget);

    // Offered but not pressable, which says "this is where it will be" rather
    // than hiding the feature until somebody stumbles on it.
    expect(find.text('Copy recipes'), findsOneWidget);
    await tester.tap(find.text('Copy recipes'));
    await tester.pump();
    expect(clipboard.where((c) => c.method == 'Clipboard.setData'), isEmpty);
  });

  testWidgets('what you wrote goes on the clipboard as one pack',
      (tester) async {
    final library = testLibrary();
    await library.save(smoker('smoker_measured'));
    await pumpMenu(tester, library: library);

    await openRecipes(tester);
    await tester.tap(find.text('Copy recipes'));
    await tester.pumpAndSettle();

    final copied = clipboard.firstWhere((c) => c.method == 'Clipboard.setData');
    final pack = RecipePack.decode(
        (copied.arguments as Map<dynamic, dynamic>)['text'] as String);
    expect(pack.processes.single.id, 'smoker_measured');
    expect(pack.processes.single.ports.first.accepted, ['wood', 'peat']);
    expect(textContaining('1 recipe copied'), findsOneWidget);
  });

  testWidgets('and somebody else\'s pack arrives in the palette',
      (tester) async {
    _pasted = RecipePack(processes: [smoker('smoker_measured')]).encode();
    final library = testLibrary();
    await pumpMenu(tester, library: library);

    await openRecipes(tester);
    await tester.tap(find.text('Paste recipes'));
    await tester.pumpAndSettle();

    expect(library.database.process('smoker_measured'), isNotNull);
    expect(library.isCustom('smoker_measured'), isTrue);
    expect(textContaining('1 added'), findsOneWidget);
  });

  testWidgets('replacing one of yours is said out loud', (tester) async {
    final library = testLibrary();
    await library.save(smoker('smoker_measured', name: 'Mine'));
    _pasted = RecipePack(processes: [smoker('smoker_measured', name: 'Theirs')])
        .encode();
    await pumpMenu(tester, library: library);

    await openRecipes(tester);
    await tester.tap(find.text('Paste recipes'));
    await tester.pumpAndSettle();

    // Theirs wins, which is what importing means — but an evening's measuring
    // must not vanish without a word.
    expect(library.database.processOrThrow('smoker_measured').name, 'Theirs');
    expect(textContaining('replaced one of yours'), findsOneWidget);
  });

  testWidgets('the wrong thing on the clipboard says what it wanted',
      (tester) async {
    _pasted = 'have you seen my hatch';
    await pumpMenu(tester);
    await openRecipes(tester);

    await tester.tap(find.text('Paste recipes'));
    await tester.pumpAndSettle();

    expect(textContaining('recipe pack'), findsOneWidget);
  });

  test('an imported pack outlives the session', () async {
    final store = MemoryJsonStore();
    final first = LibraryController(bundled: testDatabase, store: store);
    await first.load();
    await first.import(RecipePack(processes: [smoker('smoker_measured')]));

    final second = LibraryController(bundled: testDatabase, store: store);
    await second.load();
    expect(second.database.process('smoker_measured'), isNotNull);
  });
}

String _pasted = '';
