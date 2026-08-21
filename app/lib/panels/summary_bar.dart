import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import '../design/tokens.dart';
import '../design/widgets.dart';

/// Always-visible totals for the whole build.
class SummaryBar extends StatelessWidget {
  const SummaryBar({
    required this.solution,
    required this.database,
    super.key,
  });

  final PipelineSolution solution;
  final GameDatabase database;

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
      child: Row(
        children: [
          OniStat(
            label: 'net power',
            value: Unit.watts.format(net),
            valueColour: net < -1e-6 ? OniColors.danger : OniColors.ok,
          ),
          const _Divider(),
          OniStat(
            label: 'heat',
            value: Unit.kdtuPerSecond.format(solution.totalHeatKdtu),
            valueColour: solution.totalHeatKdtu > 0
                ? OniColors.text
                : OniColors.ok,
          ),
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
          Expanded(
            child: _Flows(
              label: 'inputs needed',
              flows: solution.externalInputs,
              database: database,
            ),
          ),
          const _Divider(),
          Expanded(
            child: _Flows(
              label: 'outputs',
              flows: solution.externalOutputs,
              database: database,
            ),
          ),
        ],
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
  });

  final String label;
  final Map<String, double> flows;
  final GameDatabase database;

  @override
  Widget build(BuildContext context) {
    final entries = flows.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label.toUpperCase(), style: OniType.label),
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
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: OniItemColors.ofItem(item),
                      ),
                    ),
                    Text(
                      '${item?.name ?? entries[i].key}  '
                      '${(item?.unit ?? Unit.gramsPerSecond).format(entries[i].value, precision: 1)}',
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
