import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import '../design/tokens.dart';
import '../design/widgets.dart';
import '../state/pipeline_controller.dart';

/// Everything about whatever is selected — and, for a node, the pin control
/// that drives the entire app.
class InspectorPanel extends StatelessWidget {
  const InspectorPanel({required this.controller, super.key});

  final PipelineController controller;

  @override
  Widget build(BuildContext context) {
    final node = controller.selectedNode;
    final edge = controller.selectedEdge;
    return OniPanel(
      title: 'Inspector',
      width: 300,
      child: switch ((node, edge)) {
        (final PipelineNode n, _) => _NodeInspector(
            key: ValueKey(n.id),
            controller: controller,
            node: n,
          ),
        (_, final PipelineEdge e) =>
          _EdgeInspector(controller: controller, edge: e),
        _ => const _EmptyInspector(),
      },
    );
  }
}

class _EmptyInspector extends StatelessWidget {
  const _EmptyInspector();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(OniSpacing.lg),
        child: Text(
          'Select a node to say how many you have.\n\n'
          'Everything else in the pipeline is then worked out from it.',
          style: OniType.body.copyWith(color: OniColors.textFaint),
        ),
      );
}

class _NodeInspector extends StatefulWidget {
  const _NodeInspector({
    required this.controller,
    required this.node,
    super.key,
  });

  final PipelineController controller;
  final PipelineNode node;

  @override
  State<_NodeInspector> createState() => _NodeInspectorState();
}

class _NodeInspectorState extends State<_NodeInspector> {
  late final TextEditingController _amount = TextEditingController();

  PipelineController get controller => widget.controller;
  PipelineNode get node => widget.node;
  ProcessSpec get spec => controller.specOf(node);

  bool get _isBoundary =>
      spec.kind == ProcessKind.source || spec.kind == ProcessKind.sink;

  /// Boundary nodes are pinned by rate; real buildings by how many you have.
  String? get _boundaryPortId =>
      _isBoundary && spec.ports.isNotEmpty ? spec.ports.first.id : null;

  @override
  void initState() {
    super.initState();
    _amount.text = _currentPinText();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String _currentPinText() {
    final pin = controller.pinFor(node.id);
    return switch (pin) {
      BuildingCountPin(:final count) => _trim(count),
      PortRatePin(:final ratePerSecond) => _trim(ratePerSecond),
      StockPin(:final ratePerSecond) => _trim(ratePerSecond),
      null => '',
    };
  }

  static String _trim(double value) {
    final fixed = value.toStringAsFixed(2);
    return fixed.endsWith('.00') ? fixed.substring(0, fixed.length - 3) : fixed;
  }

  void _applyPin(String raw) {
    final value = double.tryParse(raw.trim());
    if (value == null) return;
    final portId = _boundaryPortId;
    controller.pin(
      portId == null
          ? BuildingCountPin(nodeId: node.id, count: value)
          : PortRatePin(
              nodeId: node.id, portId: portId, ratePerSecond: value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = controller.solution.nodes[node.id];
    final pinned = controller.pinFor(node.id) != null;
    final unit = _boundaryPortId == null
        ? null
        : controller.database
            .item(spec.portByIdOrThrow(_boundaryPortId!).itemId)
            ?.unit;

    return ListView(
      padding: const EdgeInsets.all(OniSpacing.lg),
      children: [
        Text(spec.name, style: OniType.heading),
        if (spec.description != null) ...[
          const SizedBox(height: OniSpacing.xs),
          Text(spec.description!,
              style: OniType.body
                  .copyWith(fontSize: 11.5, color: OniColors.textFaint)),
        ],
        const SizedBox(height: OniSpacing.lg),

        // The headline control.
        Text(
          _isBoundary
              ? 'I HAVE THIS MUCH  (${unit?.symbol ?? 'g/s'})'
              : 'I HAVE THIS MANY',
          style: OniType.label.copyWith(color: OniColors.accent),
        ),
        const SizedBox(height: OniSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OniField(
                controller: _amount,
                hint: _isBoundary ? 'rate' : 'count',
                onChanged: _applyPin,
                onSubmitted: _applyPin,
              ),
            ),
            const SizedBox(width: OniSpacing.sm),
            OniButton(
              label: 'Clear',
              compact: true,
              onPressed: pinned
                  ? () {
                      controller.clearPin();
                      setState(() => _amount.text = '');
                    }
                  : null,
            ),
          ],
        ),
        const SizedBox(height: OniSpacing.md),

        if (result != null) ...[
          Row(
            children: [
              Expanded(
                child: OniStat(
                  label: _isBoundary ? 'rate' : 'needed',
                  value: _isBoundary
                      ? (unit ?? Unit.gramsPerSecond).format(result.count)
                      : '${result.count.toStringAsFixed(2)} ×',
                ),
              ),
              if (!_isBoundary)
                Expanded(
                  child: OniStat(
                    label: 'build',
                    value: '${result.wholeCount}',
                    valueColour: OniColors.accent,
                  ),
                ),
              if (!_isBoundary)
                Expanded(
                  child: OniStat(
                    label: 'busy',
                    value: '${(result.utilisation * 100).toStringAsFixed(0)}%',
                  ),
                ),
            ],
          ),
          const SizedBox(height: OniSpacing.lg),
          if (!_isBoundary)
            Row(
              children: [
                Expanded(
                  child: OniStat(
                    label: 'power',
                    value: Unit.watts.format(spec.netPowerWatts * result.count),
                    valueColour: spec.netPowerWatts < 0
                        ? OniColors.ok
                        : OniColors.text,
                  ),
                ),
                Expanded(
                  child: OniStat(
                    label: 'heat',
                    value: Unit.kdtuPerSecond
                        .format(spec.netHeatKdtu * result.count),
                  ),
                ),
              ],
            ),
          const SizedBox(height: OniSpacing.lg),
        ],

        Text('PORTS', style: OniType.label),
        const SizedBox(height: OniSpacing.sm),
        for (final port in spec.ports)
          _PortRow(controller: controller, node: node, port: port),

        const SizedBox(height: OniSpacing.xl),
        OniButton(
          label: 'Delete node',
          tone: OniButtonTone.danger,
          onPressed: () {
            controller.select(NodeSelection(node.id));
            controller.deleteSelection();
          },
        ),
      ],
    );
  }
}

class _PortRow extends StatelessWidget {
  const _PortRow({
    required this.controller,
    required this.node,
    required this.port,
  });

