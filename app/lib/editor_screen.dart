import 'package:flutter/services.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:flutter/widgets.dart';

import 'canvas/auto_layout.dart';
import 'canvas/graph_canvas.dart';
import 'design/tokens.dart';
import 'design/widgets.dart';
import 'panels/guide_panel.dart';
import 'panels/inspector_panel.dart';

import 'panels/palette_panel.dart';
import 'panels/pipelines_menu.dart';
import 'panels/process_editor.dart';
import 'panels/problems_panel.dart';
import 'panels/summary_bar.dart';
import 'state/display_controller.dart';
import 'state/library_controller.dart';
import 'state/pipeline_controller.dart';
import 'state/workspace_controller.dart';

/// The whole app: palette on the left, canvas in the middle, inspector on the
/// right, totals along the bottom.
class EditorScreen extends StatefulWidget {
  const EditorScreen({
    required this.controller,
    required this.library,
    required this.workspace,
    required this.displaySettings,
    this.loadGuide,
    super.key,
  });

  final PipelineController controller;
  final LibraryController library;
  final WorkspaceController workspace;
  final DisplayController displaySettings;

  /// Where the guide's text comes from; the asset unless a test says otherwise.
  final Future<String> Function()? loadGuide;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final GlobalKey<GraphCanvasState> _canvasKey = GlobalKey<GraphCanvasState>();

  PipelineController get controller => widget.controller;

  /// Kept rather than built with the rest of the actions: it remembers when
  /// the last arrow press was, so a run of them is one edit, and a fresh
  /// instance on every rebuild would forget between keystrokes.
  late final _NudgeAction _nudge = _NudgeAction(controller);

  /// The recipe being edited, shown over the whole editor.
  ProcessSpec? _editing;
  bool _pipelinesOpen = false;
  bool _guideOpen = false;

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

  /// Copies the selected nodes to the clipboard, so they can be pasted into
  /// another build — the clipboard being the one place both builds can reach.
  Future<void> _copySelection() async {
    final selection = controller.copySelection();
    if (selection == null) return;
    await Clipboard.setData(
      ClipboardData(text: PipelineShareCode.encode(selection)),
    );
  }

