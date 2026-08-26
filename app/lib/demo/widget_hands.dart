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
/// nothing to watch. These move a cursor to the thing first, click it, let the
/// real port menu open, and choose a row out of it. The build changes for
/// exactly the reasons it would if somebody were doing it.
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
  bool _pressed = false;
  String? _litSpec;
  PortRef? _litPort;

  /// Where the cursor is, in global coordinates. Null when nothing is being
  /// pointed at, which is most of a talking step.
  Offset? get cursor => _cursor;

  /// Whether the cursor is mid-click, for the ring that says so.
  bool get pressed => _pressed;

  /// The palette row and the port dot to light: what is about to be clicked,
  /// rather than what has just been.
  String? get litSpec => _litSpec;
  PortRef? get litPort => _litPort;

  /// Put the cursor somewhere and let it be seen getting there.
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
        // Search for it, the way a person would, and for the same reason:
        // otherwise the row is somewhere below the fold and there is nothing
        // on screen to point at.
        final name = controller.database.process(specId)?.name ?? specId;
        search.text = name;
        _litSpec = specId;
        _litPort = null;
        notifyListeners();
        await Future<void>.delayed(dwell);

        await _moveTo(_centreOf(rowKeys[specId]));
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
        _litPort = ref;
        _litSpec = null;
        notifyListeners();
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
        await _moveTo(null);

      case PinAmount(:final node, :final count, :final portId, :final rate):
        final id = stage.nodeId(node);
        controller.select(NodeSelection(id));
        // Nothing to walk to: the amount is typed into the inspector, which
        // is already open on the thing that was just selected.
        await _moveTo(null);
        controller.pin(count != null
            ? BuildingCountPin(nodeId: id, count: count)
            : PortRatePin(nodeId: id, portId: portId!, ratePerSecond: rate!));

      case AskForTheBest(:final node):
        final id = stage.nodeId(node);
        controller.select(NodeSelection(id));
        await _moveTo(null);
        controller.optimiseFor(id);
    }
  }
}
