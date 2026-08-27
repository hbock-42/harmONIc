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
      if (spec.kind.isBoundary) {
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
      spec.kind.isBoundary;

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
                key: amountFieldKey,
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
        if (_isBoundary) ...[
          const SizedBox(height: OniSpacing.sm),
          _Stockpile(
            controller: controller,
            node: node,
            portId: _boundaryPortId!,
            onPinned: () => setState(() => _amount.text = _currentPinText()),
          ),
        ],
        if (_isBoundary && controller.hasASplitToChoose) ...[
          const SizedBox(height: OniSpacing.sm),
          _TheMostOfIt(controller: controller, node: node, spec: spec),
        ],
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
          _oneMoreNote(controller, node),
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

        if (controller.database.variantsOf(spec).length > 1) ...[
          _Variants(controller: controller, node: node, spec: spec),
          const SizedBox(height: OniSpacing.lg),
        ],

        for (final port in choosablePorts(controller.database, spec)) ...[
          MaterialChoiceRow(
            controller: controller,
            node: node,
            spec: spec,
            port: port,
          ),
          const SizedBox(height: OniSpacing.lg),
        ],

        // A building on a sensor is not a building that has stopped: the
        // ratios hold, you just need more of them. Nothing could say so until
        // now, though the solver has always known how.
        // Not for a geyser, whose duty cycle is a fact about the world and
        // already has its own control; nor for a critter or a plant, which do
        // not have an off switch.
        if (!_isBoundary &&
            !controller.isGeyser(node) &&
            spec.kind != ProcessKind.critter &&
            spec.kind != ProcessKind.plant) ...[
          _Uptime(controller: controller, node: node, result: result),
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

  /// What the next one of these would buy, and cost.
  ///
  /// The question a ratio raises and never answers. It could always be asked by
  /// editing the amount and looking, which is two moves and a memory of what
  /// the numbers were before.
  Widget _oneMoreNote(PipelineController controller, PipelineNode node) {
    final answer = controller.oneMoreOf(node.id);
    if (answer == null) return const SizedBox.shrink();

    String rate(String itemId, double value) {
      final item = controller.database.item(itemId);
      final formatted =
          item?.formatRate(value.abs(), widget.rateDisplay, precision: 1) ??
              value.abs().toStringAsFixed(1);
      return '${value < 0 ? '−' : '+'}$formatted ${item?.name ?? itemId}';
    }

    final lines = <String>[
      for (final entry in answer.outputs.entries) rate(entry.key, entry.value),
      for (final entry in answer.inputs.entries) rate(entry.key, -entry.value),
    ];
    final power = controller.database.itemOrThrow(WellKnownItems.power);

    return Padding(
      padding: const EdgeInsets.only(top: OniSpacing.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: OniSpacing.sm, vertical: 6),
        decoration: BoxDecoration(
          color: OniColors.surface,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: OniColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GOING FROM ${answer.from} TO ${answer.to}',
                style: OniType.label),
            const SizedBox(height: 4),
            for (final line in lines.take(6))
              Text(line, style: OniType.body.copyWith(fontSize: 11.5)),
            Text(
              '${answer.powerWatts < 0 ? '−' : '+'}'
              '${power.formatRate(answer.powerWatts.abs(), widget.rateDisplay, precision: 0)}'
              '  ·  ${answer.heatKdtu < 0 ? '−' : '+'}'
              '${answer.heatKdtu.abs().toStringAsFixed(1)} kDTU/s',
              style: OniType.body.copyWith(
                fontSize: 11.5,
                color: answer.powerWatts < 0
                    ? OniColors.warning
                    : OniColors.textMuted,
              ),
            ),
          ],
        ),
      ),
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
    if (result == null || result.wholeCount == 0) return const SizedBox.shrink();
    // Nothing shipped is unpriced, and a recipe you wrote yourself is until
    // you say otherwise. Saying so beats leaving it out of the total in
    // silence, which is what happened before.
    if (spec.buildCost.isEmpty) {
      if (spec.kind != ProcessKind.building) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: OniSpacing.md),
        child: Text(
          'Nobody has said what this costs to put up, so it is missing from '
          'the build total. Add it with + Recipe if you know.',
          style: OniType.body
              .copyWith(fontSize: 11.5, color: OniColors.warning),
        ),
      );
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
                    '${formatMaterial(controller.database.item(entry.key), entry.value * result.wholeCount)} '
                    '${controller.database.item(entry.key)?.name ?? entry.key}'
                    // A counted part is the right way to say what a building
                    // asks for, and it leaves you having to know what one
                    // costs before you can tell whether you can afford it.
                    '${_madeFrom(controller, entry.key, entry.value * result.wholeCount)}',
                    style: OniType.body,
                  ),
                // Which member of that class, when the building runs hot
                // enough for the choice to stop being free.
                if (_materialAdvice(controller, spec, result.nodeId)
                    case final String advice) ...[
                  const SizedBox(height: OniSpacing.sm),
                  Text(
                    advice,
                    style: OniType.body
                        .copyWith(fontSize: 11.5, color: OniColors.warning),
                  ),
                ],
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