  Future<void> _pasteNodes() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) return;
    try {
      controller.pasteNodes(PipelineShareCode.decode(text));
    } on Object {
      // A clipboard holding something else is not an error worth interrupting
      // for; ⌘V over a canvas is a reasonable thing to try by accident.
      return;
    }
  }

  void _add(String specId) {
    final centre = _canvasKey.currentState?.viewportCentreWorld ??
        const Offset(200, 200);
    controller.addNode(specId, centre);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([controller, widget.displaySettings]),
        builder: (context, _) => Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
                _UndoIntent(),
            SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
                _RedoIntent(),
            SingleActivator(LogicalKeyboardKey.delete): _DeleteIntent(),
            SingleActivator(LogicalKeyboardKey.backspace): _DeleteIntent(),
            SingleActivator(LogicalKeyboardKey.escape): _DeselectIntent(),
            SingleActivator(LogicalKeyboardKey.equal, meta: true):
                _ZoomInIntent(),
            SingleActivator(LogicalKeyboardKey.add, meta: true): _ZoomInIntent(),
            SingleActivator(LogicalKeyboardKey.minus, meta: true):
                _ZoomOutIntent(),
            SingleActivator(LogicalKeyboardKey.digit0, meta: true):
                _ZoomResetIntent(),
            SingleActivator(LogicalKeyboardKey.keyC, meta: true): _CopyIntent(),
            SingleActivator(LogicalKeyboardKey.keyV, meta: true): _PasteIntent(),
            // One grid cell per press — the grid is 8 — and eight cells with
            // shift. Written out rather than referred to, because the map is
            // const. Dragging was the only way to move a node, and dragging
            // something four pixels is a thing hands are bad at.
            SingleActivator(LogicalKeyboardKey.arrowLeft):
                _NudgeIntent(Offset(-8, 0)),
            SingleActivator(LogicalKeyboardKey.arrowRight):
                _NudgeIntent(Offset(8, 0)),
            SingleActivator(LogicalKeyboardKey.arrowUp):
                _NudgeIntent(Offset(0, -8)),
            SingleActivator(LogicalKeyboardKey.arrowDown):
                _NudgeIntent(Offset(0, 8)),
            SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
                _NudgeIntent(Offset(-64, 0)),
            SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
                _NudgeIntent(Offset(64, 0)),
            SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
                _NudgeIntent(Offset(0, -64)),
            SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
                _NudgeIntent(Offset(0, 64)),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _UndoIntent: _CanvasAction<_UndoIntent>(controller.undo),
              _RedoIntent: _CanvasAction<_RedoIntent>(controller.redo),
              _DeleteIntent:
                  _CanvasAction<_DeleteIntent>(controller.deleteSelection),
              _DeselectIntent:
                  _CanvasAction<_DeselectIntent>(() => controller.select(null)),
              _ZoomInIntent: _CanvasAction<_ZoomInIntent>(
                  () => _canvasKey.currentState?.zoomAtCentre(1.25)),
              _ZoomOutIntent: _CanvasAction<_ZoomOutIntent>(
                  () => _canvasKey.currentState?.zoomAtCentre(1 / 1.25)),
              _ZoomResetIntent: _CanvasAction<_ZoomResetIntent>(
                  () => _canvasKey.currentState?.resetView()),
              _CopyIntent: _CanvasAction<_CopyIntent>(_copySelection),
              _PasteIntent: _CanvasAction<_PasteIntent>(_pasteNodes),
              _NudgeIntent: _nudge,
            },
            child: Focus(
              autofocus: true,
              child: Stack(
                children: [
              DecoratedBox(
                decoration: BoxDecoration(color: OniColors.background),
                child: Column(
                  children: [
                    _TopBar(
                      controller: controller,
                      workspace: widget.workspace,
                      canvasKey: _canvasKey,
                      displaySettings: widget.displaySettings,
                      onTogglePipelines: () =>
                          setState(() => _pipelinesOpen = !_pipelinesOpen),
                      onOpenGuide: () => setState(() => _guideOpen = true),
                    ),
                    _Tabs(workspace: widget.workspace),
                    _RepairNotice(workspace: widget.workspace),
                    ProblemsBanner(controller: controller),
                    Expanded(
                      child: Row(
                        children: [
                          PalettePanel(
                            database: controller.database,
                            display: widget.displaySettings,
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
                                    rateDisplay:
                                        widget.displaySettings.display,
                                    offers: widget.displaySettings.includes,
                                    onToggleRates:
                                        widget.displaySettings.toggle,
                                  ),
                          ),
                          InspectorPanel(
                            controller: controller,
                            rateDisplay: widget.displaySettings.display,
                            onToggleRates: widget.displaySettings.toggle,
                          ),
                        ],
                      ),
                    ),
                    SummaryBar(
                      // The build being worked in, when there is more than one
                      // on the page: adding two builds' power together gives a
                      // figure that describes neither.
                      solution: controller.focusedSolution,
                      scope: controller.focusedBuild == null
                          ? (controller.builds.length > 1
                              ? 'whole canvas'
                              : 'this build')
                          : 'this build',
                      database: controller.database,
                      rateDisplay: widget.displaySettings.display,
                      onToggleRates: widget.displaySettings.toggle,
                      // Only where something in the build is divided: with
                      // nothing to choose, the offer would be to do nothing.
                      onMinimise: controller.hasASplitToChoose
                          ? controller.optimiseTotal
                          : null,
                      asBuilt: controller.asBuiltReport,
                    ),
                  ],
                ),
              ),
              ?_pipelinesMenu(),
              if (_guideOpen)
                Positioned.fill(
                  child: GuidePanel(
                    onClose: () => setState(() => _guideOpen = false),
                    load: widget.loadGuide,
                  ),
                ),
              ?_recipeEditor(),
                ],
              ),
            ),
          ),
        ),
      );

  Widget? _pipelinesMenu() {
    if (!_pipelinesOpen) return null;
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _pipelinesOpen = false),
        child: ColoredBox(
          color: const Color(0x33000000),
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: OniSpacing.lg, top: 48),
              child: GestureDetector(
                onTap: () {},
                child: ListenableBuilder(
                  listenable: widget.workspace,
                  builder: (context, _) => PipelinesMenu(
                    workspace: widget.workspace,
                    controller: widget.controller,
                    library: widget.library,
                    rateDisplay: widget.displaySettings.display,
                    onClose: () => setState(() => _pipelinesOpen = false),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

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
                offersItem: widget.displaySettings.includesItem,
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

/// Says what had to change to open a build drawn against older recipes.
///
/// Shown once and dismissed, rather than living in the problems banner: it is
/// history, not something still wrong.
class _RepairNotice extends StatelessWidget {
  const _RepairNotice({required this.workspace});

  final WorkspaceController workspace;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: workspace,
        builder: (context, _) {
          final notes = workspace.repairNotes;
          if (notes.isEmpty) return const SizedBox.shrink();
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: OniSpacing.lg, vertical: OniSpacing.sm),
            decoration: BoxDecoration(
              color: OniColors.accent.withValues(alpha: 0.1),
              border: Border(
                bottom:
                    BorderSide(color: OniColors.accent.withValues(alpha: 0.4)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Some recipes changed since this was drawn:',
                        style: OniType.body.copyWith(fontSize: 12),
                      ),
                      for (final note in notes.take(4))
                        Text(note,
                            style: OniType.numberSmall
                                .copyWith(color: OniColors.text)),
                      if (notes.length > 4)
                        Text('and ${notes.length - 4} more',
                            style: OniType.numberSmall),
                    ],
                  ),
                ),
                OniButton(
                  label: 'Dismiss',
                  compact: true,
                  onPressed: workspace.dismissRepairNotes,
                ),
              ],
            ),
          );
        },
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

