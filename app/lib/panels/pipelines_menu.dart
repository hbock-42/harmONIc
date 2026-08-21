import 'package:flutter/widgets.dart';

import '../design/tokens.dart';
import '../design/widgets.dart';
import '../state/workspace_controller.dart';

/// The list of saved pipelines: open one, copy one, throw one away.
class PipelinesMenu extends StatelessWidget {
  const PipelinesMenu({
    required this.workspace,
    required this.onClose,
    super.key,
  });

  final WorkspaceController workspace;
  final VoidCallback onClose;

  static const double width = 280;

  @override
  Widget build(BuildContext context) {
    final saved = workspace.saved;
    return Container(
      width: width,
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
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: OniSpacing.sm),
              children: [
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
