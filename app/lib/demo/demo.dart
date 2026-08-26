import '../state/pipeline_controller.dart';

/// What a step is allowed to touch.
///
/// The controller, and nothing else. A demo that could paint its own numbers
/// would become a lie the first time a recipe changed, and the numbers are the
/// whole argument — so a step may only do things a person could have done, and
/// what appears on screen comes back out of the solver as usual.
///
/// The view is separate on purpose: fitting the canvas is the player's job in
/// `E15-2`, and a demo that had to know about pixels could not be run by a
/// test that has no screen.
class DemoStage {
  DemoStage(this.controller);

  final PipelineController controller;

  final Map<String, String> _named = {};

  /// Keep the id of something a step has just made, under a name the demo
  /// chose.
  ///
  /// A later step almost always needs it — you place a geyser and then wire
  /// it up — and node ids are generated rather than chosen. Naming it where
  /// it is made reads better than hunting for it by recipe afterwards, and
  /// this map is the only state a demo carries.
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
}

/// One thing a demo does, and the line it says while doing it.
class DemoStep {
  const DemoStep({required this.says, this.does});

  /// The narration. Whatever figures it quotes are checked against what the
  /// app really says — see `E15-3` — so it is a claim rather than a caption.
  final String says;

  /// The action. Null for a step that only talks: the first line of a demo
  /// and the last are usually about what is already on screen.
  final void Function(DemoStage stage)? does;
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
  /// to watch it. The same shape as a `PipelineTemplate`'s summary, because it
  /// is offered in the same place.
  final String summary;

  final List<DemoStep> steps;
}

/// A demo part-way through.
///
/// Holds the position and nothing else; the build lives in the controller,
/// where it would have lived if somebody had done all this by hand. Which
/// means the app renders a demo exactly as it renders anything, and there is
/// no second way for a node to be drawn.
class DemoRun {
  DemoRun(this.demo, PipelineController controller)
      : _stage = DemoStage(controller);

  final Demo demo;
  final DemoStage _stage;

  int _done = 0;

  /// How many steps have been played.
  int get played => _done;

  bool get isDone => _done >= demo.steps.length;

  /// What is being said now: the line of the last step played, or the first
  /// line before anything has been.
  String get says => demo.steps.isEmpty
      ? ''
      : demo.steps[_done == 0 ? 0 : _done - 1].says;

  /// Play one step. Returns false when there was nothing left to play.
  bool step() {
    if (isDone) return false;
    demo.steps[_done].does?.call(_stage);
    _done++;
    return true;
  }

  /// Play the rest of it.
  ///
  /// The same thing as pressing step until it stops, which is a property worth
  /// keeping: the test that checks a demo's figures runs it this way, and a
  /// person watching runs it the other, and they had better agree.
  void runToEnd() {
    while (step()) {}
  }
}
