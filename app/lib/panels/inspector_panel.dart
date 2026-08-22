import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import '../design/item_glyph.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import '../state/pipeline_controller.dart';

/// Everything about whatever is selected — and, for a node, the pin control
/// that drives the entire app.
class InspectorPanel extends StatelessWidget {
  const InspectorPanel({
    required this.controller,
    required this.rateDisplay,
    required this.onToggleRates,
    super.key,
  });

  final PipelineController controller;
  final RateDisplay rateDisplay;
  final VoidCallback onToggleRates;

  @override
  Widget build(BuildContext context) {
    final node = controller.selectedNode;
    final edge = controller.selectedEdge;
    return OniPanel(
      title: 'Inspector',
      width: 300,
      child: controller.selectedNodeIds.length > 1
          ? _MultiSelection(controller: controller)
          : switch ((node, edge)) {
        (final PipelineNode n, _) => _NodeInspector(
            key: ValueKey(n.id),
            controller: controller,
            node: n,
            rateDisplay: rateDisplay,
            onToggleRates: onToggleRates,
          ),
        (_, final PipelineEdge e) => _EdgeInspector(
            controller: controller,
            edge: e,
            rateDisplay: rateDisplay,
            onToggleRates: onToggleRates,
          ),
        _ => const _EmptyInspector(),
      },
    );
  }
}

/// What a marquee gets you: what is in it, what it costs, and the two things
/// worth doing to a group.
class _MultiSelection extends StatelessWidget {
  const _MultiSelection({required this.controller});

  final PipelineController controller;

  @override
  Widget build(BuildContext context) {
    final ids = controller.selectedNodeIds;
    var power = 0.0;
    var heat = 0.0;
    var labour = 0.0;
    var tiles = 0;
    for (final id in ids) {
      final node = controller.pipeline.node(id);
      final result = controller.solution.nodes[id];
      if (node == null || result == null) continue;
      final spec = controller.specOf(node);
      if (spec.kind == ProcessKind.source || spec.kind == ProcessKind.sink) {
        continue;
      }
      power += spec.netPowerWatts * result.count;
      heat += spec.netHeatKdtu * result.count;
      labour += spec.dupeLabourSecondsPerCycle * result.count;
      tiles += result.totalFootprintTiles;
    }

    return ListView(
      padding: const EdgeInsets.all(OniSpacing.lg),
      children: [
        Text('${ids.length} nodes selected', style: OniType.heading),
        const SizedBox(height: OniSpacing.lg),
        Wrap(
          spacing: OniSpacing.md,
          runSpacing: OniSpacing.md,
          children: [
            SizedBox(
              width: 118,
              child: OniStat(
                label: 'power',
                value: Unit.watts.format(power),
                valueColour: power < 0 ? OniColors.ok : OniColors.text,
              ),
            ),
            SizedBox(
              width: 118,
              child: OniStat(
                label: 'heat',
                value: Unit.kdtuPerSecond.format(heat),
              ),
            ),
            if (labour > 0)
              SizedBox(
                width: 118,
                child: OniStat(
                  label: 'dupe time',
                  value: '${labour.toStringAsFixed(0)} s/cycle',
                ),
              ),
            if (tiles > 0)
              SizedBox(
                width: 118,
                child: OniStat(label: 'floor', value: '$tiles tiles'),
              ),
          ],
        ),
        const SizedBox(height: OniSpacing.xl),
        Text('SELECTED', style: OniType.label),
        const SizedBox(height: OniSpacing.sm),
        for (final id in ids)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              controller.specOf(controller.pipeline.nodeOrThrow(id)).name,
              style: OniType.body.copyWith(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const SizedBox(height: OniSpacing.xl),
        OniButton(
          label: 'Delete ${ids.length} nodes   ⌫',
          tone: OniButtonTone.danger,
          onPressed: controller.deleteSelection,
        ),
      ],
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
    required this.rateDisplay,
    required this.onToggleRates,
    super.key,
  });

  final PipelineController controller;
  final PipelineNode node;
  final RateDisplay rateDisplay;
  final VoidCallback onToggleRates;

  @override
  State<_NodeInspector> createState() => _NodeInspectorState();
}

class _NodeInspectorState extends State<_NodeInspector> {
  late final TextEditingController _amount = TextEditingController();

