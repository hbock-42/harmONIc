import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import '../state/pipeline_controller.dart';

/// One node the search turned up, and why.
class FindMatch {
  const FindMatch({required this.nodeId, required this.title, this.because});

  final String nodeId;
  final String title;

  /// Why this one is here, when its name is not what matched: "makes sulfur".
  /// Null when the name matched, where saying so would be reading the name
  /// back to somebody who just typed it.
  final String? because;
}

/// The nodes in a build whose name — or whose recipe — answers to [query].
///
/// Named things first, because somebody typing "kiln" wants the Kiln and not
/// the nine nodes that touch refined carbon. Within each half, the ones that
/// *start* with what was typed lead: "sulfur" should find the Sulfur before
/// the Polluted Brine that happens to make some.
List<FindMatch> findNodes(PipelineController controller, String query) {
  final wanted = query.trim().toLowerCase();
  if (wanted.isEmpty) return const [];

  final byName = <FindMatch>[];
  final byRecipe = <FindMatch>[];
  for (final node in controller.pipeline.nodes) {
    final spec = controller.specFor(node);
    if (spec == null) continue;
    final title = node.label ?? spec.name;
    if (title.toLowerCase().contains(wanted)) {
      byName.add(FindMatch(nodeId: node.id, title: title));
      continue;
    }
    for (final port in spec.ports) {
      final item = controller.database.item(port.itemId);
      final name = item?.name ?? port.itemId;
      if (!name.toLowerCase().contains(wanted)) continue;
      byRecipe.add(FindMatch(
        nodeId: node.id,
        title: title,
        because: '${port.isOutput ? 'makes' : 'takes'} ${name.toLowerCase()}',
      ));
      break;
    }
  }

  int leading(FindMatch a, FindMatch b) {
    final byStart = (a.title.toLowerCase().startsWith(wanted) ? 0 : 1)
        .compareTo(b.title.toLowerCase().startsWith(wanted) ? 0 : 1);
    return byStart != 0 ? byStart : a.title.compareTo(b.title);
  }

  byName.sort(leading);
  byRecipe.sort(leading);
  return [...byName, ...byRecipe];
}

/// Find a node in a build, without hunting the canvas for it.
///
/// A build outgrows its window long before it outgrows its author's patience,
/// and the only way to a node forty screens away was to remember roughly where
/// it had been put. This works the way find works everywhere else: type, and
/// the first match comes to you; Enter for the next one.
class FindPanel extends StatefulWidget {
  const FindPanel({
    required this.controller,
    required this.onClose,
    super.key,
  });

  final PipelineController controller;
  final VoidCallback onClose;

  @override
  State<FindPanel> createState() => FindPanelState();
}

class FindPanelState extends State<FindPanel> {
  final TextEditingController _query = TextEditingController();
  late final FocusNode _focus = FocusNode(onKeyEvent: _onKey);
  List<FindMatch> _matches = const [];
  int _at = 0;

  @override
  void initState() {
    super.initState();
    // After the frame rather than with `autofocus`: the editor itself holds
    // focus for the shortcuts, and a bar that opens without the cursor in it
    // is one where the next thing typed goes nowhere.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  /// Put the cursor back in the field and select what is there, so that asking
  /// for the search again starts a new one rather than appending to the old.
  void takeFocus() {
    _focus.requestFocus();
    _query.selection =
        TextSelection(baseOffset: 0, extentOffset: _query.text.length);
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Handled on the field's own focus node, which is consulted before the text
  /// editing shortcuts above it: an arrow key in a search box belongs to the
  /// search, not to the cursor.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final shift = HardwareKeyboard.instance.isShiftPressed;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        widget.onClose();
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _step(shift ? -1 : 1);
      case LogicalKeyboardKey.arrowDown:
        _step(1);
      case LogicalKeyboardKey.arrowUp:
        _step(-1);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _search(String text) {
    setState(() {
      _matches = findNodes(widget.controller, text);
      _at = 0;
    });
    // The first match as you type, the way find works everywhere else.
    if (_matches.isNotEmpty) _go(_matches.first);
  }

  /// Wraps, because a search that stops at the end makes somebody count.
  void _step(int by) {
    if (_matches.isEmpty) return;
    setState(() => _at = (_at + by) % _matches.length);
    _go(_matches[_at]);
  }

  /// Selecting one node is already what brings it into view, so this is the
  /// whole of going to a match.
  void _go(FindMatch match) =>
      widget.controller.select(NodeSelection(match.nodeId));

  @override
  Widget build(BuildContext context) {
    final typed = _query.text.trim().isNotEmpty;
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: OniColors.surface,
        border: Border.all(color: OniColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(OniSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: OniField(
                    controller: _query,
                    focusNode: _focus,
                    autofocus: true,
                    hint: 'Find a node…',
                    clearable: true,
                    onChanged: _search,
                  ),
                ),
                const SizedBox(width: OniSpacing.sm),
                Text(
                  !typed
                      ? ''
                      : _matches.isEmpty
                          ? 'none'
                          : '${_at + 1} of ${_matches.length}',
                  style: OniType.numberSmall.copyWith(
                      color: typed && _matches.isEmpty
                          ? OniColors.textFaint
                          : OniColors.textMuted),
                ),
                const SizedBox(width: OniSpacing.xs),
                OniButton(
                  label: '↑',
                  compact: true,
                  onPressed: _matches.isEmpty ? null : () => _step(-1),
                ),
                const SizedBox(width: 2),
                OniButton(
                  label: '↓',
                  compact: true,
                  onPressed: _matches.isEmpty ? null : () => _step(1),
                ),
                const SizedBox(width: OniSpacing.xs),
                OniButton(
                    label: 'Close', compact: true, onPressed: widget.onClose),
              ],
            ),
          ),
          if (typed && _matches.isNotEmpty)
            ConstrainedBox(
              // Enough to choose from, not enough to become a second canvas.
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: OniSpacing.sm),
                itemCount: _matches.length,
                itemBuilder: (context, i) => _Row(
                  match: _matches[i],
                  on: i == _at,
                  onTap: () {
                    setState(() => _at = i);
                    _go(_matches[i]);
                  },
                ),
              ),
            ),
          if (typed && _matches.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  OniSpacing.sm, 0, OniSpacing.sm, OniSpacing.sm),
              child: Text(
                'Nothing in this build answers to that. Names and what a node '
                'makes or takes are both searched.',
                style: OniType.body
                    .copyWith(fontSize: 11.5, color: OniColors.textFaint),
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.match, required this.on, required this.onTap});

  final FindMatch match;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: OniSpacing.sm, vertical: 6),
          color: on ? OniColors.accent.withValues(alpha: 0.12) : null,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  match.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OniType.body.copyWith(
                      fontSize: 12,
                      color: on ? OniColors.accent : OniColors.text),
                ),
              ),
              if (match.because case final String why) ...[
                const SizedBox(width: OniSpacing.sm),
                Text(why,
                    style: OniType.numberSmall
                        .copyWith(color: OniColors.textFaint)),
              ],
            ],
          ),
        ),
      );
}
