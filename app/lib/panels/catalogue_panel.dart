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
/// Grouped by what comes out and sorted by how much, because that is how a
/// wrong figure shows itself. A Pip gives 20 kg of dirt a cycle and a Cuddle
/// Pip five eighths of that; while the Pip was wrong it sat *below* the Cuddle
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

/// The families, in the order somebody would look for them.
enum _Family {
  critters('Critters'),
  plants('Plants'),
  food('Cooking'),
  refining('Refining'),
  power('Power'),
  everything('Everything');

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

class _CataloguePanelState extends State<CataloguePanel> {
  final TextEditingController _search = TextEditingController();
  _Family _family = _Family.critters;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final groups = [
      for (final group in madeBy(widget.database, where: _family.matches))
        if (query.isEmpty || _hits(group, query)) group,
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
            title: 'Every figure',
            width: 720,
            trailing: OniButton(
              label: 'Close',
              compact: true,
              onPressed: widget.onClose,
            ),
            child: Column(
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
                      Wrap(
                        spacing: OniSpacing.xs,
                        runSpacing: OniSpacing.xs,
                        children: [
                          for (final family in _Family.values)
                            OniButton(
                              label: family.label,
                              compact: true,
                              tone: family == _family
                                  ? OniButtonTone.accent
                                  : OniButtonTone.neutral,
                              onPressed: () =>
                                  setState(() => _family = family),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(OniSpacing.md, 0,
                        OniSpacing.md, OniSpacing.lg),
                    children: [
                      Text(
                        'Read down a list, not across it. Two things that make '
                        'the same stuff should be within reach of each other, '
                        'and the one that is not is the one to check. Rates '
                        'are per cycle.',
                        style: OniType.body.copyWith(
                            fontSize: 11.5, color: OniColors.textFaint),
                      ),
                      const SizedBox(height: OniSpacing.md),
                      for (final group in groups)
                        _MadeBySection(
                          group: group,
                          database: widget.database,
                          onReport: widget.onReport,
                        ),
                      if (groups.isEmpty)
                        Text('Nothing here makes anything called "$query".',
                            style: OniType.body),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _hits(MadeBy group, String query) {
    final item = widget.database.item(group.itemId)?.name ?? group.itemId;
    if (item.toLowerCase().contains(query)) return true;
    return group.makers.any((m) => m.spec.name.toLowerCase().contains(query));
  }
}

class _MadeBySection extends StatelessWidget {
  const _MadeBySection({
    required this.group,
    required this.database,
    this.onReport,
  });

  final MadeBy group;
  final GameDatabase database;
  final void Function(ProcessSpec spec)? onReport;

  /// Per cycle, which is how the game quotes a recipe and how anybody
  /// checking one thinks. Grams a second is right for a pipe and wrong for a
  /// Hatch.
  String _perCycle(String itemId, double ratePerSecond) {
    final item = database.item(itemId);
    return item?.formatRate(ratePerSecond, RateDisplay.perCycle, precision: 2) ??
        (ratePerSecond * secondsPerCycle).toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final name = database.item(group.itemId)?.name ?? group.itemId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(name.toUpperCase(), style: OniType.label),
        ),
        for (final maker in group.makers)
          _MakerRow(
            maker: maker,
            made: _perCycle(group.itemId, maker.made.ratePerSecond),
            takes: [
              for (final port in maker.takes)
                '${database.item(port.itemId)?.name ?? port.itemId} '
                    '${_perCycle(port.itemId, port.ratePerSecond)}',
            ].join(' · '),
            onReport: onReport,
          ),
        const SizedBox(height: OniSpacing.md),
      ],
    );
  }
}

class _MakerRow extends StatefulWidget {
  const _MakerRow({
    required this.maker,
    required this.made,
    required this.takes,
    this.onReport,
  });

  final Maker maker;
  final String made;
  final String takes;
  final void Function(ProcessSpec spec)? onReport;

  @override
  State<_MakerRow> createState() => _MakerRowState();
}

class _MakerRowState extends State<_MakerRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final unverified = widget.maker.spec.tags.contains('unverified');
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        color: _hover ? OniColors.surfaceHover : null,
        padding: const EdgeInsets.symmetric(
            horizontal: OniSpacing.sm, vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(
                widget.made,
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
                    widget.maker.spec.name +
                        (unverified ? '  ·  unverified' : ''),
                    style: OniType.body.copyWith(
                      fontSize: 12,
                      color: unverified ? OniColors.warning : null,
                    ),
                  ),
                  if (widget.takes.isNotEmpty)
                    Text(
                      'from ${widget.takes}',
                      style: OniType.numberSmall
                          .copyWith(color: OniColors.textFaint),
                    ),
                ],
              ),
            ),
            if (_hover && widget.onReport != null)
              GestureDetector(
                onTap: () => widget.onReport!(widget.maker.spec),
                child: Text('wrong?',
                    style: OniType.numberSmall
                        .copyWith(color: OniColors.accent)),
              ),
          ],
        ),
      ),
    );
  }
}
