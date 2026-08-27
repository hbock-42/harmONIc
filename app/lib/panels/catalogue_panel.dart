import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import '../design/tokens.dart';
import '../design/widgets.dart';

/// Every figure the app uses, for somebody checking them.
///
/// Built from the database the app is running on, so there is nothing here to
/// drift: it is the same numbers the solver used a moment ago, arranged for
/// reading rather than for solving.
///
/// Grouped by a thing and sorted by how much, because that is how a wrong
/// figure shows itself. A Pip gives 20 kg of dirt a cycle and a Cuddle Pip
/// five eighths of that; while the Pip was wrong it sat *below* the Cuddle
/// Pip, which anybody can see is impossible without knowing either number.
class CataloguePanel extends StatefulWidget {
  const CataloguePanel({
    required this.database,
    required this.onClose,
    this.onReport,
    super.key,
  });

  final GameDatabase database;
  final VoidCallback onClose;

  /// Say a figure is wrong, with the recipe already named.
  final void Function(ProcessSpec spec)? onReport;

  @override
  State<CataloguePanel> createState() => _CataloguePanelState();
}

/// Which way round: what makes a thing, or what eats it.
///
/// Both, because a figure means little alone and a lot beside its neighbours,
/// and a recipe has two sides. An Orehull's 20 kg of nori a cycle means
/// something next to everything else that eats nori.
enum _Way {
  made('What makes it'),
  used('What eats it');

  const _Way(this.label);
  final String label;
}

enum _Family {
  everything('Everything'),
  critters('Critters'),
  plants('Plants'),
  food('Cooking'),
  refining('Refining'),
  power('Power');

  const _Family(this.label);
  final String label;

  bool matches(ProcessSpec spec) => switch (this) {
        _Family.critters => spec.kind == ProcessKind.critter,
        _Family.plants => spec.tags.contains('farming'),
        _Family.food => spec.tags.contains('food'),
        _Family.refining => spec.tags.contains('refining'),
        _Family.power => spec.tags.contains('power'),
        // Boundary nodes are one per item and say nothing worth checking.
        _Family.everything => spec.kind != ProcessKind.source &&
            spec.kind != ProcessKind.sink,
      };
}

/// What state a thing is in, which is a filter because somebody checking gases
/// is not checking ores.
enum _State {
  all('All states'),
  solid('Solid'),
  liquid('Liquid'),
  gas('Gas'),
  food('Food'),
  energy('Heat / Power'),
  growth('Growth');

  const _State(this.label);
  final String label;

  bool matches(Item? item) {
    if (item == null) return this == _State.all;
    return switch (this) {
      _State.all => true,
      _State.solid => item.category == ItemCategory.solid && !item.isFood,
      _State.liquid => item.category == ItemCategory.liquid,
      _State.gas => item.category == ItemCategory.gas,
      _State.food => item.isFood,
      _State.energy => item.category == ItemCategory.power ||
          item.category == ItemCategory.heat,
      _State.growth => item.tags.contains('growth'),
    };
  }
}

enum _Trust {
  all('All'),
  published('Published'),
  judged('Judged');

  const _Trust(this.label);
  final String label;

  bool matches(ProcessSpec spec) => switch (this) {
        _Trust.all => true,
        _Trust.published => !spec.tags.contains('unverified'),
        _Trust.judged => spec.tags.contains('unverified'),
      };
}

enum _Sort {
  name('Name (A–Z)'),
  most('Most first'),
  crowded('Most ways first');

  const _Sort(this.label);
  final String label;
}

/// One heading and the rows under it, whichever way round the list is.
class _Group {
  _Group({required this.itemId, required this.title, required this.rows});

  final String itemId;
  final String title;
  final List<_Line> rows;

  double get most =>
      rows.isEmpty ? 0 : rows.map((r) => r.rate).reduce((a, b) => a > b ? a : b);

  bool matches(String query) {
    if (query.isEmpty) return true;
    if (title.toLowerCase().contains(query)) return true;
    return rows.any((row) =>
        row.spec.name.toLowerCase().contains(query) ||
        (row.spec.description ?? '').toLowerCase().contains(query));
  }
}

