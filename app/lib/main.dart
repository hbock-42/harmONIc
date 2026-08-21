import 'package:flutter/material.dart';
import 'package:oni_engine/oni_engine.dart';

void main() => runApp(const OniPipelineApp());

class OniPipelineApp extends StatelessWidget {
  const OniPipelineApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ONI Pipeline Planner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3FB8AF),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const PipelineScreen(),
      );
}

/// A deliberately plain harness for the engine: pick a node, say how many you
/// have, read the plan. The canvas UI (KANBAN E7) replaces this screen; the
/// engine calls it makes stay the same.
class PipelineScreen extends StatefulWidget {
  const PipelineScreen({super.key});

  @override
  State<PipelineScreen> createState() => _PipelineScreenState();
}

class _PipelineScreenState extends State<PipelineScreen> {
  late final GameDatabase _db = loadDefaultDatabase();
  late final PipelineSolver _solver = PipelineSolver(_db);
  late final Pipeline _pipeline = _buildSpom();

  late String _pinnedNodeId = 'elec';
  final TextEditingController _amount = TextEditingController(text: '4');

  Pipeline _buildSpom() {
    final b = PipelineBuilder(_db, name: 'SPOM')
      ..addSource('water')
      ..add('electrolyzer', nodeId: 'elec')
      ..add('hydrogen_generator', nodeId: 'hgen')
      ..addSink('oxygen')
      ..connectItem('src_water', 'elec', 'water')
      ..connectItem('elec', 'hgen', 'hydrogen')
      ..connectItem('elec', 'sink_oxygen', 'oxygen');
    return b.build();
  }

  /// Sources and sinks are pinned by rate (their count *is* g/s); real
  /// buildings are pinned by how many you have.
  Pin _pin() {
    final spec = _db.processOrThrow(_pipeline.nodeOrThrow(_pinnedNodeId).specId);
    final value = double.tryParse(_amount.text) ?? 0;
    return switch (spec.kind) {
      ProcessKind.source => PortRatePin(
          nodeId: _pinnedNodeId, portId: sourcePortId, ratePerSecond: value),
      ProcessKind.sink => PortRatePin(
          nodeId: _pinnedNodeId, portId: sinkPortId, ratePerSecond: value),
      _ => BuildingCountPin(nodeId: _pinnedNodeId, count: value),
    };
  }

  String _labelFor(PipelineNode node) =>
      node.label ?? _db.processOrThrow(node.specId).name;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final solution = _solver.solvePinned(_pipeline, _pin());
    final spec = _db.processOrThrow(_pipeline.nodeOrThrow(_pinnedNodeId).specId);
    final isRate =
        spec.kind == ProcessKind.source || spec.kind == ProcessKind.sink;

    return Scaffold(
      appBar: AppBar(title: Text(_pipeline.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _pinnedNodeId,
                  decoration: const InputDecoration(
                    labelText: 'I know how much of this I have',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final node in _pipeline.nodes)
                      DropdownMenuItem(
                        value: node.id,
                        child: Text(_labelFor(node)),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _pinnedNodeId = value ?? _pinnedNodeId),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isRate ? 'g/s' : 'how many',
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                formatSolution(solution, _db),
                style: const TextStyle(fontFamily: 'monospace', height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
