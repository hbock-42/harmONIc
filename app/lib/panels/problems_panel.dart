import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import '../design/tokens.dart';
import '../design/widgets.dart';
import '../state/pipeline_controller.dart';

/// Solver complaints, phrased as things to do and wired to the doing.
///
/// The commonest one by far is "not enough pins", whose answer is always to pin
/// one of a handful of nodes — so those nodes are offered as buttons rather than
/// named in a sentence and left for the reader to go and find.
class ProblemsBanner extends StatefulWidget {
  const ProblemsBanner({required this.controller, super.key});

  final PipelineController controller;

  @override
  State<ProblemsBanner> createState() => _ProblemsBannerState();
}

class _ProblemsBannerState extends State<ProblemsBanner> {
  bool _expanded = false;

  static const int _collapsedCount = 2;

  PipelineController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final solution = controller.solution;
    final blocking =
        solution.issues.where((i) => i.severity != IssueSeverity.info).toList();
    if (blocking.isEmpty) return const SizedBox.shrink();

    // Info notes are the "here is how to fix it" half of an error and are worth
    // nothing if the banner hides them.
    final issues = [
      ...blocking,
      ...solution.issues.where((i) => i.severity == IssueSeverity.info),
    ];
    final worst =
        blocking.any((i) => i.isError) ? OniColors.danger : OniColors.warning;
    final shown = _expanded ? issues : issues.take(_collapsedCount).toList();
    final hidden = issues.length - shown.length;

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
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final issue in shown) _IssueRow(
                    issue: issue,
                    controller: controller,
                  ),
                ],
              ),
            ),
          ),
          if (solution.status == SolveStatus.underdetermined &&
              solution.freeNodeIds.isNotEmpty)
            _PinSuggestions(controller: controller),
          if (hidden > 0 || _expanded)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text(
                    _expanded ? 'show less' : 'and $hidden more',
                    style:
                        OniType.numberSmall.copyWith(color: OniColors.accent),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.issue, required this.controller});

  final PipelineIssue issue;
  final PipelineController controller;

  @override
  Widget build(BuildContext context) => Padding(
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
                color: switch (issue.severity) {
                  IssueSeverity.error => OniColors.danger,
                  IssueSeverity.warning => OniColors.warning,
                  IssueSeverity.info => OniColors.textFaint,
                },
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
                onTap: () => controller.selectNode(issue.nodeId!),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Text('show',
                      style: OniType.numberSmall
                          .copyWith(color: OniColors.accent)),
                ),
              ),
          ],
        ),
      );
}

/// The nodes worth giving an amount, as buttons. Clicking one selects it, which
/// puts the cursor in the field that fixes the problem.
class _PinSuggestions extends StatelessWidget {
  const _PinSuggestions({required this.controller});

  final PipelineController controller;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Wrap(
          spacing: OniSpacing.sm,
          runSpacing: OniSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('GIVE AN AMOUNT FOR', style: OniType.label),
            for (final id in controller.solution.freeNodeIds.take(6))
              if (controller.pipeline.node(id) case final PipelineNode node)
                OniButton(
                  label: controller.specOf(node).name,
                  compact: true,
                  tone: OniButtonTone.accent,
                  onPressed: () => controller.selectNodeForAmount(id),
                ),
          ],
        ),
      );
}
