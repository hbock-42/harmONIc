import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import '../design/tokens.dart';
import '../design/widgets.dart';

/// The catalogue of things you can place: buildings grouped by what they are
/// for, plus a supply and an output node per item.
class PalettePanel extends StatefulWidget {
  const PalettePanel({
    required this.database,
    required this.onAdd,
    super.key,
  });

  final GameDatabase database;
  final ValueChanged<String> onAdd;

  @override
  State<PalettePanel> createState() => _PalettePanelState();
}

class _PalettePanelState extends State<PalettePanel> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Buildings first, grouped by their tag; boundary nodes last, because you
  /// reach for them less often.
  Map<String, List<ProcessSpec>> get _groups {
    final query = _search.text.trim().toLowerCase();
    final groups = <String, List<ProcessSpec>>{};
    for (final spec in widget.database.processes) {
      if (query.isNotEmpty && !spec.name.toLowerCase().contains(query)) continue;
      final group = switch (spec.kind) {
        ProcessKind.source => 'Supply',
        ProcessKind.sink => 'Output',
        ProcessKind.duplicant => 'Colony',
        _ => _capitalise(
            spec.tags.firstWhere((t) => t != 'verified', orElse: () => 'other')),
      };
      groups.putIfAbsent(group, () => []).add(spec);
    }
    for (final list in groups.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    return groups;
  }

  static String _capitalise(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final names = groups.keys.toList()
      ..sort((a, b) {
        int rank(String g) => switch (g) {
              'Supply' => 2,
              'Output' => 3,
              _ => 1,
            };
        final byRank = rank(a).compareTo(rank(b));
        return byRank != 0 ? byRank : a.compareTo(b);
      });

    return OniPanel(
      title: 'Add',
      width: 232,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(OniSpacing.sm),
            child: OniField(
              controller: _search,
              hint: 'Search…',
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: OniSpacing.lg),
              children: [
                for (final name in names) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        OniSpacing.md, OniSpacing.md, OniSpacing.md, 4),
                    child: Text(name.toUpperCase(), style: OniType.label),
                  ),
                  for (final spec in groups[name]!)
                    _PaletteRow(
                      spec: spec,
                      database: widget.database,
                      onTap: () => widget.onAdd(spec.id),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteRow extends StatefulWidget {
  const _PaletteRow({
    required this.spec,
    required this.database,
    required this.onTap,
  });

  final ProcessSpec spec;
  final GameDatabase database;
  final VoidCallback onTap;

  @override
  State<_PaletteRow> createState() => _PaletteRowState();
}

class _PaletteRowState extends State<_PaletteRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final firstPort =
        widget.spec.ports.isEmpty ? null : widget.spec.ports.first;
    final colour = OniItemColors.ofItem(
        firstPort == null ? null : widget.database.item(firstPort.itemId));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: _hover ? OniColors.surfaceHover : null,
          padding: const EdgeInsets.symmetric(
              horizontal: OniSpacing.md, vertical: 6),
          child: Row(
            children: [
              Container(width: 3, height: 16, color: colour),
              const SizedBox(width: OniSpacing.sm),
              Expanded(
                child: Text(
                  widget.spec.name,
                  style: OniType.body.copyWith(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
