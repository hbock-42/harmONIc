import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import '../canvas/graph_canvas.dart';
import '../state/pipeline_controller.dart';
import 'demo.dart';

/// How long the cursor takes to reach the thing it is going to click, and how
/// long it rests there afterwards so the click is seen to land.
const Duration kCursorTravel = Duration(milliseconds: 700);
const Duration kCursorDwell = Duration(milliseconds: 450);

/// Hands that use the app the way a person would.
///
/// The straight [ModelHands] call the controller, which is why a demo used to
/// look like a build assembling itself: nothing was ever clicked, so there was
/// nothing to watch. These aim at the thing first — so the words and the
/// cursor arrive before anything moves — then click it, let the real port menu
/// open, and choose a row out of it.
class WidgetHands extends ChangeNotifier implements DemoHands {
  WidgetHands({
    required this.canvas,
    required this.rowKeys,
    required this.search,
    this.travel = kCursorTravel,
    this.dwell = kCursorDwell,
  });

  final GlobalKey<GraphCanvasState> canvas;

  /// Where each palette row is, filled in by the palette as it builds.
  final Map<String, GlobalKey> rowKeys;

  /// The palette's search box. A demo types into it for the same reason
  /// anybody does: the list is a hundred recipes long and the row it wants is
  /// below the fold, where a cursor cannot point at it.
  final TextEditingController search;

  final Duration travel;
  final Duration dwell;

  Offset? _cursor;
  Offset? _aim;
  bool _pressed = false;
  String? _litSpec;
  PortRef? _litPort;

  /// Where the cursor is, in global coordinates.
  Offset? get cursor => _cursor;

  /// Where the next thing to be clicked is, so the words can sit beside it.
  /// Null for a step with nothing to point at, which puts them in the middle.
  Offset? get aim => _aim;

  /// Whether the cursor is mid-click, for the ring that says so.
  bool get pressed => _pressed;

  /// The palette row and the port dot to light: what is about to be clicked.
  String? get litSpec => _litSpec;
  PortRef? get litPort => _litPort;

  /// Point at what the next step will touch, and get the screen ready for it.
  ///
  /// Called before the step rather than during it: the words go beside the
  /// thing, and somebody reading them should be looking at the right part of
  /// the screen before they press Next.
  void aimAt(DemoAction? action, DemoStage stage) {
    try {
      _aimAt(action, stage);
    } on StateError {
      // Pointing at something a later step has not made yet. Nowhere to aim,
      // which is a fact rather than a failure — and never a reason to take
      // the frame down with it.
      _aim = null;
      _litSpec = null;
      _litPort = null;
    }
  }

  void _aimAt(DemoAction? action, DemoStage stage) {
    final wasAim = _aim;
    final wasSpec = _litSpec;
    final wasPort = _litPort;
    _litSpec = null;
    _litPort = null;
    switch (action) {
      case null:
      case SaySoFar():
        _aim = null;
      case PlaceFromPalette(:final specId):
        // Searching is part of the aim: the row has to be on screen before
        // there is anywhere to point.
        search.text =
            stage.controller.database.process(specId)?.name ?? specId;
        _litSpec = specId;
        _aim = null;
      case ClickPortAndPick(:final node, :final portId):
        _litPort = stage.portOf(node, portId);
        _aim = canvas.currentState?.globalPointOf(_litPort!);
      case ConnectPorts(:final fromNode, :final fromPortId):
        _litPort = stage.portOf(fromNode, fromPortId);
        _aim = canvas.currentState?.globalPointOf(_litPort!);
      case LetTheProducerDecide(:final node, :final portId):
        _litPort = stage.portOf(node, portId);
        _aim = canvas.currentState?.globalPointOf(_litPort!);
      case PinAmount(:final node):
      case AskForTheBest(:final node):
        _aim = _centreOfNode(stage.nodeId(node));
    }
    // Only when it has actually moved. This is asked again after every frame
    // — a node placed this frame has no position until the next one, and the
    // canvas is still sliding to fit — and notifying regardless would be a
    // rebuild asking to be rebuilt.
    if (_aim != wasAim || _litSpec != wasSpec || _litPort != wasPort) {
      notifyListeners();
    }
  }

