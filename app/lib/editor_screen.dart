import 'dart:async';
import 'package:flutter/services.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:flutter/widgets.dart';

import 'canvas/auto_layout.dart';
import 'demo/demo.dart';
import 'demo/demo_callout.dart';
import 'demo/demo_cursor.dart';
import 'demo/demos.dart';
import 'demo/demo_player.dart';
import 'demo/widget_hands.dart';
import 'canvas/graph_canvas.dart';
import 'design/keys.dart';
import 'design/tokens.dart';
import 'design/widgets.dart';
import 'panels/guide_panel.dart';
import 'panels/keys_panel.dart';
import 'panels/report_footer.dart';
import 'panels/inspector_panel.dart';

import 'panels/palette_panel.dart';
import 'panels/pipelines_menu.dart';
import 'panels/process_editor.dart';
import 'panels/changelog_panel.dart';
import 'panels/problems_panel.dart';
import 'panels/summary_bar.dart';
import 'state/display_controller.dart';
import 'state/library_controller.dart';
import 'state/news_controller.dart';
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
    this.news,
    this.apple,
    this.openLink,
    this.demoPlayer,
    this.firstVisit = false,
    this.demoHands,
    this.canvasKey,
    super.key,
  });

  final PipelineController controller;
  final LibraryController library;
  final WorkspaceController workspace;
  final DisplayController displaySettings;

  /// Where the guide's text comes from; the asset unless a test says otherwise.
  final Future<String> Function()? loadGuide;

  /// Whether there is a changelog entry nobody here has read. Null in tests
  /// that are not about it, and on a platform with nowhere to remember.
  final NewsController? news;

  /// Whether this is somebody's first time here — nothing was restored from
  /// the last session, because there was no last session.
  ///
  /// The only moment somebody does not know there is anything to be shown. It
  /// buys one offer and no more: taken or waved away, it does not come back,
  /// and the next launch has a session to restore so the question never
  /// arises again.
  final bool firstVisit;

  /// The hands a demo is being played with, when it is being played on a
  /// screen: they hold the cursor and what it is about to click.
  final WidgetHands? demoHands;

  /// The canvas's key, when somebody outside needs it — the demo's hands
  /// click port dots through it.
  final GlobalKey<GraphCanvasState>? canvasKey;

  /// The demo being played, if the app is playing one. Handed in rather than
  /// made here because it opens and deletes builds, which is the workspace's
  /// business and not a screen's.
  final DemoPlayer? demoPlayer;

  /// How a link out of the app is opened; the browser unless a test says
  /// otherwise, since a widget test has no browser to hand one to.
  final Future<bool> Function(Uri)? openLink;

  /// Which keyboard this is; the machine's unless a test says otherwise.
  ///
  /// Injected rather than read from the platform flag, for the same reason the
  /// guide's loader is: a test that wants to be at a Mac should say so in the
  /// test, and `debugDefaultTargetPlatformOverride` is global state the
  /// framework then complains was left set.
  final bool? apple;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

/// Every key the editor answers to.
///
/// Lifted out of the widget so that the guide can be checked against it: the
/// app grew sixteen shortcuts and the guide mentioned three, and copy and
/// paste — which is how you move part of a build into another one — was
/// written down nowhere at all.
Map<ShortcutActivator, Intent> editorShortcuts({required bool apple}) {
  // Held with ⌘ on a Mac and with Ctrl everywhere else. This was `meta: true`
  // outright, which on Windows and Linux is a key most keyboards do not have.
  final held = apple
      ? (LogicalKeyboardKey key, {bool shift = false}) =>
          SingleActivator(key, meta: true, shift: shift)
      : (LogicalKeyboardKey key, {bool shift = false}) =>
          SingleActivator(key, control: true, shift: shift);
  return <ShortcutActivator, Intent>{
  held(LogicalKeyboardKey.keyZ):
      const _UndoIntent(),
  held(LogicalKeyboardKey.keyZ, shift: true):
      const _RedoIntent(),
  const SingleActivator(LogicalKeyboardKey.delete): const _DeleteIntent(),
  const SingleActivator(LogicalKeyboardKey.backspace): const _DeleteIntent(),
  const SingleActivator(LogicalKeyboardKey.escape): const _DeselectIntent(),
  held(LogicalKeyboardKey.equal):
      const _ZoomInIntent(),
  held(LogicalKeyboardKey.add): const _ZoomInIntent(),
  held(LogicalKeyboardKey.minus):
      const _ZoomOutIntent(),
  held(LogicalKeyboardKey.digit0):
      const _ZoomResetIntent(),
  held(LogicalKeyboardKey.keyC): const _CopyIntent(),
  held(LogicalKeyboardKey.keyV): const _PasteIntent(),
  // One grid cell per press — the grid is 8 — and eight cells with
  // shift. Written out rather than referred to, because the map is
  // const. Dragging was the only way to move a node, and dragging
  // something four pixels is a thing hands are bad at.
  const SingleActivator(LogicalKeyboardKey.arrowLeft):
      const _NudgeIntent(Offset(-8, 0)),
  const SingleActivator(LogicalKeyboardKey.arrowRight):
      const _NudgeIntent(Offset(8, 0)),
  const SingleActivator(LogicalKeyboardKey.arrowUp):
      const _NudgeIntent(Offset(0, -8)),
  const SingleActivator(LogicalKeyboardKey.arrowDown):
      const _NudgeIntent(Offset(0, 8)),
  const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
      const _NudgeIntent(Offset(-64, 0)),
  const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
      const _NudgeIntent(Offset(64, 0)),
  const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
      const _NudgeIntent(Offset(0, -64)),
  const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
      const _NudgeIntent(Offset(0, 64)),
  };
}

