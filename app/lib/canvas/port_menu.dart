import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import '../design/item_glyph.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import '../state/pipeline_controller.dart';

/// The picker that opens when you click a port: everything that could plug in
/// there, ready to be placed and wired in one go.
class PortMenu extends StatefulWidget {
  const PortMenu({
    required this.controller,
    required this.offers,
    required this.ref,
    required this.onPick,
    required this.onDismiss,
    super.key,
  });

  final PipelineController controller;

  /// Whether the palette would offer this, so a pack switched off does not
  /// come back through the side door.
  final bool Function(ProcessSpec) offers;
  final PortRef ref;
  final ValueChanged<String> onPick;
  final VoidCallback onDismiss;

  static const double width = 244;
  static const double maxHeight = 320;

  @override
  State<PortMenu> createState() => _PortMenuState();
}

class _PortMenuState extends State<PortMenu> {
  final TextEditingController _search = TextEditingController();

  /// How many of the things that *could* fill this port your pack switches
  /// are hiding. The reason an empty list is empty.
  int _hidden = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final node = controller.pipeline.node(widget.ref.nodeId);
    final spec = node == null ? null : controller.specFor(node);
    if (node == null || spec == null) return const SizedBox.shrink();
    final port = spec.portById(widget.ref.portId);
    if (port == null) return const SizedBox.shrink();

    final item = controller.database.item(port.itemId);
    final query = _search.text.trim().toLowerCase();
    final offered = controller.candidatesFor(widget.ref);
    final candidates = offered
        .where(widget.offers)
        .where((s) => query.isEmpty || s.name.toLowerCase().contains(query))
        .toList();
    // Only what the packs hide, not what the search box narrows: somebody who
    // typed a word knows why the list is short.
    _hidden = query.isEmpty ? offered.length - offered.where(widget.offers).length : 0;

    return Container(
      width: PortMenu.width,
      constraints: const BoxConstraints(maxHeight: PortMenu.maxHeight),
      decoration: BoxDecoration(
        color: OniColors.surfaceRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: OniColors.borderStrong),
        boxShadow: const [
          BoxShadow(color: Color(0x99000000), blurRadius: 20, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                OniSpacing.md, OniSpacing.md, OniSpacing.md, OniSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    OniItemGlyph.ofItem(item),
                    const SizedBox(width: OniSpacing.sm),
                    Expanded(
                      child: Text(
                        port.isInput
                            ? 'What supplies ${item?.name ?? port.itemId}?'
                            : 'Where does ${item?.name ?? port.itemId} go?',
                        style: OniType.title,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: OniSpacing.sm),
                OniField(
                  controller: _search,
                  hint: 'Search…',
                  clearable: true,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          Flexible(
            child: candidates.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(OniSpacing.md),
                    child: Text(
                      // Every item has a supply and an output, generated —
                      // including one you invented — so "nothing here makes
                      // that" is not a thing this list can honestly say. It
                      // was said anyway, to anybody whose search matched
                      // nothing: 1 415 ports were checked and not one of them
                      // has an empty list of its own.
                      //
                      // So an empty list has exactly two meanings, and both of
                      // them are about something you did.
                      _hidden > 0
                          ? '$_hidden '
                              '${_hidden == 1 ? 'recipe is' : 'recipes are'} '
                              'hidden by your pack filters.'
                          : 'Nothing here matches "${_search.text.trim()}".',
                      style: OniType.body
                          .copyWith(fontSize: 12, color: OniColors.textFaint),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: OniSpacing.sm),
                    itemCount: candidates.length,
                    itemBuilder: (context, i) => _CandidateRow(
                      spec: candidates[i],
                      onTap: () => widget.onPick(candidates[i].id),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CandidateRow extends StatefulWidget {
  const _CandidateRow({required this.spec, required this.onTap});

  final ProcessSpec spec;
  final VoidCallback onTap;

  @override
  State<_CandidateRow> createState() => _CandidateRowState();
}

class _CandidateRowState extends State<_CandidateRow> {
  bool _hover = false;

  bool get _isBoundary =>
      widget.spec.kind.isBoundary;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            color: _hover ? OniColors.surfaceHover : null,
            padding: const EdgeInsets.symmetric(
                horizontal: OniSpacing.md, vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.spec.name,
                  style: OniType.body.copyWith(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_isBoundary)
                  Text(
                    widget.spec.kind == ProcessKind.source
                        ? 'from outside this build'
                        : 'leaves this build',
                    style: OniType.numberSmall.copyWith(fontSize: 10),
                  ),
              ],
            ),
          ),
        ),
      );
}
