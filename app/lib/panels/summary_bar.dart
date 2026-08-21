import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import '../design/item_glyph.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';

/// Always-visible totals for the whole build.
class SummaryBar extends StatelessWidget {
  const SummaryBar({
    required this.solution,
    required this.scope,
    required this.database,
    required this.rateDisplay,
    required this.onToggleRates,
    super.key,
  });

  final PipelineSolution solution;

  /// What the figures describe: the whole page, or the one build being worked
  /// in. Said out loud, because a total is meaningless without it.
  final String scope;
  final GameDatabase database;
  final RateDisplay rateDisplay;
  final VoidCallback onToggleRates;

  Map<String, double> get _materials =>
      solution.constructionMaterials(database);

  @override
  Widget build(BuildContext context) {
    final net = solution.netPowerWatts;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: OniSpacing.lg),
      decoration: const BoxDecoration(
        color: OniColors.surface,
        border: Border(top: BorderSide(color: OniColors.border)),
      ),
      // The whole bar scrolls sideways rather than overflowing. There is no
      // width at which all of this fits — a build with power, heat, floor,
      // labour, materials and two lists of flows needs about 1 300 px — and a
      // total that has fallen off the edge is worse than one you have to reach
      // for. The toolbar above already works this way.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: OniSpacing.lg),
            child: Text(scope.toUpperCase(), style: OniType.label),
          ),
          OniStat(
            label: 'net power',
            value: database.itemOrThrow(WellKnownItems.power)
                .formatRate(net, rateDisplay),
            valueColour: net < -1e-6 ? OniColors.danger : OniColors.ok,
            onToggle: onToggleRates,
          ),
          const _Divider(),
          OniStat(
            label: 'heat',
            value: database.itemOrThrow(WellKnownItems.heat)
                .formatRate(solution.totalHeatKdtu, rateDisplay),
            onToggle: onToggleRates,
            valueColour: solution.totalHeatKdtu > 0
                ? OniColors.text
                : OniColors.ok,
          ),
          if (solution.totalFootprintTiles > 0) ...[
            const _Divider(),
            OniStat(
              label: 'floor',
              value: '${solution.totalFootprintTiles} tiles',
            ),
          ],
          if (_materials.isNotEmpty) ...[
            const _Divider(),
            OniStat(
              label: 'to build',
              // A stock, not a flow: this is what you carry to the site once,
              // so it does not answer to the per-cycle toggle.
              value: formatMass(
                  _materials.values.reduce((a, b) => a + b)),
            ),
          ],
          if (solution.dupeLabourSecondsPerCycle > 0) ...[
            const _Divider(),
            OniStat(
              label: 'dupe time',
              // 600 s is one Duplicant's whole cycle, which is how the rest of
              // the data books labour too.
              value: '${solution.dupeLabourSecondsPerCycle.toStringAsFixed(0)} s'
                  '  ·  ${(solution.dupeLabourSecondsPerCycle / secondsPerCycle).toStringAsFixed(2)} dupes',
              valueColour: solution.dupeLabourSecondsPerCycle > secondsPerCycle
                  ? OniColors.warning
                  : OniColors.text,
            ),
          ],
          const _Divider(),
          SizedBox(
            width: 260,
            child: _Flows(
              label: 'inputs needed',
              flows: solution.externalInputs,
              database: database,
              rateDisplay: rateDisplay,
              onToggle: onToggleRates,
            ),
          ),
          const _Divider(),
          SizedBox(
            width: 260,
            child: _Flows(
              label: 'outputs',
              flows: solution.externalOutputs,
              database: database,
              rateDisplay: rateDisplay,
              onToggle: onToggleRates,
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: OniSpacing.lg),
        color: OniColors.border,
      );
}

class _Flows extends StatelessWidget {
  const _Flows({
    required this.label,
    required this.flows,
    required this.database,
    required this.rateDisplay,
    required this.onToggle,
  });

  final String label;
  final Map<String, double> flows;
  final GameDatabase database;
  final RateDisplay rateDisplay;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final entries = flows.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        // One line, whatever the width. Squeezed narrow enough, "inputs
        // needed" wrapped to three lines and pushed the rates themselves out
        // of the bar — an overflow here is a total nobody can see.
        Text(
          label.toUpperCase(),
          style: OniType.label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
        ),
        const SizedBox(height: 3),
        if (entries.isEmpty)
          Text('—', style: OniType.number)
        else
          SizedBox(
            height: 16,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(width: OniSpacing.md),
              itemBuilder: (context, i) {
                final item = database.item(entries[i].key);
                return Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: OniItemGlyph.ofItem(item, size: 7),
                    ),
                    OniRate(
                      text: '${item?.name ?? entries[i].key}  '
                          '${item?.formatRate(entries[i].value, rateDisplay, precision: 1) ?? entries[i].value.toStringAsFixed(1)}',
                      onToggle: onToggle,
                      style: OniType.numberSmall
                          .copyWith(color: OniColors.text),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