/// How much of the time you intend to run this.
///
/// Distinct from the "busy" figure beside the count, which is what rounding
/// leaves you with: build three where you needed 2.5 and the third is idle a
/// third of the time whether you like it or not. This is the other direction —
/// a choice you are making, usually with a sensor. A SPOM's Electrolyzers on a
/// pressure switch are the standard example, and the ratios do not change when
/// you do it. You simply need more Electrolyzers.
class _Uptime extends StatefulWidget {
  const _Uptime({
    required this.controller,
    required this.node,
    required this.result,
  });

  final PipelineController controller;
  final PipelineNode node;
  final NodeResult? result;

  @override
  State<_Uptime> createState() => _UptimeState();
}

class _UptimeState extends State<_Uptime> {
  static const List<double> _presets = [1, 0.75, 0.5, 0.25];

  @override
  Widget build(BuildContext context) {
    final uptime = widget.node.uptime;
    final result = widget.result;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RUNS', style: OniType.label),
        const SizedBox(height: OniSpacing.sm),
        Wrap(
          spacing: OniSpacing.sm,
          runSpacing: OniSpacing.sm,
          children: [
            for (final preset in _presets)
              OniButton(
                label: preset == 1
                    ? 'All the time'
                    : '${(preset * 100).toStringAsFixed(0)}%',
                compact: true,
                tone: (uptime - preset).abs() < 1e-6
                    ? OniButtonTone.accent
                    : OniButtonTone.neutral,
                onPressed: () =>
                    widget.controller.setNodeUptime(widget.node.id, preset),
              ),
          ],
        ),
        if (uptime < 1 && result != null) ...[
          const SizedBox(height: OniSpacing.sm),
          Text(
            'Running ${(uptime * 100).toStringAsFixed(0)} % of the time, so '
            '${result.count.toStringAsFixed(2)} × of work needs '
            '${result.wholeCount} built rather than '
            '${result.count.ceil()}. Everything it makes and eats stays the '
            'same; there is simply more of it standing there.',
            style: OniType.body
                .copyWith(fontSize: 11.5, color: OniColors.textMuted),
          ),
        ],
      ],
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

  /// The other half of what a geyser rolls: what it puts out, in the unit the
  /// game reports. Kept as its own field because a percentage and a rate are
  /// two ways of saying the same thing and somebody has one or the other.
  final TextEditingController _rate = TextEditingController();
  bool _rateInvalid = false;



  PipelineController get controller => widget.controller;

  @override
  void dispose() {
    _percent.dispose();
    _rate.dispose();
    super.dispose();
  }

