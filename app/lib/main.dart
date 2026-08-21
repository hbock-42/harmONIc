import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:oni_engine/oni_engine.dart';

import 'design/tokens.dart';
import 'editor_screen.dart';
import 'state/pipeline_controller.dart';

void main() => runApp(OniPipelineApp(database: loadDefaultDatabase()));

/// No `MaterialApp`: the app is hosted on a bare [WidgetsApp] with forui's
/// theme layered on top, so nothing imposes a design language we did not pick.
class OniPipelineApp extends StatefulWidget {
  const OniPipelineApp({required this.database, this.initial, super.key});

  final GameDatabase database;
  final Pipeline? initial;

  @override
  State<OniPipelineApp> createState() => _OniPipelineAppState();
}

class _OniPipelineAppState extends State<OniPipelineApp> {
  late final PipelineController _controller = PipelineController(
    widget.database,
    initial: widget.initial ?? starterPipeline(widget.database),
  );

  @override
  void dispose() {
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
        home: EditorScreen(controller: _controller),
      );
}

/// A small starting graph, so the first run shows the app working rather than
/// an empty grid. Everything in it can be deleted.
Pipeline starterPipeline(GameDatabase database) {
  final builder = PipelineBuilder(database, name: 'Oxygen for the crew')
    ..addSource('water', x: 0, y: 176)
    ..add('electrolyzer', nodeId: 'elec', x: 296, y: 120)
    ..add('duplicant', nodeId: 'dupes', x: 640, y: 40)
    ..add('hydrogen_generator', nodeId: 'hgen', x: 640, y: 264)
    ..addSink('power', nodeId: 'spare', x: 952, y: 296)
    ..connectItem('src_water', 'elec', 'water')
    ..connectItem('elec', 'dupes', 'oxygen')
    ..connectItem('elec', 'hgen', 'hydrogen')
    ..connectItem('hgen', 'elec', 'power')
    ..connectItem('hgen', 'spare', 'power')
    ..pinCount('dupes', 8);
  return builder.build();
}