  /// The amount field's focus, so a suggestion can put the cursor in it.
  final FocusNode _amountFocus = FocusNode();


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
    // Opened by someone asking for the amount, so the cursor belongs in the
    // field rather than one click away. After the frame, because the field is
    // not in the tree yet.
    if (widget.controller.claimAmountRequest(widget.node.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _amountFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _amountFocus.dispose();
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
    final boundaryItem = _boundaryPortId == null
        ? null
        : controller.database.item(spec.portByIdOrThrow(_boundaryPortId!).itemId);
    final unit = boundaryItem?.unit;

    return ListView(
      padding: const EdgeInsets.all(OniSpacing.lg),
      children: [
        Text(spec.name, style: OniType.heading),
        if (spec.tags.contains('unverified')) ...[
          const SizedBox(height: OniSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: OniSpacing.sm, vertical: 6),
            decoration: BoxDecoration(
              color: OniColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border:
                  Border.all(color: OniColors.warning.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('!',
                    style: OniType.title.copyWith(color: OniColors.warning)),
                const SizedBox(width: OniSpacing.sm),
                Expanded(
                  child: Text(
                    'These numbers could not be confirmed — treat the result '
                    'as an estimate.',
                    style: OniType.body
                        .copyWith(fontSize: 11.5, color: OniColors.warning),
                  ),
                ),
              ],
            ),
          ),
        ],
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
                focusNode: _amountFocus,
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
                      controller.clearPin(node.id);
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
                      ? (boundaryItem?.formatRate(result.count, widget.rateDisplay) ??
                          result.count.toStringAsFixed(2))
                      : '${result.count.toStringAsFixed(2)} ×',
                  onToggle: _isBoundary ? widget.onToggleRates : null,
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
          _asBuiltNote(controller, result),
          _buildCost(controller, spec, result),
          const SizedBox(height: OniSpacing.lg),
          if (!_isBoundary)
            Wrap(
              spacing: OniSpacing.md,
              runSpacing: OniSpacing.md,
              children: [
                SizedBox(
                  width: 118,
                  child: OniStat(
                    label: 'power',
                    value: controller.database
                        .itemOrThrow(WellKnownItems.power)
                        .formatRate(
                            spec.netPowerWatts * result.count, widget.rateDisplay),
                    valueColour: spec.netPowerWatts < 0
                        ? OniColors.ok
                        : OniColors.text,
                    onToggle: widget.onToggleRates,
                  ),
                ),
                SizedBox(
                  width: 118,
                  child: OniStat(
                    label: 'heat',
                    value: controller.database
                        .itemOrThrow(WellKnownItems.heat)
                        .formatRate(
                            spec.netHeatKdtu * result.count, widget.rateDisplay),
                    onToggle: widget.onToggleRates,
                  ),
                ),
                if (spec.dupeLabourSecondsPerCycle > 0)
                  SizedBox(
                    width: 118,
                    child: OniStat(
                      label: 'dupe time',
                      value: '${(spec.dupeLabourSecondsPerCycle * result.count).toStringAsFixed(0)} s/cycle',
                    ),
                  ),
                if (spec.hasFootprint)
                  SizedBox(
                    width: 118,
                    child: OniStat(
                      label: 'floor',
                      value: '${result.totalFootprintTiles} tiles'
                          '  (${spec.footprintWidth}×${spec.footprintHeight})',
                    ),
                  ),
              ],
            ),
          const SizedBox(height: OniSpacing.lg),
        ],

        if (spec.kind == ProcessKind.source) ...[
          _SupplyTemperature(controller: controller, node: node),
          const SizedBox(height: OniSpacing.lg),
        ],

        for (final port in choosablePorts(controller.database, spec)) ...[
          _MaterialChoice(
            controller: controller,
            node: node,
            spec: spec,
            port: port,
          ),
          const SizedBox(height: OniSpacing.lg),
        ],

        if (controller.isGeyser(node)) ...[
          _GeyserActivity(
            controller: controller,
            node: node,
            rateDisplay: widget.rateDisplay,
          ),
          const SizedBox(height: OniSpacing.lg),
        ],
        Text('PORTS', style: OniType.label),
        const SizedBox(height: OniSpacing.sm),
        for (final port in spec.ports)
          _PortRow(
            controller: controller,
            node: node,
            port: port,
            rateDisplay: widget.rateDisplay,
            onToggleRates: widget.onToggleRates,
          ),

        const SizedBox(height: OniSpacing.xl),
        OniButton(
          label: 'Delete node   ⌫',
          tone: OniButtonTone.danger,
          onPressed: () {
            controller.select(NodeSelection(node.id));
            controller.deleteSelection();
          },
        ),
      ],
    );
  }

