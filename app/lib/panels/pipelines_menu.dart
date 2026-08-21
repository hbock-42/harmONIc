import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import '../design/tokens.dart';
import '../design/widgets.dart';
import '../state/library_controller.dart';
import '../state/pipeline_controller.dart';
import '../state/workspace_controller.dart';

/// The list of saved pipelines: open one, copy one, throw one away.
class PipelinesMenu extends StatefulWidget {
  const PipelinesMenu({
    required this.workspace,
    required this.controller,
    required this.library,
    required this.rateDisplay,
    required this.onClose,
    super.key,
  });

  final WorkspaceController workspace;

  /// The open build, for the summary — which is about what is on screen now
  /// rather than about what was last saved.
  final PipelineController controller;

  /// Where a build saved as a recipe goes, and where the palette reads from.
  final LibraryController library;
  final RateDisplay rateDisplay;
  final VoidCallback onClose;

  static const double width = 280;

  @override
  State<PipelinesMenu> createState() => _PipelinesMenuState();
}

class _PipelinesMenuState extends State<PipelinesMenu> {
  String? _message;

  WorkspaceController get workspace => widget.workspace;
  VoidCallback get onClose => widget.onClose;

  /// Copies the open build as a one-line code, which is the format that
  /// survives a forum post or a chat message intact.
  Future<void> _copy() async {
    final id = workspace.currentId;
    final pipeline = id == null ? null : workspace.pipelineFor(id);
    if (pipeline == null) return;
    await Clipboard.setData(
      ClipboardData(text: PipelineShareCode.encode(pipeline)),
    );
    if (mounted) setState(() => _message = 'Share code copied.');
  }

  /// The whole build as text, for pasting somewhere that is not this app.
  ///
  /// The engine has been able to write this since before there was a canvas
  /// and nobody could ever see it. A share code is for another copy of this
  /// app; this is for a forum post, a note, or somebody who just wants to know
  /// what to build.
  Future<void> _copySummary() async {
    final controller = widget.controller;
    final report = formatSolution(
      controller.focusedSolution,
      controller.database,
      perCycle: widget.rateDisplay == RateDisplay.perCycle,
    );
    await Clipboard.setData(ClipboardData(
      text: '${controller.pipeline.name}\n\n$report',
    ));
    if (mounted) setState(() => _message = 'Summary copied.');
  }

  /// Saves the open build as a recipe, so it can be one node in a bigger plan.
  Future<void> _saveAsRecipe() async {
    final controller = widget.controller;
    final name = controller.pipeline.name;
    try {
      final spec = specFromBuild(
        pipeline: controller.pipeline,
        database: controller.database,
        solution: controller.solution,
        only: controller.focusedBuild,
        id: 'build_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}',
        name: name,
      );
      await widget.library.save(spec);
      if (mounted) {
        setState(() => _message =
            '"$name" is in the palette under My builds. Close this and search '
            'for it to place one.');
      }
    } on StateError catch (e) {
      if (mounted) setState(() => _message = e.message);
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    try {
      await workspace.import(PipelineShareCode.decode(text));
      onClose();
    } on FormatException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } on Object {
      if (mounted) {
        setState(() => _message = 'That build could not be read.');
      }
    }
  }

  bool _templatesOpen = false;
  bool _reuseOpen = false;

