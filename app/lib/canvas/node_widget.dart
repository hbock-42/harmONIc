import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import '../design/item_glyph.dart';
import '../design/tokens.dart';
import '../state/pipeline_controller.dart';
import 'geometry.dart';

/// A node on the canvas: what it is, how many you need, and every port as a
/// dot you can drag a wire out of.
class NodeWidget extends StatelessWidget {
  const NodeWidget({
    required this.node,
    required this.spec,
    required this.controller,
    required this.selected,
    required this.rateDisplay,
    required this.onPortTap,
    required this.onPortDragStart,
    required this.onPortDragUpdate,
    required this.onPortDragEnd,
    required this.highlightPort,
    super.key,
  });

  final PipelineNode node;
  final ProcessSpec spec;
  final PipelineController controller;
  final bool selected;
  final RateDisplay rateDisplay;
  final void Function(PortRef ref, Offset globalPosition) onPortTap;
  final void Function(PortRef ref, Offset globalPosition) onPortDragStart;
  final void Function(Offset globalPosition) onPortDragUpdate;
  final void Function(Offset globalPosition) onPortDragEnd;

  /// True when a wire is being dragged and this port is a legal drop target.
  final bool Function(PortRef ref) highlightPort;

  bool get _isBoundary =>
      spec.kind.isBoundary;