  /// What it takes to put these up, once.
  ///
  /// Priced per building actually placed rather than per fractional one, since
  /// half an Electrolyzer still costs its whole 200 kg of ore, and shown in the
  /// class the game asks for: any metal ore will do, and which one you choose
  /// changes its heat tolerance rather than whether it can be built.
  Widget _buildCost(
      PipelineController controller, ProcessSpec spec, NodeResult? result) {
    if (result == null || spec.buildCost.isEmpty || result.wholeCount == 0) {
      return const SizedBox.shrink();
    }
    final entries = spec.buildCost.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.only(top: OniSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text('TO BUILD', style: OniType.label),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final entry in entries)
                  Text(
                    '${formatMass(entry.value * result.wholeCount)} '
                    '${controller.database.item(entry.key)?.name ?? entry.key}',
                    style: OniType.body,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A machine you only half need idles, and the "busy" figure above already
  /// says so. A critter, a plant or a Duplicant cannot idle: the one you had to
  /// round up eats and produces like all the others, every cycle, whether the
  /// ratio wanted it or not. That is worth saying where the rounding happens.
  Widget _asBuiltNote(PipelineController controller, NodeResult? result) {
    if (result == null || _isBoundary) return const SizedBox.shrink();
    final report = controller.asBuiltReport;
    final extra = report.roundedUp[result.nodeId];
    if (extra == null) return const SizedBox.shrink();

    final spec = controller.database.process(result.specId);
    if (spec == null) return const SizedBox.shrink();

    final lines = <String>[];
    for (final port in spec.ports) {
      final item = controller.database.item(port.itemId);
      if (item == null || item.isCapacity) continue;
      final amount = port.ratePerSecond * extra;
      if (amount.abs() < 1e-9) continue;
      lines.add('${port.isOutput ? 'makes' : 'eats'} '
          '${item.formatRate(amount, widget.rateDisplay)} more '
          '${item.name.toLowerCase()}');
    }

    return Padding(
      padding: const EdgeInsets.only(top: OniSpacing.md),
      child: GestureDetector(
        onTap: widget.onToggleRates,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: OniSpacing.sm, vertical: 6),
          decoration: BoxDecoration(
            color: OniColors.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: OniColors.accent.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You cannot have ${result.count.toStringAsFixed(2)} of these, '
                'and the spare one does not idle the way a machine would. '
                'Against the ratio, what you actually place:',
                style: OniType.body.copyWith(color: OniColors.accent),
              ),
              const SizedBox(height: 4),
              for (final line in lines)
                Text(line, style: OniType.body),
            ],
          ),
        ),
      ),
    );
  }
}

/// How active you assume this particular geyser is.
///
/// The shipped rate is a lifetime average at a typical roll. The presets cover
/// the band a geyser can land in, and the field takes the exact figure Field
/// Research reports for yours.
class _GeyserActivity extends StatefulWidget {
  const _GeyserActivity({
    required this.controller,
    required this.node,
    required this.rateDisplay,
  });

  final PipelineController controller;
  final PipelineNode node;
  final RateDisplay rateDisplay;

  @override
  State<_GeyserActivity> createState() => _GeyserActivityState();
}

class _GeyserActivityState extends State<_GeyserActivity> {
  final TextEditingController _percent = TextEditingController();

  /// The last value this widget put into the field, so an edit made elsewhere
  /// (the top bar's all-geysers control) refreshes it, while typing does not
  /// fight itself.
  double? _shown;
  bool _invalid = false;

  PipelineController get controller => widget.controller;

  @override
  void dispose() {
    _percent.dispose();
    super.dispose();
  }

  static String _format(double fraction) {
    final percent = fraction * 100;
    return percent == percent.roundToDouble()
        ? percent.toStringAsFixed(0)
        : percent.toStringAsFixed(1);
  }

  void _apply(String raw) {
    final value = double.tryParse(raw.trim());
    if (value == null || value <= 0 || value > 100) {
      setState(() => _invalid = raw.trim().isNotEmpty);
      return;
    }
    _shown = value / 100;
    setState(() => _invalid = false);
    controller.setNodeActivity(widget.node.id, value / 100);
  }

