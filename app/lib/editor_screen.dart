import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'canvas/graph_canvas.dart';
import 'design/tokens.dart';
import 'design/widgets.dart';
import 'panels/inspector_panel.dart';
import 'package:oni_engine/oni_engine.dart';

import 'panels/palette_panel.dart';
import 'panels/process_editor.dart';
import 'panels/problems_panel.dart';
import 'panels/summary_bar.dart';
import 'state/library_controller.dart';
import 'state/pipeline_controller.dart';

/// The whole app: palette on the left, canvas in the middle, inspector on the
/// right, totals along the bottom.
class EditorScreen extends StatefulWidget {
  const EditorScreen({
    required this.controller,
    required this.library,
    super.key,
  });

  final PipelineController controller;
  final LibraryController library;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final GlobalKey<GraphCanvasState> _canvasKey = GlobalKey<GraphCanvasState>();

  PipelineController get controller => widget.controller;

  /// The recipe being edited, shown over the whole editor.
  ProcessSpec? _editing;

  @override
  void initState() {
    super.initState();
    widget.library.addListener(_onLibraryChanged);
  }

  @override
  void dispose() {
    widget.library.removeListener(_onLibraryChanged);
    super.dispose();
  }

  void _onLibraryChanged() =>
      controller.useDatabase(widget.library.database);

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
            SingleActivator(LogicalKeyboardKey.escape): _DeselectIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _UndoIntent: _CanvasAction<_UndoIntent>(controller.undo),
              _RedoIntent: _CanvasAction<_RedoIntent>(controller.redo),
              _DeleteIntent:
                  _CanvasAction<_DeleteIntent>(controller.deleteSelection),
              _DeselectIntent:
                  _CanvasAction<_DeselectIntent>(() => controller.select(null)),
            },
            child: Focus(
              autofocus: true,
              child: Stack(
                children: [
              DecoratedBox(
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
                            onNewRecipe: () => setState(
                                () => _editing = widget.library.draft()),
                            onEditRecipe: (spec) => setState(() =>
                                _editing = widget.library.editable(spec)),
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
              ?_recipeEditor(),
                ],
              ),
            ),
          ),
        ),
      );

  Widget? _recipeEditor() {
    final spec = _editing;
    if (spec == null) return null;
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _editing = null),
        child: ColoredBox(
          color: const Color(0xB3000000),
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: ProcessEditor(
                library: widget.library,
                spec: spec,
                onClose: () => setState(() => _editing = null),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// True when the keyboard belongs to a text field rather than the canvas.
bool _isEditingText() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  if (context.widget is EditableText) return true;
  return context.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// A canvas shortcut that stands down while you are typing.
///
/// Without this, the editor's ⌫ ("delete the selected node") swallows every
/// backspace before the search box or the pin field ever sees it — reporting
/// the key as handled stops the platform delivering it to the text input at
/// all. Disabling the action makes the shortcut resolve to "ignored", so the
/// event carries on up to Flutter's own text-editing shortcuts. The same goes
/// for ⌘Z, which a text field should undo for itself.
class _CanvasAction<T extends Intent> extends Action<T> {
  _CanvasAction(this.onInvoke);

  final VoidCallback onInvoke;

  @override
  bool get isActionEnabled => !_isEditingText();

  @override
  bool consumesKey(T intent) => !_isEditingText();

  @override
  Object? invoke(T intent) {
    onInvoke();
    return null;
  }
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

class _DeselectIntent extends Intent {
  const _DeselectIntent();
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
