import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import '../design/tokens.dart';
import '../state/pipeline_controller.dart';

/// Solver complaints, phrased as things to do rather than error codes.
class ProblemsBanner extends StatelessWidget {
  const ProblemsBanner({required this.controller, super.key});

  final PipelineController controller;

  @override
  Widget build(BuildContext context) {
    final solution = controller.solution;
    final issues = solution.issues
        .where((i) => i.severity != IssueSeverity.info)
        .toList();
    if (issues.isEmpty) return const SizedBox.shrink();

    final worst = issues.any((i) => i.isError)
        ? OniColors.danger
        : OniColors.warning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: OniSpacing.lg, vertical: OniSpacing.sm),
      decoration: BoxDecoration(
        color: worst.withValues(alpha: 0.1),
        border: Border(bottom: BorderSide(color: worst.withValues(alpha: 0.4))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final issue in issues.take(3))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(top: 6, right: OniSpacing.sm),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: issue.isError ? OniColors.danger : OniColors.warning,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      issue.message,
                      style: OniType.body.copyWith(fontSize: 12),
                    ),
                  ),
                  if (issue.nodeId != null)
                    GestureDetector(
                      onTap: () =>
                          controller.select(NodeSelection(issue.nodeId!)),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Text('show',
                            style: OniType.numberSmall
                                .copyWith(color: OniColors.accent)),
                      ),
                    ),
                ],
              ),
            ),
          if (issues.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('and ${issues.length - 3} more',
                  style: OniType.numberSmall),
            ),
        ],
      ),
    );
  }
}