  @override
  Widget build(BuildContext context) {
    final active = controller.activityOf(widget.node);
    if (_shown == null || (active - _shown!).abs() > 1e-6) {
      _shown = active;
      _percent.text = _format(active);
    }
    final spec = controller.specOf(widget.node);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ASSUME ACTIVE', style: OniType.label),
        const SizedBox(height: OniSpacing.sm),
        Wrap(
          spacing: OniSpacing.sm,
          runSpacing: OniSpacing.sm,
          children: [
            for (final entry in GeyserActivity.presets.entries)
              OniButton(
                label: '${entry.key} '
                    '${(entry.value * 100).toStringAsFixed(0)}%',
                compact: true,
                tone: (active - entry.value).abs() < 1e-6
                    ? OniButtonTone.accent
                    : OniButtonTone.neutral,
                onPressed: () =>
                    controller.setNodeActivity(widget.node.id, entry.value),
              ),
          ],
        ),
        const SizedBox(height: OniSpacing.sm),
        Row(
          children: [
            SizedBox(
              width: 84,
              child: OniField(
                key: geyserActivityFieldKey,
                controller: _percent,
                hint: '60',
                textAlign: TextAlign.right,
                onChanged: _apply,
              ),
            ),
            const SizedBox(width: OniSpacing.sm),
            Expanded(
              child: Text(
                _invalid
                    ? 'Between 1 and 100.'
                    : '% active, from Field Research',
                style: OniType.body.copyWith(
                  fontSize: 11.5,
                  color: _invalid ? OniColors.danger : OniColors.textMuted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: OniSpacing.sm),
        // What that assumption actually buys, so the number is not abstract.
        for (final port in spec.outputs)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Text('→ ', style: OniType.numberSmall),
                Expanded(
                  child: Text(
                    controller.database.item(port.itemId)?.name ?? port.itemId,
                    style: OniType.numberSmall,
                  ),
                ),
                Text(
                  controller.database.item(port.itemId)?.formatRate(
                        port.ratePerSecond * widget.node.outputScale,
                        widget.rateDisplay,
                        precision: 1,
                      ) ??
                      (port.ratePerSecond * widget.node.outputScale)
                          .toStringAsFixed(1),
                  style: OniType.numberSmall.copyWith(color: OniColors.text),
                ),
              ],
            ),
          ),
        const SizedBox(height: OniSpacing.sm),
        Text(
          'A geyser is active 40–80 % of a dormancy cycle, rolled when the '
          'world was made. The shipped rate assumes 60 %. Field Research on '
          'this geyser tells you its real figure.',
          style: OniType.body
              .copyWith(fontSize: 11.5, color: OniColors.textFaint),
        ),
      ],
    );
  }
}

/// Which particular material runs through a port whose recipe asks for a class.
///
/// A Metal Refinery takes any ore, and until you say which, that is genuinely
/// what it is: generic, and able to feed anything that wants a metal. Say
/// copper and it becomes a copper refinery — it will no longer feed an iron
/// port, and the build will say so rather than quietly agree.
class _MaterialChoice extends StatelessWidget {
  const _MaterialChoice({
    required this.controller,
    required this.node,
    required this.spec,
    required this.port,
  });

  final PipelineController controller;
  final PipelineNode node;
  final ProcessSpec spec;
  final Port port;

  @override
  Widget build(BuildContext context) {
    final db = controller.database;
    final klass = db.itemOrThrow(port.itemId);
    final chosen = node.materials[port.id];
    final members = klass.members.toList()
      ..sort((a, b) => (db.item(a)?.name ?? a).compareTo(db.item(b)?.name ?? b));

    // What the choice does downstream, said only where it does something.
    final follower = spec.ports
        .where((p) => p.followsPortId == port.id)
        .firstOrNull;
    final produced = follower == null
        ? ''
        : itemFlowingIn(db, node, spec, follower);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${klass.name.toUpperCase()} USED', style: OniType.label),
        const SizedBox(height: OniSpacing.sm),
        Wrap(
          spacing: OniSpacing.sm,
          runSpacing: OniSpacing.sm,
          children: [
            OniButton(
              label: 'Any',
              compact: true,
              tone: chosen == null
                  ? OniButtonTone.accent
                  : OniButtonTone.neutral,
              onPressed: () => controller.setMaterial(node.id, port.id, null),
            ),
            for (final member in members)
              OniButton(
                label: db.item(member)?.name ?? member,
                compact: true,
                tone: chosen == member
                    ? OniButtonTone.accent
                    : OniButtonTone.neutral,
                onPressed: () =>
                    controller.setMaterial(node.id, port.id, member),
              ),
          ],
        ),
        if (follower != null) ...[
          const SizedBox(height: OniSpacing.sm),
          Text(
            chosen == null
                ? 'Any ore will do, and what comes out is just '
                    '"${db.item(produced)?.name ?? produced}" — enough to feed '
                    'anything that wants one. Pick an ore if something '
                    'downstream needs a particular metal.'
                : 'Makes ${db.item(produced)?.name ?? produced}. It will no '
                    'longer feed a port that wants a different metal.',
            style: OniType.body
                .copyWith(fontSize: 11.5, color: OniColors.textFaint),
          ),
        ],
      ],
    );
  }
}