/// What each of them is called, in the words the guide uses.
const Map<String, String> kShortcutNames = <String, String>{
  '⌘Z': 'undo',
  '⇧⌘Z': 'redo',
  '⌫': 'delete what is selected',
  'esc': 'select nothing',
  '⌘=': 'zoom in',
  '⌘−': 'zoom out',
  '⌘0': 'zoom back to life size',
  '⌘C': 'copy the selected nodes',
  '⌘V': 'paste them',
  'arrow keys': 'nudge by a grid cell, eight with shift',
  'space': 'drag to pan',
};

class _EditorScreenState extends State<EditorScreen> {
  late final GlobalKey<GraphCanvasState> _canvasKey =
      widget.canvasKey ?? GlobalKey<GraphCanvasState>();

  PipelineController get controller => widget.controller;

  bool get _apple => widget.apple ?? appleKeys;

  /// Kept rather than built with the rest of the actions: it remembers when
  /// the last arrow press was, so a run of them is one edit, and a fresh
  /// instance on every rebuild would forget between keystrokes.
  late final _NudgeAction _nudge = _NudgeAction(controller);

  /// Waved away, this session. There is no second session to worry about:
  /// the next launch has something to restore, so [EditorScreen.firstVisit] is
  /// false and the offer is not made again.
  bool _offerDeclined = false;

  bool get _offerDemo =>
      widget.firstVisit &&
      !_offerDeclined &&
      widget.demoPlayer != null &&
      widget.demoPlayer!.run == null &&
      kDemos.isNotEmpty;

  /// The recipe being edited, shown over the whole editor.
  ProcessSpec? _editing;
  bool _pipelinesOpen = false;
  bool _guideOpen = false;
  bool _changelogOpen = false;

  /// The keys card. Two ways in, and they behave differently on purpose: the
  /// button pins it open until dismissed, and holding ? shows it only for as
  /// long as the key is down — which is what you want mid-drag, when letting
  /// go of the mouse to close a panel is the thing you were trying to avoid.
  bool _keysPinned = false;
  bool _keysHeld = false;

  @override
  void initState() {
    super.initState();
    widget.library.addListener(_onLibraryChanged);
    widget.demoPlayer?.addListener(_demoChanged);
    widget.news?.addListener(_onNews);
  }

  @override
  void dispose() {
    widget.library.removeListener(_onLibraryChanged);
    widget.demoPlayer?.removeListener(_demoChanged);
    widget.news?.removeListener(_onNews);
    super.dispose();
  }

