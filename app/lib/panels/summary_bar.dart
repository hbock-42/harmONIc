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
    this.onMinimise,
    this.asBuilt,
    super.key,
  });

  /// Chooses the splits that make one of these totals as small as it can be.
  ///
  /// Null when there is nothing divided in the build, and then no figure
  /// offers it: without a choice there is nothing to choose. The offer belongs
  /// beside the number it is about, which is the only place somebody looking
  /// at a power figure they dislike would think to look.
  final void Function(BuildTotal total)? onMinimise;

  /// The build as it would really be placed, when that differs from the exact
  /// ratio. Null where nothing had to be rounded, which is most builds.
  final AsBuiltReport? asBuilt;

  final PipelineSolution solution;

  /// What the figures describe: the whole page, or the one build being worked
  /// in. Said out loud, because a total is meaningless without it.
  final String scope;
  final GameDatabase database;
  final RateDisplay rateDisplay;
  final VoidCallback onToggleRates;

  Map<String, double> get _materials =>
      solution.constructionMaterials(database);

  Set<String> get _unpriced => solution.unpricedBuildings(database);

  @override
  Widget build(BuildContext context) {
    final net = solution.netPowerWatts;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: OniSpacing.lg),
      decoration: BoxDecoration(
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
            trailing: _Minimise(total: BuildTotal.power, onMinimise: onMinimise),
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
            trailing: _Minimise(total: BuildTotal.heat, onMinimise: onMinimise),
          ),
          if (solution.totalFootprintTiles > 0) ...[
            const _Divider(),
            OniStat(
              label: 'floor',
              value: '${solution.totalFootprintTiles} tiles',
              trailing:
                  _Minimise(total: BuildTotal.floor, onMinimise: onMinimise),
            ),
          ],
          if (_materials.isNotEmpty || _unpriced.isNotEmpty) ...[
            const _Divider(),
            OniStat(
              label: 'to build',
              // A stock, not a flow: this is what you carry to the site once,
              // so it does not answer to the per-cycle toggle.
              // Mass only. Adding four gaskets to 1.2 t of ore gives a number
              // that is not a weight and not a count of anything.
              value: formatMass(_materials.entries
                  .where((e) => !(database.item(e.key)?.isCounted ?? false))
                  .fold<double>(0, (sum, e) => sum + e.value)),
              // A shopping list that quietly leaves a building out is worse
              // than no list. Nothing shipped is unpriced; a recipe you wrote
              // yourself has no cost until you give it one, and the total has
              // been silently ignoring those.
              trailing: _unpriced.isEmpty
                  ? null
                  : Text(
                      '+${_unpriced.length} NOT PRICED',
                      style: OniType.label.copyWith(color: OniColors.warning),
                    ),
            ),
          ],
          // What the build does once it is real. The figures beside this one
          // are the exact ratio; a critter cannot idle, so the thirteenth
          // Hatch you had to place eats like a Hatch and the ratio quietly
          // understates what you must supply.
          if (asBuilt case final AsBuiltReport report
              when report.drifts.isNotEmpty) ...[
            const _Divider(),
            _AsBuilt(
              report: report,
              database: database,
              rateDisplay: rateDisplay,
              onToggle: onToggleRates,
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


/// The "make this smaller" affordance beside a total.
///
/// One word, in the accent colour, because it sits in a bar that is already
/// full and it is an offer rather than a headline. There is no tooltip in this
/// app to explain it, so it has to read as what it does on its own: LEAST,
/// next to NET POWER.
///
/// It disappears entirely when there is nothing divided in the build. A
/// control that cannot change anything is worse than no control.
class _Minimise extends StatelessWidget {
  const _Minimise({required this.total, required this.onMinimise});

  final BuildTotal total;
  final void Function(BuildTotal total)? onMinimise;

  @override
  Widget build(BuildContext context) {
    final onMinimise = this.onMinimise;
    if (onMinimise == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => onMinimise(total),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Text('LEAST',
            style: OniType.label.copyWith(color: OniColors.accent)),
      ),
    );
  }
}


/// What rounding up costs the whole build.
///
/// A machine you half need idles; a critter, a plant or a Duplicant does not.
/// The inspector says what the spare one costs on the node that has it, and
/// this says what the build ends up eating and making because of all of them —
/// which is the figure you supply against, and not the one beside it.
class _AsBuilt extends StatelessWidget {
  const _AsBuilt({
    required this.report,
    required this.database,
    required this.rateDisplay,
    required this.onToggle,
  });

  final AsBuiltReport report;
  final GameDatabase database;
  final RateDisplay rateDisplay;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    // Worst first, which is how the engine sorts them.
    final worst = report.drifts.first;
    final item = database.item(worst.itemId);
    final more = report.drifts.length - 1;

    return OniStat(
      label: 'as built',
      value: '${worst.change > 0 ? '+' : '−'}'
          '${item?.formatRate(worst.change.abs(), rateDisplay) ?? worst.change.abs().toStringAsFixed(1)}'
          ' ${item?.name ?? worst.itemId}'
          '${more > 0 ? '  ·  and $more more' : ''}',
      // Eating more is the half worth noticing; making more is a surplus.
      valueColour: worst.change < 0 ? OniColors.warning : OniColors.text,
      onToggle: onToggle,
    );
  }
}