/// What temperature this supply arrives at.
///
/// A build's temperatures have to start somewhere, and the game does not know:
/// water out of a Cool Steam Vent is 95 °C, water out of a reservoir is
/// whatever you left it at. Given one figure here, everything downstream can be
/// worked out — mixed by mass and specific heat, or overridden wherever a
/// recipe publishes its own.
class _SupplyTemperature extends StatefulWidget {
  const _SupplyTemperature({required this.controller, required this.node});

  final PipelineController controller;
  final PipelineNode node;

  @override
  State<_SupplyTemperature> createState() => _SupplyTemperatureState();
}

class _SupplyTemperatureState extends State<_SupplyTemperature> {
  late final TextEditingController _field = TextEditingController(
      text: widget.node.temperatureC?.toStringAsFixed(0) ?? '');

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _apply(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      widget.controller.setNodeTemperature(widget.node.id, null);
      return;
    }
    final value = double.tryParse(trimmed);
    if (value == null) return;
    widget.controller.setNodeTemperature(widget.node.id, value);
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ARRIVES AT', style: OniType.label),
          const SizedBox(height: OniSpacing.sm),
          Row(
            children: [
              SizedBox(
                width: 84,
                child: OniField(
                  key: supplyTemperatureFieldKey,
                  controller: _field,
                  hint: '—',
                  textAlign: TextAlign.right,
                  onChanged: _apply,
                ),
              ),
              const SizedBox(width: OniSpacing.sm),
              Expanded(
                child: Text(
                  widget.node.temperatureC == null
                      ? '°C. Leave it blank if you do not know — the build will '
                          'simply not say what anything downstream runs at.'
                      : '°C, and everything downstream follows from it.',
                  style: OniType.body
                      .copyWith(fontSize: 11.5, color: OniColors.textMuted),
                ),
              ),
            ],
          ),
        ],
      );
}

/// Named so tests can drive it directly.
const Key supplyTemperatureFieldKey = ValueKey('supply-temperature');

/// The measured-percentage field, named so tests can drive it directly.
const Key geyserActivityFieldKey = ValueKey('geyser-activity-percent');

class _PortRow extends StatelessWidget {
  const _PortRow({
    required this.controller,
    required this.node,
    required this.port,
    required this.rateDisplay,
    required this.onToggleRates,
  });

  final PipelineController controller;
  final PipelineNode node;
  final Port port;
  final RateDisplay rateDisplay;
  final VoidCallback onToggleRates;

