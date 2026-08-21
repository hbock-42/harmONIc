import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import '../design/tokens.dart';
import '../design/widgets.dart';
import '../state/pipeline_controller.dart';
import '../state/workspace_controller.dart';

/// The list of saved pipelines: open one, copy one, throw one away.
class PipelinesMenu extends StatefulWidget {
  const PipelinesMenu({
    required this.workspace,
    required this.controller,
    required this.rateDisplay,
    required this.onClose,
    super.key,
  });

  final WorkspaceController workspace;

  /// The open build, for the summary — which is about what is on screen now
  /// rather than about what was last saved.
  final PipelineController controller;
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

  /// Starting points, folded away.
  ///
  /// A blank canvas is the right default — most opens are to keep working on
  /// something — but a blank canvas is also the worst way to learn what the app
  /// can say, so the builds worth copying are one click behind it.
  Widget _templates() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _templatesOpen = !_templatesOpen),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  OniSpacing.md, 0, OniSpacing.md, OniSpacing.sm),
              child: Text(
                _templatesOpen ? '▾ START FROM A BUILD' : '▸ START FROM A BUILD',
                style: OniType.label,
              ),
            ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(
                OniSpacing.md, 0, OniSpacing.md, OniSpacing.sm),
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
                _templates(),
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