  /// Typing what yours gives sets the same scale the percentage does — they
  /// are one number wearing two hats, so setting either shows the other.
  void _applyRate(String raw) {
    final spec = controller.specOf(widget.node);
    if (spec.outputs.length != 1) return;
    final shipped = spec.outputs.first.ratePerSecond;
    final typed = double.tryParse(raw.trim());
    if (typed == null || typed <= 0 || shipped <= 0) {
      setState(() => _rateInvalid = raw.trim().isNotEmpty);
      return;
    }
    setState(() => _rateInvalid = false);
    controller.setNodeOutputScale(widget.node.id, typed / shipped);
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
        // A geyser rolls two numbers when the world is made, not one: how
        // often it is awake, and how much it emits while it is. The percentage
        // above covers the first. This covers the second, and covers it in the
        // unit Field Research reports rather than as a multiplier nobody
        // measures.
        if (spec.outputs.length == 1) ...[
          Row(
            children: [
              SizedBox(
                width: 84,
                child: OniField(
                  key: geyserRateFieldKey,
                  controller: _rate,
                  hint: spec.outputs.first.ratePerSecond
                      .toStringAsFixed(0),
                  textAlign: TextAlign.right,
                  onChanged: _applyRate,
                ),
              ),
              const SizedBox(width: OniSpacing.sm),
              Expanded(
                child: Text(
                  _rateInvalid
                      ? 'A rate above nothing.'
                      : 'or ${controller.database.item(spec.outputs.first.itemId)?.unit.symbol ?? 'g/s'} '
                          'yours averages',
                  style: OniType.body.copyWith(
                    fontSize: 11.5,
                    color: _rateInvalid
                        ? OniColors.danger
                        : OniColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: OniSpacing.sm),
        ],
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
          // The three figures come from the engine rather than from this
          // sentence. They were typed out here, which meant the app would go
          // on saying "60 %" after somebody changed what it assumes.
          'A geyser is active '
          '${(GeyserActivity.minimumActiveFraction * 100).toStringAsFixed(0)}–'
          '${_asPercent(GeyserActivity.maximumActiveFraction)} of a dormancy '
          'cycle, rolled when the world was made. The shipped rate assumes '
          '${_asPercent(GeyserActivity.typicalActiveFraction)}. Field Research '
          'on this geyser tells you its real figure.',
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
class MaterialChoiceRow extends StatelessWidget {
  const MaterialChoiceRow({
    required this.controller,
    required this.node,
    required this.spec,
    required this.port,
    super.key,
  });

  final PipelineController controller;
  final PipelineNode node;
  final ProcessSpec spec;
  final Port port;

  @override
  Widget build(BuildContext context) {
    final db = controller.database;
    final chosen = node.materials[port.id];

    // Two shapes end up here. A port asking for a class the game groups, whose
    // options are that class's members; and a port listing alternatives
    // outright, whose options are what it listed — with a class among them
    // expanded, since "wood" means any wood.
    final klass = db.item(port.itemId);
    final members = optionsAt(db, port)
      ..sort((a, b) => (db.item(a)?.name ?? a).compareTo(db.item(b)?.name ?? b));
    final heading = port.alternatives.isEmpty && (klass?.isClass ?? false)
        ? '${klass!.name.toUpperCase()} USED'
        : 'TAKES';

    // What the choice does downstream, said only where it does something.
    final follower = spec.ports
        .where((p) => p.followsPortId == port.id)
        .firstOrNull;
    final produced = follower == null
        ? ''
        : itemFlowingThrough(db, controller.pipeline, node, spec, follower);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading, style: OniType.label),
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
const Key geyserRateFieldKey = ValueKey('geyser-rate');

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
          // What it costs to bring back to room temperature, which is a
          // different question from what it will melt.
          if (item == null
              ? null
              : _coolingNote(item, flow, celsius) case final String note) ...[
            const SizedBox(height: OniSpacing.sm),
            Text(
              note,
              style: OniType.body
                  .copyWith(fontSize: 11.5, color: OniColors.textMuted),
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
        if (edge.mode == EdgeMode.push) ...[
          const SizedBox(height: OniSpacing.lg),
          _EdgeShare(controller: controller, edge: edge),
        ],
        const SizedBox(height: OniSpacing.lg),
        _Valve(controller: controller, edge: edge, item: item),
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

/// "I have this much of it, and I want it to last."
///
/// The third kind of pin, and the one nothing could ever create: the model has
/// had it since the solver was written, the inspector could already *show* one,
/// and there was no way to make one. It answers a question the other two
/// cannot — not "what rate do I have" but "I have two tonnes of coal in a
/// store, how big a build will that keep running for twenty cycles?" — and a
/// rate is what it works out for you.
class _Stockpile extends StatefulWidget {
  const _Stockpile({
    required this.controller,
    required this.node,
    required this.portId,
    required this.onPinned,
  });

  final PipelineController controller;
  final PipelineNode node;
  final String portId;
  final VoidCallback onPinned;

  @override
  State<_Stockpile> createState() => _StockpileState();
}

class _StockpileState extends State<_Stockpile> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _cycles = TextEditingController();
  bool _open = false;

  @override
  void initState() {
    super.initState();
    final pin = widget.controller.pinFor(widget.node.id);
    if (pin is StockPin) {
      _open = true;
      _amount.text = (pin.amount / 1000).toStringAsFixed(0);
      _cycles.text = (pin.durationSeconds / secondsPerCycle).toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _cycles.dispose();
    super.dispose();
  }

  void _apply() {
    final kilograms = double.tryParse(_amount.text.trim());
    final cycles = double.tryParse(_cycles.text.trim());
    if (kilograms == null || cycles == null || cycles <= 0) return;
    widget.controller.pin(StockPin(
      nodeId: widget.node.id,
      portId: widget.portId,
      amount: kilograms * 1000,
      durationSeconds: cycles * secondsPerCycle,
    ));
    widget.onPinned();
  }

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _open = true),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Text('or say what you have in store',
              style: OniType.body
                  .copyWith(fontSize: 11.5, color: OniColors.accent)),
        ),
      );
    }

    final pin = widget.controller.pinFor(widget.node.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: OniSpacing.sm),
        Text('IN STORE', style: OniType.label),
        const SizedBox(height: OniSpacing.sm),
        // Wrapped rather than one row: the inspector is 240-odd pixels wide
        // and two fields with words between them do not fit across it.
        Wrap(
          spacing: OniSpacing.sm,
          runSpacing: OniSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 76,
              child: OniField(
                key: stockAmountFieldKey,
                controller: _amount,
                hint: 'kg',
                textAlign: TextAlign.right,
                onChanged: (_) => _apply(),
              ),
            ),
            Text('kg, to last', style: OniType.body.copyWith(fontSize: 11.5)),
            SizedBox(
              width: 56,
              child: OniField(
                key: stockCyclesFieldKey,
                controller: _cycles,
                hint: '20',
                textAlign: TextAlign.right,
                onChanged: (_) => _apply(),
              ),
            ),
            Text('cycles', style: OniType.body.copyWith(fontSize: 11.5)),
          ],
        ),
        if (pin is StockPin) ...[
          const SizedBox(height: OniSpacing.sm),
          Text(
            'Which is ${(pin.ratePerSecond).toStringAsFixed(1)} g/s, and that '
            'is what the build is sized to. Run it faster and the store runs '
            'out sooner.',
            style: OniType.body
                .copyWith(fontSize: 11.5, color: OniColors.textFaint),
          ),
        ],
      ],
    );
  }
}

