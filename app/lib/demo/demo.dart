import 'dart:ui' show Offset;

import 'package:oni_engine/oni_engine.dart';

import '../state/pipeline_controller.dart';

/// What a step wants done, said as the thing a person would do.
///
/// Not as a call on the controller, which is what it was: a step that says
/// "add this node" can only ever be watched as a node appearing, and the app
/// had no way to show a click that never happened. Said this way, the same
/// step can be carried out twice over — straight at the model by a test with
/// no screen, and through the real widgets by somebody watching, with a
/// cursor that arrives before anything moves.
sealed class DemoAction {
  const DemoAction();
}

/// Place a recipe from the palette on the left.
class PlaceFromPalette extends DemoAction {
  const PlaceFromPalette(this.specId, {required this.remember});

  final String specId;

  /// The name later steps will call it by, since the node's id is generated.
  final String remember;
}

/// Click a port dot, and pick something out of the menu that opens.
///
/// The two halves are one action because they are one intent — "follow this
/// port to whatever takes it" — and because a menu left open with nothing
/// picked is not a state a demo should ever rest in.
class ClickPortAndPick extends DemoAction {
  const ClickPortAndPick({
    required this.node,
    required this.portId,
    required this.pick,
    required this.remember,
  });

  /// The remembered name of the node whose port this is.
  final String node;
  final String portId;

  /// The recipe to choose out of the menu.
  final String pick;
  final String remember;
}

/// Wire two things that are already on the canvas to each other.
class ConnectPorts extends DemoAction {
  const ConnectPorts({
    required this.fromNode,
    required this.fromPortId,
    required this.toNode,
    required this.toPortId,
  });

  final String fromNode;
  final String fromPortId;
  final String toNode;
  final String toPortId;
}

/// Select a node and say how much of it there is.
class PinAmount extends DemoAction {
  const PinAmount({required this.node, this.count, this.portId, this.rate});

  final String node;

  /// "I have three of these", or a rate on a port. One or the other.
  final double? count;
  final String? portId;
  final double? rate;
}

/// Select a boundary node and ask for the best it can do.
class AskForTheBest extends DemoAction {
  const AskForTheBest(this.node);

  final String node;
}

/// Nothing but talk: a line about what is already on screen.
class SaySoFar extends DemoAction {
  const SaySoFar();
}

/// What a step is allowed to touch, and what it has made so far.
class DemoStage {
  DemoStage(this.controller);

  final PipelineController controller;

  final Map<String, String> _named = {};

  /// Keep the id of something a step has just made, under a name the demo
  /// chose. Node ids are generated; the names in a demo are not.
  String remember(String name, String nodeId) {
    _named[name] = nodeId;
    return nodeId;
  }

  /// What [remember] put there. Throws rather than returning null: a demo
  /// asking for something it never made is a broken demo, and the test that
  /// runs every one of them should say so loudly.
  String nodeId(String name) =>
      _named[name] ??
      (throw StateError('This demo never made anything called "$name"'));

  /// The port a named step's node carries, ready to be clicked or wired.
  PortRef portOf(String name, String portId) => PortRef(nodeId(name), portId);
}

/// One thing a demo does, and the line it says while doing it.
class DemoStep {
  const DemoStep({required this.says, this.does = const SaySoFar()});

  /// The narration. Whatever figures it quotes are checked against what the
  /// app really says — see `E15-3` — so it is a claim rather than a caption.
  final String says;

  final DemoAction does;
}

/// A demo: a build assembled a step at a time, with somebody explaining.
class Demo {
  const Demo({
    required this.id,
    required this.name,
    required this.summary,
    required this.steps,
  });

  final String id;
  final String name;

  /// One line saying what it shows, in the terms of somebody deciding whether
  /// to watch it.
  final String summary;

  final List<DemoStep> steps;
}

/// Who carries a step out.
///
/// The straight one runs against the controller and returns; the one the app
/// supplies moves a cursor, opens the real menu, and takes its time. Both
/// leave the build in the same state, which is a test.
abstract class DemoHands {
  /// Do it. Returns when the build has changed and the screen has caught up.
  Future<void> perform(DemoAction action, DemoStage stage);
}

/// The straight one: no screen, no waiting, no cursor.
///
/// What every test uses, and what `E15-3` checks the figures against.
class ModelHands implements DemoHands {
  const ModelHands();

  @override
  Future<void> perform(DemoAction action, DemoStage stage) async {
    final controller = stage.controller;
    switch (action) {
      case SaySoFar():
        return;
      case PlaceFromPalette(:final specId, :final remember):
        stage.remember(remember, controller.addNode(specId, Offset.zero));
      case ClickPortAndPick(
          :final node,
          :final portId,
          :final pick,
          :final remember
        ):
        final made =
            controller.addNodeFor(stage.portOf(node, portId), pick);
        if (made == null) {
          throw StateError('$pick will not attach to $node.$portId');
        }
        stage.remember(remember, made);
      case ConnectPorts(:final fromNode, :final fromPortId, :final toNode,
            :final toPortId):
        controller.connect(
            stage.portOf(fromNode, fromPortId), stage.portOf(toNode, toPortId));
      case PinAmount(:final node, :final count, :final portId, :final rate):
        final id = stage.nodeId(node);
        controller.select(NodeSelection(id));
        controller.pin(count != null
            ? BuildingCountPin(nodeId: id, count: count)
            : PortRatePin(
                nodeId: id, portId: portId!, ratePerSecond: rate!));
      case AskForTheBest(:final node):
        final id = stage.nodeId(node);
        controller.select(NodeSelection(id));
        controller.optimiseFor(id);
    }
  }
}

/// A demo part-way through.
class DemoRun {
  DemoRun(this.demo, PipelineController controller,
      {this.hands = const ModelHands()})
      : _stage = DemoStage(controller);

  final Demo demo;

  /// Who carries the steps out. A test's hands are the model's.
  final DemoHands hands;
  final DemoStage _stage;

  int _done = 0;
  bool _busy = false;

  /// How many steps have been played.
  int get played => _done;

  bool get isDone => _done >= demo.steps.length;

  /// What is being said now: the line of the last step played, or the first
  /// line before anything has been.
  String get says => demo.steps.isEmpty
      ? ''
      : demo.steps[_done == 0 ? 0 : _done - 1].says;

  /// The step about to happen, for anybody who needs to know where the next
  /// click is going.
  DemoAction? get next => isDone ? null : demo.steps[_done].does;

  /// Play one step. Returns false when there was nothing left to play, or
  /// when the last one has not finished — a demo on screen takes its time,
  /// and a second Next while a cursor is still travelling would run two at
  /// once.
  Future<bool> step() async {
    if (isDone || _busy) return false;
    _busy = true;
    try {
      final step = demo.steps[_done];
      // The line first, so what is said arrives before what it describes.
      _done++;
      await hands.perform(step.does, _stage);
    } finally {
      _busy = false;
    }
    return true;
  }

  /// Play the rest of it.
  Future<void> runToEnd() async {
    while (await step()) {}
  }
}
