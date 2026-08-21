import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/design/tokens.dart';
import 'package:oni_pipeline/state/library_controller.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';
import 'package:oni_pipeline/storage/user_data_store.dart';

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
Future<void> useDesktopSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// A catalogue backed by memory rather than the disk.
LibraryController testLibrary([MemoryUserDataStore? store]) => LibraryController(
      bundled: testDatabase,
      store: store ?? MemoryUserDataStore(),
    );

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
Finder textLabel(String label) => find.byWidgetPredicate(
      (w) => w is Text && w.data == label,
      description: 'Text("$label")',
    );

/// Finds the first widget of type [T] whose text contains [needle].
Finder textContaining(String needle) => find.byWidgetPredicate(
      (w) => w is Text && (w.data ?? '').contains(needle),
      description: 'Text containing "$needle"',
    );