class _DeselectIntent extends Intent {
  const _DeselectIntent();
}

class _ZoomInIntent extends Intent {
  const _ZoomInIntent();
}

class _ZoomOutIntent extends Intent {
  const _ZoomOutIntent();
}

class _ZoomResetIntent extends Intent {
  const _ZoomResetIntent();
}

class _CopyIntent extends Intent {
  const _CopyIntent();
}

class _PasteIntent extends Intent {
  const _PasteIntent();
}

/// The builds you have open, as a row of tabs.
///
/// Switching used to mean opening the menu, finding the name and clicking it —
/// three moves for the thing you do most while comparing two builds. The menu
/// is still where everything you have ever drawn lives; this is the handful in
/// front of you.
///
/// It hides itself when there is only one, since a single tab is a label for
/// something already on screen.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.workspace});

  final WorkspaceController workspace;

  @override
  Widget build(BuildContext context) {
    final tabs = workspace.openTabs;
    if (tabs.length < 2) return const SizedBox.shrink();

    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: OniColors.surface,
        border: Border(bottom: BorderSide(color: OniColors.border)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, i) => _Tab(
          summary: tabs[i],
          current: tabs[i].id == workspace.currentId,
          onOpen: () => workspace.open(tabs[i].id),
          onClose: () => workspace.closeTab(tabs[i].id),
        ),
      ),
    );
  }
}

class _Tab extends StatefulWidget {
  const _Tab({
    required this.summary,
    required this.current,
    required this.onOpen,
    required this.onClose,
  });