  final PipelineController controller;
  final PipelineNode node;
  final Port port;

  @override
  Widget build(BuildContext context) {
    final item = controller.database.item(port.itemId);
    final ref = PortRef(node.id, port.id);
    PortBalance? balance;
    for (final b in controller.solution.portBalances) {
      if (b.ref == ref) balance = b;
    }
    final unit = item?.unit ?? Unit.gramsPerSecond;
    final unmet = balance != null && balance.isExternalInput;
    final spare = balance != null && balance.isSurplus;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: OniItemColors.ofItem(item),
            ),
          ),
          const SizedBox(width: OniSpacing.sm),
          Expanded(
            child: Text(
              '${port.isInput ? '←' : '→'} ${item?.name ?? port.itemId}',
              style: OniType.body.copyWith(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            unit.format(balance?.rate ?? 0, precision: 1),
            style: OniType.numberSmall.copyWith(color: OniColors.text),
          ),
          if (unmet || spare)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text(
                unmet ? 'supply' : 'spare',
                style: OniType.numberSmall.copyWith(
                  color: unmet ? OniColors.warning : OniColors.textFaint,
                  fontSize: 9.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EdgeInspector extends StatelessWidget {
  const _EdgeInspector({required this.controller, required this.edge});

  final PipelineController controller;
  final PipelineEdge edge;

  @override
  Widget build(BuildContext context) {
    final fromNode = controller.pipeline.node(edge.fromNodeId);
    final toNode = controller.pipeline.node(edge.toNodeId);
    final flow = controller.solution.edgeFlows[edge.id] ?? 0;
    final port = fromNode == null
        ? null
        : controller.specOf(fromNode).portById(edge.fromPortId);
    final item = port == null ? null : controller.database.item(port.itemId);

    return ListView(
      padding: const EdgeInsets.all(OniSpacing.lg),
      children: [
        Text(item?.name ?? 'Connection', style: OniType.heading),
        const SizedBox(height: OniSpacing.xs),
        Text(
          '${fromNode == null ? '?' : controller.specOf(fromNode).name}'
          '  →  '
          '${toNode == null ? '?' : controller.specOf(toNode).name}',
          style: OniType.body.copyWith(color: OniColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: OniSpacing.lg),
        OniStat(
          label: 'flow',
          value: (item?.unit ?? Unit.gramsPerSecond).format(flow),
        ),
        const SizedBox(height: OniSpacing.lg),
        Text('WHO DECIDES THE AMOUNT', style: OniType.label),
        const SizedBox(height: OniSpacing.sm),
        Row(
          children: [
            OniButton(
              label: 'The consumer',
              compact: true,
              tone: edge.mode == EdgeMode.pull
                  ? OniButtonTone.accent
                  : OniButtonTone.neutral,
              onPressed: () => controller.setEdgeMode(edge.id, EdgeMode.pull),
            ),
            const SizedBox(width: OniSpacing.sm),
            OniButton(
              label: 'The producer',
              compact: true,
              tone: edge.mode == EdgeMode.push
                  ? OniButtonTone.accent
                  : OniButtonTone.neutral,
              onPressed: () => controller.setEdgeMode(edge.id, EdgeMode.push),
            ),
          ],
        ),
        const SizedBox(height: OniSpacing.sm),
        Text(
          edge.mode == EdgeMode.pull
              ? 'This line carries whatever the consumer needs, and the '
                  'producer is sized to cover it.'
              : 'This line carries a fixed share of what the producer makes.',
          style: OniType.body
              .copyWith(fontSize: 11.5, color: OniColors.textFaint),
        ),
        const SizedBox(height: OniSpacing.xl),
        OniButton(
          label: 'Delete connection',
          tone: OniButtonTone.danger,
          onPressed: () {
            controller.select(EdgeSelection(edge.id));
            controller.deleteSelection();
          },
        ),
      ],
    );
  }
}
