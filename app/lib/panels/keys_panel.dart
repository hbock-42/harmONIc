import 'package:flutter/widgets.dart';

import '../design/keys.dart';
import '../design/tokens.dart';
import '../design/widgets.dart';

/// One row of the keys card: what to press, and what it does.
typedef KeyLine = (String keys, String does);

/// The keys, in groups, in the order somebody would want them.
///
/// Written in the Apple spelling and translated on the way to the screen, so
/// that there is one list rather than two that can disagree.
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
  ('Finding things', [
    ('⌘F', 'find a node  ·  ⏎ for the next'),
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
  const KeysPanel({required this.apple, this.onDismiss, super.key});

  /// Whether to spell them ⌘Z or Ctrl+Z.
  final bool apple;

  /// Null while it is being held open: there is nothing to press, and a
  /// dismiss target under a held key would only be in the way.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onDismiss,
        child: Container(
          color: const Color(0xCC000000),
        // Against the right edge, beside the inspector, for the same reason
        // the guide is: what you are pressing these keys at is the canvas, and
        // it should stay visible while you look them up.
          alignment: Alignment.centerRight,
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
                            // On the baseline, not the top of the box: the
                            // keys are set in a monospace face at a different
                            // size from the words beside them, so the two
                            // columns only look like one line if the letters
                            // sit on the same line rather than the boxes.
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              // A fixed column, so the keys line up and the
                              // eye can run down them without reading.
                              SizedBox(
                                width: 116,
                                child: Text(
                                  chord(keys, apple: apple),
                                  style: OniType.numberSmall.copyWith(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: OniColors.accent,
                                  ),
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