  @override
  Widget build(BuildContext context) {
    final result = controller.solution.nodes[node.id];
    final pin = controller.pinFor(node.id);
    final size = NodeLayout.sizeOf(spec);
    final accent = _accentColour();

    return SizedBox(
      width: size.width,
      height: size.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: OniColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? OniColors.accent : OniColors.border,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0x66000000),
              blurRadius: selected ? 16 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(accent, result, pin),
            ..._portRows(),
            _footer(result),
          ],
        ),
      ),
    );
  }

  Color _accentColour() {
    if (_isBoundary) {
      final port = spec.ports.isEmpty ? null : spec.ports.first;
      return OniItemColors.ofItem(
          port == null ? null : controller.database.item(port.itemId));
    }
    return OniColors.textFaint;
  }

  Widget _header(Color accent, NodeResult? result, Pin? pin) => SizedBox(
        height: NodeLayout.headerHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 8, 5),
          child: Row(
            children: [
              Container(width: 3, height: 26, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      node.label ?? spec.name,
                      style: OniType.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (result != null)
                      Text(
                        _countLabel(result),
                        style: OniType.numberSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Scaled down rather than spilling: a node with three things to
              // say is narrower than the three things, and a header that
              // overflows is a header that has lost one of them.
              if (_marks() case final marks when marks.isNotEmpty)
                // No flex of its own -- a Flexible with the default flex of 1
                // splits the free space with the name beside it, which is what
                // left VENT stranded in the middle of one node and SET hard
                // right on the next -- and a ceiling, because a flex-0 child
                // is laid out unbounded and would rather overflow than shrink.
                ConstrainedBox(
                  constraints:
                      BoxConstraints(maxWidth: NodeLayout.sizeOf(spec).width / 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (index, (label, colour))
                            in marks.indexed) ...[
                          if (index > 0) const SizedBox(width: 3),
                          _Mark(label, colour),
                        ],
                        // Only where something follows: a gap after the last
                        // one would leave the strip short of the edge that
                        // SET sits on.
                        if (pin != null) const SizedBox(width: 3),
                      ],
                    ),
                  ),
                ),
              if (pin != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: OniColors.accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'SET',
                    style: OniType.numberSmall.copyWith(
                      color: OniColors.accent,
                      fontSize: 9,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );

  /// Boundary nodes are measured in g/s, real buildings in units of themselves.
  String _countLabel(NodeResult result) {
    // A count the solve could not work out is not zero, and printing zero says
    // it is. Somebody looking at a spare-power outlet reading "0.0 W" reads
    // that as "no spare power" rather than as "nothing here sets the size" —
    // reported by somebody who could not see how much power they had spare,
    // and the honest answer was that the app did not know either.
    if (controller.solution.freeNodeIds.contains(node.id)) return 'any amount';
    if (_isBoundary) {
      final port = spec.ports.isEmpty ? null : spec.ports.first;
      final item = port == null ? null : controller.database.item(port.itemId);
      return item?.formatRate(result.count, rateDisplay, precision: 1) ??
          Unit.gramsPerSecond.format(result.count, precision: 1);
    }
    if (result.count <= 0) return '—';
    return '${result.count.toStringAsFixed(2)} ×  ·  build ${result.wholeCount}';
  }

  List<Widget> _portRows() {
    final inputs = spec.inputs.toList();
    final outputs = spec.outputs.toList();
    return [
      for (var row = 0; row < NodeLayout.rowCount(spec); row++)
        SizedBox(
          height: NodeLayout.portRowHeight,
          child: Row(
            children: [
              Expanded(
                child: row < inputs.length
                    ? _portCell(inputs[row], isInput: true)
                    : const SizedBox.shrink(),
              ),
              Expanded(
                child: row < outputs.length
                    ? _portCell(outputs[row], isInput: false)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _portCell(Port port, {required bool isInput}) {
    // Named for what is really running through it: a refinery set to copper
    // says Copper Ore and Copper, not Metal Ore and Refined Metal — and one
    // fed by an Iron Ore supply says Iron Ore and Iron without being told.
    final item = controller.database.item(itemFlowingThrough(
        controller.database,
        controller.pipeline,
        node,
        controller.specOf(node),
        port));
    final colour = OniItemColors.ofItem(item);
    final ref = PortRef(node.id, port.id);
    final balance = _balanceFor(ref);
    final highlighted = highlightPort(ref);

    final label = Text(
      item?.name ?? port.itemId,
      style: OniType.numberSmall.copyWith(
        color: highlighted ? OniColors.text : OniColors.textMuted,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: isInput ? TextAlign.left : TextAlign.right,
    );

    final dot = _PortDot(
      colour: colour,
      category: item?.category ?? ItemCategory.other,
      highlighted: highlighted,
      unmet: balance != null && (balance.isExternalInput || balance.isSurplus),
      onTap: (global) => onPortTap(ref, global),
      onDragStart: (global) => onPortDragStart(ref, global),
      onDragUpdate: onPortDragUpdate,
      onDragEnd: onPortDragEnd,
    );

    return Row(
      mainAxisAlignment: isInput ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: isInput
          ? [dot, const SizedBox(width: 3), Flexible(child: label)]
          : [Flexible(child: label), const SizedBox(width: 3), dot],
    );
  }

  /// What this node is quietly doing that nothing else on the canvas says.
  ///
  /// Asked for: "would it be possible to mark any blocks that have venting
  /// toggled on, spare, or needs-supply details shown when you click into
  /// them? Realising that was causing imbalance allowed me to diagnose and
  /// correct these pipelines." All three are decisions or loose ends visible
  /// only to somebody who opened the node and read down it.
  List<(String, Color)> _marks() {
    final marks = <(String, Color)>[];
    if (node.ventedPorts.isNotEmpty) {
      // Amber, because this one is a choice with consequences: something is
      // being thrown away on purpose and the balance sheet knows it.
      marks.add(('VENT', OniColors.warning));
    }
    // The mirror of it, on the way in. A ranch nobody grooms lays a twelfth of
    // the eggs, and until this the card looked exactly like one that was
    // groomed -- the port sat there unwired, which is what a port waiting for
    // a supply looks like too. Two ranches side by side and nothing to tell
    // them apart, on a difference of twelve times.
    if (node.portsSwitchedOff.isNotEmpty) {
      marks.add(('OFF', OniColors.warning));
    }
    var spare = false;
    var needs = false;
    var over = false;
    for (final balance in controller.solution.portBalances) {
      if (balance.ref.nodeId != node.id) continue;
      // More is being taken from this port than it makes. Reported: a refinery
      // making 408 g/s of petroleum with 2 800 drawn off it showed nothing at
      // all, while the node it fed lost its NEEDS and looked settled. It is
      // the commonest reason a build will not solve and it was the one thing
      // these marks did not say.
      if (balance.direction == PortDirection.output &&
          balance.linkedRate > balance.rate + 1e-6) {
        over = true;
      }
      // Already said, and better: venting is a choice and this is a leftover.
      if (node.ventsPort(balance.ref.portId)) continue;
      // Heat leaving a building is where heat goes. Almost nothing wires it
      // up, so marking it would put SPARE on nearly every node in the app.
      if (balance.itemId == WellKnownItems.heat) continue;
      // Not on a supply or an output node: drawing from outside the build is
      // the whole of what those are for, and a mark that is true of every one
      // of them says nothing about any of them. Being over-drawn is different
      // -- a supply told it has one kilogram a second and asked for four and a
      // half is exactly worth saying.
      if (_isBoundary) continue;
      if (balance.isSurplus) spare = true;
      if (balance.isExternalInput) needs = true;
    }
    // First, because it is the only one of these that means something is
    // wrong rather than merely open.
    if (over) marks.insert(0, ('OVER', OniColors.danger));
    if (spare) marks.add(('SPARE', OniColors.textMuted));
    if (needs) marks.add(('NEEDS', OniColors.textMuted));
    return marks;
  }

  PortBalance? _balanceFor(PortRef ref) {
    for (final b in controller.solution.portBalances) {
      if (b.ref == ref) return b;
    }
    return null;
  }

  Widget _footer(NodeResult? result) {
    if (result == null || _isBoundary) {
      return const SizedBox(height: NodeLayout.footerHeight);
    }
    final utilisation = result.utilisation.clamp(0.0, 1.0);
    return SizedBox(
      height: NodeLayout.footerHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
        child: Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 4,
                  child: Stack(
                    children: [
                      ColoredBox(
                          color: OniColors.surfaceRaised,
                          child: SizedBox.expand()),
                      FractionallySizedBox(
                        widthFactor: utilisation == 0 ? 0.0001 : utilisation,
                        child: ColoredBox(
                          color: utilisation > 0.95
                              ? OniColors.ok
                              : OniColors.accent,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              result.wholeCount == 0
                  ? '—'
                  : '${(utilisation * 100).toStringAsFixed(0)}%',
              style: OniType.numberSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// The draggable dot. Deliberately larger than it looks, so it is easy to grab.
class _PortDot extends StatefulWidget {
  const _PortDot({
    required this.colour,
    required this.category,
    required this.highlighted,
    required this.unmet,
    required this.onTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final Color colour;
  final ItemCategory category;
  final bool highlighted;
  final bool unmet;
  final void Function(Offset globalPosition) onTap;
  final void Function(Offset globalPosition) onDragStart;
  final void Function(Offset globalPosition) onDragUpdate;
  final void Function(Offset globalPosition) onDragEnd;

  @override
  State<_PortDot> createState() => _PortDotState();
}

class _PortDotState extends State<_PortDot> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final radius = NodeLayout.portDotRadius +
        (_hovering || widget.highlighted ? 1.5 : 0);
    return MouseRegion(
      cursor: SystemMouseCursors.precise,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Same as the card: scrolling over a port dot should scroll.
        supportedDevices: kGrabDevices,
        onTapUp: (d) => widget.onTap(d.globalPosition),
        onPanStart: (d) => widget.onDragStart(d.globalPosition),
        onPanUpdate: (d) => widget.onDragUpdate(d.globalPosition),
        onPanEnd: (d) => widget.onDragEnd(d.globalPosition),
        child: SizedBox(
          width: 18,
          height: NodeLayout.portRowHeight,
          child: Center(
            // Shape says what kind of thing it is, and the ring says nobody is
            // supplying it. Both were carried by colour and fill alone before,
            // which left the two signals fighting over one dot.
            child: SizedBox(
              width: radius * 2.6,
              height: radius * 2.6,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.unmet)
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: widget.colour, width: 1.2),
                      ),
                    ),
                  OniItemGlyph(
                    category: widget.category,
                    size: radius * 1.7,
                    colour: widget.colour,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One thing a node is doing that its figures do not say.
class _Mark extends StatelessWidget {
  const _Mark(this.label, this.colour);

  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: OniType.numberSmall.copyWith(color: colour, fontSize: 9),
        ),
      );
}