  /// Starting points, folded away.
  ///
  /// A blank canvas is the right default — most opens are to keep working on
  /// something — but a blank canvas is also the worst way to learn what the app
  /// can say, so the builds worth copying are one click behind it.
  Widget _templates() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            label: 'Start from a build',
            detail: '${pipelineTemplates.length}',
            open: _templatesOpen,
            onTap: () => setState(() => _templatesOpen = !_templatesOpen),
          ),
          if (_templatesOpen)
            for (final template in pipelineTemplates)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await widget.workspace.createFromTemplate(template);
                  widget.onClose();
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      OniSpacing.md, 0, OniSpacing.md, OniSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(template.name,
                          style: OniType.body.copyWith(color: OniColors.text)),
                      Text(
                        template.summary,
                        style: OniType.body.copyWith(
                            fontSize: 11.5, color: OniColors.textFaint),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      );

  /// Turning this build into something you can place in another one.
  ///
  /// It was a button called "Save as recipe" sitting between "Copy code" and
  /// "Paste build", which told you neither what it did nor where the result
  /// went. Said properly it is a small idea: this whole build, as one node.
  Widget _reuse() {
    final controller = widget.controller;
    final name = controller.pipeline.name;
    final scoped = controller.focusedSolution;
    final ready = scoped.status == SolveStatus.solved;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          label: 'Use this build in another',
          open: _reuseOpen,
          onTap: () => setState(() => _reuseOpen = !_reuseOpen),
        ),
        if (_reuseOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                OniSpacing.md, 0, OniSpacing.md, OniSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
            ready
                ? 'Adds "$name" to the palette as a single node, under '
                    'My builds. Place it in another plan and everything in '
                    'here scales with it — what goes in and out is what '
                    'crosses its edges today.'
                : 'Give this build an amount first. Without one there is no '
                    'telling how big a copy of it would be.',
                  style: OniType.body
                      .copyWith(fontSize: 11.5, color: OniColors.textFaint),
                ),
                const SizedBox(height: OniSpacing.sm),
                OniButton(
                  label: 'Add to palette',
                  compact: true,
                  onPressed: workspace.currentId == null || !ready
                      ? null
                      : _saveAsRecipe,
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final saved = workspace.saved;
    return Container(
      width: PipelinesMenu.width,
      constraints: const BoxConstraints(maxHeight: 420),
      decoration: BoxDecoration(
        color: OniColors.surfaceRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: OniColors.borderStrong),
        boxShadow: const [
          BoxShadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(OniSpacing.md),
            child: Row(
              children: [
                Expanded(child: Text('PIPELINES', style: OniType.label)),
                OniButton(
                  label: '+ New',
                  compact: true,
                  tone: OniButtonTone.accent,
                  onPressed: () async {
                    await workspace.createNew();
                    onClose();
                  },
                ),
              ],
            ),
          ),
          const _MenuRule(key: menuRuleKey),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                OniSpacing.md, OniSpacing.sm, OniSpacing.md, OniSpacing.sm),
            child: Wrap(
              spacing: OniSpacing.sm,
              runSpacing: OniSpacing.sm,
              children: [
                OniButton(
                  label: 'Copy code',
                  compact: true,
                  onPressed: workspace.currentId == null ? null : _copy,
                ),
                OniButton(
                  label: 'Copy summary',
                  compact: true,
                  onPressed:
                      workspace.currentId == null ? null : _copySummary,
                ),
                OniButton(
                  label: 'Paste build',
                  compact: true,
                  onPressed: _paste,
                ),
              ],
            ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  OniSpacing.md, 0, OniSpacing.md, OniSpacing.sm),
              child: Text(
                _message!,
                style: OniType.body
                    .copyWith(fontSize: 11.5, color: OniColors.textMuted),
              ),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: OniSpacing.sm),
              children: [
                // Inside the scroller rather than above it: with the section
                // expanded, the menu is taller than the window it opens in.
                const _MenuRule(key: menuRuleKey),
                _templates(),
                _reuse(),
                const _MenuRule(key: menuRuleKey),
                Padding(
                  padding: const EdgeInsets.fromLTRB(OniSpacing.md,
                      OniSpacing.sm, OniSpacing.md, OniSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('SAVED HERE', style: OniType.label),
                      ),
                      Text('${saved.length}',
                          style: OniType.numberSmall
                              .copyWith(color: OniColors.textFaint)),
                    ],
                  ),
                ),
                for (final summary in saved)
                  _Row(
                    summary: summary,
                    current: summary.id == workspace.currentId,
                    onOpen: () async {
                      await workspace.open(summary.id);
                      onClose();
                    },
                    onDuplicate: () async {
                      await workspace.duplicate(summary.id);
                      onClose();
                    },
                    onDelete: () async => workspace.delete(summary.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({
    required this.summary,
    required this.current,
    required this.onOpen,
    required this.onDuplicate,
    required this.onDelete,
  });

  final PipelineSummary summary;
  final bool current;
  final VoidCallback onOpen;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onOpen,
          child: Container(
            color: _hover ? OniColors.surfaceHover : null,
            padding: const EdgeInsets.symmetric(
                horizontal: OniSpacing.md, vertical: 7),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 22,
                  color: widget.current
                      ? OniColors.accent
                      : const Color(0x00000000),
                ),
                const SizedBox(width: OniSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.summary.name,
                        style: OniType.body.copyWith(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text('${widget.summary.nodeCount} nodes',
                          style: OniType.numberSmall),
                    ],
                  ),
                ),
                if (_hover) ...[
                  GestureDetector(
                    onTap: widget.onDuplicate,
                    child: Text('copy',
                        style: OniType.numberSmall
                            .copyWith(color: OniColors.accent)),
                  ),
                  const SizedBox(width: OniSpacing.sm),
                  GestureDetector(
                    onTap: widget.onDelete,
                    child: Text('delete',
                        style: OniType.numberSmall
                            .copyWith(color: OniColors.danger)),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

/// A row that opens and closes a section of the menu.
///
/// It was a line of small grey capitals with a triangle in front of it, which
/// looked exactly like the labels above things that are not clickable. A
/// section you can open should look like a row you can press: full width, a
/// hover, a chevron with room around it, and text bright enough to read as
/// something rather than as a caption for something else.
class _SectionHeader extends StatefulWidget {
  const _SectionHeader({
    required this.label,
    required this.open,
    required this.onTap,
    this.detail,
  });

  final String label;
  final String? detail;
  final bool open;
  final VoidCallback onTap;

  @override
  State<_SectionHeader> createState() => _SectionHeaderState();
}

class _SectionHeaderState extends State<_SectionHeader> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            color: _hover ? OniColors.surfaceHover : null,
            padding: const EdgeInsets.symmetric(
                horizontal: OniSpacing.md, vertical: OniSpacing.sm),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  child: Text(
                    widget.open ? '⌄' : '›',
                    style: OniType.body.copyWith(
                      color: OniColors.textMuted,
                      height: 1,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    widget.label,
                    style: OniType.body.copyWith(color: OniColors.text),
                  ),
                ),
                if (widget.detail != null)
                  Text(widget.detail!,
                      style: OniType.numberSmall
                          .copyWith(color: OniColors.textFaint)),
              ],
            ),
          ),
        ),
      );
}

/// Named so a test can check the sections really are ruled apart.
const Key menuRuleKey = ValueKey('menu-rule');

/// A rule between two sections of the menu, because five kinds of thing in one
/// column with even spacing reads as one kind of thing.
class _MenuRule extends StatelessWidget {
  const _MenuRule({super.key});

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: OniSpacing.md),
        color: OniColors.border,
      );
}