/// The other recipes this same building runs.
///
/// A Rock Crusher makes sand or lime or metal; an Aquatuner is one machine per
/// coolant. They are separate recipes because their rates differ — that is
/// what a recipe is — but they are one building, and changing your mind should
/// not mean deleting what you placed and wiring it up again.
class _Variants extends StatefulWidget {
  const _Variants({
    required this.controller,
    required this.node,
    required this.spec,
  });

  final PipelineController controller;
  final PipelineNode node;
  final ProcessSpec spec;

  @override
  State<_Variants> createState() => _VariantsState();
}

class _VariantsState extends State<_Variants> {
  String? _said;

  @override
  Widget build(BuildContext context) {
    final variants = widget.controller.database.variantsOf(widget.spec);
    // "Aquatuner (Petroleum)" twenty-two times is a wall of the same word, so
    // where every name shares a beginning, only the part that differs is
    // shown. The heading carries the rest.
    final prefix = _sharedPrefix(variants.map((s) => s.name));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prefix.isEmpty ? 'THIS BUILDING ALSO RUNS' : '${prefix.toUpperCase()} —',
          style: OniType.label,
        ),
        const SizedBox(height: OniSpacing.sm),
        Wrap(
          spacing: OniSpacing.sm,
          runSpacing: OniSpacing.sm,
          children: [
            for (final variant in variants)
              OniButton(
                label: _shorten(variant.name, prefix),
                compact: true,
                tone: variant.id == widget.spec.id
                    ? OniButtonTone.accent
                    : OniButtonTone.neutral,
                onPressed: variant.id == widget.spec.id
                    ? null
                    : () {
                        final dropped = widget.controller
                            .swapSpec(widget.node.id, variant.id);
                        setState(() => _said = dropped == 0
                            ? null
                            : '$dropped ${dropped == 1 ? 'wire' : 'wires'} did '
                                'not fit the new recipe and came off. Undo '
                                'puts everything back.');
                      },
              ),
          ],
        ),
        if (_said case final String said) ...[
          const SizedBox(height: OniSpacing.sm),
          Text(
            said,
            style: OniType.body
                .copyWith(fontSize: 11.5, color: OniColors.warning),
          ),
        ],
      ],
    );
  }
}

