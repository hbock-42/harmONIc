import 'dart:async';

import 'package:flutter/foundation.dart';

import '../state/pipeline_controller.dart';
import '../state/workspace_controller.dart';
import 'demo.dart';

/// How long a step sits on screen before the next one.
///
/// One number for every step, which is wrong and knowingly so: a line of six
/// words and a line that asks you to read a figure off a node do not want the
/// same pause. `E15-7` is that, and it is waiting on somebody actually
/// watching one, because rules about reading speed invented at a desk are
/// usually wrong.
const Duration kDemoStepDelay = Duration(milliseconds: 2600);

/// Plays a demo, in a build of its own.
///
/// The tab is the point. A demo places nodes and pins amounts on a real
/// controller — that is what makes its numbers real — so it must not do any of
/// that to what you were working on. It gets its own pipeline, and leaving
/// throws that pipeline away: a demo is not your work and should not turn up
/// in your list of builds afterwards.
class DemoPlayer extends ChangeNotifier {
  DemoPlayer({
    required this.workspace,
    required this.controller,
    this.stepDelay = kDemoStepDelay,
    Timer Function(Duration, void Function(Timer))? schedule,
  }) : _schedule = schedule ?? Timer.periodic {
    // A demo owns a tab, and only while that tab is the one on screen. Open
    // another and the next step would build into it — or throw, because the
    // node it meant to wire up is somewhere else.
    workspace.addListener(_stopIfLeftBehind);
  }

  final WorkspaceController workspace;
  final PipelineController controller;
  final Duration stepDelay;

  /// How the waiting is done. A real timer, unless a test says otherwise —
  /// the seam the guide's loader and the link opener already have.
  final Timer Function(Duration, void Function(Timer)) _schedule;

  DemoRun? _run;
  Timer? _timer;
  String? _tabId;
  bool _leaving = false;

  /// The demo being played, if one is.
  DemoRun? get run => _run;

  bool get isPlaying => _timer != null;

  /// Started and not yet finished or left.
  bool get isRunning => _run != null;

  /// Opens a build of its own and plays [demo] in it.
  Future<void> start(Demo demo) async {
    await leave();
    _tabId = await workspace.createNew(name: demo.name);
    _run = DemoRun(demo, controller);
    notifyListeners();
    play();
  }

  void play() {
    if (_run == null || _run!.isDone || isPlaying) return;
    _timer = _schedule(stepDelay, (_) => step());
    notifyListeners();
  }

  void pause() {
    if (!isPlaying) return;
    _timer!.cancel();
    _timer = null;
    notifyListeners();
  }

  /// One step, whether or not it is playing.
  ///
  /// Pressing this while it plays does not double up: the timer is left alone
  /// and simply has less to do, and the last step stops the clock rather than
  /// letting it tick on over a finished demo.
  void step() {
    final run = _run;
    if (run == null) return;
    run.step();
    if (run.isDone) pause();
    notifyListeners();
  }

  /// Stop, and throw the demo's build away.
  ///
  /// Deleted rather than closed: a tab you did not make, left in your list of
  /// builds, is litter — and the one thing worse than a demo you cannot leave
  /// is one that leaves something behind.
  void _stopIfLeftBehind() {
    final tab = _tabId;
    if (tab == null || _leaving || workspace.currentId == tab) return;
    unawaited(leave());
  }

  Future<void> leave() async {
    if (_leaving) return;
    _leaving = true;
    pause();
    _run = null;
    final tab = _tabId;
    _tabId = null;
    if (tab != null) await workspace.delete(tab);
    _leaving = false;
    notifyListeners();
  }

  @override
  void dispose() {
    workspace.removeListener(_stopIfLeftBehind);
    _timer?.cancel();
    super.dispose();
  }
}
