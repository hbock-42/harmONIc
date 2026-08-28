import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import '../design/tokens.dart';
import '../design/widgets.dart';
import '../state/display_controller.dart';

/// The catalogue of things you can place: buildings grouped by what they are
/// for, plus a supply and an output node per item.
/// Why a search turned a row up, when it was not the name.
///
/// A production planner is asked about materials — "what makes oxygen?" — far
/// more often than about names, and this list matched names only. So an
/// Electrolyzer did not answer "oxygen", which is the first thing anybody
/// types.
///
/// Null means the name matched, or that nothing matched at all; [paletteRank]
/// is what tells those apart.
String? paletteWhy(ProcessSpec spec, String query, GameDatabase database) {
  if (query.isEmpty || spec.name.toLowerCase().contains(query)) return null;
  String? takes;
  for (final port in spec.ports) {
    final name = database.item(port.itemId)?.name ?? port.itemId;
    if (!name.toLowerCase().contains(query)) continue;
    // What a thing *makes* is the usual reason for asking, so it wins over
    // what the same thing happens to eat.
    if (port.isOutput) return 'makes ${name.toLowerCase()}';
    takes ??= 'takes ${name.toLowerCase()}';
  }
  return takes;
}

/// What a thing is for, in one line: the first sentence of what the recipe
/// already says about itself.
///
/// The first question anybody asked was "I'm unsure how to make use of Arbor
/// Tree vs Arbor Tree (grazed)", and the answer was already written on the
/// spec — *the same plant, left for a critter to graze instead of harvested*.
/// The list showed the name and nothing else, so the sentence that answers it
/// was a click away at the moment it was being asked.
///
/// Not for supplies and outputs: there are hundreds of them, their names say
/// what they are, and a hundred identical lines saying "whatever brings this
/// into the build" is furniture rather than help.
String? paletteHint(ProcessSpec spec) {
  if (spec.kind == ProcessKind.source || spec.kind == ProcessKind.sink) {
    return null;
  }
  final text = spec.description?.trim();
  if (text == null || text.isEmpty) return null;
  final stop = RegExp(r'[.!?](\s|$)').firstMatch(text);
  final sentence = stop == null ? text : text.substring(0, stop.start + 1);
  return sentence.replaceAll('**', '').replaceAll('*', '').replaceAll('`', '');
}

/// 0 for a name, 1 for something that makes it, 2 for something that eats it,
/// and 3 for no match at all. Somebody typing "oxygen" wants the Electrolyzer
/// above the Duplicant that breathes it.
int paletteRank(ProcessSpec spec, String query, GameDatabase database) {
  if (query.isEmpty || spec.name.toLowerCase().contains(query)) return 0;
  final why = paletteWhy(spec, query, database);
  if (why == null) return 3;
  return why.startsWith('makes') ? 1 : 2;
}

class PalettePanel extends StatefulWidget {
  const PalettePanel({
    required this.database,
    required this.display,
    required this.onAdd,
    required this.onNewRecipe,
    required this.onEditRecipe,
    this.pointingAt,
    this.rowKeys,
    this.search,
    super.key,
  });

  /// A recipe to light up: the one a demo is about to place, so somebody
  /// watching sees where the click is going before it lands.
  final String? pointingAt;

  /// Where each row ended up, filled in as they are built. A demo points at
  /// one of these, and a row nobody can find is a cursor with nowhere to go.
  final Map<String, GlobalKey>? rowKeys;

  /// The search box's own controller, when somebody outside needs to type
  /// into it. A demo does: the list is long, the row it wants is usually
  /// somewhere below the fold, and searching for it is what a person does
  /// anyway.
  final TextEditingController? search;

  final GameDatabase database;

  /// Which packs are switched on, and whether wild variants are offered.
  final DisplayController display;
  final ValueChanged<String> onAdd;
  final VoidCallback onNewRecipe;
  final ValueChanged<ProcessSpec> onEditRecipe;

  @override
  State<PalettePanel> createState() => _PalettePanelState();
}

class _PalettePanelState extends State<PalettePanel> {
  late final TextEditingController _search =
      widget.search ?? TextEditingController();
  bool _filtersOpen = false;

  /// The groups the reader has folded away.
  ///
  /// Three start folded. A supply and an output node exist for every item in
  /// the database and an eating node for every food, so those three groups
  /// are 428 of the roughly 700 rows here — and none of them is what somebody
  /// opening the palette is looking for. The buildings are.
  final Set<String> _folded = {'Supply', 'Output', 'Eating'};

