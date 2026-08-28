import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/design/tokens.dart';
import 'package:oni_pipeline/state/display_controller.dart';
import 'package:oni_pipeline/state/library_controller.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';
import 'package:oni_pipeline/state/workspace_controller.dart';
import 'package:oni_pipeline/storage/json_store.dart';

/// The database is immutable and parsing it is not free — share one.
final GameDatabase testDatabase = loadDefaultDatabase();

/// Wraps a widget in exactly what the real app provides: forui's theme, a text
/// direction and a default text style. No Material anywhere.
Widget harness(Widget child) => WidgetsApp(
      color: OniColors.accent,
      localizationsDelegates: FLocalizations.localizationsDelegates,
      supportedLocales: FLocalizations.supportedLocales,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
          PageRouteBuilder<T>(
        settings: settings,
        pageBuilder: (context, _, _) => builder(context),
      ),
      builder: (context, child) => FTheme(
        data: FTheme.neutral.dark.desktop,
        child: DefaultTextStyle(style: OniType.body, child: child!),
      ),
      home: child,
    );

/// A desktop-sized surface, since the editor is a three-column layout that does
/// not fit the 800×600 test default.
Future<void> useDesktopSurface(WidgetTester tester, {Size? size}) async {
  // Tall enough for the whole of the inspector, which is a long panel and a
  // lazy list: a widget below the fold is not built, so a test looking for one
  // finds nothing and reads as a missing feature rather than a short window.
  // Adding a single line to that panel used to break eight tests that had
  // nothing to do with it.
  //
  // A test about the *viewport* -- what is off screen, what has to be scrolled
  // to -- says its own size, because for those the window is the subject.
  await tester.binding.setSurfaceSize(size ?? const Size(1440, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// A catalogue backed by memory rather than the disk.
LibraryController testLibrary([MemoryJsonStore? store]) => LibraryController(
      bundled: testDatabase,
      store: store ?? MemoryJsonStore(),
    );

/// Display settings backed by memory rather than the disk.
DisplayController testDisplay([MemoryJsonStore? store]) =>
    DisplayController(store ?? MemoryJsonStore());

/// A workspace wired to memory, already holding [controller]'s pipeline.
Future<WorkspaceController> testWorkspace(
  PipelineController controller, [
  MemoryJsonStore? store,
]) async {
  final workspace = WorkspaceController(
    store: store ?? MemoryJsonStore(),
    controller: controller,
    debounce: Duration.zero,
  );
  await workspace.load();
  await workspace.adopt(controller.pipeline);
  // Autosave leaves a debounce timer behind; a widget test fails if one is
  // still pending when it ends.
  addTearDown(workspace.dispose);
  return workspace;
}

/// water → electrolyzer → dupes, with the hydrogen vented. Small enough to
/// assert on, big enough to exercise pulling.
PipelineController testController({Pipeline? pipeline}) => PipelineController(
      testDatabase,
      initial: pipeline ?? testPipeline(),
    );

Pipeline testPipeline() => (PipelineBuilder(testDatabase, name: 'Test build')
      ..addSource('water', x: 0, y: 100)
      ..add('electrolyzer', nodeId: 'elec', x: 300, y: 100)
      ..add('duplicant', nodeId: 'dupes', x: 620, y: 60)
      ..addSink('hydrogen', nodeId: 'h2out', x: 620, y: 260)
      ..connectItem('src_water', 'elec', 'water')
      ..connectItem('elec', 'dupes', 'oxygen')
      ..connectItem('elec', 'h2out', 'hydrogen')
      ..pinCount('dupes', 10))
    .build();

/// Matches a real [Text] with exactly this content — unlike `find.text`, which
/// also matches the [EditableText] inside a search box showing the same string.
/// What a [Text] reads, whether it was given a string or a run of spans.
///
/// A figure set in two weights — the number loud, its unit quiet — is one
/// string to everybody except a finder that only looks at [Text.data].
String _reads(Text text) => text.data ?? text.textSpan?.toPlainText() ?? '';

Finder textLabel(String label) => find.byWidgetPredicate(
      (w) => w is Text && _reads(w) == label,
      description: 'Text("$label")',
    );

/// Finds the first widget of type [T] whose text contains [needle].
Finder textContaining(String needle) => find.byWidgetPredicate(
      (w) => w is Text && _reads(w).contains(needle),
      description: 'Text containing "$needle"',
    );
