import 'package:flutter/widgets.dart';

import '../design/tokens.dart';
import '../design/widgets.dart';

/// One row of the keys card: what to press, and what it does.
typedef KeyLine = (String keys, String does);

/// The keys, in groups, in the order somebody would want them.
///
/// Written here rather than derived from the binding map, because the map is
/// nineteen entries and this is eleven lines: four arrow keys are one idea,
/// two ways to delete are one idea, and a card you can read at a glance is the
/// whole point. A test holds the two together so neither drifts.
const List<(String, List<KeyLine>)> kKeyGroups = [
  ('Editing', [
    ('⌘Z', 'undo'),
    ('⇧⌘Z', 'redo'),
    ('⌫', 'delete what is selected'),
    ('⌘C  ⌘V', 'copy and paste nodes'),
  ]),
  ('Moving about', [
    ('drag', 'select with a box'),
    ('space + drag', 'pan'),
    ('middle drag', 'pan'),
    ('arrow keys', 'nudge  ·  ⇧ for eight'),
  ]),
  ('Looking', [
    ('⌘=  ⌘−', 'zoom in and out'),
    ('⌘0', 'life size'),
    ('esc', 'select nothing'),
  ]),
];

/// A card of the keyboard shortcuts.
///
/// Held open by a key rather than opened and closed, so it can be glanced at
/// mid-drag without losing what you were doing — which is also why it is a
/// card of pairs and not the prose the guide keeps.
class KeysPanel extends StatelessWidget {
  const KeysPanel({this.onDismiss, super.key});

  /// Null while it is being held open: there is nothing to press, and a
  /// dismiss target under a held key would only be in the way.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: Container(
          color: const Color(0xCC000000),
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {},
            child: OniPanel(
              title: 'Keys',
              width: 420,
              trailing: onDismiss == null
                  ? null
                  : OniButton(
                      label: 'Close',
                      compact: true,
                      onPressed: onDismiss,
                    ),
              child: Padding(
                padding: const EdgeInsets.all(OniSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final (heading, lines) in kKeyGroups) ...[
                      Text(heading.toUpperCase(), style: OniType.label),
                      const SizedBox(height: OniSpacing.sm),
                      for (final (keys, does) in lines)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // A fixed column, so the keys line up and the
                              // eye can run down them without reading.
                              SizedBox(
                                width: 116,
                                child: Text(
                                  keys,
                                  style: OniType.numberSmall
                                      .copyWith(color: OniColors.accent),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  does,
                                  style: OniType.body.copyWith(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: OniSpacing.md),
                    ],
                    Text(
                      'Hold ? to see this again.',
                      style: OniType.body.copyWith(
                          fontSize: 11.5, color: OniColors.textFaint),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