  @override
  Widget build(BuildContext context) {
    final item = controller.database.item(port.itemId);
    final ref = PortRef(node.id, port.id);
    PortBalance? balance;
    for (final b in controller.solution.portBalances) {
      if (b.ref == ref) balance = b;
    }
    final unmet = balance != null && balance.isExternalInput;
    final spare = balance != null && balance.isSurplus;
    final venting = node.ventsPort(port.id);
    // Only worth offering where it changes anything: an output nothing pulls
    // from already spills its excess.
    final canVent =
        port.isOutput && controller.portIsPulled(node.id, port.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OniItemGlyph.ofItem(item),
              const SizedBox(width: OniSpacing.sm),
              Expanded(
                child: Text(
                  '${port.isInput ? '←' : '→'} ${item?.name ?? port.itemId}',
                  style: OniType.body.copyWith(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              OniRate(
                text: item?.formatRate(balance?.rate ?? 0, rateDisplay,
                        precision: 1) ??
                    (balance?.rate ?? 0).toStringAsFixed(1),
                onToggle: onToggleRates,
                style: OniType.numberSmall.copyWith(color: OniColors.text),
              ),
            ],
          ),
          // Everything qualifying the flow goes on its own line: cramming the
          // temperature, the shortfall and the vent switch onto the first one
          // left no room for the name.
          if (port.temperatureC != null ||
              controller.temperatures.at(ref) != null ||
              unmet ||
              spare ||
              canVent)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 3),
              child: Wrap(
                spacing: OniSpacing.sm,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // The recipe's own figure if it has one; failing that, what
                  // the build works out this port actually runs at, marked as
                  // worked out rather than published.
                  if (port.temperatureC case final double celsius)
                    Text(
                      '${celsius.toStringAsFixed(0)} °C',
                      style: OniType.numberSmall.copyWith(
                        color:
                            port.runsHot ? OniColors.warning : OniColors.textFaint,
                      ),
                    )
                  else if (controller.temperatures.at(ref)
                      case final double celsius)
                    Text(
                      '~${celsius.toStringAsFixed(0)} °C',
                      style: OniType.numberSmall.copyWith(
                        color: celsius > commonOverheatCelsius
                            ? OniColors.warning
                            : OniColors.textFaint,
                      ),
                    ),
                  if (unmet || spare)
                    Text(
                      unmet ? 'needs supply' : 'spare',
                      style: OniType.numberSmall.copyWith(
                        color:
                            unmet ? OniColors.warning : OniColors.textFaint,
                      ),
                    ),
                  if (canVent)
                    OniButton(
                      label: venting ? 'venting' : 'vent',
                      compact: true,
                      tone: venting
                          ? OniButtonTone.accent
                          : OniButtonTone.neutral,
                      onPressed: () => controller.setPortVenting(
                        node.id,
                        port.id,
                        venting: !venting,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EdgeInspector extends StatelessWidget {
  const _EdgeInspector({
    required this.controller,
    required this.edge,
    required this.rateDisplay,
    required this.onToggleRates,
  });

  final PipelineController controller;
  final PipelineEdge edge;
  final RateDisplay rateDisplay;
  final VoidCallback onToggleRates;

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
          value: item?.formatRate(flow, rateDisplay) ?? flow.toStringAsFixed(2),
          onToggle: onToggleRates,
        ),
        if (item != null)
          if (Conduits.describe(flow, item.category) case final String carried) ...[
            const SizedBox(height: OniSpacing.md),
            OniStat(label: 'carried by', value: carried),
          ],
        // The temperature the recipe states, or failing that the one the build
        // works out for this wire — which is usually the only one there is.
        if (port?.temperatureC ??
            controller.temperatures.at(PortRef(edge.fromNodeId, edge.fromPortId))
            case final double celsius) ...[
          const SizedBox(height: OniSpacing.md),
          OniStat(
            label: 'arrives at',
            value: '${port?.temperatureC == null ? '~' : ''}'
                '${celsius.toStringAsFixed(0)} °C',
            valueColour:
                Overheating.isTrouble(celsius) ? OniColors.warning : null,
          ),
          if (Overheating.isTrouble(celsius)) ...[
            const SizedBox(height: OniSpacing.sm),
            Text(
              _overheatAdvice(controller, celsius),
              style: OniType.body
                  .copyWith(fontSize: 11.5, color: OniColors.warning),
            ),
          ],
        ],
        const SizedBox(height: OniSpacing.lg),
        Text('WHO DECIDES THE AMOUNT', style: OniType.label),
        const SizedBox(height: OniSpacing.sm),
        Wrap(
          spacing: OniSpacing.sm,
          runSpacing: OniSpacing.sm,
          children: [
            OniButton(
              label: 'The consumer',
              compact: true,
              tone: edge.mode == EdgeMode.pull
                  ? OniButtonTone.accent
                  : OniButtonTone.neutral,
              onPressed: () => controller.setEdgeMode(edge.id, EdgeMode.pull),
            ),
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
          label: 'Delete connection   ⌫',
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

/// What to build a pipe out of, for something this hot.
///
/// Everything starts at 75 °C and its material moves that up. Naming the
/// coolest-tolerating material that still holds is the useful answer: it is the
/// cheapest thing that will do, and the reader can go up the list from there.
String _overheatAdvice(PipelineController controller, double celsius) {
  final survivors = Overheating.survivors(celsius);
  String named(String id) => '${controller.database.item(id)?.name ?? id} '
      '(${Overheating.toleranceOf(id).toStringAsFixed(0)} °C)';

  if (survivors.isEmpty) {
    return 'At ${celsius.toStringAsFixed(0)} °C nothing this app knows about '
        'will hold it — every material here gives up first. Whatever carries '
        'this is a problem to solve before the rest of the build matters.';
  }
  return 'Hotter than the 75 °C a plain building tolerates, so what this is '
      'made of stops being a detail: ${named(survivors.first)} is the coolest '
      'that holds, up to ${named(survivors.last)}. Whether it actually cooks '
      'anything also depends on what it runs past, which this model cannot see.';
}