class _Line {
  const _Line({
    required this.spec,
    required this.itemId,
    required this.rate,
    required this.others,
    required this.othersLead,
  });

  final ProcessSpec spec;
  final String itemId;
  final double rate;

  /// The other side of the recipe: what it costs, or what the cost buys.
  final List<Port> others;
  final String othersLead;
}

class _CataloguePanelState extends State<CataloguePanel> {
  final TextEditingController _search = TextEditingController();
  _Way _way = _Way.made;
  _Family _family = _Family.everything;
  _State _state = _State.all;
  _Trust _trust = _Trust.all;
  _Sort _sort = _Sort.name;

  /// Folded groups, and how many of each thing to show at once. Both are per
  /// reader and per visit: nothing here is worth remembering between sessions.
  final Set<String> _folded = {};
  final Map<String, int> _times = {};
  bool _helpOpen = false;
  ProcessSpec? _inspecting;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _itemName(String itemId) =>
      widget.database.item(itemId)?.name ?? itemId;

  /// Per cycle, which is how the game quotes a recipe and how anybody
  /// checking one thinks. Grams a second is right for a pipe, wrong for a
  /// Hatch.
  String _rate(String itemId, double ratePerSecond, [int times = 1]) =>
      widget.database.item(itemId)?.formatRate(
          ratePerSecond * times, RateDisplay.perCycle, precision: 2) ??
      (ratePerSecond * times * secondsPerCycle).toStringAsFixed(2);

  int _timesFor(ProcessSpec spec) => _times[spec.id] ?? 1;