/// The words every one of these names begins with, if any.
String _sharedPrefix(Iterable<String> names) {
  final bracket = names.first.indexOf(' (');
  if (bracket <= 0) return '';
  final prefix = names.first.substring(0, bracket);
  return names.every((n) => n.startsWith('$prefix (')) ? prefix : '';
}

String _shorten(String name, String prefix) => prefix.isEmpty
    ? name
    : name.substring(prefix.length + 2, name.length - 1);

/// A cap on this line, which is a valve.
///
/// It does not change what the build needs — the solver holds equations, and a
/// cap is an inequality — so what it buys is being told when the build has
/// outgrown what you allowed it. The optimiser is the other half: it holds
/// inequalities, so "get as much as possible" answers with your valves shut.
class _Valve extends StatefulWidget {
  const _Valve({required this.controller, required this.edge, this.item});

  final PipelineController controller;
  final PipelineEdge edge;
  final Item? item;

  @override
  State<_Valve> createState() => _ValveState();
}

class _ValveState extends State<_Valve> {
  late final TextEditingController _cap = TextEditingController(
      text: widget.edge.capPerSecond?.toStringAsFixed(0) ?? '');

  @override
  void dispose() {
    _cap.dispose();
    super.dispose();
  }

  void _apply() {
    final typed = double.tryParse(_cap.text.trim());
    widget.controller.setEdgeCap(
        widget.edge.id, typed == null || typed < 0 ? null : typed);
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('VALVE', style: OniType.label),
          const SizedBox(height: OniSpacing.sm),
          Wrap(
            spacing: OniSpacing.sm,
            runSpacing: OniSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 76,
                child: OniField(
                  key: valveFieldKey,
                  controller: _cap,
                  hint: 'none',
                  textAlign: TextAlign.right,
                  onChanged: (_) => _apply(),
                ),
              ),
              Text(
                '${widget.item?.unit.symbol ?? 'g/s'} at most',
                style: OniType.body.copyWith(fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: OniSpacing.sm),
          Text(
            'A cap on this line. It does not change what the build needs — it '
            'says when the build needs more than you have allowed. Asking an '
            'output node for as much as possible works inside your valves.',
            style: OniType.body
                .copyWith(fontSize: 11.5, color: OniColors.textFaint),
          ),
        ],
      );
}

const Key valveFieldKey = ValueKey('edge-valve');

/// Named so tests can drive them directly.
const Key amountFieldKey = ValueKey('amount');
const Key stockAmountFieldKey = ValueKey('stock-amount');
const Key stockCyclesFieldKey = ValueKey('stock-cycles');

/// How much of a producer's output this particular line takes.
///
/// Only a push line has one: a pull line carries whatever its consumer needs.
/// The share has been in the model since the solver was written and there has
/// never been a way to set it — split an Electrolyzer's oxygen between a crew
/// and an Oxylite Refinery and the app would give them half each for ever,
/// which is a decision it was making on your behalf without saying so.
///
/// Leaving it unset is a real answer and the default one: the lines with no
/// share split whatever the explicit ones leave, equally.
class _EdgeShare extends StatelessWidget {
  const _EdgeShare({required this.controller, required this.edge});

  final PipelineController controller;
  final PipelineEdge edge;

  static const List<double> _presets = [0.25, 0.5, 0.75, 1];