  /// Follow the demo: rebuild for what it is pointing at, and keep what it is
  /// building on screen.
  ///
  /// A demo puts each new node to the right of the last, and the geyser one
  /// ends up 1 152 px wide — wider than the canvas at any window this app is
  /// used at. Without this the last two things it places happen off the edge,
  /// narrated but invisible.
  ///
  /// Here rather than in the demo, which is the arrangement `demo.dart`
  /// describes: a step says what to build, and the view is somebody else's
  /// problem. Next frame, because the node it just placed is not laid out yet.
  void _demoChanged() {
    // The palette and the canvas both read what the step pointed at, and
    // neither is inside the builder the bar sits in.
    setState(() {});
    if (widget.demoPlayer?.run == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _canvasKey.currentState?.fitToContent();
      // Aim again once everything has a position. A node placed this frame
      // has none until the next, and the view is still sliding to fit it, so
      // the answer the player got a moment ago was either null or stale.
      final player = widget.demoPlayer;
      // Not while a step is in flight: the thing the step *after* it points
      // at is usually the thing this one is still making.
      if (player != null && player.run != null && !player.isStepping) {
        widget.demoHands?.aimAt(player.run!.next, player.run!.stage);
      }
    });
  }

  /// The changelog arrives after the canvas does, on purpose.
  void _onNews() {
    if (mounted) setState(() {});
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


  /// Hold **?** to see the keys, let go to put them away.
  ///
  /// Handled here rather than through `Shortcuts`, which reports a key going
  /// down and never coming up. The physical key is watched rather than the
  /// character, because ? is shift and / on most keyboards and letting go of
  /// shift first would otherwise leave the card on screen.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.slash &&
        event.logicalKey != LogicalKeyboardKey.question) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent && !_keysHeld) {
      setState(() => _keysHeld = true);
    } else if (event is KeyUpEvent && _keysHeld) {
      setState(() => _keysHeld = false);
    }
    // Every event for this key is claimed, repeats included. Holding a key
    // sends one down and then a repeat every few dozen milliseconds, and an
    // unclaimed key event goes on to the system — which on macOS answers each
    // one with a beep. Saying "handled" once and ignoring the rest sounded
    // exactly like the app was refusing the key.
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([controller, widget.displaySettings]),
        builder: (context, _) => Shortcuts(
          shortcuts: editorShortcuts(apple: _apple),
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
              onKeyEvent: _onKey,
              child: Stack(
                children: [
              DecoratedBox(
                decoration: BoxDecoration(color: OniColors.background),
                child: Column(
                  children: [
                    _TopBar(
                      apple: _apple,
                      controller: controller,
                      workspace: widget.workspace,
                      canvasKey: _canvasKey,
                      displaySettings: widget.displaySettings,
                      onTogglePipelines: () =>
                          setState(() => _pipelinesOpen = !_pipelinesOpen),
                      onOpenGuide: () => setState(() => _guideOpen = true),
                      onOpenKeys: () => setState(() => _keysPinned = true),
                    ),
                    _Tabs(workspace: widget.workspace),
                    if (_offerDemo)
                      _FirstVisitOffer(
                        demo: kDemos.first,
                        onWatch: (demo) {
                          setState(() => _offerDeclined = true);
                          unawaited(widget.demoPlayer!.start(demo));
                        },
                        onDismiss: () =>
                            setState(() => _offerDeclined = true),
                      ),
                    if (widget.news?.unread case final String release)
                      _WhatsNewNotice(
                        release: release,
                        onRead: () {
                          setState(() => _changelogOpen = true);
                          unawaited(widget.news!.markSeen());
                        },
                        onDismiss: () =>
                            unawaited(widget.news!.markSeen()),
                      ),
                    _RepairNotice(workspace: widget.workspace),
                    ProblemsBanner(controller: controller),
                    Expanded(
                      child: Row(
                        children: [
                          PalettePanel(
                            pointingAt: widget.demoHands?.litSpec,
                            rowKeys: widget.demoHands?.rowKeys,
                            search: widget.demoHands?.search,
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
                                ? _EmptyCanvas(
                                    onStartFrom: widget.workspace
                                        .createFromTemplate,
                                    onWatch: widget.demoPlayer == null
                                        ? null
                                        : (demo) => unawaited(
                                            widget.demoPlayer!.start(demo)),
                                  )
                                : GraphCanvas(
                                    key: _canvasKey,
                                    controller: controller,
                                    rateDisplay:
                                        widget.displaySettings.display,
                                    offers: widget.displaySettings.includes,
                                    onToggleRates:
                                        widget.displaySettings.toggle,
                                    pointingAt: widget.demoHands?.litPort,
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
              if (_changelogOpen)
                Positioned.fill(
                  child: ChangelogPanel(
                    onClose: () => setState(() => _changelogOpen = false),
                    // Already in hand: the controller read it to work out
                    // whether there was anything to say.
                    load: switch (widget.news?.changelog) {
                      final String text => () async => text,
                      null => null,
                    },
                  ),
                ),
              if (_guideOpen)
                Positioned.fill(
                  child: GuidePanel(
                    onClose: () => setState(() => _guideOpen = false),
                    load: widget.loadGuide,
                    footer: ReportFooter(
                      controller: controller,
                      open: widget.openLink,
                      onWatch: widget.demoPlayer == null || kDemos.isEmpty
                          ? null
                          : () {
                              setState(() => _guideOpen = false);
                              unawaited(widget.demoPlayer!.start(kDemos.first));
                            },
                      // Over the guide rather than instead of it: closing the
                      // changelog puts somebody back where they were.
                      onWhatsNew: () => setState(() => _changelogOpen = true),
                    ),
                  ),
                ),
              if (_keysPinned || _keysHeld)
                Positioned.fill(
                  child: KeysPanel(
                    apple: _apple,
                    onDismiss: _keysHeld
                        ? null
                        : () => setState(() => _keysPinned = false),
                  ),
                ),
              ?_recipeEditor(),
              // Over everything, because they point at everything.
              if (widget.demoHands case final WidgetHands hands) ...[
                Positioned.fill(child: DemoCursor(hands: hands)),
                if (widget.demoPlayer case final DemoPlayer player)
                  Positioned.fill(
                    child: DemoCallout(player: player, hands: hands),
                  ),
              ],
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

  /// Every other canvas shortcut stands down while a text field has the
  /// keyboard, and this one did not — so an arrow key moved the node instead
  /// of the caret, and the field you were typing in never saw the press.
  @override
  bool get isActionEnabled =>
      controller.selectedNodeIds.isNotEmpty && !_isEditingText();

  @override
  bool consumesKey(_NudgeIntent intent) => isActionEnabled;

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
    required this.onOpenKeys,
    required this.apple,
  });

  /// ⌘ or Ctrl, decided once by whoever built this.
  final bool apple;

  final PipelineController controller;
  final WorkspaceController workspace;
  final GlobalKey<GraphCanvasState> canvasKey;
  final DisplayController displaySettings;
  final VoidCallback onTogglePipelines;
  final VoidCallback onOpenGuide;

  /// The keys card, for anybody who would rather press a button than know to
  /// hold a key — which is everybody, the first time.
  final VoidCallback onOpenKeys;

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
    final apple = widget.apple;

    return Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: OniSpacing.lg),
        decoration: BoxDecoration(
          color: OniColors.surface,
          border: Border(bottom: BorderSide(color: OniColors.border)),
        ),
        // The bar's own width, so the status can be capped as a share of it.
        // Measured out here because a LayoutBuilder among the children would
        // be handed an unbounded width and learn nothing.
        child: LayoutBuilder(
          builder: (context, bar) => Row(
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
            // Not flexible: it takes the width of its own words and leaves
            // every remaining pixel to the actions, which are the things that
            // run out of room. Flexible or Expanded, it was given a *share* of
            // the free space — half the bar — and stood mostly empty beside a
            // scrolled-off ALL GEYSERS either way.
            //
            // Capped so that the reverse cannot happen on a narrow window: a
            // long status ellipsises rather than squeezing the buttons out.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bar.maxWidth * 0.28),
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
            // `reverse` also keeps them against the right edge when they fit.
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
              // The key is on the button, the way the inspector's delete says
              // ⌫. A shortcut nobody can find is a shortcut nobody has.
              label: 'Undo  ${chord('⌘Z', apple: apple)}',
              compact: true,
              onPressed: controller.canUndo ? controller.undo : null,
            ),
            const SizedBox(width: OniSpacing.xs),
            OniButton(
              label: 'Redo  ${chord('⇧⌘Z', apple: apple)}',
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
            const SizedBox(width: OniSpacing.xs),
            OniButton(
              // Beside the guide, because they answer the same kind of
              // question: one is how it works, the other is what to press.
              //
              // Named rather than drawn: it was ⌘, which is a key that half
              // the people who can open this have never had. And it carries
              // its own shortcut, the way Undo does — the button that opens
              // the keys should be the one the key opens.
              label: 'Keys  ?',
              compact: true,
              onPressed: widget.onOpenKeys,
            ),
            const SizedBox(width: OniSpacing.xs),
            OniButton(
              label: 'Guide',
              compact: true,
              onPressed: widget.onOpenGuide,
            ),
                ]),
              ),
            ),
          ],
          ),
        ),
      );
  }
}

