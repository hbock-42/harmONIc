import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import '../design/item_glyph.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';
import '../state/library_controller.dart';

/// Named so a test can pick what kind of thing it is inventing.
Key newItemKindKey(ItemCategory kind) => ValueKey('new-item-${kind.name}');

/// Named so a test can type into the right one of several weights.
Key costKilogramsFieldKey(int index) => ValueKey('cost-kg-$index');

/// A form for writing down a recipe the app does not know.
///
/// The wiki lags every DLC and never publishes some numbers at all, so this is
/// the escape hatch: measure it in game, type it in, use it immediately.
class ProcessEditor extends StatefulWidget {
  const ProcessEditor({
    required this.library,
    required this.spec,
    required this.onClose,
    this.offersItem = _anyItem,
    super.key,
  });

  final LibraryController library;

  /// Whether an item belongs in the picker. A pack switched off should not come
  /// back here either — this is the third door into the catalogue.
  final bool Function(Item) offersItem;

  static bool _anyItem(Item item) => true;
  final ProcessSpec spec;
  final VoidCallback onClose;

  @override
  State<ProcessEditor> createState() => _ProcessEditorState();
}

class _PortDraft {
  _PortDraft({
    required this.itemId,
    required this.direction,
    required String rate,
  }) : rate = TextEditingController(text: rate);

  String itemId;
  PortDirection direction;
  final TextEditingController rate;
}

/// One line of "what it takes to put one up": a material and a weight.
class _CostDraft {
  _CostDraft({required this.itemId, required String kilograms})
      : kilograms = TextEditingController(text: kilograms);

  String itemId;
  final TextEditingController kilograms;
}

