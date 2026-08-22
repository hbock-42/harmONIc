import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import '../canvas/auto_layout.dart';
import '../storage/json_store.dart';
import 'pipeline_controller.dart';

/// One entry in the "open a pipeline" list.
class PipelineSummary {
  const PipelineSummary({
    required this.id,
    required this.name,
    required this.nodeCount,
  });

  final String id;
  final String name;
  final int nodeCount;
}

/// Every pipeline the player has, and the one they are looking at.
///
/// Editing saves itself: a planning tool that loses a half-drawn build because
/// nobody pressed ⌘S is a planning tool people stop trusting. Saving is
/// debounced so a drag is one write rather than sixty.
class WorkspaceController extends ChangeNotifier {
  WorkspaceController({
    required JsonStore store,
    required PipelineController controller,
    this.debounce = const Duration(milliseconds: 400),
  })  // Named parameters cannot be written `this._store`.
      // ignore: prefer_initializing_formals
      : _store = store,
        // ignore: prefer_initializing_formals
        _controller = controller {
    _controller.addListener(_onPipelineChanged);
  }

  final JsonStore _store;
  final PipelineController _controller;
  final Duration debounce;

  final Map<String, Pipeline> _pipelines = {};
  final List<String> _repairNotes = [];
  String? _currentId;

  /// The builds with a tab, oldest first.
  ///
  /// Separate from what is saved: everything you have ever drawn is in the
  /// menu, and the tabs are the handful you are working on now. Closing a tab
  /// puts a build away rather than throwing it out, which is the distinction
  /// the menu could not make.
  final List<String> _openIds = [];
  Timer? _timer;
  Pipeline? _lastSeen;
  bool _saving = false;
  bool _loaded = false;

  String? get currentId => _currentId;

  /// The open tabs, in the order they were opened.
  List<PipelineSummary> get openTabs => [
        for (final id in _openIds)
          if (_pipelines[id] case final Pipeline pipeline)
            PipelineSummary(
                id: pipeline.id,
                name: pipeline.name,
                nodeCount: pipeline.nodes.length),
      ];
  bool get isSaving => _saving;

  /// What had to change to bring saved builds back into line with the recipes.
  /// Empty when nothing did, which is the usual case.
  List<String> get repairNotes => List.unmodifiable(_repairNotes);

  void dismissRepairNotes() {
    _repairNotes.clear();
    notifyListeners();
  }

  /// Brings a pipeline up to date, keeping a note of anything that changed.
  Pipeline _repaired(Pipeline pipeline) {
    final repair = repairPipeline(pipeline, _controller.database);
    if (repair.changed) {
      _repairNotes.addAll(
        repair.notes.map((note) => '${pipeline.name}: $note'),
      );
    }
    return repair.pipeline;
  }

  /// The saved pipeline with this id, for exporting it.
  Pipeline? pipelineFor(String id) => _pipelines[id];

