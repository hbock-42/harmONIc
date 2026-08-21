import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:oni_engine/oni_engine.dart';

import 'canvas/auto_layout.dart';
import 'design/tokens.dart';
import 'editor_screen.dart';
import 'state/display_controller.dart';
import 'state/library_controller.dart';
import 'state/pipeline_controller.dart';
import 'state/workspace_controller.dart';
import 'storage/json_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final library = LibraryController(
    bundled: loadDefaultDatabase(),
    store: const FileJsonStore('user_processes.json'),
  );
  // Recipes the player has written down are part of the catalogue from the
  // first frame, so nothing on screen ever shows the stale numbers.
  await library.load();
  final display = DisplayController(const FileJsonStore('settings.json'));
  await display.load();
  runApp(OniPipelineApp(
    library: library,
    pipelineStore: const FileJsonStore('pipelines.json'),
    displaySettings: display,
  ));
}

/// No `MaterialApp`: the app is hosted on a bare [WidgetsApp] with forui's
/// theme layered on top, so nothing imposes a design language we did not pick.
class OniPipelineApp extends StatefulWidget {
  const OniPipelineApp({
    required this.library,
    required this.pipelineStore,
    this.displaySettings,
    this.initial,
    super.key,
  });

  final LibraryController library;
  final JsonStore pipelineStore;
  final DisplayController? displaySettings;
  final Pipeline? initial;

  @override
  State<OniPipelineApp> createState() => _OniPipelineAppState();
}

class _OniPipelineAppState extends State<OniPipelineApp> {
  late final PipelineController _controller = PipelineController(
    widget.library.database,
    initial: widget.initial ?? starterPipeline(widget.library.database),
  );
  late final WorkspaceController _workspace = WorkspaceController(
    store: widget.pipelineStore,
    controller: _controller,
  );
  late final DisplayController _display =
      widget.displaySettings ?? DisplayController(MemoryJsonStore());
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    unawaited(_restore());
  }

  /// Reopen whatever was on screen last time. If this is a first run there is
  /// nothing to reopen, so the starter build becomes the first saved pipeline
  /// rather than something that vanishes when the window closes.
  Future<void> _restore() async {
    final restored = await _workspace.load();
    if (!restored) {
      await _workspace.adopt(_controller.pipeline);
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _workspace.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WidgetsApp(
        title: 'ONI Pipeline Planner',
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
          child: DefaultTextStyle(
            style: OniType.body,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: _ready
            ? EditorScreen(
                controller: _controller,
                library: widget.library,
                workspace: _workspace,
                displaySettings: _display,
              )
            : const ColoredBox(color: OniColors.background),
      );
}

/// A small starting graph, so the first run shows the app working rather than
/// an empty grid. Everything in it can be deleted.
///
/// It is the SPOM template, laid out the way the canvas would lay it out, so
/// the first thing anybody sees is also something they can make again from the
/// pipelines menu rather than a one-off nobody can find twice.
Pipeline starterPipeline(GameDatabase database) {
  final template =
      pipelineTemplates.firstWhere((t) => t.id == 'spom');
  final built = template.build(database);
  final placed =
      AutoLayout(pipeline: built, database: database).positions();
  return Pipeline(
    id: built.id,
    name: built.name,
    dataVersion: database.dataVersion,
    nodes: [
      for (final node in built.nodes)
        if (placed[node.id] case final Offset at)
          node.copyWith(x: at.dx, y: at.dy)
        else
          node,
    ],
    edges: built.edges,
    pins: built.pins,
  );
}