  List<_Group> _groups(_Family family) {
    final groups = _way == _Way.made
        ? [
            for (final made in madeBy(widget.database,
                where: (s) => family.matches(s) && _trust.matches(s)))
              _Group(
                itemId: made.itemId,
                title: _itemName(made.itemId),
                rows: [
                  for (final maker in made.makers)
                    _Line(
                      spec: maker.spec,
                      itemId: made.itemId,
                      rate: maker.made.ratePerSecond,
                      others: maker.takes,
                      othersLead: 'Takes',
                    ),
                ],
              )
          ]
        : [
            for (final used in usedBy(widget.database,
                where: (s) => family.matches(s) && _trust.matches(s)))
              _Group(
                itemId: used.itemId,
                title: _itemName(used.itemId),
                rows: [
                  for (final taker in used.takers)
                    _Line(
                      spec: taker.spec,
                      itemId: used.itemId,
                      rate: taker.takes.ratePerSecond,
                      others: taker.makes,
                      othersLead: 'Gives',
                    ),
                ],
              )
          ];

    final query = _search.text.trim().toLowerCase();
    final kept = [
      for (final group in groups)
        if (_state.matches(widget.database.item(group.itemId)) &&
            group.matches(query))
          group,
    ];
    switch (_sort) {
      case _Sort.name:
        break; // already by name, from the engine
      case _Sort.most:
        kept.sort((a, b) => b.most.compareTo(a.most));
      case _Sort.crowded:
        kept.sort((a, b) => b.rows.length.compareTo(a.rows.length));
    }
    return kept;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups(_family);
    final methods = groups.fold<int>(0, (sum, g) => sum + g.rows.length);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onClose,
      child: Container(
        color: const Color(0xCC000000),
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: () {},
          child: OniPanel(
            title: _inspecting?.name ?? 'Every figure',
            width: 920,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_inspecting != null) ...[
                  OniButton(
                    label: '← All figures',
                    compact: true,
                    onPressed: () => setState(() => _inspecting = null),
                  ),
                  const SizedBox(width: OniSpacing.xs),
                ],
                OniButton(
                    label: 'Close', compact: true, onPressed: widget.onClose),
              ],
            ),
            child: _inspecting == null
                ? _browse(groups, methods)
                : _Inspect(
                    database: widget.database,
                    spec: _inspecting!,
                    times: _timesFor(_inspecting!),
                    onTimes: (n) =>
                        setState(() => _times[_inspecting!.id] = n),
                    onReport: widget.onReport,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _browse(List<_Group> groups, int methods) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _filters(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  OniSpacing.md, OniSpacing.sm, OniSpacing.md, OniSpacing.lg),
              children: [
                _Guidelines(
                  open: _helpOpen,
                  onToggle: () => setState(() => _helpOpen = !_helpOpen),
                ),
                const SizedBox(height: OniSpacing.md),
                Text(
                  'Showing $methods ${methods == 1 ? 'way' : 'ways'} across '
                  '${groups.length} ${groups.length == 1 ? 'thing' : 'things'}.',
                  style: OniType.body
                      .copyWith(fontSize: 11.5, color: OniColors.textFaint),
                ),
                const SizedBox(height: OniSpacing.sm),
                for (final group in groups)
                  _GroupCard(
                    group: group,
                    database: widget.database,
                    folded: _folded.contains(group.itemId),
                    onFold: () => setState(() {
                      if (!_folded.remove(group.itemId)) {
                        _folded.add(group.itemId);
                      }
                    }),
                    rate: _rate,
                    timesFor: _timesFor,
                    onTimes: (spec, n) =>
                        setState(() => _times[spec.id] = n),
                    onInspect: (spec) => setState(() => _inspecting = spec),
                    onSearch: (name) => setState(() => _search.text = name),
                    onReport: widget.onReport,
                    lead: _way == _Way.made ? 'Takes' : 'Gives',
                  ),
                if (groups.isEmpty)
                  Text('Nothing here matches that.', style: OniType.body),
              ],
            ),
          ),
        ],
      );

  Widget _filters() => Container(
        padding: const EdgeInsets.all(OniSpacing.md),
        decoration: BoxDecoration(
          color: OniColors.surface,
          border: Border(bottom: BorderSide(color: OniColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OniField(
              controller: _search,
              hint: 'Search…',
              clearable: true,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: OniSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: OniSpacing.xs,
                    runSpacing: OniSpacing.xs,
                    children: [
                      for (final family in _Family.values)
                        _Chip(
                          label: family.label,
                          count: _groups(family)
                              .fold<int>(0, (sum, g) => sum + g.rows.length),
                          on: family == _family,
                          onTap: () => setState(() => _family = family),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: OniSpacing.sm),
                _Chip(
                  label: _folded.isEmpty ? 'Fold all' : 'Unfold all',
                  on: false,
                  onTap: () => setState(() {
                    if (_folded.isEmpty) {
                      _folded.addAll(_groups(_family).map((g) => g.itemId));
                    } else {
                      _folded.clear();
                    }
                  }),
                ),
              ],
            ),
            const SizedBox(height: OniSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5, right: OniSpacing.sm),
                  child: Text('TYPE', style: OniType.label),
                ),
                Expanded(
                  child: Wrap(
                    spacing: OniSpacing.xs,
                    runSpacing: OniSpacing.xs,
                    children: [
                      for (final state in _State.values)
                        _Chip(
                          label: state.label,
                          on: state == _state,
                          onTap: () => setState(() => _state = state),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: OniSpacing.sm),
            Wrap(
              spacing: OniSpacing.xs,
              runSpacing: OniSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final way in _Way.values)
                  _Chip(
                    label: way.label,
                    on: way == _way,
                    onTap: () => setState(() => _way = way),
                  ),
                const SizedBox(width: OniSpacing.md),
                for (final trust in _Trust.values)
                  _Chip(
                    label: trust.label,
                    on: trust == _trust,
                    onTap: () => setState(() => _trust = trust),
                  ),
                const SizedBox(width: OniSpacing.md),
                for (final sort in _Sort.values)
                  _Chip(
                    label: sort.label,
                    on: sort == _sort,
                    onTap: () => setState(() => _sort = sort),
                  ),
              ],
            ),
          ],
        ),
      );
}


/// Split "75000.00 kg/cycle" into the figure and its unit, so the figure can
/// be set large and the unit stay quiet beside it. The figure is the thing
/// somebody came to read; the unit is the same on every card in the group.
(String, String) _figure(String formatted) {
  final space = formatted.indexOf(' ');
  if (space < 0) return (formatted, '');
  return (formatted.substring(0, space), formatted.substring(space + 1));
}

/// Which family a recipe belongs to, for the line under its name.
String _familyOf(ProcessSpec spec) {
  for (final family in _Family.values) {
    if (family != _Family.everything && family.matches(spec)) {
      return family.label;
    }
  }
  return 'Other';
}

