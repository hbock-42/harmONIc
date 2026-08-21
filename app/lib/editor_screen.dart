import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'canvas/graph_canvas.dart';
import 'design/tokens.dart';
import 'design/widgets.dart';
import 'panels/inspector_panel.dart';
import 'panels/palette_panel.dart';
import 'panels/problems_panel.dart';
import 'panels/summary_bar.dart';
import 'state/pipeline_controller.dart';

/// The whole app: palette on the left, canvas in the middle, inspector on the
/// right, totals along the bottom.
class EditorScreen extends StatefulWidget {
  const EditorScreen({required this.controller, super.key});

  final PipelineController controller;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final GlobalKey<GraphCanvasState> _canvasKey = GlobalKey<GraphCanvasState>();

  PipelineController get controller => widget.controller;

  void _add(String specId) {
    final centre = _canvasKey.currentState?.viewportCentreWorld ??
        const Offset(200, 200);
    controller.addNode(specId, centre);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
                _UndoIntent(),
            SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
                _RedoIntent(),
            SingleActivator(LogicalKeyboardKey.delete): _DeleteIntent(),
            SingleActivator(LogicalKeyboardKey.backspace): _DeleteIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _UndoIntent: CallbackAction<_UndoIntent>(
                  onInvoke: (_) => controller.undo()),
              _RedoIntent: CallbackAction<_RedoIntent>(
                  onInvoke: (_) => controller.redo()),
              _DeleteIntent: CallbackAction<_DeleteIntent>(
                  onInvoke: (_) => controller.deleteSelection()),
            },
            child: Focus(
              autofocus: true,
              child: DecoratedBox(
                decoration: const BoxDecoration(color: OniColors.background),
                child: Column(
                  children: [
                    _TopBar(controller: controller, canvasKey: _canvasKey),
                    ProblemsBanner(controller: controller),
                    Expanded(
                      child: Row(
                        children: [
                          PalettePanel(
                            database: controller.database,
                            onAdd: _add,
                          ),
                          Expanded(
                            child: controller.pipeline.nodes.isEmpty
                                ? const _EmptyCanvas()
                                : GraphCanvas(
                                    key: _canvasKey,
                                    controller: controller,
                                  ),
                          ),
                          InspectorPanel(controller: controller),
                        ],
                      ),
                    ),
                    SummaryBar(
                      solution: controller.solution,
                      database: controller.database,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _UndoIntent extends Intent {
  const _UndoIntent();
}

class _RedoIntent extends Intent {
  const _RedoIntent();
}

class _DeleteIntent extends Intent {
  const _DeleteIntent();
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.controller, required this.canvasKey});

  final PipelineController controller;
  final GlobalKey<GraphCanvasState> canvasKey;

  @override
  Widget build(BuildContext context) => Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: OniSpacing.lg),
        decoration: const BoxDecoration(
          color: OniColors.surface,
          border: Border(bottom: BorderSide(color: OniColors.border)),
        ),
        child: Row(
          children: [
            Text(controller.pipeline.name, style: OniType.heading),
            const SizedBox(width: OniSpacing.lg),
            Text(
              '${controller.pipeline.nodes.length} nodes · '
              '${controller.pipeline.edges.length} links · '
              '${controller.solution.status.name}',
              style: OniType.numberSmall,
            ),
            const Spacer(),
            OniButton(
              label: 'Undo',
              compact: true,
              onPressed: controller.canUndo ? controller.undo : null,
            ),
            const SizedBox(width: OniSpacing.sm),
            OniButton(
              label: 'Redo',
              compact: true,
              onPressed: controller.canRedo ? controller.redo : null,
            ),
            const SizedBox(width: OniSpacing.sm),
            OniButton(
              label: 'Fit',
              compact: true,
              onPressed: () => canvasKey.currentState?.fitToContent(),
            ),
          ],
        ),
      );
}

class _EmptyCanvas extends StatelessWidget {
  const _EmptyCanvas();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(color: OniColors.background),
        child: Center(
          child: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Nothing here yet', style: OniType.heading),
                const SizedBox(height: OniSpacing.sm),
                Text(
                  'Pick something from the list on the left to place it, then '
                  'drag from a port dot to wire it up. Select any node and say '
                  'how many you have — the rest follows.',
                  textAlign: TextAlign.center,
                  style: OniType.body.copyWith(color: OniColors.textFaint),
                ),
              ],
            ),
          ),
        ),
      );
}
