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
/// Both, because checking a figure means seeing it beside its neighbours and a
/// recipe has two sides. An Orehull's 20 kg of nori a cycle means nothing on
/// its own and something next to everything else that eats nori.
enum _Way {
  made('What makes it'),
  used('What eats it');

  const _Way(this.label);
  final String label;
}

/// How much of a row to show at once.
enum _Density {
  detailed('Cards'),
  compact('Rows'),
  table('Table');

  const _Density(this.label);
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

/// Whether a figure is the game's or ours.
enum _Trust {
  all('All'),
  verified('Published'),
  unverified('Judged');

  const _Trust(this.label);
  final String label;

  bool matches(ProcessSpec spec) => switch (this) {
        _Trust.all => true,
        _Trust.verified => !spec.tags.contains('unverified'),
        _Trust.unverified => spec.tags.contains('unverified'),
      };
}

class _CataloguePanelState extends State<CataloguePanel> {
  final TextEditingController _search = TextEditingController();
  _Way _way = _Way.made;
  _Density _density = _Density.compact;
  _Family _family = _Family.critters;
  _Trust _trust = _Trust.all;

  /// Everything shown at this many of each thing, for checking a ratio in
  /// your head without doing the multiplication.
  int _times = 1;

  ProcessSpec? _inspecting;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _keep(ProcessSpec spec) => _family.matches(spec) && _trust.matches(spec);

  String _itemName(String itemId) =>
      widget.database.item(itemId)?.name ?? itemId;

  /// Per cycle, which is how the game quotes a recipe and how anybody
  /// checking one thinks. Grams a second is right for a pipe, wrong for a
  /// Hatch.
  String _rate(String itemId, double ratePerSecond) {
    final scaled = ratePerSecond * _times;
    return widget.database
            .item(itemId)
            ?.formatRate(scaled, RateDisplay.perCycle, precision: 2) ??
        (scaled * secondsPerCycle).toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final sections = _way == _Way.made
        ? [
            for (final group in madeBy(widget.database, where: _keep))
              _Section.made(group, _itemName(group.itemId))
          ]
        : [
            for (final group in usedBy(widget.database, where: _keep))
              _Section.used(group, _itemName(group.itemId))
          ];
    final shown = [
      for (final section in sections)
        if (section.matches(query)) section,
    ];

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
            width: 760,
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
                  label: 'Close',
                  compact: true,
                  onPressed: widget.onClose,
                ),
              ],
            ),
            child: _inspecting == null
                ? _browse(shown)
                : _Inspect(
                    database: widget.database,
                    spec: _inspecting!,
                    times: _times,
                    onTimes: (n) => setState(() => _times = n),
                    onReport: widget.onReport,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _browse(List<_Section> shown) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(OniSpacing.md),
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
                _chips<_Way>(_Way.values, _way, (v) => v.label,
                    (v) => setState(() => _way = v)),
                const SizedBox(height: OniSpacing.xs),
                _chips<_Family>(_Family.values, _family, (v) => v.label,
                    (v) => setState(() => _family = v)),
                const SizedBox(height: OniSpacing.xs),
                Row(
                  children: [
                    _chips<_Density>(_Density.values, _density, (v) => v.label,
                        (v) => setState(() => _density = v)),
                    const SizedBox(width: OniSpacing.md),
                    _chips<_Trust>(_Trust.values, _trust, (v) => v.label,
                        (v) => setState(() => _trust = v)),
                  ],
                ),
                const SizedBox(height: OniSpacing.xs),
                Row(
                  children: [
                    Text('AT ONCE', style: OniType.label),
                    const SizedBox(width: OniSpacing.sm),
                    _chips<int>(const [1, 2, 5, 10], _times, (n) => '×$n',
                        (n) => setState(() => _times = n)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  OniSpacing.md, 0, OniSpacing.md, OniSpacing.lg),
              children: [
                Text(
                  _way == _Way.made
                      ? 'Read down a list rather than across it. Two things '
                          'making the same stuff belong near each other, and '
                          'the one that does not is the one to check.'
                      : 'What everything spends, so a cost has neighbours: an '
                          'Orehull eating 20 kg of nori a cycle means '
                          'something beside everything else that eats nori.',
                  style: OniType.body
                      .copyWith(fontSize: 11.5, color: OniColors.textFaint),
                ),
                const SizedBox(height: OniSpacing.md),
                for (final section in shown) ..._section(section),
                if (shown.isEmpty)
                  Text('Nothing here matches that.', style: OniType.body),
              ],
            ),
          ),
        ],
      );

  Widget _chips<T>(List<T> values, T current, String Function(T) label,
          void Function(T) pick) =>
      Wrap(
        spacing: OniSpacing.xs,
        runSpacing: OniSpacing.xs,
        children: [
          for (final value in values)
            OniButton(
              label: label(value),
              compact: true,
              tone: value == current
                  ? OniButtonTone.accent
                  : OniButtonTone.neutral,
              onPressed: () => pick(value),
            ),
        ],
      );

  List<Widget> _section(_Section section) => [
        Padding(
          padding: const EdgeInsets.only(bottom: 4, top: 4),
          child: Row(
            children: [
              Text(section.title.toUpperCase(), style: OniType.label),
              const SizedBox(width: OniSpacing.sm),
              Text('${section.rows.length}',
                  style: OniType.numberSmall
                      .copyWith(color: OniColors.textFaint)),
            ],
          ),
        ),
        if (_density == _Density.table)
          _Table(rows: section.rows, rate: _rate, onOpen: _open)
        else
          for (final row in section.rows)
            _Row(
              row: row,
              detailed: _density == _Density.detailed,
              rate: _rate,
              itemName: _itemName,
              onOpen: () => _open(row.spec),
              onReport: widget.onReport,
            ),
        const SizedBox(height: OniSpacing.md),
      ];

  void _open(ProcessSpec spec) => setState(() => _inspecting = spec);
}