/// A filter chip, with how many are behind it where that is worth knowing.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.on,
    required this.onTap,
    this.count,
  });

  final String label;
  final bool on;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = on ? OniColors.accent : OniColors.textMuted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          // A pill, and a tinted one when it is on: a chip that only changes
          // its text colour is a chip nobody can see the state of.
          color: on
              ? OniColors.accent.withValues(alpha: 0.12)
              : OniColors.surfaceRaised,
          border: Border.all(
            color: on
                ? OniColors.accent.withValues(alpha: 0.55)
                : OniColors.border,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: OniType.body.copyWith(
                fontSize: 12,
                color: on ? OniColors.accent : OniColors.textMuted,
                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (count case final int many) ...[
              const SizedBox(width: 7),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$many',
                    style: OniType.numberSmall.copyWith(color: tint)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The ×1 ×2 ×5 ×10 run, as one control rather than four loose buttons.
class _Times extends StatelessWidget {
  const _Times({
    required this.itemId,
    required this.spec,
    required this.times,
    required this.onTimes,
  });

  final String itemId;
  final ProcessSpec spec;
  final int times;
  final ValueChanged<int> onTimes;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: OniColors.surface,
          border: Border.all(color: OniColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final n in const [1, 2, 5, 10])
              GestureDetector(
                // Keyed by the group as well as the recipe: one thing turns up
                // under everything it makes, so the recipe alone names several.
                key: ValueKey('times:$itemId:${spec.id}:$n'),
                onTap: () => onTimes(n),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: n == times
                        ? OniColors.accent.withValues(alpha: 0.9)
                        : null,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    '×$n',
                    style: OniType.numberSmall.copyWith(
                      fontSize: 11.5,
                      color: n == times
                          ? OniColors.background
                          : OniColors.textMuted,
                      fontWeight:
                          n == times ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

/// The rules that make every figure on this page readable.
class _Guidelines extends StatelessWidget {
  const _Guidelines({required this.open, required this.onToggle});

  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: OniColors.surface,
          border: Border.all(color: OniColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(
            horizontal: OniSpacing.md, vertical: OniSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Text('ⓘ',
                      style: OniType.label.copyWith(color: OniColors.accent)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text('How to read these figures',
                        style: OniType.body.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: OniColors.accent)),
                  ),
                  Text(open ? '▾' : '▸',
                      style: OniType.label.copyWith(color: OniColors.accent)),
                ],
              ),
            ),
            if (open) ...[
              const SizedBox(height: OniSpacing.sm),
              Text(
                'A cycle is 600 seconds, and every rate here is per cycle: '
                'divide by 600 for the grams a second a pipe carries.\n\n'
                'A wild plant ripens at a quarter of a farmed one’s speed '
                'and takes no water or fertiliser at all — which is why its '
                'row shows a quarter of the yield and nothing in the column '
                'beside it.\n\n'
                'Judged means somebody decided the figure rather than read it '
                'off the game. The recipe says which part is doubtful.',
                style: OniType.body
                    .copyWith(fontSize: 11.5, color: OniColors.textFaint),
              ),
            ],
          ],
        ),
      );
}

/// One thing, and every way of getting it.
class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.database,
    required this.folded,
    required this.onFold,
    required this.rate,
    required this.timesFor,
    required this.onTimes,
    required this.onInspect,
    required this.onSearch,
    required this.lead,
    this.onReport,
  });

  final _Group group;
  final GameDatabase database;
  final bool folded;
  final VoidCallback onFold;
  final String Function(String, double, [int]) rate;
  final int Function(ProcessSpec) timesFor;
  final void Function(ProcessSpec, int) onTimes;
  final void Function(ProcessSpec) onInspect;
  final void Function(String) onSearch;
  final String lead;
  final void Function(ProcessSpec)? onReport;

  @override
  Widget build(BuildContext context) {
    final item = database.item(group.itemId);
    final colour = OniItemColors.ofItem(item);
    final best = group.rows.first;
    final (most, unit) = _figure(rate(group.itemId, best.rate));

    return Container(
      margin: const EdgeInsets.only(bottom: OniSpacing.md),
      decoration: BoxDecoration(
        color: OniColors.surface,
        border: Border.all(color: OniColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: onFold,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                  OniSpacing.md, OniSpacing.md, OniSpacing.md, OniSpacing.md),
              child: Row(
                children: [
                  Text(folded ? '▸' : '▾',
                      style: OniType.label.copyWith(color: colour)),
                  const SizedBox(width: OniSpacing.sm),
                  Flexible(
                    child: Text(
                      group.title.toUpperCase(),
                      style: OniType.heading.copyWith(letterSpacing: 1.1),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: OniSpacing.sm),
                  // What state the thing is in, in its own hue — the same hue
                  // its ports carry on the canvas.
                  _Badge(
                    (item?.category.name ?? 'other').toUpperCase(),
                    colour: colour,
                  ),
                  const SizedBox(width: OniSpacing.sm),
                  Text(
                    '${group.rows.length} '
                    '${group.rows.length == 1 ? 'way' : 'ways'}',
                    style: OniType.numberSmall
                        .copyWith(color: OniColors.textFaint),
                  ),
                  const Spacer(),
                  // The best in the group, boxed: the figure a reader checks
                  // the others against without scrolling the group.
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: OniSpacing.sm, vertical: 5),
                      decoration: BoxDecoration(
                        color: OniColors.surfaceRaised,
                        border: Border.all(color: OniColors.border),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text.rich(
                        TextSpan(
                          style: OniType.numberSmall
                              .copyWith(color: OniColors.textFaint),
                          children: [
                            const TextSpan(text: 'most '),
                            TextSpan(
                              text: '$most $unit',
                              style: TextStyle(
                                  color: OniColors.text,
                                  fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: ' · ${best.spec.name}'),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!folded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  OniSpacing.md, 0, OniSpacing.md, OniSpacing.md),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Two to a row where there is room, which is what makes two
                  // ways of getting the same thing comparable at a glance.
                  final columns = constraints.maxWidth > 620 ? 2 : 1;
                  final width = (constraints.maxWidth -
                          (columns - 1) * OniSpacing.sm) /
                      columns;
                  return Wrap(
                    spacing: OniSpacing.sm,
                    runSpacing: OniSpacing.sm,
                    children: [
                      for (final row in group.rows)
                        SizedBox(
                          width: width,
                          child: _ProducerCard(
                            row: row,
                            database: database,
                            of: group.most,
                            colour: colour,
                            times: timesFor(row.spec),
                            onTimes: (n) => onTimes(row.spec, n),
                            rate: rate,
                            onInspect: () => onInspect(row.spec),
                            onSearch: onSearch,
                            lead: lead,
                            onReport: onReport,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// One way of getting a thing: how much, from what, and how it compares.
class _ProducerCard extends StatelessWidget {
  const _ProducerCard({
    required this.row,
    required this.database,
    required this.of,
    required this.colour,
    required this.times,
    required this.onTimes,
    required this.rate,
    required this.onInspect,
    required this.onSearch,
    required this.lead,
    this.onReport,
  });

  final _Line row;
  final GameDatabase database;

  /// The biggest in this group, so the bar says "this much of the best" —
  /// which is the comparison somebody is making anyway.
  final double of;
  final Color colour;
  final int times;
  final ValueChanged<int> onTimes;
  final String Function(String, double, [int]) rate;
  final VoidCallback onInspect;
  final void Function(String) onSearch;
  final String lead;
  final void Function(ProcessSpec)? onReport;

  String _itemName(String itemId) =>
      database.item(itemId)?.name ?? itemId;

  @override
  Widget build(BuildContext context) {
    final spec = row.spec;
    final share = of <= 0 ? 0.0 : (row.rate / of).clamp(0.0, 1.0);
    final (figure, unit) = _figure(rate(row.itemId, row.rate, times));
    final badges = <(String, Color)>[
      if (spec.tags.contains('wild')) ('wild', OniColors.ok),
      if (spec.id.contains('grazed')) ('grazed', OniItemColors.of(ItemCategory.entity)),
      if (spec.tags.contains('unverified')) ('judged', OniColors.warning),
    ];

    return Container(
      decoration: BoxDecoration(
        color: OniColors.surfaceRaised,
        border: Border.all(color: OniColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The figure large and in the thing's own hue, the unit quiet
              // beside it: the unit is the same on every card in the group and
              // the figure is what somebody came to check.
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // One run rather than two Texts: the unit reads quiet but
                  // the figure and its unit are still one string, which is
                  // what anybody selecting or searching the page expects.
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: figure,
                          style: OniType.number.copyWith(
                              fontSize: 24,
                              height: 1.0,
                              fontWeight: FontWeight.w700,
                              color: colour),
                        ),
                        TextSpan(
                          text: ' $unit',
                          style: OniType.numberSmall
                              .copyWith(color: OniColors.textFaint),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 7),
                  // How much of the best in this group, which is the
                  // comparison somebody is making anyway.
                  SizedBox(
                    width: 132,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 4,
                        color: OniColors.border,
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: share,
                          child: Container(color: colour),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: OniSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(spec.name,
                            style: OniType.title.copyWith(fontSize: 13)),
                        for (final (label, tint) in badges)
                          _Badge(label, colour: tint),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${_familyOf(spec)} · ${spec.kind.name}',
                      style: OniType.body.copyWith(
                          fontSize: 11, color: OniColors.textFaint),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: OniSpacing.md),
          _Times(
            itemId: row.itemId,
            spec: spec,
            times: times,
            onTimes: onTimes,
          ),
          const SizedBox(height: OniSpacing.md),
          Container(height: 1, color: OniColors.border),
          const SizedBox(height: OniSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4, right: OniSpacing.sm),
                child: Text('${lead.toUpperCase()}:', style: OniType.label),
              ),
              Expanded(
                child: row.others.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('nothing at all',
                            style: OniType.body.copyWith(
                                fontSize: 11.5, color: OniColors.textFaint)),
                      )
                    : Wrap(
                        spacing: OniSpacing.xs,
                        runSpacing: OniSpacing.xs,
                        children: [
                          for (final port in row.others)
                            _Pill(
                              name: _itemName(port.itemId),
                              rate: rate(
                                  port.itemId, port.ratePerSecond, times),
                              colour: OniItemColors.ofItem(
                                  database.item(port.itemId)),
                              // Clicking a thing it takes searches for that
                              // thing, which is how somebody walks a chain
                              // backwards.
                              onTap: () => onSearch(_itemName(port.itemId)),
                            ),
                        ],
                      ),
              ),
            ],
          ),
          const SizedBox(height: OniSpacing.md),
          Container(height: 1, color: OniColors.border),
          const SizedBox(height: OniSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  spec.description ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: OniType.body.copyWith(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: OniColors.textFaint),
                ),
              ),
              const SizedBox(width: OniSpacing.sm),
              _Link(
                key: ValueKey('inspect:${row.itemId}:${spec.id}'),
                label: 'Inspect',
                onTap: onInspect,
              ),
              if (onReport != null) ...[
                const SizedBox(width: OniSpacing.md),
                _Link(
                  key: ValueKey('wrong:${row.itemId}:${spec.id}'),
                  label: 'Wrong?',
                  colour: OniColors.warning,
                  onTap: () => onReport!(spec),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A quiet text action, for the things a card offers rather than asks.
class _Link extends StatelessWidget {
  const _Link({
    required this.label,
    required this.onTap,
    this.colour,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final Color? colour;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Text(
          label,
          style: OniType.body.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: colour ?? OniColors.accent),
        ),
      );
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, {required this.colour});

  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.14),
          border: Border.all(color: colour.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: OniType.numberSmall.copyWith(
              fontSize: 9.5,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
              color: colour),
        ),
      );
}

/// One thing on the other side of a recipe, with its hue and its figure.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.name,
    required this.rate,
    required this.colour,
    required this.onTap,
  });

  final String name;
  final String rate;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (figure, unit) = _figure(rate);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: OniColors.surface,
          border: Border.all(color: OniColors.border),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration:
                  BoxDecoration(color: colour, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OniType.body
                      .copyWith(fontSize: 11.5, color: OniColors.textMuted)),
            ),
            const SizedBox(width: 6),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: figure,
                    style: OniType.numberSmall.copyWith(
                        fontSize: 11,
                        color: OniColors.text,
                        fontWeight: FontWeight.w700),
                  ),
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: ' $unit',
                      style: OniType.numberSmall
                          .copyWith(fontSize: 10, color: OniColors.textFaint),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Inspect extends StatelessWidget {
  const _Inspect({
    required this.database,
    required this.spec,
    required this.times,
    required this.onTimes,
    this.onReport,
  });

  final GameDatabase database;
  final ProcessSpec spec;
  final int times;
  final ValueChanged<int> onTimes;
  final void Function(ProcessSpec)? onReport;

  String _rate(Port port) =>
      database.item(port.itemId)?.formatRate(
          port.ratePerSecond * times, RateDisplay.perCycle, precision: 2) ??
      (port.ratePerSecond * times * secondsPerCycle).toStringAsFixed(2);

  String _name(String itemId) => database.item(itemId)?.name ?? itemId;

  @override
  Widget build(BuildContext context) {
    final drift = massDrift(database, spec);
    final mass = massOf(database, spec);

    return ListView(
      padding: const EdgeInsets.all(OniSpacing.lg),
      children: [
        if (spec.description case final String said) ...[
          Text(said,
              style: OniType.body
                  .copyWith(fontSize: 12, color: OniColors.textFaint)),
          const SizedBox(height: OniSpacing.lg),
        ],
        Row(
          children: [
            Text('AT ONCE', style: OniType.label),
            const SizedBox(width: OniSpacing.sm),
            for (final n in const [1, 2, 5, 10])
              Padding(
                padding: const EdgeInsets.only(right: OniSpacing.xs),
                child: OniButton(
                  label: '×$n',
                  compact: true,
                  tone: n == times
                      ? OniButtonTone.accent
                      : OniButtonTone.neutral,
                  onPressed: () => onTimes(n),
                ),
              ),
          ],
        ),
        const SizedBox(height: OniSpacing.lg),
        Text('TAKES', style: OniType.label),
        for (final port in spec.inputs)
          _PortLine(name: _name(port.itemId), rate: _rate(port)),
        if (spec.inputs.isEmpty)
          Text('nothing', style: OniType.body.copyWith(fontSize: 12)),
        const SizedBox(height: OniSpacing.md),
        Text('GIVES', style: OniType.label),
        for (final port in spec.outputs)
          _PortLine(name: _name(port.itemId), rate: _rate(port)),
        const SizedBox(height: OniSpacing.lg),
        if (drift != null) ...[
          Text('WHAT IT DOES TO MATTER', style: OniType.label),
          const SizedBox(height: 2),
          Text(
            '${(mass.input * times * secondsPerCycle / 1000).toStringAsFixed(1)} kg in, '
            '${(mass.output * times * secondsPerCycle / 1000).toStringAsFixed(1)} kg out '
            '— ${drift.abs() < 0.005 ? 'the same' : '${(drift * 100).toStringAsFixed(0)} %'}'
            '${drift.abs() < 0.005 ? '' : drift > 0 ? ' more than went in' : ' of what went in'}.',
            style: OniType.body.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            'Weighable things only, so calories, power, heat and a plant\\u2019s '
            'growth are left out. A recipe that makes matter is not always '
            'wrong — a Hatch gives back half of what it eats and that is the '
            'point of it — but it is the first thing to check.',
            style: OniType.body
                .copyWith(fontSize: 11, color: OniColors.textFaint),
          ),
          const SizedBox(height: OniSpacing.lg),
        ],
        if (onReport != null)
          Align(
            alignment: Alignment.centerLeft,
            child: OniButton(
              label: 'This number looks wrong',
              compact: true,
              onPressed: () => onReport!(spec),
            ),
          ),
      ],
    );
  }
}

class _PortLine extends StatelessWidget {
  const _PortLine({required this.name, required this.rate});

  final String name;
  final String rate;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(rate,
                  textAlign: TextAlign.right, style: OniType.numberSmall),
            ),
            const SizedBox(width: OniSpacing.sm),
            Expanded(
                child:
                    Text(name, style: OniType.body.copyWith(fontSize: 12))),
          ],
        ),
      );
}
