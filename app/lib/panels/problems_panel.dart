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
    final blocking = solution.issues
        .where((i) => i.severity != IssueSeverity.info)
        .toList();
    final notice = controller.notice;
    if (blocking.isEmpty) {
      return notice == null ? const SizedBox.shrink() : _Notice(notice);
    }

    // Info notes are the "here is how to fix it" half of an error and are worth
    // nothing if the banner hides them.
    final issues = [
      ...blocking,
      ...solution.issues.where((i) => i.severity == IssueSeverity.info),
    ];
    final worst = blocking.any((i) => i.isError)
        ? OniColors.danger
        : OniColors.warning;
    final shown = _expanded ? issues : issues.take(_collapsedCount).toList();
    final hidden = issues.length - shown.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: OniSpacing.lg,
        vertical: OniSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: worst.withValues(alpha: 0.1),
        border: Border(bottom: BorderSide(color: worst.withValues(alpha: 0.4))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notice != null) _Notice(notice, inset: true),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final issue in shown)
                    _IssueRow(issue: issue, controller: controller),
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
                    style: OniType.numberSmall.copyWith(
                      color: OniColors.accent,
                    ),
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
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 13),
          child: _Places(issue: issue, controller: controller),
        ),
      ],
    ),
  );
}

/// Something the app did on the reader's behalf, said out loud.
///
/// Doing a thing quietly and doing it visibly are not the same, and this is
/// the difference. It goes at the next edit; there is nothing to acknowledge.
class _Notice extends StatelessWidget {
  const _Notice(this.text, {this.inset = false});

  final String text;
  final bool inset;

  @override
  Widget build(BuildContext context) {
    final line = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1, right: OniSpacing.sm),
          child: Text('✓', style: OniType.label.copyWith(color: OniColors.ok)),
        ),
        Expanded(
          child: Text(text, style: OniType.body.copyWith(fontSize: 12)),
        ),
      ],
    );
    if (inset) {
      return Padding(
        padding: const EdgeInsets.only(bottom: OniSpacing.sm),
        child: line,
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: OniSpacing.lg,
        vertical: OniSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: OniColors.ok.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: OniColors.ok.withValues(alpha: 0.4)),
        ),
      ),
      child: line,
    );
  }
}

/// Where a message points, as something to click.
///
/// A sentence naming six ports is six places to look, and every one of them is
/// somewhere on a canvas bigger than the window. Reported: "if I manage to find
/// the correct one that's overflowing ... it's hard to tell which one is the
/// problem" — half of that was the app not saying which, and the other half was
/// having to go and find it.
/// What to call the button that shows [place], so a test can name the thing it
/// means to click rather than "the first button in the banner".
String showKeyFor(IssueTarget place) =>
    'show:${place.edgeId ?? place.nodeId}.${place.portId ?? ''}';

class _Places extends StatelessWidget {
  const _Places({required this.issue, required this.controller});

  final PipelineIssue issue;
  final PipelineController controller;

  void _go(IssueTarget place) {
    if (place.edgeId case final String edgeId) {
      controller.select(EdgeSelection(edgeId));
      return;
    }
    if (place.nodeId case final String nodeId) controller.selectNode(nodeId);
  }

  @override
  Widget build(BuildContext context) {
    // Deduplicated: a node with two over-committed ports is named twice, and
    // two buttons that go to the same place are one button.
    final seen = <String>{};
    final places = [
      for (final place in issue.places)
        if (seen.add(showKeyFor(place))) place,
    ];
    if (places.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Wrap(
        spacing: OniSpacing.xs,
        runSpacing: OniSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // The change itself, where the message knows one: four wires to set
          // by hand is four trips, and the reader has already been told what
          // to do. One step on the undo stack, so it is a shortcut and not an
          // authority.
          if (issue.fix case final IssueFix fix)
            if (!fix.isEmpty)
              OniButton(
                key: ValueKey('fix:${issue.nodeId ?? issue.edgeId}'),
                label: fix.label,
                compact: true,
                tone: OniButtonTone.accent,
                onPressed: () => controller.applyFix(fix),
              ),
          Text(
            places.length == 1 ? 'SHOW ME' : 'SHOW ME ONE OF',
            style: OniType.label,
          ),
          for (final place in places.take(8))
            OniButton(
              key: ValueKey(showKeyFor(place)),
              label: place.label,
              compact: true,
              onPressed: () => _go(place),
            ),
        ],
      ),
    );
  }
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