  @override
  void initState() {
    super.initState();
    widget.display.addListener(_onDisplayChanged);
  }

  @override
  void didUpdateWidget(PalettePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.display != widget.display) {
      oldWidget.display.removeListener(_onDisplayChanged);
      widget.display.addListener(_onDisplayChanged);
    }
  }

  void _onDisplayChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.display.removeListener(_onDisplayChanged);
    if (widget.search == null) _search.dispose();
    super.dispose();
  }

  /// How much is being kept out of the list right now, so a filter that has
  /// been on since last week is not mistaken for an empty database.
  int get _hidden {
    var hidden = 0;
    for (final spec in widget.database.processes) {
      if (!widget.display.includes(spec)) hidden++;
    }
    return hidden;
  }

  /// Buildings first, grouped by their tag; boundary nodes last, because you
  /// reach for them less often.
  Map<String, List<ProcessSpec>> get _groups {
    final query = _search.text.trim().toLowerCase();
    final groups = <String, List<ProcessSpec>>{};
    for (final spec in widget.database.processes) {
      if (!widget.display.includes(spec)) continue;
      if (paletteRank(spec, query, widget.database) == 3) continue;
      final group = switch (spec.kind) {
        ProcessKind.source => 'Supply',
        ProcessKind.sink => 'Output',
        ProcessKind.duplicant => 'Colony',
        // A build saved as a recipe goes in a group of its own, named after
        // where it came from rather than after the fact that it is custom.
        _ when spec.tags.contains('build') => 'My builds',
        // Pumps and filters are one building per fluid apiece, so they get
        // groups of their own rather than swamping the list they would
        // otherwise be sorted into.
        _ when spec.tags.contains('pumping') => 'Pumping',
        // And one eating node per food, for the same reason: 64 ways to put
        // something on a plate would bury the dozen buildings that cook.
        _ when spec.tags.contains('eating') => 'Eating',
        _ when spec.tags.contains('filtering') => 'Filtering',
        _ => _capitalise(
          spec.tags.firstWhere((t) => t != 'verified', orElse: () => 'other'),
        ),
      };
      groups.putIfAbsent(group, () => []).add(spec);
    }
    for (final list in groups.values) {
      list.sort((a, b) {
        final byRank = paletteRank(
          a,
          query,
          widget.database,
        ).compareTo(paletteRank(b, query, widget.database));
        return byRank != 0 ? byRank : a.name.compareTo(b.name);
      });
    }
    return groups;
  }

  /// The pack switches, folded away until asked for: most people set these
  /// once, and a row of always-visible toggles would cost more list than it
  /// saves.
  Widget _filters() {
    final display = widget.display;
    final hidden = _hidden;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _filtersOpen = !_filtersOpen),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                OniSpacing.md,
                2,
                OniSpacing.md,
                OniSpacing.sm,
              ),
              child: Row(
                children: [
                  Text(
                    _filtersOpen ? '▾ SHOWING' : '▸ SHOWING',
                    style: OniType.label,
                  ),
                  const SizedBox(width: OniSpacing.sm),
                  Expanded(
                    child: Text(
                      hidden == 0 ? 'everything' : '$hidden hidden',
                      style: OniType.body.copyWith(
                        fontSize: 11.5,
                        color: hidden == 0
                            ? OniColors.textFaint
                            : OniColors.accent,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_filtersOpen)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OniSpacing.md,
              0,
              OniSpacing.md,
              OniSpacing.sm,
            ),
            child: Wrap(
              spacing: OniSpacing.sm,
              runSpacing: OniSpacing.sm,
              children: [
                for (final pack in kContentPacks.entries)
                  OniButton(
                    label: pack.value,
                    compact: true,
                    tone: display.packEnabled(pack.key)
                        ? OniButtonTone.accent
                        : OniButtonTone.neutral,
                    onPressed: () => display.setPack(
                      pack.key,
                      enabled: !display.packEnabled(pack.key),
                    ),
                  ),
                OniButton(
                  label: 'Wild',
                  compact: true,
                  tone: display.showWild
                      ? OniButtonTone.accent
                      : OniButtonTone.neutral,
                  onPressed: () =>
                      display.setShowWild(showWild: !display.showWild),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _capitalise(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final searching = _search.text.trim().isNotEmpty;
    final names = groups.keys.toList()
      ..sort((a, b) {
        int rank(String g) => switch (g) {
          'My builds' => 0,
          'Pumping' => 2,
          'Filtering' => 2,
          'Eating' => 2,
          'Supply' => 3,
          'Output' => 4,
          _ => 1,
        };
        final byRank = rank(a).compareTo(rank(b));
        return byRank != 0 ? byRank : a.compareTo(b);
      });

    return OniPanel(
      title: 'Add',
      width: 232,
      trailing: OniButton(
        label: '+ Recipe',
        compact: true,
        tone: OniButtonTone.accent,
        onPressed: widget.onNewRecipe,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(OniSpacing.sm),
            child: OniField(
              controller: _search,
              hint: 'Search…',
              clearable: true,
              onChanged: (_) => setState(() {}),
            ),
          ),
          _filters(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: OniSpacing.lg),
              children: [
                for (final name in names) ...[
                  _GroupHeader(
                    name: name,
                    count: groups[name]!.length,
                    // A search that has found something shows it, whatever
                    // was folded before the search was typed.
                    folded: _folded.contains(name) && !searching,
                    onTap: () => setState(() {
                      if (!_folded.remove(name)) _folded.add(name);
                    }),
                  ),
                  if (!(_folded.contains(name) && !searching))
                    for (final spec in groups[name]!)
                      _PaletteRow(
                        key: widget.rowKeys?.putIfAbsent(
                          spec.id,
                          GlobalKey.new,
                        ),
                        spec: spec,
                        database: widget.database,
                        pointedAt: spec.id == widget.pointingAt,
                        // Why it is in a filtered list wins over what it is
                        // for: somebody who searched "oxygen" is owed the
                        // reason a Duplicant came back before anything else.
                        why:
                            paletteWhy(
                              spec,
                              _search.text.trim().toLowerCase(),
                              widget.database,
                            ) ??
                            paletteHint(spec),
                        onTap: () => widget.onAdd(spec.id),
                        onEdit: () => widget.onEditRecipe(spec),
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

/// A group's name, how many are in it, and whether it is folded away.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.name,
    required this.count,
    required this.folded,
    required this.onTap,
  });

  final String name;
  final int count;
  final bool folded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            OniSpacing.md,
            OniSpacing.md,
            OniSpacing.md,
            4,
          ),
          child: Row(
            children: [
              // Pointing down when open and right when folded, which is the
              // arrow every file tree has taught everybody to read.
              Text(folded ? '\u25B8' : '\u25BE', style: OniType.label),
              const SizedBox(width: 6),
              Expanded(child: Text(name.toUpperCase(), style: OniType.label)),
              Text('$count', style: OniType.label),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaletteRow extends StatefulWidget {
  const _PaletteRow({
    required this.spec,
    required this.database,
    required this.onTap,
    required this.onEdit,
    this.why,
    this.pointedAt = false,
    super.key,
  });

  /// Lit because a demo has just placed this, so somebody watching can see
  /// where it came from.
  final bool pointedAt;

  final ProcessSpec spec;
  final GameDatabase database;

  /// Why this row is in a filtered list, when the name is not the reason.
  /// A Hatch answering a search for "coal" has to say that it makes some.
  final String? why;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  State<_PaletteRow> createState() => _PaletteRowState();
}

class _PaletteRowState extends State<_PaletteRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final firstPort = widget.spec.ports.isEmpty
        ? null
        : widget.spec.ports.first;
    final colour = OniItemColors.ofItem(
      firstPort == null ? null : widget.database.item(firstPort.itemId),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          // The pointed-at row reads as hovered and then some: it is the
          // same gesture being shown, so it should look like the same thing
          // about to happen.
          decoration: BoxDecoration(
            color: widget.pointedAt
                ? OniColors.accent.withValues(alpha: 0.14)
                : _hover
                ? OniColors.surfaceHover
                : null,
            border: widget.pointedAt
                ? Border(left: BorderSide(color: OniColors.accent, width: 2))
                : null,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: OniSpacing.md,
            vertical: 6,
          ),
          child: Row(
            children: [
              Container(width: 3, height: 16, color: colour),
              const SizedBox(width: OniSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.spec.name,
                      style: OniType.body.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.why case final String why)
                      Text(
                        why,
                        style: OniType.numberSmall.copyWith(
                          color: OniColors.textFaint,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (_hover)
                GestureDetector(
                  onTap: widget.onEdit,
                  child: Text(
                    'edit',
                    style: OniType.numberSmall.copyWith(
                      color: OniColors.accent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