  /// The palette row's position, once the search has put it on screen.
  Offset? aimAtRow(String specId) => _centreOf(rowKeys[specId]);

  Offset? _centreOfNode(String nodeId) {
    final state = canvas.currentState;
    final node = state?.controller.pipeline.node(nodeId);
    if (state == null || node == null) return null;
    final spec = state.controller.specFor(node);
    if (spec == null) return null;
    return state.globalPointOf(
        PortRef(nodeId, spec.ports.isEmpty ? '' : spec.ports.first.id));
  }

  Future<void> _moveTo(Offset? target) async {
    _cursor = target;
    notifyListeners();
    if (target != null) await Future<void>.delayed(travel);
  }

  Future<void> _click() async {
    _pressed = true;
    notifyListeners();
    await Future<void>.delayed(dwell);
    _pressed = false;
    notifyListeners();
  }

  void _lightNothing() {
    _litSpec = null;
    _litPort = null;
  }

  Offset? _centreOf(GlobalKey? key) {
    final box = key?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  @override
  Future<void> perform(DemoAction action, DemoStage stage) async {
    final controller = stage.controller;
    switch (action) {
      case SaySoFar():
        _lightNothing();
        await _moveTo(null);

      case PlaceFromPalette(:final specId, :final remember):
        await _moveTo(aimAtRow(specId));
        await _click();
        stage.remember(remember, controller.addNode(specId, Offset.zero));
        // And put the list back the way it was found.
        search.text = '';
        _lightNothing();
        await _moveTo(null);

      case ClickPortAndPick(
          :final node,
          :final portId,
          :final pick,
          :final remember
        ):
        final ref = stage.portOf(node, portId);
        await _moveTo(canvas.currentState?.globalPointOf(ref));
        await _click();

        // The real menu, not a picture of one. This is the step that used to
        // be invisible: a wire simply existed, and now you watch it being
        // asked for.
        canvas.currentState?.openPortMenuOn(ref);
        _litPort = null;
        _litSpec = pick;
        notifyListeners();
        await Future<void>.delayed(dwell);
        await _click();

        final made = canvas.currentState?.pickFromPortMenu(pick) ??
            controller.addNodeFor(ref, pick);
        if (made == null) {
          throw StateError('$pick will not attach to $node.$portId');
        }
        stage.remember(remember, made);
        _lightNothing();
        await _moveTo(null);

      case ConnectPorts(:final fromNode, :final fromPortId, :final toNode,
            :final toPortId):
        final from = stage.portOf(fromNode, fromPortId);
        final to = stage.portOf(toNode, toPortId);
        // A drag, shown as one: to the dot, press, across, release.
        await _moveTo(canvas.currentState?.globalPointOf(from));
        _pressed = true;
        notifyListeners();
        await _moveTo(canvas.currentState?.globalPointOf(to));
        controller.connect(from, to);
        _pressed = false;
        _lightNothing();
        await _moveTo(null);

      case PinAmount(:final node, :final count, :final portId, :final rate):
        final id = stage.nodeId(node);
        controller.select(NodeSelection(id));
        await _moveTo(_centreOfNode(id));
        await _click();
        controller.pin(count != null
            ? BuildingCountPin(nodeId: id, count: count)
            : PortRatePin(nodeId: id, portId: portId!, ratePerSecond: rate!));
        await _moveTo(null);

      case LetTheProducerDecide(:final node, :final portId):
        // Pointed at the port the lines leave, because that is where the
        // decision is: at the source, not at each destination.
        final ref = stage.portOf(node, portId);
        _litPort = ref;
        await _moveTo(canvas.currentState?.globalPointOf(ref));
        await _click();
        controller.driveFromProducer(ref);
        _lightNothing();
        await _moveTo(null);

      case AskForTheBest(:final node):
        final id = stage.nodeId(node);
        controller.select(NodeSelection(id));
        await _moveTo(_centreOfNode(id));
        await _click();
        controller.optimiseFor(id);
        await _moveTo(null);
    }
  }
}