  List<PipelineSummary> get saved {
    final list = [
      for (final p in _pipelines.values)
        PipelineSummary(id: p.id, name: p.name, nodeCount: p.nodes.length),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.removeListener(_onPipelineChanged);
    super.dispose();
  }

  /// Reads everything back and reopens whatever was last on screen. Returns
  /// false when there was nothing saved, so the caller can seed a starter.
  Future<bool> load() async {
    final raw = await _store.read();
    _loaded = true;
    if (raw == null) return false;

    var restoredId = raw['lastOpenedId'] as String?;
    for (final entry in (raw['pipelines'] as List<dynamic>? ?? const [])) {
      try {
        final pipeline = _repaired(
          Pipeline.fromJson(entry as Map<String, dynamic>),
        );
        _pipelines[pipeline.id] = pipeline;
      } on Object {
        // Skip the unreadable one rather than losing every other pipeline.
        continue;
      }
    }
    if (_pipelines.isEmpty) return false;

    // A build that needed repairing must be written back, or it is repaired
    // again on every start and the note never stops appearing.
    if (_repairNotes.isNotEmpty) unawaited(_persist());

    _openIds
      ..clear()
      ..addAll([
        for (final id in (raw['openIds'] as List<dynamic>? ?? const []))
          if (_pipelines.containsKey(id as String)) id,
      ]);

    restoredId ??= _pipelines.keys.first;
    final pipeline = _pipelines[restoredId] ?? _pipelines.values.first;
    _openWithoutSaving(pipeline);
    notifyListeners();
    return true;
  }

  /// Adopts a pipeline that is already on screen — used for the starter build
  /// on a first run, so it is saved like anything else.
  Future<void> adopt(Pipeline pipeline) async {
    _pipelines[pipeline.id] = pipeline;
    if (!_openIds.contains(pipeline.id)) _openIds.add(pipeline.id);
    _currentId = pipeline.id;
    _lastSeen = pipeline;
    await _persist();
    notifyListeners();
  }

  Future<void> open(String id) async {
    final pipeline = _pipelines[id];
    if (pipeline == null) return;
    await saveNow();
    _openWithoutSaving(pipeline);
    await _persist();
    notifyListeners();
  }

  /// Puts a build away without deleting it. It stays in the menu.
  Future<void> closeTab(String id) async {
    if (!_openIds.remove(id)) return;
    if (_currentId == id) {
      // Move to the neighbour rather than to nothing: an editor with no
      // document is a state with nothing useful in it.
      final next = _openIds.isNotEmpty ? _openIds.last : null;
      if (next != null && _pipelines[next] != null) {
        await saveNow();
        _openWithoutSaving(_pipelines[next]!);
      } else if (_pipelines.isNotEmpty) {
        await saveNow();
        _openWithoutSaving(_pipelines.values.first);
      }
    }
    await _persist();
    notifyListeners();
  }

  Future<String> createNew({String name = 'New pipeline'}) async {
    await saveNow();
    final pipeline = _blank(name);
    _pipelines[pipeline.id] = pipeline;
    _openWithoutSaving(pipeline);
    await _persist();
    notifyListeners();
    return pipeline.id;
  }

  /// Opens a fresh copy of a starting build.
  ///
  /// Templates carry no positions — laying a graph out is the canvas's job —
  /// so the arrangement happens here, on the way in, and what lands on screen
  /// is what Tidy would have made of it.
  Future<String> createFromTemplate(PipelineTemplate template) async {
    await saveNow();
    final built = template.build(_controller.database);
    final placed = AutoLayout(
      pipeline: built,
      database: _controller.database,
    ).positions();

    final pipeline = Pipeline(
      id: 'pipeline_${DateTime.now().microsecondsSinceEpoch}',
      name: template.name,
      dataVersion: _controller.database.dataVersion,
      nodes: [
        for (final node in built.nodes)
          if (placed[node.id] case final Offset at)
            node.copyWith(x: at.dx, y: at.dy)
          else
            node,
      ],
      edges: built.edges,
      pins: built.pins,
    );

    _pipelines[pipeline.id] = pipeline;
    _openWithoutSaving(pipeline);
    await _persist();
    notifyListeners();
    return pipeline.id;
  }

  Pipeline _blank(String name) => Pipeline(
        id: 'pipeline_${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        dataVersion: _controller.database.dataVersion,
      );

  /// Takes in a pipeline from elsewhere, under a fresh id so it can never
  /// overwrite something already here — two people's builds may well share an
  /// id, since ids come from the name they were given.
  Future<String> import(Pipeline rawIncoming) async {
    await saveNow();
    final incoming = _repaired(rawIncoming);
    final taken = _pipelines.keys.toSet();
    var id = incoming.id;
    var name = incoming.name;
    if (taken.contains(id)) {
      id = 'imported_${DateTime.now().microsecondsSinceEpoch}';
      name = '$name (imported)';
    }
    final pipeline = Pipeline(
      id: id,
      name: name,
      nodes: incoming.nodes,
      edges: incoming.edges,
      pins: incoming.pins,
      dataVersion: incoming.dataVersion,
    );
    _pipelines[id] = pipeline;
    _openWithoutSaving(pipeline);
    await _persist();
    notifyListeners();
    return id;
  }

  /// A copy under a new id, so experimenting never risks the original.
  Future<String> duplicate(String id) async {
    final source = _pipelines[id];
    if (source == null) return id;
    await saveNow();
    final copy = Pipeline(
      id: 'pipeline_copy_${DateTime.now().microsecondsSinceEpoch}',
      name: '${source.name} copy',
      nodes: source.nodes,
      edges: source.edges,
      pins: source.pins,
      dataVersion: source.dataVersion,
    );
    _pipelines[copy.id] = copy;
    _openWithoutSaving(copy);
    await _persist();
    notifyListeners();
    return copy.id;
  }

  Future<void> delete(String id) async {
    // Any pending autosave still refers to the pipeline being deleted, and
    // writing it back would resurrect what the player just threw away.
    _timer?.cancel();
    _timer = null;

    final wasCurrent = _currentId == id;
    _pipelines.remove(id);
    if (wasCurrent) {
      final next = _pipelines.isEmpty
          ? _blank('New pipeline')
          : _pipelines.values.first;
      _pipelines[next.id] = next;
      _openWithoutSaving(next);
    }
    await _persist();
    notifyListeners();
  }

  /// Writes immediately, cancelling any pending debounce.
  Future<void> saveNow() async {
    _timer?.cancel();
    _timer = null;
    if (!_loaded) return;
    // Written with the rates its recipes have right now, so that if one of
    // them is corrected before this build is opened again, the app can say
    // which figure moved instead of quietly reporting different numbers.
    final current = _controller.pipeline.copyWith(
      recipeSnapshot:
          recipeSnapshot(_controller.pipeline.nodes, _controller.database),
    );
    _pipelines[current.id] = current;
    _currentId = current.id;
    await _persist();
  }

  void _openWithoutSaving(Pipeline pipeline) {
    if (!_openIds.contains(pipeline.id)) _openIds.add(pipeline.id);
    _currentId = pipeline.id;
    _lastSeen = pipeline;
    _controller.load(pipeline);
  }

  /// Selecting a node rebuilds the UI but not the document, so compare
  /// identity: only a genuine edit is worth a write.
  void _onPipelineChanged() {
    if (!_loaded) return;
    final current = _controller.pipeline;
    if (identical(current, _lastSeen)) return;
    _lastSeen = current;
    _timer?.cancel();
    if (debounce == Duration.zero) {
      // No timer at all — used by tests, where a pending one would outlive the
      // test and be reported as a leak.
      unawaited(saveNow());
      return;
    }
    _timer = Timer(debounce, () {
      unawaited(saveNow());
    });
  }

  Future<void> _persist() async {
    _saving = true;
    await _store.write(<String, dynamic>{
      'schemaVersion': 1,
      if (_currentId != null) 'lastOpenedId': _currentId,
      'openIds': [..._openIds],
      'pipelines': [for (final p in _pipelines.values) p.toJson()],
    });
    _saving = false;
  }
}
