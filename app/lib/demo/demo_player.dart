import 'dart:async';

import 'package:flutter/foundation.dart';

import '../state/pipeline_controller.dart';
import '../state/workspace_controller.dart';
import 'demo.dart';
import 'widget_hands.dart';

/// Plays a demo, in a build of its own, one press at a time.
///
/// Nothing advances on a clock. A demo that plays itself is a video with extra
/// steps: you look away to read a number and it has moved on without you. The
/// press is the pace.
///
/// The tab is the other half. A demo places nodes and pins amounts on a real
/// controller — that is what makes its numbers real — so it must not do any of
/// that to what you were working on. Leaving throws its build away.
class DemoPlayer extends ChangeNotifier {
  DemoPlayer({
    required this.workspace,
    required this.controller,
    this.hands = const ModelHands(),
  }) {
    // A demo owns a tab, and only while that tab is the one on screen. Open
    // another and the next step would build into it — or throw, because the
    // node it meant to wire up is somewhere else.
    workspace.addListener(_stopIfLeftBehind);
  }

  final WorkspaceController workspace;
  final PipelineController controller;

  /// Who carries the steps out: the model directly in a test, and the real
  /// widgets — cursor, palette search, port menu — on screen.
  final DemoHands hands;

  DemoRun? _run;
  String? _tabId;
  bool _leaving = false;
  bool _stepping = false;

  /// The demo being played, if one is.
  DemoRun? get run => _run;

  /// Started and not yet finished or left.
  bool get isRunning => _run != null;

  /// A step is in flight — the cursor is still travelling, so Next should
  /// wait rather than start a second one over the top.
  bool get isStepping => _stepping;

  /// Opens a build of its own and gets ready to play [demo] in it.
  Future<void> start(Demo demo) async {
    await leave();
    _tabId = await workspace.createNew(name: demo.name);
    final run = DemoRun(demo, controller, hands: hands);
    _run = run;
    _aim();
    notifyListeners();
  }

  /// Do the next thing, and then point at the one after it.
  Future<void> step() async {
    final run = _run;
    if (run == null || _stepping) return;
    _stepping = true;
    notifyListeners();
    try {
      await run.step();
    } finally {
      _stepping = false;
    }
    if (_run != run) return;
    _aim();
    notifyListeners();
  }

  void _aim() {
    final run = _run;
    if (run == null) return;
    if (hands case final WidgetHands widget) {
      widget.aimAt(run.next, run.stage);
    }
  }

  void _stopIfLeftBehind() {
    final tab = _tabId;
    if (tab == null || _leaving || workspace.currentId == tab) return;
    unawaited(leave());
  }

  /// Stop, and throw the demo's build away.
  ///
  /// Deleted rather than closed: a tab you did not make, left in your list of
  /// builds, is litter — and the one thing worse than a demo you cannot leave
  /// is one that leaves something behind.
  Future<void> leave() async {
    if (_leaving) return;
    _leaving = true;
    _run = null;
    final tab = _tabId;
    _tabId = null;
    if (hands case final WidgetHands widget) {
      widget.aimAt(null, DemoStage(controller));
    }
    if (tab != null) await workspace.delete(tab);
    _leaving = false;
    notifyListeners();
  }

  @override
  void dispose() {
    workspace.removeListener(_stopIfLeftBehind);
    super.dispose();
  }
}