class _ProcessEditorState extends State<ProcessEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.spec.name);
  late final TextEditingController _power = TextEditingController(
      text: _trim(widget.spec.netPowerWatts));
  late final TextEditingController _heat =
      TextEditingController(text: _trim(widget.spec.netHeatKdtu));
  late ProcessKind _kind = widget.spec.kind;
  late final List<_PortDraft> _ports = [
    for (final port in widget.spec.ports)
      if (port.itemId != WellKnownItems.power &&
          port.itemId != WellKnownItems.heat)
        _PortDraft(
          itemId: port.itemId,
          direction: port.direction,
          rate: _trim(port.ratePerSecond),
        ),
  ];

  /// What it costs to build, in the same shape as the ports. Carried over from
  /// whatever is being edited: overriding a Metal Refinery's rates should not
  /// quietly throw away the 800 kg of rock it is made of.
  late final List<_CostDraft> _costs = [
    for (final entry in widget.spec.buildCost.entries)
      _CostDraft(itemId: entry.key, kilograms: _trim(entry.value)),
  ];

  final List<Item> _newItems = [];
  String? _error;

  static String _trim(double value) {
    if (value == 0) return '';
    final fixed = value.toStringAsFixed(4);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  @override
  void dispose() {
    _name.dispose();
    _power.dispose();
    _heat.dispose();
    for (final port in _ports) {
      port.rate.dispose();
    }
    for (final cost in _costs) {
      cost.kilograms.dispose();
    }
    super.dispose();
  }

  GameDatabase get _db => widget.library.database;

  Item? _item(String id) {
    for (final item in _newItems) {
      if (item.id == id) return item;
    }
    return _db.item(id);
  }

  Future<void> _save() async {
    final ports = <Port>[];
    final seen = <String>{};
    for (final draft in _ports) {
      final rate = double.tryParse(draft.rate.text.trim());
      if (draft.itemId.isEmpty) {
        setState(() => _error = 'Every line needs an item.');
        return;
      }
      if (rate == null || rate < 0) {
        setState(() => _error = 'Every line needs a rate of 0 or more.');
        return;
      }
      // Two ports for the same item need distinct ids, as a coolant loop does.
      var id = draft.itemId;
      var suffix = 2;
      while (!seen.add(id)) {
        id = '${draft.itemId}_$suffix';
        suffix++;
      }
      ports.add(Port(
        id: id,
        itemId: draft.itemId,
        direction: draft.direction,
        ratePerSecond: rate,
      ));
    }

    final power = double.tryParse(_power.text.trim()) ?? 0;
    final heat = double.tryParse(_heat.text.trim()) ?? 0;
    if (power > 0) {
      ports.add(Port(
        id: 'power_in',
        itemId: WellKnownItems.power,
        direction: PortDirection.input,
        ratePerSecond: power,
      ));
    } else if (power < 0) {
      ports.add(Port(
        id: 'power_out',
        itemId: WellKnownItems.power,
        direction: PortDirection.output,
        ratePerSecond: -power,
      ));
    }
    if (heat != 0) {
      ports.add(Port(
        id: heat > 0 ? 'heat_out' : 'heat_in',
        itemId: WellKnownItems.heat,
        direction: heat > 0 ? PortDirection.output : PortDirection.input,
        ratePerSecond: heat.abs(),
      ));
    }

    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give it a name.');
      return;
    }

    final buildCost = <String, double>{};
    for (final draft in _costs) {
      final kilograms = double.tryParse(draft.kilograms.text.trim());
      if (draft.itemId.isEmpty) {
        setState(() => _error = 'Every line needs an item.');
        return;
      }
      if (kilograms == null || kilograms <= 0) {
        setState(() => _error = 'What it is built from needs a weight.');
        return;
      }
      buildCost[draft.itemId] = kilograms;
    }

    await widget.library.save(
      ProcessSpec(
        id: widget.spec.id,
        name: name,
        kind: _kind,
        ports: ports,
        buildingId: widget.spec.buildingId,
        dupeLabourSecondsPerCycle: widget.spec.dupeLabourSecondsPerCycle,
        footprintWidth: widget.spec.footprintWidth,
        footprintHeight: widget.spec.footprintHeight,
        buildCost: buildCost,
        // No field of its own: a building the game rates itself keeps its
        // rating through an edit of its rates, since one has nothing to do
        // with the other.
        overheatCelsius: widget.spec.overheatCelsius,
        tags: {...widget.spec.tags, 'custom', 'unverified'},
        description: 'UNVERIFIED: entered by hand.',
      ),
      newItems: _newItems,
    );
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final overriding = _db.process(widget.spec.id) != null &&
        widget.library.bundled.process(widget.spec.id) != null;

    return Container(
      width: 520,
      constraints: const BoxConstraints(maxHeight: 620),
      decoration: BoxDecoration(
        color: OniColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OniColors.borderStrong),
        boxShadow: const [
          BoxShadow(color: Color(0xAA000000), blurRadius: 32, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(OniSpacing.lg, OniSpacing.lg,
                OniSpacing.lg, OniSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    overriding ? 'Correct a recipe' : 'Add a recipe',
                    style: OniType.heading,
                  ),
                ),
                OniButton(
                  label: 'Cancel',
                  compact: true,
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),
          if (overriding)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: OniSpacing.lg),
              child: Text(
                'Your numbers replace the ones that ship with the app. You can '
                'put them back later.',
                style: OniType.body
                    .copyWith(fontSize: 11.5, color: OniColors.textFaint),
              ),
            ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.all(OniSpacing.lg),
              children: [
                _label('Name'),
                OniField(controller: _name, hint: 'Beakon'),
                const SizedBox(height: OniSpacing.md),
                _label('Kind'),
                Row(
                  children: [
                    for (final kind in const [
                      ProcessKind.building,
                      ProcessKind.critter,
                      ProcessKind.plant,
                      ProcessKind.custom,
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: OniSpacing.sm),
                        child: OniButton(
                          label: kind.name,
                          compact: true,
                          tone: _kind == kind
                              ? OniButtonTone.accent
                              : OniButtonTone.neutral,
                          onPressed: () => setState(() => _kind = kind),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: OniSpacing.lg),
                _label('Consumes and produces  (per second)'),
                for (final draft in _ports) _portRow(draft),
                const SizedBox(height: OniSpacing.sm),
                Row(
                  children: [
                    OniButton(
                      label: '+ Consumes',
                      compact: true,
                      onPressed: () => setState(() => _ports.add(_PortDraft(
                            itemId: '',
                            direction: PortDirection.input,
                            rate: '',
                          ))),
                    ),
                    const SizedBox(width: OniSpacing.sm),
                    OniButton(
                      label: '+ Produces',
                      compact: true,
                      onPressed: () => setState(() => _ports.add(_PortDraft(
                            itemId: '',
                            direction: PortDirection.output,
                            rate: '',
                          ))),
                    ),
                  ],
                ),
                const SizedBox(height: OniSpacing.lg),
                _label('To build one  (kg)'),
                for (final (index, draft) in _costs.indexed)
                  _costRow(draft, index),
                const SizedBox(height: OniSpacing.sm),
                OniButton(
                  label: '+ Built from',
                  compact: true,
                  onPressed: () => setState(
                      () => _costs.add(_CostDraft(itemId: '', kilograms: ''))),
                ),
                const SizedBox(height: OniSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Power (W, negative generates)'),
                          OniField(controller: _power, hint: '0'),
                        ],
                      ),
                    ),
                    const SizedBox(width: OniSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Heat (kDTU/s)'),
                          OniField(controller: _heat, hint: '0'),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: OniSpacing.md),
                  Text(_error!,
                      style: OniType.body
                          .copyWith(fontSize: 12, color: OniColors.danger)),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(OniSpacing.lg),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: OniColors.border)),
            ),
            child: Row(
              children: [
                if (widget.library.isCustom(widget.spec.id))
                  OniButton(
                    label: overriding ? 'Restore original' : 'Delete',
                    tone: OniButtonTone.danger,
                    compact: true,
                    onPressed: () async {
                      await widget.library.revert(widget.spec.id);
                      widget.onClose();
                    },
                  ),
                const Spacer(),
                OniButton(
                  label: 'Save',
                  tone: OniButtonTone.accent,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(text.toUpperCase(), style: OniType.label),
      );

  Widget _costRow(_CostDraft draft, int index) => Padding(
        padding: const EdgeInsets.only(bottom: OniSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: _ItemPicker(
                database: _db,
                offersItem: widget.offersItem,
                extraItems: _newItems,
                selected: _item(draft.itemId),
                onSelected: (id) => setState(() => draft.itemId = id),
                onCreate: (created) => setState(() {
                  _newItems.add(created);
                  draft.itemId = created.id;
                }),
              ),
            ),
            const SizedBox(width: OniSpacing.sm),
            SizedBox(
              width: 84,
              child: OniField(
                key: costKilogramsFieldKey(index),
                controller: draft.kilograms,
                hint: 'kg',
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: OniSpacing.xs),
            OniButton(
              label: '×',
              compact: true,
              tone: OniButtonTone.danger,
              onPressed: () => setState(() => _costs.remove(draft)),
            ),
          ],
        ),
      );

  Widget _portRow(_PortDraft draft) {
    final item = _item(draft.itemId);
    return Padding(
      padding: const EdgeInsets.only(bottom: OniSpacing.sm),
      child: Row(
        children: [
          OniButton(
            label: draft.direction == PortDirection.input ? 'in' : 'out',
            compact: true,
            tone: draft.direction == PortDirection.input
                ? OniButtonTone.neutral
                : OniButtonTone.accent,
            onPressed: () => setState(() => draft.direction =
                draft.direction == PortDirection.input
                    ? PortDirection.output
                    : PortDirection.input),
          ),
          const SizedBox(width: OniSpacing.sm),
          Expanded(
            child: _ItemPicker(
              database: _db,
              offersItem: widget.offersItem,
              extraItems: _newItems,
              selected: item,
              onSelected: (id) => setState(() => draft.itemId = id),
              onCreate: (created) => setState(() {
                _newItems.add(created);
                draft.itemId = created.id;
              }),
            ),
          ),
          const SizedBox(width: OniSpacing.sm),
          SizedBox(
            width: 84,
            child: OniField(
              controller: draft.rate,
              hint: 'g/s',
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: OniSpacing.xs),
          OniButton(
            label: '×',
            compact: true,
            tone: OniButtonTone.danger,
            onPressed: () => setState(() => _ports.remove(draft)),
          ),
        ],
      ),
    );
  }
}

/// The open picker's search box. Named so tests can drive it without guessing
/// its position among the form's other fields.
const Key itemPickerSearchKey = ValueKey('item-picker-search');

/// Picks an item, or invents one — because a DLC the app has not caught up with
/// brings new elements as well as new recipes.
class _ItemPicker extends StatefulWidget {
  const _ItemPicker({
    required this.database,
    required this.offersItem,
    required this.extraItems,
    required this.selected,
    required this.onSelected,
    required this.onCreate,
  });

  final GameDatabase database;
  final bool Function(Item) offersItem;
  final List<Item> extraItems;
  final Item? selected;
  final ValueChanged<String> onSelected;
  final ValueChanged<Item> onCreate;

  @override
  State<_ItemPicker> createState() => _ItemPickerState();
}

class _ItemPickerState extends State<_ItemPicker> {
  final TextEditingController _search = TextEditingController();
  bool _open = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Item> get _matches {
    final query = _search.text.trim().toLowerCase();
    // Items you invented are always offered: you made them, so you have them.
    final all = [
      ...widget.database.items.where(widget.offersItem),
      ...widget.extraItems,
    ];
    if (query.isEmpty) return all.take(40).toList();
    return all
        .where((i) => i.name.toLowerCase().contains(query))
        .take(40)
        .toList();
  }

  /// What kind of thing the one being invented is.
  ///
  /// Solid unless somebody says otherwise, because most materials are. The
  /// choice decides more than the icon: what carries it (a rail or a pipe),
  /// whether it gets a pump, whether it can be filtered, and whether a
  /// temperature can be worked out for it at all. Inventing a liquid and
  /// being given a conveyor belt is a wrong answer, not a cosmetic one.
  ItemCategory _newKind = ItemCategory.solid;

  void _create() {
    final name = _search.text.trim();
    if (name.isEmpty) return;
    final id = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    widget.onCreate(
      Item(id: id, name: name, category: _newKind, tags: const {'custom'}),
    );
    setState(() {
      _open = false;
      _newKind = ItemCategory.solid;
      _search.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return GestureDetector(
        onTap: () => setState(() => _open = true),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: OniColors.background,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: OniColors.border),
            ),
            child: Row(
              children: [
                if (widget.selected != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OniItemGlyph(category: widget.selected!.category),
                  ),
                Expanded(
                  child: Text(
                    widget.selected?.name ?? 'Choose an item…',
                    style: OniType.body.copyWith(
                      fontSize: 12,
                      color: widget.selected == null
                          ? OniColors.textFaint
                          : OniColors.text,
                    ),
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

    final matches = _matches;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        OniField(
          key: itemPickerSearchKey,
          controller: _search,
          hint: 'Search or type a new name…',
          clearable: true,
          autofocus: true,
          onChanged: (_) => setState(() {}),
        ),
        Container(
          constraints: const BoxConstraints(maxHeight: 160),
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: OniColors.surfaceRaised,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: OniColors.border),
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final item in matches)
                GestureDetector(
                  onTap: () {
                    widget.onSelected(item.id);
                    setState(() {
                      _open = false;
                      _search.clear();
                    });
                  },
                  child: Container(
                    color: OniColors.surfaceRaised,
                    padding: const EdgeInsets.symmetric(
                        horizontal: OniSpacing.sm, vertical: 5),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: OniItemGlyph(category: item.category),
                        ),
                        Expanded(
                          child: Text(item.name,
                              style: OniType.body.copyWith(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_search.text.trim().isNotEmpty && matches.isEmpty)
                Container(
                  color: OniColors.surfaceRaised,
                  padding: const EdgeInsets.all(OniSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // The three that behave differently. Power, heat and the
                      // rest are the app's own vocabulary rather than
                      // materials anybody needs to invent.
                      Wrap(
                        spacing: OniSpacing.xs,
                        children: [
                          for (final kind in const [
                            ItemCategory.solid,
                            ItemCategory.liquid,
                            ItemCategory.gas,
                          ])
                            OniButton(
                              key: newItemKindKey(kind),
                              label: kind.name,
                              compact: true,
                              tone: _newKind == kind
                                  ? OniButtonTone.accent
                                  : OniButtonTone.neutral,
                              onPressed: () =>
                                  setState(() => _newKind = kind),
                            ),
                        ],
                      ),
                      const SizedBox(height: OniSpacing.xs),
                      GestureDetector(
                        onTap: _create,
                        child: Text(
                          'Create "${_search.text.trim()}"',
                          style: OniType.body
                              .copyWith(fontSize: 12, color: OniColors.accent),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
