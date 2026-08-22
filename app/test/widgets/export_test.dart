import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/panels/pipelines_menu.dart';
import 'package:oni_pipeline/storage/exporter.dart';

import '../support/harness.dart';

/// Writing a build out as a file you can keep.
///
/// Everything here uses a temporary folder. A test that wrote to the real
/// downloads folder would be a test that leaves litter on somebody's machine.
void main() {
  late Directory folder;

  setUp(() => folder = Directory.systemTemp.createTempSync('oni_export'));
  tearDown(() => folder.deleteSync(recursive: true));

  BuildExporter exporterInto(Directory dir) =>
      BuildExporter(directory: () async => dir);

  Pipeline named(String name) =>
      (PipelineBuilder(testDatabase, name: name)
            ..addSource('water', x: 0, y: 0)
            ..add('electrolyzer', nodeId: 'elec', x: 340, y: 0)
            ..connectItem('src_water', 'elec', 'water')
            ..pinCount('elec', 3))
          .build();

  test('a build comes back out of the file it was written to', () async {
    final file = await exporterInto(folder).export(named('Oxygen'));

    expect(file.path, endsWith('Oxygen.oni.json'));
    final read = Pipeline.fromJson(
        jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);
    expect(read.name, 'Oxygen');
    expect(read.nodes, hasLength(2));
    expect(read.node('elec')!.specId, 'electrolyzer');

    // Written for a person to open, not only for the app to parse.
    expect(file.readAsStringSync(), contains('\n  '));
  });

  test('exporting twice keeps both', () async {
    final exporter = exporterInto(folder);
    final first = await exporter.export(named('Oxygen'));
    final second = await exporter.export(named('Oxygen'));

    // Overwriting the archive you made yesterday is not what "export" means.
    expect(second.path, isNot(first.path));
    expect(second.path, endsWith('Oxygen 2.oni.json'));
    expect(first.existsSync(), isTrue);
    expect(folder.listSync(), hasLength(2));
  });

  test('a name a file system would refuse still gets a file', () async {
    final exporter = exporterInto(folder);
    final awkward = await exporter.export(named('SPOM: v2/final?'));
    expect(awkward.existsSync(), isTrue);
    expect(awkward.path, endsWith('SPOM v2 final.oni.json'));

    // And a name with nothing usable left in it.
    final nameless = await exporter.export(named('///'));
    expect(nameless.path, endsWith('Build.oni.json'));
  });

  testWidgets('the button says where it put it', (tester) async {
    await useDesktopSurface(tester);
    final controller = testController();
    final workspace = await testWorkspace(controller);

    await tester.pumpWidget(harness(PipelinesMenu(
      workspace: workspace,
      controller: controller,
      library: testLibrary(),
      rateDisplay: RateDisplay.perSecond,
      onClose: () {},
      exporter: exporterInto(folder),
    )));

    expect(workspace.currentId, isNotNull);
    // Writing a file is real I/O, which does not happen inside the fake clock
    // a widget test runs on: without this the tap returns before anything has
    // been written and the panel never hears back.
    await tester.runAsync(() async {
      await tester.tap(find.text('Export'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    // The path is the whole point: an export you cannot find is a file you do
    // not have.
    expect(textContaining(folder.path), findsOneWidget);
    expect(folder.listSync(), hasLength(1));
  });

  testWidgets('and says so when it cannot', (tester) async {
    await useDesktopSurface(tester);
    final controller = testController();
    final workspace = await testWorkspace(controller);

    await tester.pumpWidget(harness(PipelinesMenu(
      workspace: workspace,
      controller: controller,
      library: testLibrary(),
      rateDisplay: RateDisplay.perSecond,
      onClose: () {},
      exporter: BuildExporter(
          directory: () async => throw const FileSystemException('nope')),
    )));

    await tester.runAsync(() async {
      await tester.tap(find.text('Export'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();

    // An export that silently does nothing is indistinguishable from one that
    // worked, which is the worse of the two failures.
    expect(textContaining('could not be saved'), findsOneWidget);
  });
}
