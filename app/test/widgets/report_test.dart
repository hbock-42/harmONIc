import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/report_footer.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// Saying that something is wrong, from inside the app.
void main() {
  late List<Uri> opened;

  Future<PipelineController> pumpEditor(WidgetTester tester,
      {Pipeline? pipeline}) async {
    await useDesktopSurface(tester);
    opened = [];
    final controller = testController(pipeline: pipeline ?? testPipeline());
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
      loadGuide: () async => '# Using it\n\nWords.',
      openLink: (uri) async {
        opened.add(uri);
        return true;
      },
    )));
    return controller;
  }

  Future<void> openGuide(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Guide'));
    await tester.tap(find.text('Guide'));
    await tester.pumpAndSettle();
  }

  testWidgets('the guide is where you go to say something is wrong',
      (tester) async {
    await pumpEditor(tester);
    await openGuide(tester);

    expect(find.text('Report a bug'), findsOneWidget);
    expect(find.text('Suggest something'), findsOneWidget);
    // And which build this is, so a report can quote it.
    expect(find.textContaining('build '), findsWidgets);
  });

  testWidgets('and the report takes the build with it', (tester) async {
    final controller = await pumpEditor(tester);
    await openGuide(tester);
    await tester.tap(find.text('Report a bug'));
    await tester.pumpAndSettle();

    expect(opened, hasLength(1));
    final query = opened.single.queryParameters;
    expect(query['template'], 'bug.yml');
    expect(query['version'], isNotEmpty);
    expect(query['platform'], isNotEmpty);
    // The whole point: the code in the link opens the build that broke.
    expect(PipelineShareCode.decode(query['build']!).nodes,
        hasLength(controller.pipeline.nodes.length));
    expect(find.textContaining('already in it'), findsOneWidget);
  });

  testWidgets('an idea goes to the other form', (tester) async {
    await pumpEditor(tester);
    await openGuide(tester);
    await tester.tap(find.text('Suggest something'));
    await tester.pumpAndSettle();

    expect(opened.single.queryParameters['template'], 'idea.yml');
  });

  testWidgets('a build too big for a link goes on the clipboard instead',
      (tester) async {
    // A URL that silently truncates would send a share code decoding to
    // nothing, which is worse than no code at all.
    final big = PipelineBuilder(testDatabase, name: 'A large base');
    for (var i = 0; i < 300; i++) {
      big.add('electrolyzer', nodeId: 'elec$i', x: i * 10, y: i * 10);
    }
    final clipboard = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );

    await pumpEditor(tester, pipeline: big.build());
    await openGuide(tester);
    await tester.tap(find.text('Report a bug'));
    await tester.pumpAndSettle();

    expect(opened.single.queryParameters.containsKey('build'), isFalse);
    expect(clipboard, hasLength(1));
    expect(PipelineShareCode.decode(clipboard.single).nodes, hasLength(300));
    expect(find.textContaining('on your clipboard'), findsOneWidget);
  });

  test('the link is inside what a browser will carry', () {
    final uri = reportUri(
      template: 'bug.yml',
      version: 'abc1234',
      platform: 'macOS',
      shareCode: 'x' * 1200,
    );
    expect(uri.toString().length, greaterThan(1200));
    // The budget is the whole URL rather than the code, so the cut-off sits
    // below kUrlBudget by however much the rest of the link costs.
    expect(shareCodeFits('x' * (kUrlBudget + 1)), isFalse);
    expect(shareCodeFits('x' * 200), isTrue);
  });
  test('and the builds people actually draw travel in it', () {
    // The regression this is here for: the budget was first set at 1500, and
    // every build the app ships with is longer than that — so the code never
    // once travelled in the link, which is the whole feature.
    for (final template in pipelineTemplates) {
      final code = PipelineShareCode.encode(template.build(testDatabase));
      expect(shareCodeFits(code), isTrue,
          reason: '${template.name} is ${code.length} characters');
    }
  });

}