  @override
  Widget build(BuildContext context) {
    final share = edge.share;
    // Every other line off this port, however it is driven.
    //
    // It used to count only the producer-driven ones, so a port with one of
    // those and two consumers said "nothing else is asking for it" while two
    // things asked. The other lines are what "whatever is left" is left over
    // from; leaving some of them out of the count is how the sentence came to
    // describe a port that was not there.
    final others = controller.pipeline.edges
        .where((e) =>
            e.id != edge.id &&
            e.fromNodeId == edge.fromNodeId &&
            e.fromPortId == edge.fromPortId)
        .toList();
    // Only the ones with no share of their own divide the remainder equally.
    final sharingTheRest = others
        .where((e) => e.mode == EdgeMode.push && e.share == null)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TAKES', style: OniType.label),
        const SizedBox(height: OniSpacing.sm),
        Wrap(
          spacing: OniSpacing.sm,
          runSpacing: OniSpacing.sm,
          children: [
            OniButton(
              label: sharingTheRest > 0 ? 'An even split' : 'Whatever is left',
              compact: true,
              tone: share == null
                  ? OniButtonTone.accent
                  : OniButtonTone.neutral,
              onPressed: () => controller.setEdgeShare(edge.id, null),
            ),
            for (final preset in _presets)
              OniButton(
                label: '${(preset * 100).toStringAsFixed(0)}%',
                compact: true,
                tone: share != null && (share - preset).abs() < 1e-6
                    ? OniButtonTone.accent
                    : OniButtonTone.neutral,
                onPressed: () => controller.setEdgeShare(edge.id, preset),
              ),
          ],
        ),
        const SizedBox(height: OniSpacing.sm),
        Text(
          share == null
              ? (sharingTheRest > 0
                  ? 'Sharing what the named shares do not claim, equally with '
                      '$sharingTheRest other '
                      '${sharingTheRest == 1 ? 'line' : 'lines'} off this port.'
                  : others.isEmpty
                      ? 'Taking everything the port makes, since nothing else '
                          'is asking for it.'
                      : 'Taking what the other ${others.length} '
                          '${others.length == 1 ? 'line does' : 'lines do'} '
                          'not claim.')
              : 'Taking ${(share * 100).toStringAsFixed(0)} % of what the port '
                  'makes. Whatever the other lines do not claim after that is '
                  'surplus.',
          style: OniType.body
              .copyWith(fontSize: 11.5, color: OniColors.textFaint),
        ),
      ],
    );
  }
}

/// What to build a pipe out of, for something this hot.
///
/// "Get as much of this as the build can give", or as little as it can manage.
///
/// The same question from either end: an output node wants the most of what it
/// collects, a supply node wants to spend the least of what it brings. Shown
/// only where something in the build is divided, since without a choice there
/// is nothing to choose and the button would be offering to do nothing.
///
/// What it does is set shares — the same ones somebody could have typed — so
/// afterwards the build is an ordinary build, the numbers come from the
/// ordinary solver, and undo puts it back.
class _TheMostOfIt extends StatefulWidget {
  const _TheMostOfIt({
    required this.controller,
    required this.node,
    required this.spec,
  });

  final PipelineController controller;
  final PipelineNode node;
  final ProcessSpec spec;

  @override
  State<_TheMostOfIt> createState() => _TheMostOfItState();
}

class _TheMostOfItState extends State<_TheMostOfIt> {
  String? _said;

  @override
  Widget build(BuildContext context) {
    final wanting = widget.spec.kind == ProcessKind.sink;
    final ports = wanting ? widget.spec.inputs : widget.spec.outputs;
    final item = widget.controller.database.item(ports.first.itemId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OniButton(
          label: wanting
              ? 'Get as much as possible'
              : 'Use as little as possible',
          compact: true,
          onPressed: () {
            final most = widget.controller.optimiseFor(widget.node.id);
            setState(() {
              final rate = most == null
                  ? ''
                  : item?.formatRate(most, RateDisplay.perSecond) ??
                      most.toStringAsFixed(1);
              _said = most == null
                  // The ways there is no answer, said as what to do about them
                  // rather than as a status. A supply with no amount set is
                  // infinite, so "the most" has no answer; and pins that
                  // contradict each other have none either way.
                  ? (wanting
                      ? 'There is no most: nothing in this build limits it, or '
                          'two amounts you have set contradict each other.'
                      // Naming the amount to set, because an amount on this
                      // node is not it: the cheapest way to use no ore is to
                      // make no metal, and that is the answer you get.
                      : 'There is no least until you say what you want: put an '
                          'amount on what comes out of the build, not on this. '
                          'With nothing asked for, the least of anything is '
                          'none of it.')
                  : wanting
                      ? 'Divided to give $rate. The splits it chose are on the '
                          'wires, and undo puts them back.'
                      : 'Divided to need only $rate. The splits it chose are on '
                          'the wires, and undo puts them back.';
            });
          },
        ),
        if (_said case final String said) ...[
          const SizedBox(height: OniSpacing.sm),
          Text(
            said,
            style: OniType.body
                .copyWith(fontSize: 11.5, color: OniColors.textFaint),
          ),
        ],
      ],
    );
  }
}