/// What a blank canvas says, and what it offers.
///
/// It said what to do and gave nothing to press, while four worked builds sat
/// behind two clicks in a menu — the wrong way round for the one screen
/// somebody sees before they know the app has any.
class _EmptyCanvas extends StatelessWidget {
  const _EmptyCanvas({required this.onStartFrom, this.onWatch});

  final ValueChanged<PipelineTemplate> onStartFrom;

  /// Play a demo. Null when the app was built without a player — the tests
  /// that are about templates should not have to know demos exist.
  final ValueChanged<Demo>? onWatch;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: OniColors.background),
        child: Center(
          child: SizedBox(
            width: 340,
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
                const SizedBox(height: OniSpacing.lg),
                Text('OR START FROM ONE OF THESE', style: OniType.label),
                const SizedBox(height: OniSpacing.sm),
                Wrap(
                  spacing: OniSpacing.sm,
                  runSpacing: OniSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final template in pipelineTemplates)
                      OniButton(
                        label: template.name,
                        compact: true,
                        onPressed: () => onStartFrom(template),
                      ),
                  ],
                ),
                // Under the builds rather than above them: somebody who came
                // here to draw something should not have to walk past an
                // offer to be shown around first.
                if (onWatch case final ValueChanged<Demo> watch) ...[
                  const SizedBox(height: OniSpacing.lg),
                  Text('OR BE SHOWN', style: OniType.label),
                  const SizedBox(height: OniSpacing.sm),
                  for (final demo in kDemos)
                    Padding(
                      padding: const EdgeInsets.only(bottom: OniSpacing.sm),
                      child: OniButton(
                        label: 'Watch: ${demo.name}',
                        compact: true,
                        tone: OniButtonTone.accent,
                        onPressed: () => watch(demo),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      );
}

/// The one offer, on the one visit where nobody knows there is anything to be
/// shown.
///
/// An offer and not an interruption: nothing plays until it is asked to, and
/// waving it away is a button rather than a thing to hunt for. It sits under
/// the tabs, above the build, in the place notices already appear.
/// A line saying the app has changed since somebody was last here.
///
/// Dismissing it counts as having read it: somebody who does not care that
/// there is news should not be asked twice.
class _WhatsNewNotice extends StatelessWidget {
  const _WhatsNewNotice({
    required this.release,
    required this.onRead,
    required this.onDismiss,
  });

  final String release;
  final VoidCallback onRead;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: OniSpacing.lg, vertical: OniSpacing.sm),
        decoration: BoxDecoration(
          color: OniColors.accent.withValues(alpha: 0.1),
          border: Border(
            bottom: BorderSide(color: OniColors.accent.withValues(alpha: 0.4)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'harmONIc has changed since you were last here — $release.',
                style: OniType.body.copyWith(fontSize: 12),
              ),
            ),
            const SizedBox(width: OniSpacing.md),
            OniButton(
              label: "What's new",
              compact: true,
              tone: OniButtonTone.accent,
              onPressed: onRead,
            ),
            const SizedBox(width: OniSpacing.xs),
            OniButton(label: 'Dismiss', compact: true, onPressed: onDismiss),
          ],
        ),
      );
}

class _FirstVisitOffer extends StatelessWidget {
  const _FirstVisitOffer({
    required this.demo,
    required this.onWatch,
    required this.onDismiss,
  });

  final Demo demo;
  final ValueChanged<Demo> onWatch;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: OniSpacing.lg, vertical: OniSpacing.sm),
        decoration: BoxDecoration(
          color: OniColors.accent.withValues(alpha: 0.1),
          border: Border(
            bottom: BorderSide(color: OniColors.accent.withValues(alpha: 0.4)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'First time here? It can build one in front of you and say '
                'what it is doing — ${demo.name.toLowerCase()}, in a tab of '
                'its own.',
                style: OniType.body.copyWith(fontSize: 12),
              ),
            ),
            const SizedBox(width: OniSpacing.md),
            OniButton(
              label: 'Show me',
              compact: true,
              tone: OniButtonTone.accent,
              onPressed: () => onWatch(demo),
            ),
            const SizedBox(width: OniSpacing.xs),
            OniButton(
              label: 'No thanks',
              compact: true,
              onPressed: onDismiss,
            ),
          ],
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