  final PipelineSummary summary;
  final bool current;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onOpen,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: OniSpacing.md),
            decoration: BoxDecoration(
              color: widget.current
                  ? OniColors.surfaceRaised
                  : (_hover ? OniColors.surfaceHover : null),
              border: Border(
                right: BorderSide(color: OniColors.border),
                bottom: BorderSide(
                  width: 2,
                  color: widget.current
                      ? OniColors.accent
                      : const Color(0x00000000),
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  widget.summary.name,
                  style: OniType.body.copyWith(
                    fontSize: 12,
                    color: widget.current
                        ? OniColors.text
                        : OniColors.textMuted,
                  ),
                ),
                // The close cross appears on the tab you are pointing at or
                // working in, so a row of tabs is a row of names rather than a
                // row of names and crosses.
                if (_hover || widget.current) ...[
                  const SizedBox(width: OniSpacing.sm),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onClose,
                    child: Text('×',
                        style: OniType.body
                            .copyWith(color: OniColors.textMuted)),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

class _NudgeIntent extends Intent {
  const _NudgeIntent(this.by);

  final Offset by;
}

/// Moves the selection with the arrow keys.
///
/// Its own action rather than a [_CanvasAction] because it carries a direction,
/// and its own undo rule: a run of presses is one edit. Twelve arrow presses
/// that take twelve ⌘Z to undo is a worse editor than one that cannot nudge at
/// all.
class _NudgeAction extends Action<_NudgeIntent> {
  _NudgeAction(this.controller);

  final PipelineController controller;

  @override
  bool get isActionEnabled => controller.selectedNodeIds.isNotEmpty;

  @override
  bool consumesKey(_NudgeIntent intent) =>
      controller.selectedNodeIds.isNotEmpty;

  /// When the last press was, so a run of them collapses into one edit.
  ///
  /// Holding an arrow key for a second should be one thing to undo, the way
  /// typing a word is. A second of quiet ends the run, which is roughly how
  /// long it takes to decide the node is in the wrong place after all.
  final Stopwatch _since = Stopwatch();

  @override
  void invoke(_NudgeIntent intent) {
    if (controller.selectedNodeIds.isEmpty) return;
    final fresh = !_since.isRunning || _since.elapsedMilliseconds > 1000;
    if (fresh) controller.beginNodeDrag();
    _since
      ..reset()
      ..start();
    controller.moveSelectionBy(intent.by);
  }
}

class _TopBar extends StatefulWidget {
  const _TopBar({
    required this.controller,
    required this.workspace,
    required this.canvasKey,
    required this.displaySettings,
    required this.onTogglePipelines,
    required this.onOpenGuide,
  });

  final PipelineController controller;
  final WorkspaceController workspace;
  final GlobalKey<GraphCanvasState> canvasKey;
  final DisplayController displaySettings;
  final VoidCallback onTogglePipelines;
  final VoidCallback onOpenGuide;

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  late final TextEditingController _name =
      TextEditingController(text: widget.controller.pipeline.name);
  String _lastKnownName = '';

  PipelineController get controller => widget.controller;
  GlobalKey<GraphCanvasState> get canvasKey => widget.canvasKey;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Opening another pipeline changes the name underneath us.
    final current = controller.pipeline.name;
    if (current != _lastKnownName && current != _name.text) {
      _name.text = current;
    }
    _lastKnownName = current;

    return Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: OniSpacing.lg),
        decoration: BoxDecoration(
          color: OniColors.surface,
          border: Border(bottom: BorderSide(color: OniColors.border)),
        ),
        child: Row(
          children: [
            OniButton(
              label: 'Pipelines',
              compact: true,
              onPressed: widget.onTogglePipelines,
            ),
            const SizedBox(width: OniSpacing.md),
            SizedBox(
              width: 220,
              child: OniField(
                controller: _name,
                hint: 'Untitled',
                onChanged: controller.rename,
              ),
            ),
            const SizedBox(width: OniSpacing.lg),
            Flexible(
              child: Text(
                '${controller.pipeline.nodes.length} nodes · '
                '${controller.pipeline.edges.length} links · '
                '${controller.solution.status.name} · saved',
                style: OniType.numberSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: OniSpacing.md),
            // The actions scroll rather than overflow, so a narrow window
            // loses nothing — it just needs a nudge sideways to reach Fit.
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(children: [
            if (controller.pipeline.nodes.any(controller.isGeyser)) ...[
              Text('ALL GEYSERS', style: OniType.label),
              const SizedBox(width: OniSpacing.sm),
              for (final entry in GeyserActivity.presets.entries)
                Padding(
                  padding: const EdgeInsets.only(right: OniSpacing.xs),
                  child: OniButton(
                    label: '${(entry.value * 100).toStringAsFixed(0)}%',
                    compact: true,
                    onPressed: () =>
                        controller.setAllGeyserActivity(entry.value),
                  ),
                ),
              const SizedBox(width: OniSpacing.md),
            ],
            // Grouped by what they touch, because a row of evenly spaced
            // buttons says they are all the same kind of thing and these are
            // three kinds: the past, the arrangement, and the units.
            OniButton(
              label: 'Undo',
              compact: true,
              onPressed: controller.canUndo ? controller.undo : null,
            ),
            const SizedBox(width: OniSpacing.xs),
            OniButton(
              label: 'Redo',
              compact: true,
              onPressed: controller.canRedo ? controller.redo : null,
            ),
            // Only while there is something to draw. A permanent button for a
            // thing a finished build never needs is a permanent cost to every
            // other button's room, and this toolbar has run out of it once
            // already.
            if (controller.openPorts.isNotEmpty) ...[
              const _ToolbarDivider(),
              OniButton(
                // Says how many: the number is the reason to press it.
                label: 'Draw ${controller.openPorts.length} supplies',
                compact: true,
                onPressed: controller.closeOpenPorts,
              ),
            ],
            const _ToolbarDivider(),
            OniButton(
              label: 'Tidy',
              compact: true,
              onPressed: controller.pipeline.nodes.isEmpty
                  ? null
                  : () {
                      // With a selection, tidy just that: part of a build
                      // arranged by hand should survive tidying the rest.
                      final selection = controller.selectedNodeIds;
                      controller.applyLayout(
                        AutoLayout(
                          pipeline: controller.pipeline,
                          database: controller.database,
                          only: selection.length > 1 ? selection : const {},
                        ).positions(),
                      );
                      canvasKey.currentState?.fitToContent(
                        only: selection.length > 1 ? selection : const {},
                      );
                    },
            ),
            const SizedBox(width: OniSpacing.xs),
            OniButton(
              label: 'Fit',
              compact: true,
              onPressed: () => canvasKey.currentState?.fitToContent(
                    only: controller.selectedNodeIds.length > 1
                        ? controller.selectedNodeIds
                        : const {},
                  ),
            ),
            const _ToolbarDivider(),
            OniButton(
              label: widget.displaySettings.currentLabel,
              compact: true,
              tone: OniButtonTone.accent,
              onPressed: widget.displaySettings.toggle,
            ),
            const _ToolbarDivider(),
            OniButton(
              // The moon is what pressing it takes you *to*, the way the rate
              // button names the unit it switches into rather than the one you
              // are already reading.
              label: widget.displaySettings.isLight ? '☾' : '☀',
              compact: true,
              onPressed: () => widget.displaySettings
                  .setLight(light: !widget.displaySettings.isLight),
            ),
            OniButton(
              label: '?',
              compact: true,
              onPressed: widget.onOpenGuide,
            ),
                ]),
              ),
            ),
          ],
        ),
      );
  }
}

class _EmptyCanvas extends StatelessWidget {
  const _EmptyCanvas();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: OniColors.background),
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

/// The gap between two groups of toolbar buttons: wider than the gap inside a
/// group, with a rule down the middle, so the grouping is stated rather than
/// implied by a few pixels.
class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 16,
        margin: const EdgeInsets.symmetric(horizontal: OniSpacing.md),
        color: OniColors.border,
      );
}