/// The cooling this line brings with it, in the words of what it costs.
///
/// Deliberately not a warning colour. It is not a problem — a hot line is
/// often the whole point of the build — it is a size, and the size is what
/// decides whether it wants a steam room or nothing at all.
///
/// Null below a few degrees either side of room temperature, where the figure
/// is noise, and null for anything without a specific heat, where there is no
/// figure at all.
String? _coolingNote(Item item, double gramsPerSecond, double celsius) {
  final load = coolingLoadKdtu(item, gramsPerSecond, celsius);
  if (load == null || load.abs() < 1) return null;

  final size = load.abs() >= 100
      ? load.abs().toStringAsFixed(0)
      : load.abs().toStringAsFixed(1);
  final base = '${comfortableBaseCelsius.toStringAsFixed(0)} °C';

  return load > 0
      ? '$size kDTU/s more heat than the same flow at $base. That is what it '
          'costs to cool, if it ends up at room temperature. Where it '
          'actually goes is a question about the pipe and what it runs '
          'past, and this is the size of it rather than the answer.'
      : '$size kDTU/s colder than the same flow at $base: cooling somebody '
          'already paid for, and worth spending on the way past.';
}

/// "  ·  200 kg Plastic", for a material counted rather than weighed.
///
/// Empty for everything already measured in kilograms, and for a counted thing
/// nobody has a recipe for — the app has been pricing gaskets in gaskets since
/// they were seeded, and that was the honest answer until the recipe existed.
String _madeFrom(PipelineController controller, String materialId, double count) {
  final each = costOfOne(controller.database, materialId);
  if (each == null) return '';
  final material = controller.database.item(each.materialId);
  return '  ·  ${formatMass(each.amountEach * count)} '
      '${material?.name ?? each.materialId}';
}

/// What to build *this* out of, when what runs through it makes it matter.
///
/// The wire's advice names the whole table; a building cannot use the whole
/// table. It is put up out of the class the game asks for — 400 kg of refined
/// metal — so the useful sentence names which refined metals hold and which do
/// not, and says plainly when none of them do.
///
/// Null below the bare 75 °C, where the choice is free and a line about it
/// would be noise on every node in a cool build.
String _asPercent(double fraction) =>
    '${(fraction * 100).toStringAsFixed(0)} %';

String _degrees(double celsius) => '${celsius.toStringAsFixed(0)} °C';

String? _materialAdvice(
    PipelineController controller, ProcessSpec spec, String nodeId) {
  final celsius = controller.temperatures.hottestAt(nodeId);
  if (celsius == null || !Overheating.isTrouble(celsius)) return null;

  final verdicts = materialVerdicts(spec, controller.database, celsius);
  final hot = '${celsius.toStringAsFixed(0)} °C';

  String named(String id) => controller.database.item(id)?.name ?? id;
  String list(List<String> ids) {
    final names = ids.map(named).toList();
    if (names.length == 1) return names.single;
    return '${names.take(names.length - 1).join(', ')} or ${names.last}';
  }

  final lines = <String>[];
  for (final verdict in verdicts) {
    if (verdict.isFree) continue;
    final material = named(verdict.materialId).toLowerCase();
    lines.add(verdict.isImpossible
        // The one verdict here that means *do not build this*.
        ? '$hot: no $material holds that, so this overheats whatever you '
            'put it up with.'
        : '$hot: ${list(verdict.holds)}. '
            'The other $material gives up first.');
  }
  return lines.isEmpty ? null : lines.join('\n');
}

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
  return 'Hotter than the ${_degrees(commonOverheatCelsius)} a plain building '
      'tolerates, so what this is '
      'made of stops being a detail: ${named(survivors.first)} is the coolest '
      'that holds, up to ${named(survivors.last)}. Whether it actually cooks '
      'anything also depends on what it runs past, which this model cannot see.';
}