/// One heading and the rows under it, whichever way round the list is.
class _Section {
  _Section({required this.title, required this.rows});

  factory _Section.made(MadeBy group, String title) => _Section(
        title: title,
        rows: [
          for (final maker in group.makers)
            _Line(
              spec: maker.spec,
              itemId: group.itemId,
              rate: maker.made.ratePerSecond,
              others: maker.takes,
              othersLead: 'from',
            ),
        ],
      );

  factory _Section.used(UsedBy group, String title) => _Section(
        title: title,
        rows: [
          for (final taker in group.takers)
            _Line(
              spec: taker.spec,
              itemId: group.itemId,
              rate: taker.takes.ratePerSecond,
              others: taker.makes,
              othersLead: 'for',
            ),
        ],
      );

  final String title;
  final List<_Line> rows;

  bool matches(String query) {
    if (query.isEmpty) return true;
    if (title.toLowerCase().contains(query)) return true;
    return rows.any((row) => row.spec.name.toLowerCase().contains(query));
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

class _Row extends StatefulWidget {
  const _Row({
    required this.row,
    required this.detailed,
    required this.rate,
    required this.itemName,
    required this.onOpen,
    this.onReport,
  });

  final _Line row;
  final bool detailed;
  final String Function(String, double) rate;
  final String Function(String) itemName;
  final VoidCallback onOpen;
  final void Function(ProcessSpec)? onReport;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final spec = widget.row.spec;
    final judged = spec.tags.contains('unverified');
    final others = [
      for (final port in widget.row.others)
        '${widget.itemName(port.itemId)} '
            '${widget.rate(port.itemId, port.ratePerSecond)}',
    ].join('  ·  ');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: Container(
          margin: EdgeInsets.only(bottom: widget.detailed ? 6 : 0),
          decoration: BoxDecoration(
            color: _hover ? OniColors.surfaceHover : null,
            borderRadius: BorderRadius.circular(4),
            border: widget.detailed
                ? Border.all(
                    color: _hover ? OniColors.borderStrong : OniColors.border)
                : null,
          ),
          padding: EdgeInsets.symmetric(
              horizontal: OniSpacing.sm, vertical: widget.detailed ? 8 : 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 104,
                child: Text(
                  widget.rate(widget.row.itemId, widget.row.rate),
                  textAlign: TextAlign.right,
                  style: OniType.numberSmall,
                ),
              ),
              const SizedBox(width: OniSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.name + (judged ? '  ·  judged' : ''),
                      style: OniType.body.copyWith(
                        fontSize: 12,
                        color: judged ? OniColors.warning : null,
                      ),
                    ),
                    if (others.isNotEmpty)
                      Text('${widget.row.othersLead} $others',
                          style: OniType.numberSmall
                              .copyWith(color: OniColors.textFaint)),
                    if (widget.detailed && spec.description != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          spec.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: OniType.body.copyWith(
                              fontSize: 11, color: OniColors.textFaint),
                        ),
                      ),
                  ],
                ),
              ),
              if (_hover && widget.onReport != null)
                GestureDetector(
                  onTap: () => widget.onReport!(spec),
                  child: Text('wrong?',
                      style: OniType.numberSmall
                          .copyWith(color: OniColors.accent)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The same rows as a spreadsheet, for scanning a column rather than reading.
class _Table extends StatelessWidget {
  const _Table({required this.rows, required this.rate, required this.onOpen});

  final List<_Line> rows;
  final String Function(String, double) rate;
  final void Function(ProcessSpec) onOpen;

  @override
  Widget build(BuildContext context) => Table(
        columnWidths: const {
          0: FixedColumnWidth(110),
          1: FlexColumnWidth(),
          2: FixedColumnWidth(90),
        },
        children: [
          for (final row in rows)
            TableRow(children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(rate(row.itemId, row.rate),
                    textAlign: TextAlign.right, style: OniType.numberSmall),
              ),
              GestureDetector(
                onTap: () => onOpen(row.spec),
                child: Padding(
                  padding: const EdgeInsets.only(left: OniSpacing.sm),
                  child: Text(row.spec.name,
                      style: OniType.body.copyWith(fontSize: 12)),
                ),
              ),
              Text(
                row.spec.tags.contains('unverified') ? 'judged' : '',
                style:
                    OniType.numberSmall.copyWith(color: OniColors.warning),
              ),
            ]),
        ],
      );
}

/// One recipe, whole: what goes in, what comes out, and what it does to
/// matter on the way through.
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
